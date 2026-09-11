import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../util/money.dart';
import 'db.dart';
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
  static Future<void> markPaid(Actor actor, Txn txn) async {
    if (txn.paid) return;
    final now = DateTime.now();

    await Db.transactions.doc(txn.id).update({
      'paid': true,
      'paidAt': Timestamp.fromDate(now),
    });

    final isSale = txn.type == TxnType.sale;
    await add(
      actor: actor,
      monthId: monthIdOf(now),
      type: isSale ? TxnType.receipt : TxnType.payment,
      party: txn.party,
      category: isSale ? 'Udhaar receipt' : _paymentCategory(txn),
      amount: txn.amount,
      paid: true,
      note: 'Settles ${txn.type.label.toLowerCase()} of ${fmtDate(txn.date)}',
      customerId: txn.customerId,
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
  static Future<void> softDelete(Actor actor, Txn txn) async {
    await Db.transactions.doc(txn.id).update({
      'deletedAt': FieldValue.serverTimestamp(),
    });
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
