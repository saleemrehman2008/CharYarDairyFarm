import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers.dart';

enum UdhaarStatus {
  none,
  pending,
  approved,
  rejected;

  static UdhaarStatus parse(Object? v) => switch (s(v)) {
    'approved' => UdhaarStatus.approved,
    'rejected' => UdhaarStatus.rejected,
    'pending' => UdhaarStatus.pending,
    _ => UdhaarStatus.none,
  };

  String get label => switch (this) {
    UdhaarStatus.none => 'No khaata',
    UdhaarStatus.pending => 'Pending approval',
    UdhaarStatus.approved => 'Approved',
    UdhaarStatus.rejected => 'Not approved',
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
    required this.limit,
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

  final num limit;
  final num balance;
  final UdhaarStatus status;
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;
  final DateTime createdAt;

  bool get isApproved => status == UdhaarStatus.approved;
  num get headroom => limit - balance;

  String get slotLabel => slot == 'evening' ? 'Evening 5–8' : 'Morning 6–9';

  /// Suggested limit: litres x milk rate x 30 x 1.2, rounded up to Rs 1,000.
  static num suggestLimit(num litresPerDay, num milkRate) {
    final raw = litresPerDay * milkRate * 30 * 1.2;
    return (raw / 1000).ceil() * 1000;
  }

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
      limit: n(m['limit']),
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
