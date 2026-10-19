import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../util/money.dart';
import 'db.dart';
import 'log_service.dart';
import 'month_repo.dart';
import 'txn_repo.dart';

/// Writing down a co-founder's own money going into the farm.
///
/// The rule the farm set, in its own words: nobody's figure moves without an
/// entry behind it. So nothing here takes a number and overwrites it. Every
/// rupee is a line — what day, whose, how much, where it went — and what a
/// co-founder has put in is the sum of his lines.
///
/// The total still lives on the partner record as well, because every screen
/// and every closed period already reads it there and a figure that has to be
/// recomputed from a collection is a figure that will one day be wrong on one
/// screen and right on another. It is never typed: it moves only here, in the
/// same breath as the line that explains it.
class ContributionRepo {
  ContributionRepo._();

  /// One payment of a co-founder's own money, written as the farm's rule
  /// divides it: against his promise while he still owes on it, and as money
  /// the farm must return once he has paid it in full.
  ///
  /// Two lines where it falls both sides of the line — see [splitByPledge].
  /// Nobody is asked which it is, because it is not a matter of opinion: it
  /// follows from what he promised and what he has paid.
  static Future<void> putIn(
    Actor actor, {
    required Partner partner,
    required num amount,
    required ContributionSource source,
    required DateTime date,
    PayVia payVia = PayVia.cash,
    String receivedBy = '',
    Txn? entry,
    String note = '',
  }) async {
    final cut = splitByPledge(
      amount: amount,
      pledged: partner.pledged,
      alreadyIn: partner.invested,
    );

    for (final (kind, part) in [
      (ContributionKind.investment, cut.investment),
      (ContributionKind.loan, cut.refundable),
    ]) {
      if (part <= 0) continue;
      if (entry != null) {
        await forEntry(
          actor,
          partner: partner,
          entry: entry,
          amount: part,
          kind: kind,
          note: note,
        );
      } else {
        await handedOver(
          actor,
          partner: partner,
          amount: part,
          receivedBy: receivedBy,
          date: date,
          payVia: payVia,
          kind: kind,
          note: note,
        );
      }
    }
  }

  /// Money handed over — to whoever is keeping the farm's cash, usually.
  ///
  /// The ordinary way a promise gets paid off: eight lakh of it went on
  /// cattle through [forEntry], and the last two are counted out on a table
  /// and given to the accountant. Any amount; it is not held to what is left
  /// of the promise, because a man may put in more than he said and the app
  /// has no business refusing it.
  static Future<String> handedOver(
    Actor actor, {
    required Partner partner,
    required num amount,
    required String receivedBy,
    DateTime? date,
    PayVia payVia = PayVia.cash,
    ContributionKind kind = ContributionKind.investment,
    String note = '',
  }) => _write(
    actor,
    partner: partner,
    amount: amount,
    kind: kind,
    source: ContributionSource.cash,
    date: date ?? DateTime.now(),
    payVia: payVia,
    receivedBy: receivedBy,
    note: note,
    said:
        'put in ${rs(amount)}'
        '${receivedBy.trim().isEmpty ? '' : ', taken by ${receivedBy.trim()}'}',
  );

  /// One person's share of something the farm bought.
  ///
  /// Seventeen lakh of cattle, three men, one purchase. The entry is not
  /// touched and never splits: it stays one purchase of seventeen lakh, which
  /// is what it was. What is written here is who found the money for it, in
  /// rupees — five, five and seven — and each line carries the purchase's own
  /// date rather than today's, so a split made in December does not appear to
  /// be money that arrived in December.
  ///
  /// Nothing is handed to anybody, so no co-founder's holding moves: the
  /// money went from three pockets to the cattle market without passing
  /// through the farm's hands at all.
  static Future<String> forEntry(
    Actor actor, {
    required Partner partner,
    required Txn entry,
    required num amount,
    ContributionKind kind = ContributionKind.investment,
    String note = '',
  }) => _write(
    actor,
    partner: partner,
    amount: amount,
    kind: kind,
    source: ContributionSource.spent,
    date: entry.date,
    payVia: entry.payVia,
    receivedBy: '',
    txnId: entry.id,
    note: note.isEmpty ? '${entry.category} — ${entry.party}'.trim() : note,
    said:
        'paid ${rs(amount)} of the ${entry.category.toLowerCase()} of '
        '${fmtDateFull(entry.date)}',
  );

