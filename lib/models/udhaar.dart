import 'package:cloud_firestore/cloud_firestore.dart';

import '../util/money.dart';
import 'helpers.dart';

enum UdhaarStatus {
  none,
  pending,
  approved,
  rejected,

  /// Settled up and off the round — someone who stopped taking milk. Their
  /// bills and history stay, so an old balance is never lost.
  closed;

  static UdhaarStatus parse(Object? v) => switch (s(v)) {
    'approved' => UdhaarStatus.approved,
    'rejected' => UdhaarStatus.rejected,
    'pending' => UdhaarStatus.pending,
    'closed' => UdhaarStatus.closed,
    _ => UdhaarStatus.none,
  };

  String get label => switch (this) {
    UdhaarStatus.none => 'No khaata',
    UdhaarStatus.pending => 'Pending approval',
    UdhaarStatus.approved => 'Approved',
    UdhaarStatus.rejected => 'Not approved',
    UdhaarStatus.closed => 'Closed',
  };
}

class UdhaarAccount {
  UdhaarAccount({
    required this.uid,
    required this.name,
    required this.address,
    required this.mobile,
    required this.slot,
    required this.litresPerDay,
    required this.rate,
    required this.balance,
    required this.status,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    required this.createdAt,
  });

  final String uid;
  final String name;
  final String address;
  final String mobile;
  final String slot; // morning | evening
  final num litresPerDay;

  /// This customer's own rate per litre. Regulars are often given a little
  /// off the shop price, so it is kept per account rather than read from the
  /// product list.
  final num rate;

  final num balance;
  final UdhaarStatus status;
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;
  final DateTime createdAt;

  bool get isApproved => status == UdhaarStatus.approved;

  /// A closed khaata comes off the daily round but is still billed and
  /// collected: the milk it took, and whatever it still owes, belong to the
  /// farm either way.
  bool get isBillable =>
      status == UdhaarStatus.approved || status == UdhaarStatus.closed;
  String get slotLabel => slot == 'evening' ? 'Evening 5–8' : 'Morning 6–9';

  /// What a month of this khaata comes to at the customer's own rate — two
  /// litres a day at Rs 220 is about Rs 13,200.
  ///
  /// An estimate, not a promise: the bill is whatever milk actually went out,
  /// day by day. It is here so both sides know roughly what is coming before
  /// the month ends.
  num get monthlyEstimate => litresPerDay * rate * 30;

  /// "2 L/day × Rs 220 ≈ Rs 13,200 a month"
  String get monthlyLine => monthEstimateLine(litresPerDay, rate);

  static String monthEstimateLine(num litresPerDay, num rate) =>
      '${qty(litresPerDay)} L/day × ${rs(rate)} × 30 days ≈ '
      '${rs(litresPerDay * rate * 30)} a month';

  factory UdhaarAccount.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return UdhaarAccount(
      uid: doc.id,
      name: s(m['name']),
      address: s(m['address']),
      mobile: s(m['mobile']),
      slot: s(m['slot']).isEmpty ? 'morning' : s(m['slot']),
      litresPerDay: n(m['litresPerDay']),
      rate: n(m['rate']),
      balance: n(m['balance']),
      status: UdhaarStatus.parse(m['status']),
      approvedBy: m['approvedBy'] == null ? null : s(m['approvedBy']),
      approvedByName: m['approvedByName'] == null
          ? null
          : s(m['approvedByName']),
      approvedAt: dt(m['approvedAt']),
      createdAt: dtOr(m['createdAt']),
    );
  }
}
