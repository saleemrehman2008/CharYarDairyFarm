import '../models/models.dart';

/// The farm's figures, derived from the ledger rather than stored — so a
/// corrected entry immediately corrects every card that shows it.
class Books {
  Books({
    required this.monthId,
    required this.openingCash,
    required List<Txn> monthTxns,
    required List<Txn> unpaidTxns,
  }) : sales = _sum(monthTxns, TxnType.sale),
       purchases = _sum(monthTxns, TxnType.purchase),
       expenses = _sum(monthTxns, TxnType.expense),
       receipts = _sum(monthTxns, TxnType.receipt),
       payments = _sum(monthTxns, TxnType.payment),
       paidSales = _sum(monthTxns, TxnType.sale, paidOnly: true),
       paidPurchases = _sum(monthTxns, TxnType.purchase, paidOnly: true),
       paidExpenses = _sum(monthTxns, TxnType.expense, paidOnly: true),
       receivable = unpaidTxns
           .where((t) => t.isReceivable)
           .fold<num>(0, (a, t) => a + t.amount),
       payable = unpaidTxns
           .where((t) => t.isPayable)
           .fold<num>(0, (a, t) => a + t.amount);

  final String monthId;
  final num openingCash;

  /// Booked this month, paid or not.
  final num sales;
  final num purchases;
  final num expenses;
  final num receipts;
  final num payments;

  /// Settled this month, for the cash line.
  final num paidSales;
  final num paidPurchases;
  final num paidExpenses;

  /// Outstanding across every month, not just this one.
  final num receivable;
  final num payable;

  num get costs => purchases + expenses;

  /// Profit for the open month, on an accrual basis.
  num get profit => sales - costs;

  num get cash =>
      openingCash +
      paidSales +
      receipts -
      paidPurchases -
      paidExpenses -
      payments;

  /// Bar width on the "Month to date" card.
  double get profitBar =>
      sales <= 0 ? 0 : (profit / sales).clamp(0, 1).toDouble();

  /// What a month close would share out.
  num profitToShare({required bool arIncluded}) =>
      arIncluded ? profit : profit - receivable;

  static num _sum(List<Txn> txns, TxnType type, {bool paidOnly = false}) => txns
      .where((t) => t.type == type && (!paidOnly || t.paid))
      .fold<num>(0, (a, t) => a + t.amount);

  static Books empty(String monthId) => Books(
    monthId: monthId,
    openingCash: 0,
    monthTxns: const [],
    unpaidTxns: const [],
  );
}

/// Rounded shares for a month close, one per partner.
List<MonthShare> shareOut({
  required List<Partner> partners,
  required num profitToShare,
  required Map<String, String> choices,
}) {
  final ratios = ratiosOf(partners);
  return partners.map((p) {
    final ratio = ratios[p.id] ?? 0;
    return MonthShare(
      partnerId: p.id,
      name: p.name,
      ratio: ratio,
      share: (profitToShare * ratio).round(),
      choice: choices[p.id] ?? 'withdraw',
    );
  }).toList();
}
