import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../util/money.dart';
import 'allocation.dart';
import 'db.dart';
import 'month_repo.dart';
import 'photo_store.dart';
import 'log_service.dart';

/// Whether this person may put an entry on this day, and why not.
///
/// Null means yes; anything else is a sentence to put in front of somebody.
/// It lives out here, apart from the writing, because three different things
/// ask the same question: the form, deciding what the date picker may offer;
/// the repo, before it writes; and a test, which has neither.
///
/// Two rules, and both of them are about days other people have already read:
///
///  * Nothing is dated forward of today. Milk that has not been sold is not
///    an entry, and a date in the future leaves every figure short until it
///    arrives.
///  * Nobody but the master goes back past the day the open period began.
///    Inside the period is the ordinary correction — the 8th that was the
///    6th — and the farm is still writing those days. The day before it is a
///    period whose figures have been sent round, agreed and shared out.
String? dateMoveRefusal({
  required bool isMaster,
  required DateTime to,
  DateTime? periodStart,
  DateTime? now,
}) {
  final day = DateTime(to.year, to.month, to.day);
  final today = now ?? DateTime.now();
  if (day.isAfter(DateTime(today.year, today.month, today.day))) {
    return 'An entry cannot be dated later than today.';
  }
  if (!isMaster && periodStart != null) {
    final floor = DateTime(
      periodStart.year,
      periodStart.month,
      periodStart.day,
    );
    if (day.isBefore(floor)) {
      return 'That is before this period started. Only the master can move '
          'an entry out of the period it was written in.';
    }
  }
  return null;
}

/// Writes to the ledger. Cloud Functions mirror every change to the
/// Transactions tab of the Google Sheet, so nothing here talks to Sheets.
class TxnRepo {
  TxnRepo._();

