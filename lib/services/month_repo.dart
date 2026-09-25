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
      // What stayed in — or, on a bad month, what the loss took out. Both go
      // to the same place, because they are the same account.
      if (share.held != 0) {
        batch.update(ref, {'profitHeld': FieldValue.increment(share.held)});
      }
      if (share.taken > 0) {
        batch.update(ref, {'withdrawn': FieldValue.increment(share.taken)});
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

    await Db.months.doc(period.id).update({
      'status': 'open',
      'to': FieldValue.delete(),
      'sealedAt': FieldValue.delete(),
      'shares': <Map<String, dynamic>>[],
      'decisions': <String, dynamic>{},
    });

    await Log.write(
      actor,
      LogKind.monthClose,
      'reopened ${periodLabel(period)} — the figures are being worked out again',
      refType: 'month',
      refId: period.id,
    );
  }
}
