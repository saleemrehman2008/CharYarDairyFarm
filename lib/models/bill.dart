import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers.dart';

/// One customer's khaata bill for one month.
///
/// A bill carries whatever was left unpaid from last month, so a customer who
/// pays Rs 6,000 against Rs 6,600 sees the Rs 600 again on the next bill rather
/// than it quietly disappearing. The document id is `customerId_YYYY-MM`, which
/// makes raising the same month twice harmless.
class Bill {
  Bill({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.monthId,
    required this.litres,
    required this.thisMonth,
    required this.previousBalance,
    required this.paid,
    required this.createdAt,
    this.settledAt,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String monthId;

  /// Milk delivered this month.
  final num litres;

  /// What this month's milk came to.
  final num thisMonth;

  /// Left over from the month before.
  final num previousBalance;

  /// Paid against this bill so far — part payments are normal.
  final num paid;

  final DateTime createdAt;
  final DateTime? settledAt;

  num get total => thisMonth + previousBalance;
  num get balance => total - paid;
  bool get isSettled => balance <= 0;
  bool get isPartPaid => paid > 0 && !isSettled;

  String get statusLabel {
    if (isSettled) return 'Paid';
    if (isPartPaid) return 'Part paid';
    return 'Unpaid';
  }

  /// `customerId_YYYY-MM`
  static String idFor(String customerId, String monthId) =>
      '${customerId}_$monthId';

  factory Bill.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return Bill(
      id: doc.id,
      customerId: s(m['customerId']),
      customerName: s(m['customerName']),
      monthId: s(m['monthId']),
      litres: n(m['litres']),
      thisMonth: n(m['thisMonth']),
      previousBalance: n(m['previousBalance']),
      paid: n(m['paid']),
      createdAt: dtOr(m['createdAt']),
      settledAt: dt(m['settledAt']),
    );
  }
}
