import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers.dart';

enum TxnType {
  sale,
  purchase,
  expense,
  receipt,
  payment;

  static TxnType parse(Object? v) => switch (s(v)) {
    'purchase' => TxnType.purchase,
    'expense' => TxnType.expense,
    'receipt' => TxnType.receipt,
    'payment' => TxnType.payment,
    _ => TxnType.sale,
  };

  String get label => switch (this) {
    TxnType.sale => 'Sale',
    TxnType.purchase => 'Purchase',
    TxnType.expense => 'Expense',
    TxnType.receipt => 'Receipt',
    TxnType.payment => 'Payment',
  };

  /// Money coming in shows with a `+`, everything else with a `-`.
  bool get isIncoming => this == TxnType.sale || this == TxnType.receipt;

  /// Receipts and payments settle money that was already booked, so they carry
  /// no quantity or rate and are never "unpaid".
  bool get isSettlement => this == TxnType.receipt || this == TxnType.payment;

  /// Label for the "not settled yet" option on the entry form.
  String get unpaidLabel => switch (this) {
    TxnType.sale => 'Not received yet (udhaar / AR)',
    _ => 'Not paid yet (AP)',
  };

  List<String> get categories => switch (this) {
    TxnType.sale => const [
      'Milk',
      'Dahi',
      'Butter',
      'Ghee',
      'Lassi',
      'Paneer',
      'Cream',
      'Khoya',
      'Cattle sale',
      'Dung / manure',
      'Other sale',
    ],
    TxnType.purchase => const [
      'Fodder / feed',
      'Cattle purchase',
      'Equipment',
      'Vet & medicine',
      'Food & kitchen',
      'Other purchase',
    ],
    TxnType.expense => const [
      'Salaries',
      'Rent',
      'Utilities (bijli, gas, pani)',
      'Food & kitchen',
      'Transport',
      'Vet & medicine',
      'Repairs',
      'Equipment',
      'Fodder / feed',
      'Other expense',
    ],
    TxnType.receipt => const ['Udhaar receipt', 'Advance', 'Other receipt'],
    TxnType.payment => const [
      'Supplier payment',
      'Rent',
      'Utilities (bijli, gas, pani)',
      'Salaries',
      'Other payment',
    ],
  };
}

/// Units offered on the new-entry form.
const txnUnits = ['L', 'kg', 'maund', 'bag', 'pc', 'head', 'month'];

class Txn {
  Txn({
    required this.id,
    required this.date,
    required this.monthId,
    required this.type,
    required this.party,
    this.customerId,
    required this.category,
    this.qty,
    this.unit,
    this.rate,
    required this.amount,
    required this.paid,
    this.paidAt,
    required this.note,
    this.orderId,
    required this.createdBy,
    required this.createdAt,
    this.deletedAt,
  });

  final String id;
  final DateTime date;
  final String monthId;
  final TxnType type;
  final String party;
  final String? customerId;
  final String category;
  final num? qty;
  final String? unit;
  final num? rate;
  final num amount;
  final bool paid;
  final DateTime? paidAt;
  final String note;
  final String? orderId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  /// Unpaid sales are receivables; unpaid purchases and expenses are payables.
  bool get isReceivable => !paid && type == TxnType.sale;
  bool get isPayable =>
      !paid && (type == TxnType.purchase || type == TxnType.expense);

  /// Reads back as "240 L x Rs 200" when the entry was measured.
  String? get qtyLine {
    final q = qty, r = rate;
    if (q == null || r == null || q == 0) return null;
    final qs = q % 1 == 0 ? q.toInt().toString() : q.toString();
    return '$qs ${unit ?? ''} × Rs ${r.round()}';
  }

  factory Txn.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    final date = dtOr(m['date']);
    return Txn(
      id: doc.id,
      date: date,
      monthId: s(m['monthId']).isEmpty ? monthIdOf(date) : s(m['monthId']),
      type: TxnType.parse(m['type']),
      party: s(m['party']),
      customerId: m['customerId'] == null ? null : s(m['customerId']),
      category: s(m['category']),
      qty: m['qty'] == null ? null : n(m['qty']),
      unit: m['unit'] == null ? null : s(m['unit']),
      rate: m['rate'] == null ? null : n(m['rate']),
      amount: n(m['amount']),
      paid: b(m['paid']),
      paidAt: dt(m['paidAt']),
      note: s(m['note']),
      orderId: m['orderId'] == null ? null : s(m['orderId']),
      createdBy: s(m['createdBy']),
      createdAt: dtOr(m['createdAt'], date),
      deletedAt: dt(m['deletedAt']),
    );
  }
}
