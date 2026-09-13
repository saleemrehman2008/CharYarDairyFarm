import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../util/money.dart';
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
      if (!type.isSettlement && qty != null) 'qty': qty,
      if (!type.isSettlement && unit != null) 'unit': unit,
      if (!type.isSettlement && rate != null) 'rate': rate,
      'amount': amount,
      'paid': settled,
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

  /// Marking an entry paid settles it and posts the matching cash row: a
  /// receipt against a sale, a payment against a purchase or expense.
  static Future<void> markPaid(
    Actor actor,
    Txn txn, {
    PayVia payVia = PayVia.cash,
    String handledBy = '',
  }) async {
    if (txn.paid) return;
    final now = DateTime.now();

    await Db.transactions.doc(txn.id).update({
      'paid': true,
      'paidAt': Timestamp.fromDate(now),
      'payVia': payVia.name,
      'handledBy': handledBy,
    });

    final isSale = txn.type == TxnType.sale;
    await add(
      actor: actor,
      monthId: MonthRepo.bookingId,
      type: isSale ? TxnType.receipt : TxnType.payment,
      party: txn.party,
      category: isSale ? 'Khaata receipt' : _paymentCategory(txn),
      amount: txn.amount,
      paid: true,
      note: 'Settles ${txn.type.label.toLowerCase()} of ${fmtDate(txn.date)}',
      customerId: txn.customerId,
      // The entry above flipping to paid is what moved the cash. Tagging this
      // row keeps it in the ledger and the Sheet without the balance counting
      // the same rupees twice.
      settlesTxnId: txn.id,
      payVia: payVia,
      handledBy: handledBy,
      date: now,
    );

    // An udhaar customer's balance drops by whatever they just settled.
    final customerId = txn.customerId;
    if (isSale && customerId != null && customerId.isNotEmpty) {
      try {
        await Db.udhaarAccounts.doc(customerId).update({
          'balance': FieldValue.increment(-txn.amount),
        });
      } catch (_) {
        // No udhaar account for this party — nothing to reduce.
      }
    }

    await Log.write(
      actor,
      LogKind.transaction,
      'marked "${txn.party}" ${rs(txn.amount)} paid',
      refType: 'transaction',
      refId: txn.id,
    );
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