  /// Sets the whole split of one entry in a single pass.
  ///
  /// Opened a second time, the sheet shows what is already against the entry
  /// and saving puts right whatever was typed — a figure raised, a figure
  /// lowered, a man taken off it altogether. Each of those is still a line
  /// written or a line removed, so the history reads as what actually
  /// happened rather than as one silent total being overwritten.
  ///
  /// [amounts] is keyed by partner id. A zero or a missing partner means he
  /// paid none of it.
  static Future<void> setSplit(
    Actor actor, {
    required Txn entry,
    required List<Partner> partners,
    required List<Contribution> existing,
    required Map<String, num> amounts,
  }) async {
    final total = amounts.values.fold<num>(0, (a, v) => a + (v > 0 ? v : 0));
    if (total > entry.amount) {
      throw StateError(
        'That comes to ${rs(total)}, which is more than the entry of '
        '${rs(entry.amount)}.',
      );
    }

    // A man can have two lines against one entry — part of it finishing
    // his promise and the rest owed back to him — so his old lines are
    // gathered, not looked up one apiece.
    final mine = <String, List<Contribution>>{};
    for (final c in existing) {
      if (c.txnId != entry.id || c.isDeleted) continue;
      mine.putIfAbsent(c.partnerId, () => []).add(c);
    }

    for (final partner in partners) {
      final want = amounts[partner.id] ?? 0;
      final had = mine[partner.id] ?? const <Contribution>[];
      final hadTotal = had.fold<num>(0, (a, c) => a + c.amount);

      if (want == hadTotal) continue;

      // Written as removals and fresh lines rather than figures edited in
      // place, so what was there before is still readable afterwards.
      for (final line in had) {
        await remove(actor, line, partner: partner);
      }
      if (want <= 0) continue;

      // His total has just come down by whatever those lines held, and
      // the phone is holding a stale copy of it. The split is worked out
      // against what he will actually have, or saving the same figure
      // twice would measure it against itself.
      final hadInvested = had
          .where((c) => c.isInvestment)
          .fold<num>(0, (a, c) => a + c.amount);
      await putIn(
        actor,
        partner: _less(partner, hadInvested),
        entry: entry,
        amount: want,
        source: ContributionSource.spent,
        date: entry.date,
      );
    }
  }

  /// The same person with some of his total taken back off, for working
  /// out a split against what he is about to have rather than what the
  /// screen is still showing.
  static Partner _less(Partner p, num amount) => Partner(
    id: p.id,
    userId: p.userId,
    name: p.name,
    email: p.email,
    invested: p.invested - amount,
    pledged: p.pledged,
    profitHeld: p.profitHeld,
    withdrawn: p.withdrawn,
    createdAt: p.createdAt,
  );

