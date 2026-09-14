import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers.dart';

class Partner {
  Partner({
    required this.id,
    required this.userId,
    required this.name,
    this.email = '',
    required this.invested,
    required this.reinvested,
    required this.withdrawn,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;

  /// The account this record belongs to, shown under the name.
  ///
  /// One person can hold two accounts on the same farm — a master login and a
  /// co-founder login — and both carry the same display name from Google. The
  /// email is the only thing on screen that tells them apart.
  final String email;
  final num invested;
  final num reinvested;
  final num withdrawn;
  final DateTime createdAt;

  /// Capital that counts towards the share ratio.
  num get capital => invested + reinvested;

  /// No money has ever passed through this record.
  ///
  /// Which makes it safe to delete: there is nothing in it to lose, and no
  /// closed period's figures depend on it.
  bool get isEmpty => invested == 0 && reinvested == 0 && withdrawn == 0;

  factory Partner.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return Partner(
      id: doc.id,
      userId: s(m['userId']),
      name: s(m['name']),
      email: s(m['email']),
      invested: n(m['invested']),
      reinvested: n(m['reinvested']),
      withdrawn: n(m['withdrawn']),
      createdAt: dtOr(m['createdAt']),
    );
  }
}

/// Share ratio = (invested + reinvested) / total capital across partners.
Map<String, double> ratiosOf(List<Partner> partners) {
  final total = partners.fold<num>(0, (a, p) => a + p.capital);
  if (total <= 0) {
    final even = partners.isEmpty ? 0.0 : 1 / partners.length;
    return {for (final p in partners) p.id: even};
  }
  return {for (final p in partners) p.id: p.capital / total};
}
