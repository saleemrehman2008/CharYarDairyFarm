import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers.dart';

class Partner {
  Partner({
    required this.id,
    required this.userId,
    required this.name,
    required this.invested,
    required this.reinvested,
    required this.withdrawn,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final num invested;
  final num reinvested;
  final num withdrawn;
  final DateTime createdAt;

  /// Capital that counts towards the share ratio.
  num get capital => invested + reinvested;

  factory Partner.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return Partner(
      id: doc.id,
      userId: s(m['userId']),
      name: s(m['name']),
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
