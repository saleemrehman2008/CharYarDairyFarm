import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../util/money.dart';
import 'accounting.dart';
import 'db.dart';
import 'log_service.dart';

class MonthRepo {
  MonthRepo._();

  /// The period the farm is currently booking into: the oldest period still
  /// marked open, or today's month if the farm has never closed one.
  static Stream<FarmMonth> watchOpen() => Db.months
      .where('status', isEqualTo: 'open')
      .snapshots()
      .map((q) {
        if (q.docs.isEmpty) {
          return FarmMonth(
            id: monthIdOf(DateTime.now()),
            status: 'open',
            openingCash: 0,
          );
        }
        final months = q.docs.map(FarmMonth.fromDoc).toList()
          ..sort((a, b) => a.id.compareTo(b.id));
        return months.first;
      })
      .map((m) {
        _bookingId = m.id;
        return m;
      });

  // ---- Which period a new entry belongs to ----

  static String _bookingId = monthIdOf(DateTime.now());
  static StreamSubscription<FarmMonth>? _bookingSub;

  /// The period a new entry is booked into — the open one, not the calendar
  /// month the clock says.
  ///
  /// These are usually the same. They part company the moment a period is
  /// sealed: from then until midnight, the calendar still says September while
  /// the farm is already trading in the next period, and an entry stamped
  /// `2026-09` would land in a period whose figures are frozen and already out
  /// with the co-founders. It would be counted by nobody.
  ///
  /// Only the booking changes. The entry's own date is still the day it
  /// happened, and that is what every screen shows.
  static String get bookingId => _bookingId;

  /// Keeps [bookingId] in step. Safe to call more than once.
  ///
  /// Only for people whose phone is allowed to read the periods — partners and
  /// the rider. A customer never writes to the ledger, so they never need it.
  static void trackBooking() {
    _bookingSub ??= watchOpen().listen(
      (_) {},
      onError: (Object _) {
        // No access, or no connection. The calendar month is a good enough
        // guess, and it is only ever wrong between a seal and midnight.
      },
    );
  }

  static Future<void> stopTracking() async {
    await _bookingSub?.cancel();
    _bookingSub = null;
  }

