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
      final customerId = txn.customerId;
      if (isSale && customerId != null && customerId.isNotEmpty) {
        try {
          await Db.udhaarAccounts.doc(customerId).update({
            'balance': FieldValue.increment(-take),
          });
        } catch (_) {
          // No udhaar account for this party — nothing to reduce.
        }
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

    await add(
      actor: actor,
      monthId: monthId,
      type: TxnType.payment,
      party: to,
      category: handoverOutCategory,
      amount: amount,
      paid: true,
      note: note.isEmpty ? 'Handed to $to' : note,
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
      if (txn.paid) fresh['paidSoFar'] = amount;
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

  static Future<void> softDelete(Actor actor, Txn txn) async {
    await Db.transactions.doc(txn.id).update({
      'deletedAt': FieldValue.serverTimestamp(),
    });

    try {
      final settlements = await Db.transactions
          .where('settlesTxnId', isEqualTo: txn.id)
          .get();
      for (final doc in settlements.docs) {
        await doc.reference.update({'deletedAt': FieldValue.serverTimestamp()});
      }
    } catch (_) {
      // Worst case the settlement row stays; the master can delete it too.
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
