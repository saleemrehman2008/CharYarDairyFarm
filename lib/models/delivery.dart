import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers.dart';

/// One day's milk to one khaata customer.
///
/// The document id is `customerId_YYYY-MM-DD`, so marking the same day twice
/// overwrites rather than doubles — which matters when two co-founders are both
/// out on the round with the app open.
class Delivery {
  Delivery({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.date,
    required this.monthId,
    required this.litres,
    required this.rate,
    required this.slot,
    required this.deliveredByName,
    this.billId,
    this.billed = false,
    required this.createdAt,
  });

  final String id;
  final String customerId;
  final String customerName;
  final DateTime date;
  final String monthId;
  final num litres;
  final num rate;
  final String slot;
  final String deliveredByName;

  /// Set once the month's bill has been raised, so a delivery is never billed
  /// twice.
  final String? billId;

  /// The same fact as [billId], as a flag Firestore can be asked about — a
  /// missing field cannot be queried for, and the app needs to find days that
  /// have not been billed yet.
  final bool billed;

  final DateTime createdAt;

  num get amount => litres * rate;
  bool get isBilled => billed || billId != null;

  /// `customerId_YYYY-MM-DD`
  static String idFor(String customerId, DateTime date) =>
      '${customerId}_${dayKey(date)}';

  static String dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  factory Delivery.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    final date = dtOr(m['date']);
    return Delivery(
      id: doc.id,
      customerId: s(m['customerId']),
      customerName: s(m['customerName']),
      date: date,
      monthId: s(m['monthId']).isEmpty ? monthIdOf(date) : s(m['monthId']),
      litres: n(m['litres']),
      rate: n(m['rate']),
      slot: s(m['slot']).isEmpty ? 'morning' : s(m['slot']),
      deliveredByName: s(m['deliveredByName']),
      billId: m['billId'] == null ? null : s(m['billId']),
      billed: b(m['billed']),
      createdAt: dtOr(m['createdAt'], date),
    );
  }
}