  /// Creates the period document the first time the farm books anything.
  static Future<void> ensureOpen(String monthId, {num openingCash = 0}) async {
    final ref = Db.months.doc(monthId);
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'status': 'open',
      'openingCash': openingCash,
      'from': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Master only. Freezes the period's figures and sends every co-founder
  /// their share to decide on.
  ///
  /// This is the moment that matters. The figures are written down here and
  /// never worked out again, so a co-founder who answers two days later is
  /// answering about the same money as the one who answered in two minutes.
  /// The next period opens in the same breath, which is what keeps it true:
  /// milk sold an hour after this is next period's milk, whatever the calendar
  /// says.
  ///
  /// Nothing is paid out and no share is posted. That waits for [close].
  static Future<void> seal({
    required Actor actor,
    required FarmMonth period,
    required Books books,
    required List<Partner> partners,
    required bool arIncluded,
    num carriedReceivable = 0,
  }) async {
    if (period.isFrozen) return;

    final now = DateTime.now();
    final profitToShare = books.profitToShare(
      arIncluded: arIncluded,
      carriedReceivable: carriedReceivable,
    );
    // A loss is split the same way a profit is, and comes back negative. It
    // used to be left at nothing on the reasoning that there is nothing to
    // hand out — true, but it meant a bad month vanished off four people's
    // accounts while the cash it cost was quietly gone. Every slice adds up
    // to what the period actually did, either way.
    final shares = shareOut(partners: partners, profit: profitToShare);

    final nextId = nextPeriodId(period.id, now);
    final batch = Db.fs.batch();

    batch.update(Db.months.doc(period.id), {
      'status': 'sealed',
      'to': Timestamp.fromDate(now),
      'sealedAt': Timestamp.fromDate(now),
      'sealedBy': actor.uid,
      'sealedByName': actor.name,
      'arIncluded': arIncluded,
      'sales': books.sales,
      'otherIncome': books.otherIncome,
      'purchases': books.purchases,
      'expenses': books.expenses,
      'receivables': books.receivable,
      // What this period held back from the sharing, so the next one can add
      // it in when the money actually comes. Zero when the profit was shared
      // as it was earned.
      'carriedReceivable': arIncluded ? 0 : books.receivable,
      // Kept so the all-time running-cost figure can leave cattle out without
      // re-reading the whole ledger.
      'assets': books.assetsBought,
      'profit': books.profit,
      'profitShared': profitToShare,
      'shares': shares.map((e) => e.toMap()).toList(),
      'seen': <String, dynamic>{},
    });

    // The next period starts with the cash trading actually left behind. What
    // the partners take out is not deducted here — it leaves the farm when it
    // is paid, which is after the close, and it is booked then.
    batch.set(Db.months.doc(nextId), {
      'status': 'open',
      'openingCash': books.operatingCash,
      'from': Timestamp.fromDate(now),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
    _bookingId = nextId;

    await Log.write(
      actor,
      LogKind.monthClose,
      profitToShare < 0
          ? 'sealed ${periodLabel(period)} at a loss of '
                '${rs(profitToShare.abs())}, split between '
                '${shares.length} co-founders'
          : 'sealed ${periodLabel(period)} at ${rs(profitToShare)} to share, '
                'and sent it to ${shares.length} co-founders',
      refType: 'month',
      refId: period.id,
    );
  }

  /// One co-founder says they have seen a closed period's figures.
  ///
  /// Not a decision and not a gate. Version 1 would not close until all four
  /// had said what they wanted doing with their share, and for four friends
  /// who have agreed to leave it all in for a year that is a lock with
  /// nothing behind it. What is worth keeping is the record that they were
  /// shown it — so this writes one key of one map, their own, and the master
  /// closes whenever he closes.
  static Future<void> markSeen({
    required Actor actor,
    required FarmMonth period,
    required String partnerId,
  }) async {
    if (period.seenBy(partnerId)) return;
    await Db.months.doc(period.id).update({
      'seen.$partnerId': Timestamp.fromDate(DateTime.now()),
    });
    await Log.write(
      actor,
      LogKind.monthClose,
      'saw the figures for ${periodLabel(period)}',
      refType: 'month',
      refId: period.id,
    );
  }

  /// Master only. Hands out a share of the profit and finishes the period.
  ///
  /// One percentage for all four, which is what makes the ratio fair: they
  /// all keep back the same proportion, so nobody ends up with more of their
  /// money working in the farm than their share of it reflects.
  ///
  /// [percent] of each slice goes out as cash; the rest goes into that
  /// partner's profit account. A period at a loss hands out nothing whatever
  /// the percentage says, and every slice of it lands in the profit accounts
  /// as a debit — a bad month is shared the way a good one is.
  ///
  /// Unpaid entries are not touched: they carry forward and stay in the
  /// receivables and payables until someone marks them paid.
  static Future<void> close({
    required Actor actor,
    required FarmMonth period,
    required int percent,
    List<FounderLoan> loans = const [],

    /// The co-founders as they stand, so a man who still owes on his
    /// promise has this month's profit put against it rather than into a
    /// second pile beside it. See [keptProfitGoes].
    List<Partner> partners = const [],
  }) async {
    if (!period.isSealed) {
      throw StateError('Seal the period before closing it.');
    }

    final now = DateTime.now();
    final handed = handOut(period.shares, percent);
    final batch = Db.fs.batch();

    batch.update(Db.months.doc(period.id), {
      'status': 'closed',
      'closedAt': Timestamp.fromDate(now),
      'closedBy': actor.uid,
      'closedByName': actor.name,
      'sharedPercent': percent.clamp(0, 100),
      'shares': handed.map((e) => e.toMap()).toList(),
    });

    for (final share in handed) {
      final ref = Db.partners.doc(share.partnerId);

      // What stayed in — or, on a bad month, what the loss took out.
      //
      // A man who has not finished paying his promise does not start a
      // second pile of money: what the month made for him goes onto what he
      // owes, and only the rest lands in his profit account. It is the same
      // rule his own spending follows, and it leaves the share ratio alone
      // because that follows what he is in for and not what has arrived.
      //
      // A losing month goes nowhere near it. A loss comes out of the profit
      // account where the gains went; nobody's capital is cut because the
      // farm had a bad October.
      final who = partners.where((p) => p.id == share.partnerId).firstOrNull;
      final split = keptProfitGoes(
        kept: share.held,
        pledged: who?.pledged ?? 0,
        invested: who?.invested ?? 0,
      );

      if (split.toProfit != 0) {
        batch.update(ref, {'profitHeld': FieldValue.increment(split.toProfit)});
      }
      if (split.toCapital > 0) {
        batch.update(ref, {'invested': FieldValue.increment(split.toCapital)});
        batch.set(Db.contributions.doc(), {
          'partnerId': share.partnerId,
          'partnerName': share.name,
          'kind': ContributionKind.investment.name,
          'source': ContributionSource.opening.name,
          'amount': split.toCapital,
          'date': Timestamp.fromDate(now),
          'payVia': PayVia.cash.name,
          'receivedBy': '',
          'note':
              'His share of ${monthName(period.id)}, put against what '
              'he still owes on his promise',
          'createdBy': actor.uid,
          'createdByName': actor.name,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (share.taken > 0) {
        batch.update(ref, {'withdrawn': FieldValue.increment(share.taken)});

        // An instalment on a loan comes off what they are handed, before the
        // cash does. In a month where nothing goes out there is nothing to
        // take it from, so it is skipped and the term runs on — which is
        // every month of the first year, by their own agreement, and they
        // can pay it in themselves whenever they like.
        final loan = _runningLoan(loans, share.partnerId);
        if (loan != null) {
          final due = loan.instalment < loan.left ? loan.instalment : loan.left;
          final taking = due < share.taken ? due : share.taken;
          if (taking > 0) {
            batch.set(Db.transactions.doc(), {
              'date': Timestamp.fromDate(now),
              'monthId': bookingId,
              'type': TxnType.receipt.name,
              'party': share.name,
              'category': loanRepaidCategory,
              'amount': taking,
              'paid': true,
              'paidAt': Timestamp.fromDate(now),
              'paidOnCreate': true,
              'note':
                  'Loan instalment – ${share.name} · '
                  '${periodLabel(period, short: true)}',
              // Whose hands it passed through. The farm's own account
              // keeps a man's instalment out of his share, so it is the
              // farm's account that takes it in.
              //
              // Left blank, these rows fell into the "Nobody named" line
              // on the card that asks who is holding the farm's cash, and
              // that line went further out of true with every month the
              // farm closed — an instalment on one side and a whole
              // period's profit share on the other, against a name that
              // is not a person.
              'handledBy': farmAccountName,
              'createdBy': actor.uid,
              'createdByName': actor.name,
              'createdAt': FieldValue.serverTimestamp(),
            });
            if (loan.repaid + taking >= loan.amount) {
              batch.update(Db.loans.doc(loan.id), {
                'state': LoanState.cleared.name,
              });
            }
          }
        }
        // Real money leaving the farm, so it is a payment row — booked into
        // the period that is open now, because that is when it leaves.
        batch.set(Db.transactions.doc(), {
          'date': Timestamp.fromDate(now),
          'monthId': bookingId,
          'type': TxnType.payment.name,
          'party': share.name,
          'category': profitShareCategory,
          'amount': share.taken,
          'paid': true,
          'paidAt': Timestamp.fromDate(now),
          'note':
              'Profit share – ${share.name} · '
              '${periodLabel(period, short: true)}',
          // Paid out of the farm's own account, which is where the money
          // a period made has been sitting. See the instalment above.
          'handledBy': farmAccountName,
          'createdBy': actor.uid,
          'createdByName': actor.name,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();

    final out = handed.fold<num>(0, (a, s) => a + s.taken);
    final inFarm = handed.fold<num>(0, (a, s) => a + s.held);
    await Log.write(
      actor,
      LogKind.monthClose,
      'closed ${periodLabel(period)} at $percent% out: ${rs(out)} handed '
      'over, ${rs(inFarm)} kept in the farm',
      refType: 'month',
      refId: period.id,
    );
  }

  /// The loan a co-founder is still paying off, if there is one.
  static FounderLoan? _runningLoan(List<FounderLoan> loans, String partnerId) {
    for (final loan in loans) {
      if (loan.partnerId == partnerId && loan.state.isOpen && !loan.isCleared) {
        return loan;
      }
    }
    return null;
  }

  /// Master only. Puts a sealed period back to open, before anything is paid.
  ///
  /// For the case where the master sealed by mistake, or an entry turns out to
  /// be missing. Everything written since goes on living in the period that
  /// was opened at the seal — it is not swept backwards — so this undoes the
  /// freeze, not the trading.
  static Future<void> unseal({
    required Actor actor,
    required FarmMonth period,
  }) async {
    if (!period.isSealed) return;

    // Sealing opens the next period. Unsealing has to shut it again, or the
    // farm is left with two periods open at once — and `watchOpen` takes the
    // oldest, so the books go back into this one while anything written
    // between the seal and the unseal sits in a period nothing reads. Seal
    // on the last day of the month and the one the seal made never closes
    // at all: it keeps the opening cash of a seal that was undone, and every
    // entry the farm makes from then on is booked into it.
    //
    // Only if it is still empty. An entry written into it after the seal was
    // booked there on purpose and an entry's period never moves — not even
    // for the master, because a period's frozen figures were worked out from
    // it. So where there is anything in it, the unseal is refused and says
    // why, which leaves the farm with a choice it can see rather than two
    // open periods it cannot.
    final nextId = period.sealedAt == null
        ? null
        : nextPeriodId(period.id, period.sealedAt!);

    if (nextId != null && nextId != period.id) {
      final next = await Db.months.doc(nextId).get();
      if (next.exists && FarmMonth.fromDoc(next).isOpen) {
        final written = await Db.transactions
            .where('monthId', isEqualTo: nextId)
            .limit(1)
            .get();
        final live = written.docs.where((d) => !Txn.fromDoc(d).isDeleted);
        if (live.isNotEmpty) {
          throw StateError(
            'The period after this one already has entries in it, so this '
            'one cannot be reopened — an entry never moves between periods. '
            'Correct it in the open period instead.',
          );
        }
        await Db.months.doc(nextId).delete();
      }
    }

    await Db.months.doc(period.id).update({
      'status': 'open',
      'to': FieldValue.delete(),
      'sealedAt': FieldValue.delete(),
      'shares': <Map<String, dynamic>>[],
      'decisions': <String, dynamic>{},
    });
    _bookingId = period.id;

    await Log.write(
      actor,
      LogKind.monthClose,
      'reopened ${periodLabel(period)} — the figures are being worked out again',
      refType: 'month',
      refId: period.id,
    );
  }
}
