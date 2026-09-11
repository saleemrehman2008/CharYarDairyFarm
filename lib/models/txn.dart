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

/// How the money actually changed hands.
///
/// A farm's books are settled in person — someone hands over notes, someone
/// else gets a JazzCash message — and a month later the only way to check a
/// figure is to remember which. Recording it at the time is what makes that
/// possible.
enum PayVia {
  cash,
  bank,
  jazzcash,
  other;

  static PayVia parse(Object? v) => switch (s(v)) {
    'bank' => PayVia.bank,
    'jazzcash' => PayVia.jazzcash,
    'other' => PayVia.other,
    _ => PayVia.cash,
  };

  String get label => switch (this) {
    PayVia.cash => 'Cash',
    PayVia.bank => 'Bank',
    PayVia.jazzcash => 'JazzCash',
    PayVia.other => 'Other',
  };
}

/// Buying a buffalo is not a cost the way a bag of feed is. The cash leaves
/// either way, but the farm still owns the animal — it changed shape, it was
/// not spent. Counting it as a monthly cost would show a huge loss in the month
/// it was bought and flattering profits ever after, so these categories are
/// held out of the profit and reported as what the farm owns.
const assetCategories = {'Cattle purchase', 'Equipment'};

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
    this.settlesTxnId,
    this.paidOnCreate = false,
    this.payVia = PayVia.cash,
    this.handledBy = '',
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

  /// Set on the receipt or payment that "Mark paid" posts against an entry.
  ///
  /// The cash it moves is already captured by that entry flipping to paid, so
  /// the balance must not count this row a second time. It exists so the ledger
  /// and the Google Sheet still show when the money actually changed hands.
  final String? settlesTxnId;

  /// Named apart from `type.isSettlement`, which asks a different question:
  /// whether this is a receipt or payment at all.
  bool get settlesAnotherEntry => settlesTxnId != null;

  /// True when the money changed hands as this entry was written — "Paid now"
  /// on the form.
  ///
  /// An entry booked on credit is false forever, even after it is settled: the
  /// cash for it moves on the receipt or payment row that "Mark paid" posts,
  /// which may well be in a later month. Keeping the two apart is what lets a
  /// balance stay right across a month close.
  final bool paidOnCreate;

  /// Cash, bank or JazzCash — only meaningful once the money has moved.
  final PayVia payVia;

  /// The person who handed the money over or took it in. Not the person who
  /// typed the entry: the worker who went to the mandi may not be the
  /// co-founder who recorded it that evening.
  final String handledBy;

  /// "Received by" for money coming in, "Paid by" for money going out.
  String get handledLabel => type.isIncoming ? 'Received by' : 'Paid by';

  /// "Cash · Riaz" for the ledger row, empty when nothing was recorded.
  String get handOverLine {
    if (!paid) return '';
    final who = handledBy.trim();
    return who.isEmpty ? payVia.label : '${payVia.label} · $who';
  }

  final String createdBy;
  final DateTime createdAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  /// Cattle and equipment the farm now owns, rather than money it spent.
  bool get isCapitalAsset =>
      (type == TxnType.purchase || type == TxnType.expense) &&
      assetCategories.contains(category);

  /// Feed, salaries, bills — the cost of running the farm this month.
  bool get isRunningCost =>
      (type == TxnType.purchase || type == TxnType.expense) && !isCapitalAsset;

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

  /// Entries written before the app recorded [paidOnCreate] are read back from
  /// their timestamps: money that moved as the row was created has a `paidAt`
  /// alongside its `createdAt`, while "Mark paid" stamps one much later.
  static bool _wasPaidOnCreate(bool paid, DateTime? paidAt, DateTime created) {
    if (!paid) return false;
    if (paidAt == null) return true;
    return paidAt.difference(created).abs() < const Duration(minutes: 2);
  }

  factory Txn.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    final date = dtOr(m['date']);
    final paid = b(m['paid']);
    final paidAt = dt(m['paidAt']);
    final createdAt = dtOr(m['createdAt'], date);
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
      paid: paid,
      paidAt: paidAt,
      note: s(m['note']),
      orderId: m['orderId'] == null ? null : s(m['orderId']),
      settlesTxnId: m['settlesTxnId'] == null ? null : s(m['settlesTxnId']),
      paidOnCreate: m['paidOnCreate'] == null
          ? _wasPaidOnCreate(paid, paidAt, createdAt)
          : b(m['paidOnCreate']),
      payVia: PayVia.parse(m['payVia']),
      handledBy: s(m['handledBy']),
      createdBy: s(m['createdBy']),
      createdAt: createdAt,
      deletedAt: dt(m['deletedAt']),
    );
  }
}
