import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../util/money.dart';
import 'allocation.dart';
import 'db.dart';
import 'month_repo.dart';
import 'log_service.dart';

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