  static Future<String> add({
    required Actor actor,
    required String monthId,
    required TxnType type,
    required String party,
    required String category,
    required num amount,
    required bool paid,
    bool? capital,
    MilkShift? shift,
    num? qty,
    String? unit,
    num? rate,
    String note = '',
    String? customerId,
    String? orderId,
    String? settlesTxnId,

    /// The other half of a handover, which is one act written as two rows.
    ///
    /// The pair used to be told apart by nothing but day, amount and the
    /// two names. Correct one row's amount and the key stopped matching:
    /// both halves appeared in the ledger as two trades, and the farm's
    /// cash went out by the difference. Delete one half and the cash went
    /// out by the whole handover. A shared id is the pair saying so itself.
    String? pairId,
    PayVia payVia = PayVia.cash,
    String handledBy = '',
    DateTime? date,

    /// The receipt that came with the money, already picked. The small copy
    /// goes on the entry and the full one into its own document.
    File? receipt,
  }) async {
    final now = date ?? DateTime.now();
    final settled = type.isSettlement || paid;
    final doc = await Db.transactions.add({
      'date': Timestamp.fromDate(now),
      'monthId': monthId,
      'type': type.name,
      'party': party,
      'customerId': ?customerId,
      'category': category,
      // Only written when somebody typed the category, because only then is
      // there no list to read the answer off.
      'capital': ?capital,
      // Only on milk, and only when somebody said. See [MilkShift].
      if (shift != null) 'shift': shift.name,
      if (!type.isSettlement && qty != null) 'qty': qty,
      if (!type.isSettlement && unit != null) 'unit': unit,
      if (!type.isSettlement && rate != null) 'rate': rate,
      'amount': amount,
      'paid': settled,
      // Nothing has been taken against a credit entry yet; the whole of a
      // settled one moved as it was written.
      'paidSoFar': settled ? amount : 0,
      if (settled) 'paidAt': Timestamp.fromDate(now),
      'note': note,
      'orderId': ?orderId,
      'settlesTxnId': ?settlesTxnId,
      'pairId': ?pairId,
      // Whether the money moved as this row was written. Cash reads this
      // rather than the paid flag, so an entry settled months later is
      // counted on the day it was actually settled.
      'paidOnCreate': settled,
      'payVia': payVia.name,
      'handledBy': handledBy,
      'createdBy': actor.uid,
      'createdByName': actor.name,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // The photograph of the paper, which is the only thing that settles an
    // argument about a bank transfer three months later.
    if (receipt != null) {
      try {
        final photo = await Photos.prepare(receipt, kind: PhotoKind.receipt);
        await Db.txnPhotos.doc(doc.id).set({
          'data': photo.full,
          'at': FieldValue.serverTimestamp(),
        });
        await doc.update({'receipt': photo.thumb});
      } catch (_) {
        // An entry with no picture is worth more than no entry at all.
      }
    }

    await Log.write(
      actor,
      LogKind.transaction,
      'added ${type.label.toLowerCase()} "$party" ${rs(amount)}'
      '${settled ? '' : ' (unpaid)'}',
      refType: 'transaction',
      refId: doc.id,
    );
    return doc.id;
  }

  /// Settles one entry in full — the button on a single row.
  static Future<void> markPaid(
    Actor actor,
    Txn txn, {
    PayVia payVia = PayVia.cash,
    String handledBy = '',
  }) => settle(
    actor,
    [txn],
    amount: txn.outstanding,
    payVia: payVia,
    handledBy: handledBy,
  );

  /// Takes one lump of money against a stack of entries, oldest first.
  ///
  /// This is what actually happens on a milk round: sold on credit twice a
  /// day, paid in one handful on a Friday, and the handful rarely lands on an
  /// entry boundary. A customer hands over 100,000 against 120,000 of milk and
  /// the odd 20,000 has to live somewhere — so the money fills each entry in
  /// turn and stops part way through the last one it reaches.
  ///
  /// Oldest first, which is the only order that needs no explaining: the
  /// entry left part settled is then the oldest one still owing, so the next
  /// payment picks up exactly where this one stopped.
  ///
  /// Each entry gets its own receipt or payment row, for the part of the money
  /// that landed on it. One lump against twelve entries is twelve rows, not
  /// one — because in a month's time the question is never "what did he pay on
  /// Friday", it is "which days has he paid for".
  ///
  /// Returns how many entries this finished off.
  static Future<int> settle(
    Actor actor,
    List<Txn> entries, {
    required num amount,
    PayVia payVia = PayVia.cash,
    String handledBy = '',
  }) async {
    final now = DateTime.now();
    // Where the money goes is worked out apart from the writing of it, so the
    // rule can be tested on its own — see `allocation.dart`.
    final landings = allocate(entries, amount);
    if (landings.isEmpty) return 0;

    var taken = 0 as num;
    var finished = 0;

    for (final landing in landings) {
      final txn = landing.entry;
      final take = landing.take;
      taken += take;

      final nowPaid = landing.paidAfter;
      final settledInFull = landing.finishes;
      if (settledInFull) finished++;

      await Db.transactions.doc(txn.id).update({
        'paidSoFar': nowPaid,
        // The flag still says "nothing more to collect", which is what the
        // unpaid query asks. A part-settled entry is still outstanding.
        'paid': settledInFull,
        if (settledInFull) 'paidAt': Timestamp.fromDate(now),
        'payVia': payVia.name,
        'handledBy': handledBy,
      });

      final isSale = txn.type == TxnType.sale;
      await add(
        actor: actor,
        monthId: MonthRepo.bookingId,
        type: isSale ? TxnType.receipt : TxnType.payment,
        party: txn.party,
        category: isSale ? khaataReceiptCategory : _paymentCategory(txn),
        amount: take,
        paid: true,
        note: settledInFull
            ? 'Settles ${txn.type.label.toLowerCase()} of '
                  '${fmtDate(txn.date)}'
            : 'Part of ${txn.type.label.toLowerCase()} of '
                  '${fmtDate(txn.date)} — ${rs(txn.amount - nowPaid)} still '
                  'to come',
        customerId: txn.customerId,
        // The entry above carrying what it has taken is what moved the cash.
        // Tagging this row keeps it in the ledger and the Sheet without the
        // balance counting the same rupees twice.
        settlesTxnId: txn.id,
        payVia: payVia,
        handledBy: handledBy,
        date: now,
      );

      // An udhaar customer's balance drops by whatever just landed on it.
      if (isSale) {
        await _moveKhaata(txn, -take);
      }
    }

    await Log.write(
      actor,
      LogKind.transaction,
      landings.length == 1
          ? 'took ${rs(taken)} from "${landings.first.entry.party}"'
          : 'took ${rs(taken)} from "${landings.first.entry.party}" '
                'against ${landings.length} entries, settling $finished of '
                'them',
      refType: 'transaction',
      refId: landings.first.entry.id,
    );
    return finished;
  }

  /// Gives up on what is still owed on an entry.
  ///
  /// The farm's own case: a shop pays a year of milk bills and leaves a
  /// thousand rupees of the last one unpaid. Everybody knows it is not
  /// coming. Chasing it costs more than it is worth — and leaving it on the
  /// books is worse than either, because the account then says a thousand is
  /// owed for ever and the next co-founder to read it goes and asks for it.
  ///
  /// So the entry is marked settled and the shortfall is booked as a cost of
  /// the period it was given up in. That is what it is: a sale that is never
  /// paid for is a sale the farm did not make, and the profit has to know.
  /// No cash moves — see [badDebtCategory] — so the balance check stays
  /// level: the receivable comes off one side and the cost off the other.
  ///
  /// The master's alone. Every other correction can be argued about
  /// afterwards; this one hands somebody else the farm's money.
  static Future<void> giveUpOn(
    Actor actor,
    Txn txn, {
    num? amount,
    String note = '',
  }) async {
    final left = txn.outstanding;
    if (left <= 0) throw StateError('Nothing is outstanding on that entry.');
    final given = amount == null || amount > left ? left : amount;
    if (given <= 0) throw StateError('There is nothing to give up on.');

    final now = DateTime.now();
    final settledInFull = txn.paidSoFar + given >= txn.amount;

    await Db.transactions.doc(txn.id).update({
      'paidSoFar': txn.paidSoFar + given,
      'paid': settledInFull,
      if (settledInFull) 'paidAt': Timestamp.fromDate(now),
    });

    // Written off is written off. Left on his khaata the farm takes the
    // loss and then asks him for the money anyway on the next bill, and
    // takes the loss a second time when he does not pay it.
    if (txn.type == TxnType.sale) await _moveKhaata(txn, -given);

    await add(
      actor: actor,
      monthId: MonthRepo.bookingId,
      type: TxnType.expense,
      party: txn.party,
      category: badDebtCategory,
      amount: given,
      paid: true,
      note: note.isEmpty
          ? 'Given up on — ${txn.type.label.toLowerCase()} of '
                '${fmtDate(txn.date)}'
          : note,
      settlesTxnId: txn.id,
      customerId: txn.customerId,
      date: now,
    );

    await Log.write(
      actor,
      LogKind.correction,
      'gave up on ${rs(given)} owed by "${txn.party}" on the '
      '${txn.type.label.toLowerCase()} of ${fmtDateFull(txn.date)}',
      refType: 'transaction',
      refId: txn.id,
    );
  }

  /// Cash passing from one co-founder's hands to another's.
  ///
  /// Not a rupee enters or leaves the farm. Jalbani takes the money from
  /// Urooj Dairy at the gate and hands it to Rafeeq that evening because
  /// Rafeeq keeps the cash; the farm has exactly as much before and after.
  /// What changes is who is answerable for it, and that was the one thing
  /// the books could not say.
  ///
  /// Written as a pair, both rows at once, so it can never be half recorded:
  /// one hands over, the other takes in. The two cancel in the cash, neither
  /// touches the profit — see [handoverOutCategory] — and the only figures
  /// that move are what each of them is holding.
  static Future<void> handOver(
    Actor actor, {
    required String from,
    required String to,
    required num amount,
    PayVia payVia = PayVia.cash,
    String note = '',
    DateTime? date,
  }) async {
    if (amount <= 0) throw StateError('How much is being handed over?');
    if (partyKey(from) == partyKey(to)) {
      throw StateError('Those are the same person.');
    }
    final on = date ?? DateTime.now();
    final monthId = MonthRepo.bookingId;

    // One act, two rows, and they say so. Firestore hands out an id for a
    // document that does not exist yet, which is all this needs to be.
    final pair = Db.transactions.doc().id;

    await add(
      actor: actor,
      monthId: monthId,
      type: TxnType.payment,
      party: to,
      category: handoverOutCategory,
      amount: amount,
      paid: true,
      note: note.isEmpty ? 'Handed to $to' : note,
      pairId: pair,
      payVia: payVia,
      handledBy: from,
      date: on,
    );

    await add(
      actor: actor,
      monthId: monthId,
      type: TxnType.receipt,
      party: from,
      category: handoverInCategory,
      amount: amount,
      paid: true,
      note: note.isEmpty ? 'Taken from $from' : note,
      pairId: pair,
      payVia: payVia,
      handledBy: to,
      date: on,
    );

    await Log.write(
      actor,
      LogKind.transaction,
      '$from handed ${rs(amount)} to $to',
      refType: 'handover',
    );
  }

  /// Master only. Soft delete keeps the row in the Sheet marked `deleted`.
  ///
  /// Any receipt or payment that "Mark paid" posted against this entry goes
  /// with it — leaving that behind would keep taking the money out of the
  /// balance for an entry that no longer exists.
  /// Correct an entry that was written wrong.
  ///
  /// Two people may do this and they may do different amounts of it. Anybody
  /// who keeps the books can fix what was typed — a name, a heading, a
  /// quantity, a rate, the figure, the note — and can move the date anywhere
  /// inside the period that is open, back or forward, as far as today. Only
  /// the master may take it out of that period, because an earlier day has
  /// already been read and printed on somebody's statement.
  ///
  /// Neither may touch two things. The period it was booked into never
  /// changes: that is the field closed months are built on, and an entry that
  /// could walk between periods could take profit out of one that has already
  /// been shared. And an entry in a period that is sealed or closed cannot be
  /// corrected at all — its month's figures were frozen on the day and four
  /// people were paid out of them. A correction to one of those is a fresh
  /// entry in the period that is open, which is what a book of accounts has
  /// always done.
  ///
  /// What changed is kept on the entry itself, in the words it was shown as,
  /// so that opening the entry answers "has this been touched, and by whom"
  /// without going to look anywhere else.
  static Future<void> edit({
    required Actor actor,
    required Txn txn,
    required bool isMaster,
    required bool periodIsOpen,
    String? party,
    String? category,
    bool? capital,
    MilkShift? shift,
    num? qty,
    String? unit,
    num? rate,
    num? amount,
    String? note,
    PayVia? payVia,
    String? handledBy,
    DateTime? date,

    /// The first day somebody who is not the master may date this entry to —
    /// the day the open period began. Null leaves the date unguarded at this
    /// end, which is what the tests of the other rules want.
    DateTime? earliest,
  }) async {
    if (!periodIsOpen) {
      throw StateError(
        'That entry belongs to a period that is already settled. Put the '
        'correction in the open period instead.',
      );
    }
    if (date != null && !_sameDay(date, txn.date)) {
      final refused = dateMoveRefusal(
        isMaster: isMaster,
        to: date,
        periodStart: earliest,
      );
      if (refused != null) throw StateError(refused);
    }

    // Half of a handover cannot be corrected on its own.
    //
    // It is one act written as two rows, and the two have to agree about
    // what passed and on what day or the farm's cash changes without a
    // rupee going anywhere: a handover of 8,600 entered as 8,000 and
    // corrected on one side left the books 600 out and the two men 600
    // apart in opposite directions, with both rows then showing in the
    // ledger as separate trades.
    //
    // Correcting both from here would mean deciding which fields mirror and
    // which swap — the names do swap — and getting that wrong is the same
    // bug wearing a hat. Deleting it takes both halves now, so the way to
    // fix one is to take it off and hand the money over again, which is
    // also the plainest thing to tell somebody standing in the shed.
    if (txn.hasPair &&
        ((amount != null && amount != txn.amount) ||
            (date != null && !_sameDay(date, txn.date)))) {
      throw StateError(
        'This is one half of money handed between two of you, and the two '
        'halves have to agree. Delete it — both halves go together — and '
        'hand it over again with the right figure.',
      );
    }

    final fresh = <String, dynamic>{};
    final changes = <({String field, String from, String to})>[];

    void moved(String field, Object? was, Object? now, String key) {
      if (was == now) return;
      fresh[key] = now;
      changes.add((field: field, from: _said(was), to: _said(now)));
    }

    moved('Party', txn.party, party?.trim(), 'party');
    moved('What for', txn.category, category, 'category');
    moved('Quantity', txn.qty, qty, 'qty');
    moved('Unit', txn.unit, unit, 'unit');
    moved('Rate', txn.rate, rate, 'rate');
    moved('Note', txn.note, note?.trim(), 'note');
    moved('Handled by', txn.handledBy, handledBy?.trim(), 'handledBy');

    if (amount != null && amount != txn.amount) {
      if (amount <= 0) throw StateError('An entry needs an amount.');
      fresh['amount'] = amount;
      // What has been settled against it cannot be more than it is worth.
      // Lowering a part-paid entry below what has already come in would
      // leave the farm owing money on something it has been overpaid for.
      if (txn.paidSoFar > amount) {
        throw StateError(
          'Rs ${amount.round()} is less than the Rs ${txn.paidSoFar.round()} '
          'already settled against this entry.',
        );
      }
      // What was actually received does not change because the entry's
      // figure was corrected. `paidSoFar` is money that came in and is
      // vouched for by a receipt; the correction says the milk was worth
      // more or less than first written, not that more or less was paid.
      //
      // This used to write `paidSoFar = amount` on a settled entry. A sale
      // of 20,000 settled in full and then corrected up to 25,000 came out
      // saying 25,000 had been paid, against a receipt for 20,000 — the
      // farm was owed five thousand rupees and not one figure anywhere
      // said so, so nobody would ever have asked for it.
      //
      // So the money stands and `paid` is worked out again from it, the
      // same rule as everywhere else: an entry is settled when nothing is
      // left owing on it. Lowering it below what has come in is refused
      // above, which is the other half of the same thought.
      final settledInFull = txn.paidSoFar >= amount;
      if (settledInFull != txn.paid) {
        fresh['paid'] = settledInFull;
        if (!settledInFull) fresh['paidAt'] = FieldValue.delete();
      }
      changes.add((
        field: 'Amount',
        from: _said(txn.amount),
        to: _said(amount),
      ));
    }

    if (capital != null && capital != txn.capital) {
      fresh['capital'] = capital;
      changes.add((
        field: 'What kind of thing',
        from: txn.isCapitalAsset ? 'The farm keeps it' : 'Cost',
        to: capital ? 'The farm keeps it' : 'Cost',
      ));
    }

    if (shift != null && shift != txn.shift) {
      fresh['shift'] = shift.name;
      changes.add((
        field: 'Which milking',
        from: txn.shift?.label ?? '—',
        to: shift.label,
      ));
    }

    if (payVia != null && payVia != txn.payVia) {
      fresh['payVia'] = payVia.name;
      changes.add((field: 'How', from: txn.payVia.label, to: payVia.label));
    }

    if (date != null && !_sameDay(date, txn.date)) {
      fresh['date'] = Timestamp.fromDate(date);
      changes.add((
        field: 'Date',
        from: fmtDateFull(txn.date),
        to: fmtDateFull(date),
      ));
    }

    if (changes.isEmpty) return;

    final record = TxnEdit(
      at: DateTime.now(),
      byUid: actor.uid,
      byName: actor.name,
      changes: changes,
    );
    fresh['edits'] = FieldValue.arrayUnion([record.toMap()]);

    await Db.transactions.doc(txn.id).update(fresh);

    // A settlement corrected has to move the entry it settled, by whatever
    // the correction moved it.
    //
    // This is the deleting bug reached through the other door. A receipt of
    // 20,000 typed for a sale of 20,000, corrected down to 4,000: the
    // receipt said four and the sale went on saying paid in full, so the
    // farm was owed sixteen thousand that nothing on the books mentioned.
    // The same rupees, one row apart, and the two rows disagreeing.
    if (amount != null && amount != txn.amount && txn.settlesAnotherEntry) {
      await _moveSettled(txn, amount);
    }

    await Log.write(
      actor,
      LogKind.correction,
      // Which entry, and every field that moved, written out. The entry's
      // own date is in here because the log is read long after the entry
      // has scrolled away — "corrected Urooj Dairy Shop" names a man the
      // farm deals with every day and no particular trade.
      'corrected ${txn.party} · ${txn.category} of ${fmtDateFull(txn.date)} — '
      '${changes.map((c) => '${c.field} ${c.from} to ${c.to}').join(', ')}',
      refType: 'txn',
      refId: txn.id,
    );
  }

  /// A value as it should read in a record somebody opens years from now.
  static String _said(Object? v) {
    if (v == null) return '—';
    if (v is num) return groupPk(v);
    final text = v.toString().trim();
    return text.isEmpty ? '—' : text;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Takes an entry off the books.
  ///
  /// [periodIsOpen] is held to for everybody, the master included, the same
  /// as [edit] is. A settled period's figures are what four people were paid
  /// out of, and the sheet this button sits on says so in as many words —
  /// while the button worked. It did not move the period's frozen figures,
  /// which are written once; it moved every all-time figure built on the
  /// ledger instead. A cattle purchase of twelve lakh taken out of a closed
  /// month left what the farm owns twelve lakh lighter against shares
  /// already paid, and the check that says the books add up quietly stopped
  /// saying it.
  ///
  /// So a mistake in a settled period is answered the way a book of accounts
  /// has always answered one: an entry in the period that is open.
  static Future<void> softDelete(
    Actor actor,
    Txn txn, {
    bool periodIsOpen = true,
  }) async {
    if (!periodIsOpen) {
      throw StateError(
        'That entry belongs to a period that is already settled, and four '
        'people have been paid out of its figures. Put a correcting entry '
        'in the open period instead.',
      );
    }
    // Taking a settlement off the books has to take back what it settled.
    //
    // This is the bug that cost the farm six real sales. A receipt carries
    // the money it put onto the entry it was paying; deleting the receipt
    // used to leave that money sitting on the entry, so the sale went on
    // saying "paid in full" with nothing on the books that had paid it. The
    // balance read short, the farm assumed it had typed a figure wrong, and
    // deleted the sales themselves trying to put it right.
    //
    // A row and the figures that row moved go together, both ways. See
    // [restore], which is the same thing in reverse.
    await _unsettle(txn);

    await Db.transactions.doc(txn.id).update({
      'deletedAt': FieldValue.serverTimestamp(),
    });

    try {
      final settlements = await Db.transactions
          .where('settlesTxnId', isEqualTo: txn.id)
          .get();
      for (final doc in settlements.docs) {
        final row = Txn.fromDoc(doc);
        if (row.isDeleted) continue;
        // Each of these carries money it put onto this entry, and each has
        // to give it back — the same rule as above, applied to the rows
        // being taken down with it rather than to the row itself.
        //
        // Left out, delete and undo stopped being each other's opposite:
        // the money stayed on the entry while it was gone and [restore]
        // added it a second time on the way back, so a sale part settled
        // by 10,000 came back owing 10,000 less than it did. A fully
        // settled one was saved only by the clamp in [_moveSettled], which
        // is luck, not a rule.
        await _unsettle(row);
        await doc.reference.update({
          'deletedAt': FieldValue.serverTimestamp(),
          // Which deletion took it, so undoing that one brings back exactly
          // the rows it took and not a settlement deleted separately an
          // hour earlier for a reason of its own.
          'deletedWith': txn.id,
        });
      }
    } catch (_) {
      // Worst case the settlement row stays; the master can delete it too.
    }

    await _moveSplit(txn, keep: false);
    await _movePair(txn, keep: false);
    // What he owes goes down by a sale taken off the books, and up again
    // by a payment taken off — the receipts of this sale came down with
    // it just above, so only the sale itself is counted here.
    if (txn.type == TxnType.sale) {
      await _moveKhaata(txn, -txn.outstanding);
    } else if (txn.settlesAnotherEntry) {
      await _moveKhaata(txn, txn.amount);
    }

    await Log.write(
      actor,
      LogKind.entryDeleted,
      'deleted ${txn.type.label.toLowerCase()} "${txn.party}" '
      '${rs(txn.amount)} of ${fmtDateFull(txn.date)}',
      refType: 'transaction',
      refId: txn.id,
    );
  }

  /// Puts a deleted entry back, and everything it had done with it.
  ///
  /// The farm asked for this the hour it lost six sales, and the asking was
  /// exact: "agar entry undo ho rahi hy to sab kuch us entry ke hisaab se
  /// hona chahiye" — if an entry comes back, everything it did comes back
  /// with it. A row returned without its effects is the same half-a-job that
  /// deleting used to do, pointing the other way.
  ///
  /// So: the row itself; the money it had put onto the entry it settled, if
  /// it was a settlement; and the settlements that were taken down with it,
  /// each with the money they had put on. Nothing is hard-deleted in these
  /// books, which is the only reason any of this can be undone at all.
  static Future<void> restore(Actor actor, Txn txn) async {
    await Db.transactions.doc(txn.id).update({
      'deletedAt': FieldValue.delete(),
      'deletedWith': FieldValue.delete(),
    });
    await _resettle(txn);

    try {
      final taken = await Db.transactions
          .where('deletedWith', isEqualTo: txn.id)
          .get();
      for (final doc in taken.docs) {
        await doc.reference.update({
          'deletedAt': FieldValue.delete(),
          'deletedWith': FieldValue.delete(),
        });
        await _resettle(Txn.fromDoc(doc));
      }
    } catch (_) {
      // The entry is back either way; a settlement left down can be undone
      // on its own line in the log.
    }

    // Receipts taken down by a build that never said which deletion took
    // them.
    //
    // Everything deleted before this was written carries no mark, so the
    // query above finds nothing and the sale comes home alone — settled in
    // full against receipts that are not there. The farm met exactly that
    // undoing the ninth and the eleventh of October.
    //
    // A deleted receipt with no mark on it and nothing else to belong to
    // came off with this entry, because that is the only way it could have
    // got that way. It is a one-time kindness to the books as they stand,
    // and it costs nothing once every deletion marks its own.
    if (!txn.settlesAnotherEntry) {
      try {
        final orphans = await Db.transactions
            .where('settlesTxnId', isEqualTo: txn.id)
            .get();
        for (final doc in orphans.docs) {
          final row = Txn.fromDoc(doc);
          if (!row.isDeleted) continue;
          if (s(doc.data()['deletedWith']).isNotEmpty) continue;
          await doc.reference.update({'deletedAt': FieldValue.delete()});
        }
      } catch (_) {
        // The entry is back; a receipt left down shows on its own log line.
      }

      // And whatever came back, the entry is told what it adds up to.
      await _resync(txn.id);
    }

    await _moveSplit(txn, keep: true);
    await _movePair(txn, keep: true);
    if (txn.type == TxnType.sale) {
      await _moveKhaata(txn, txn.outstanding);
    } else if (txn.settlesAnotherEntry) {
      await _moveKhaata(txn, -txn.amount);
    }

    await Log.write(
      actor,
      LogKind.entryDeleted,
      'brought back ${txn.type.label.toLowerCase()} "${txn.party}" '
      '${rs(txn.amount)} of ${fmtDateFull(txn.date)}',
      refType: 'transaction',
      refId: txn.id,
    );
  }

  /// Takes the split written against an entry down with it, or puts it back.
  ///
  /// "Who paid for this?" writes a line per man against a purchase, and each
  /// line is money of his own that went in — it moves his capital, his share
  /// ratio and what the farm is worth. Deleting the purchase used to leave
  /// every one of those standing: a duplicate cattle entry of 15,09,000
  /// taken off the books left two co-founders credited with having paid for
  /// it, the farm's cash reading fifteen lakh high, and nothing on the page
  /// to say which fifteen lakh.
  ///
  /// The purchase is the reason those lines exist. It goes, they go; it
  /// comes back, they come back — and each takes its capital with it, the
  /// same way [ContributionRepo.remove] does when a line is taken off on
  /// its own.
  static Future<void> _moveSplit(Txn txn, {required bool keep}) async {
    try {
      final lines = await Db.contributions
          .where('txnId', isEqualTo: txn.id)
          .get();

      for (final doc in lines.docs) {
        final line = Contribution.fromDoc(doc);
        // Only the ones this deletion is answerable for. A line taken off
        // by hand before any of this stays off.
        if (keep ? s(doc.data()['deletedWith']) != txn.id : line.isDeleted) {
          continue;
        }

        await doc.reference.update(
          keep
              ? {
                  'deletedAt': FieldValue.delete(),
                  'deletedWith': FieldValue.delete(),
                }
              : {
                  'deletedAt': FieldValue.serverTimestamp(),
                  'deletedWith': txn.id,
                },
        );

        // Opening lines are the difference between what a card says and
        // what the lines come to; they are not money anybody put in, so
        // they move no capital. See [ContributionSource.opening].
        if (!line.isInvestment ||
            line.source == ContributionSource.opening ||
            line.partnerId.isEmpty) {
          continue;
        }
        await Db.partners.doc(line.partnerId).update({
          'invested': FieldValue.increment(keep ? line.amount : -line.amount),
        });
      }
    } catch (_) {
      // The entry is off the books either way. A split left standing shows
      // on the co-founder's own card, where it can be taken off by hand.
    }
  }

  /// Takes the other half of a handover down with this one, or brings it back.
  ///
  /// Money passing between two of them is one act written as two rows, and
  /// half an act is not a smaller version of it — it is a farm whose cash
  /// has changed by the whole handover without a rupee going anywhere.
  /// Delete the "Taken from" row and the books lose the amount; delete the
  /// "Handed to" row and they gain it. One of them goes, both go.
  static Future<void> _movePair(Txn txn, {required bool keep}) async {
    if (!txn.hasPair) return;
    try {
      final rows = await Db.transactions
          .where('pairId', isEqualTo: txn.pairId)
          .get();
      for (final doc in rows.docs) {
        if (doc.id == txn.id) continue;
        final other = Txn.fromDoc(doc);
        if (keep ? s(doc.data()['deletedWith']) != txn.id : other.isDeleted) {
          continue;
        }
        await doc.reference.update(
          keep
              ? {
                  'deletedAt': FieldValue.delete(),
                  'deletedWith': FieldValue.delete(),
                }
              : {
                  'deletedAt': FieldValue.serverTimestamp(),
                  'deletedWith': txn.id,
                },
        );
      }
    } catch (_) {
      // Half a handover left on the books is visible on the page that shows
      // who is holding the farm's cash, where it can be taken off by hand.
    }
  }

  /// Moves a khaata customer's running balance by what just happened.
  ///
  /// His balance is the one figure in these books kept in a field of its
  /// own rather than worked out from the ledger, and the only place it ever
  /// came down was money landing on one of his sales. Everything else left
  /// it where it was:
  ///
  ///   - Delete one of his sales and he was billed again, for ever, for
  ///     milk he had already paid for — and the receipt went with the sale,
  ///     so the money came out of the books too.
  ///   - Give up on a thousand rupees of his and the farm booked the loss,
  ///     then asked him for the thousand on the next bill, and took the
  ///     loss again when he did not pay.
  ///
  /// So every one of them moves it now, in whichever direction it went.
  static Future<void> _moveKhaata(Txn txn, num by) async {
    final customerId = txn.customerId;
    if (by == 0 || customerId == null || customerId.isEmpty) return;
    try {
      await Db.udhaarAccounts.doc(customerId).update({
        'balance': FieldValue.increment(by),
      });
    } catch (_) {
      // No udhaar account for this party — nothing to move.
    }
  }

  /// Takes a settlement's money back off the entry it had paid.
  static Future<void> _unsettle(Txn txn) => _moveSettled(txn, 0);

  /// Puts it back on.
  static Future<void> _resettle(Txn txn) => _moveSettled(txn, txn.amount);

  /// Counts up what an entry has actually been paid, and writes that.
  ///
  /// Not "add this much" or "take that much off" — counted again, from the
  /// receipts that are on the books at this moment. [by] is only a figure
  /// about to be written that the register has not been told about yet; a
  /// correction in flight, which the caller knows and the query cannot see.
  ///
  /// Adding and subtracting was the first way of doing this and it was
  /// wrong in the way that matters: it believes the figure already there.
  /// The farm had receipts deleted by a build that never marked which
  /// deletion took them, so bringing a sale back could not bring its
  /// receipts back — and the stale "paid in full" rode home on the sale,
  /// which is exactly what the farm saw when it undid the ninth and the
  /// eleventh of October and they came back settled against nothing.
  ///
  /// Counted again, that cannot happen. Whatever the receipts on the books
  /// come to is what the entry has been paid, and an entry is settled when
  /// nothing is left owing on it. A figure that is wrong for any reason at
  /// all — a half-finished write, an old build, two phones at once — comes
  /// right the next time anything touches it.
  static Future<void> _moveSettled(Txn txn, num by) async {
    final target = txn.settlesTxnId;
    if (target == null) return;
    await _resync(target, except: txn.id, counting: by);
  }

  /// Writes what one entry has actually been paid, counted from its own
  /// receipts.
  ///
  /// [except] is a row the register's copy of which is out of date — the
  /// one being written this moment — and [counting] is what that row is
  /// about to be worth: nothing when it is going, its amount when it is
  /// coming back or being corrected.
  static Future<void> _resync(
    String entryId, {
    String? except,
    num counting = 0,
  }) async {
    try {
      final doc = await Db.transactions.doc(entryId).get();
      if (!doc.exists) return;
      final entry = Txn.fromDoc(doc);

      final rows = await Db.transactions
          .where('settlesTxnId', isEqualTo: entryId)
          .get();

      var paid = counting;
      for (final r in rows.docs) {
        final row = Txn.fromDoc(r);
        if (row.id == except || row.isDeleted) continue;
        paid += row.amount;
      }

      if (paid < 0) paid = 0;
      if (paid > entry.amount) paid = entry.amount;
      final settledInFull = paid >= entry.amount;

      await Db.transactions.doc(entryId).update({
        'paidSoFar': paid,
        'paid': settledInFull,
        if (!settledInFull) 'paidAt': FieldValue.delete(),
      });
    } catch (_) {
      // Offline. The figure comes right the next time anything touches
      // this entry, which is the point of counting rather than nudging.
    }
  }

  static String _paymentCategory(Txn txn) {
    const known = {
      'Rent',
      'Salaries',
      'Utilities (bijli, gas, pani)',
      'Other payment',
    };
    return known.contains(txn.category) ? txn.category : 'Supplier payment';
  }
}