  /// A co-founder taking back money of his own that the farm was holding.
  ///
  /// The farm's own way of doing it: Jalbani paid for a load of feed out of
  /// his pocket, and a week later forty thousand of milk money passes through
  /// his hands. Rather than handing over all forty and asking for twenty back,
  /// he keeps his twenty and the farm's twenty goes on. Nothing is owed
  /// either way afterwards and every rupee of it is written down.
  ///
  /// Oldest line first, which is the only order that needs no explaining, and
  /// a line may be settled in parts — he can take back five of a twenty when
  /// five is what is passing through.
  ///
  /// Two things are written: the lines lose what has been given back, and the
  /// ledger carries a payment for the cash actually leaving. It is not a cost
  /// — the cost was booked the day he bought the feed — so it is held out of
  /// the running costs the same way a customer's security is.
  static Future<void> repay(
    Actor actor, {
    required Partner partner,
    required List<Contribution> lines,
    required num amount,
    PayVia payVia = PayVia.cash,
    String handledBy = '',
    String note = '',
  }) async {
    if (amount <= 0) throw StateError('How much is he taking back?');

    final owed =
        lines
            .where((c) => !c.isDeleted && c.isLoan && c.partnerId == partner.id)
            .where((c) => c.stillOwed > 0)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    final total = owed.fold<num>(0, (a, c) => a + c.stillOwed);
    if (total <= 0) throw StateError('The farm owes him nothing.');
    if (amount > total) {
      throw StateError('The farm only owes him ${rs(total)}.');
    }

    var left = amount;
    for (final line in owed) {
      if (left <= 0) break;
      final take = line.stillOwed < left ? line.stillOwed : left;
      await Db.contributions.doc(line.id).update({
        'repaidSoFar': line.repaidSoFar + take,
      });
      left -= take;
    }

    await TxnRepo.add(
      actor: actor,
      monthId: MonthRepo.bookingId,
      type: TxnType.payment,
      party: partner.name,
      category: founderRepaidCategory,
      amount: amount,
      paid: true,
      note: note.isEmpty
          ? 'Taken back by ${partner.name} — money of his the farm was '
                'holding'
          : note,
      payVia: payVia,
      handledBy: handledBy.isEmpty ? partner.name : handledBy,
    );

    await Log.write(
      actor,
      LogKind.correction,
      '${partner.name} took back ${rs(amount)} of his own that the farm was '
      'holding',
      refType: 'partner',
      refId: partner.id,
    );
  }

  /// Moves a figure that was typed onto a card into what the man promised,
  /// and leaves what he has put in to be read off his lines.
  ///
  /// The farm ran for months on one number per co-founder that the master
  /// typed, and it was sitting in the wrong column. Nobody had handed that
  /// money over — it was what each of them had undertaken to put in. Read as
  /// money already in, it did two things wrong at once: it said the farm held
  /// cash it did not hold, and it counted every rupee twice the moment
  /// somebody wrote down which purchase that man had actually paid for.
  ///
  /// So the typed figure becomes the promise, and what he has put in becomes
  /// the sum of his lines, which is nothing until the lines are written. The
  /// farm's cash reads low in between, and it is right to: until somebody
  /// says who paid for the cattle, the books genuinely cannot account for
  /// what bought them.
  static Future<void> adoptTypedCapital(
    Actor actor, {
    required Partner partner,
    required List<Contribution> lines,
  }) async {
    final written = investedFrom(lines, partner.id);
    final typed = partner.invested;
    if (typed <= written) return;

    final promise = partner.pledged > typed ? partner.pledged : typed;

    await Db.partners.doc(partner.id).update({
      'pledged': promise,
      'invested': written,
    });

    await Log.write(
      actor,
      LogKind.investment,
      '${partner.name} is in for ${rs(promise)} — the ${rs(typed)} that was '
      'typed on his card was a promise, not money in. What he has put in now '
      'reads ${rs(written)}, off his own lines.',
      refType: 'partner',
      refId: partner.id,
    );
  }

  /// The master putting a figure right.
  ///
  /// Even this is a line. A correction that left no trace would be exactly
  /// the thing the farm asked to stop — and it is the one kind of change
  /// four friends are most likely to ask each other about.
  static Future<String> correct(
    Actor actor, {
    required Partner partner,
    required num by,
    required String why,
  }) => _write(
    actor,
    partner: partner,
    amount: by,
    kind: ContributionKind.investment,
    source: ContributionSource.correction,
    date: DateTime.now(),
    payVia: PayVia.cash,
    receivedBy: '',
    note: why,
    said: 'corrected ${partner.name}\'s capital by ${rs(by)} — $why',
    allowNegative: true,
  );

  /// Counting money the farm owed somebody as part of what he promised.
  ///
  /// He paid for the feed on Tuesday and the farm owed him for it; the four
  /// of them have now agreed it comes off his promise instead. One line
  /// changes its kind — the day, the amount and what it paid for all stay
  /// exactly as they were, because none of that has changed.
  static Future<void> countAsInvestment(
    Actor actor,
    Contribution line, {
    required Partner partner,
  }) async {
    if (line.isInvestment) return;
    await Db.contributions.doc(line.id).update({
      'kind': ContributionKind.investment.name,
    });
    await Db.partners.doc(partner.id).update({
      'invested': FieldValue.increment(line.amount),
    });
    await Log.write(
      actor,
      LogKind.investment,
      '${rs(line.amount)} the farm owed ${partner.name} now counts as his '
      'investment',
      refType: 'partner',
      refId: partner.id,
    );
  }

