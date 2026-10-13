import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../util/money.dart';
import 'allocation.dart';
import 'db.dart';
import 'month_repo.dart';
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
      LogKind.transaction,
      'corrected ${txn.party} ${txn.category} — '
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
      LogKind.transaction,
      'deleted ${txn.type.label.toLowerCase()} "${txn.party}" ${rs(txn.amount)}',
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