  /// The other way: money counted as investment goes back to being owed.
  static Future<void> countAsOwed(
    Actor actor,
    Contribution line, {
    required Partner partner,
  }) async {
    if (line.isLoan) return;
    await Db.contributions.doc(line.id).update({
      'kind': ContributionKind.loan.name,
    });
    await Db.partners.doc(partner.id).update({
      'invested': FieldValue.increment(-line.amount),
    });
    await Log.write(
      actor,
      LogKind.investment,
      '${rs(line.amount)} of ${partner.name}\'s investment is owed back to '
      'him instead',
      refType: 'partner',
      refId: partner.id,
    );
  }

  /// Takes a line out. Master only, and the total goes with it.
  static Future<void> remove(
    Actor actor,
    Contribution line, {
    required Partner partner,
  }) async {
    await Db.contributions.doc(line.id).update({
      'deletedAt': FieldValue.serverTimestamp(),
    });
    if (line.isInvestment && line.source != ContributionSource.opening) {
      await Db.partners.doc(partner.id).update({
        'invested': FieldValue.increment(-line.amount),
      });
    }
    await Log.write(
      actor,
      LogKind.investment,
      'removed ${rs(line.amount)} from ${partner.name}\'s money in — '
      '${line.source.label.toLowerCase()}, ${fmtDateFull(line.date)}',
      refType: 'partner',
      refId: partner.id,
    );
  }

  /// What this person undertook to put in.
  ///
  /// The one figure that is not a line, because it is not money — it is a
  /// promise, and it is allowed to change when the man changes it. Every
  /// change is logged, and the share ratio moves with it from that moment,
  /// which is exactly what he is asking for when he raises it.
  static Future<void> setPledge(
    Actor actor,
    Partner partner,
    num pledged,
  ) async {
    if (pledged < 0) throw StateError('A promise cannot be less than nothing.');
    if (pledged == partner.pledged) return;
    await Db.partners.doc(partner.id).update({'pledged': pledged});
    await Log.write(
      actor,
      LogKind.investment,
      partner.pledged == 0
          ? '${partner.name} is in for ${rs(pledged)}'
          : '${partner.name} changed what he is in for from '
                '${rs(partner.pledged)} to ${rs(pledged)}',
      refType: 'partner',
      refId: partner.id,
    );
  }

  static Future<String> _write(
    Actor actor, {
    required Partner partner,
    required num amount,
    required ContributionKind kind,
    required ContributionSource source,
    required DateTime date,
    required PayVia payVia,
    required String receivedBy,
    required String note,
    required String said,
    String? txnId,
    bool allowNegative = false,
  }) async {
    if (!allowNegative && amount <= 0) {
      throw StateError('How much went in?');
    }
    if (amount == 0) throw StateError('Nothing to record.');

    final line = Contribution(
      id: '',
      partnerId: partner.id,
      partnerName: partner.name,
      kind: kind,
      source: source,
      amount: amount,
      date: date,
      payVia: payVia,
      receivedBy: receivedBy.trim(),
      txnId: txnId,
      note: note,
      createdBy: actor.uid,
      createdByName: actor.name,
      createdAt: DateTime.now(),
    );

    final doc = await Db.contributions.add({
      ...line.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // The card's total and the line are written together. Only money the
    // farm keeps counts towards it — what it has to give back is somebody
    // else's money sitting in the box, and belongs nowhere near a share.
    if (kind == ContributionKind.investment) {
      await Db.partners.doc(partner.id).update({
        'invested': FieldValue.increment(amount),
      });
    }

    await Log.write(
      actor,
      LogKind.investment,
      '${partner.name} $said',
      refType: 'partner',
      refId: partner.id,
    );
    return doc.id;
  }
}
