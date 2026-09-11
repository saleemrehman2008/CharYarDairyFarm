import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers.dart';

/// One partner's slice of a closed month.
class MonthShare {
  const MonthShare({
    required this.partnerId,
    required this.name,
    required this.ratio,
    required this.share,
    required this.choice,
  });

  final String partnerId;
  final String name;
  final double ratio;
  final num share;
  final String choice; // withdraw | reinvest

  bool get isReinvested => choice == 'reinvest';
  String get choiceLabel => isReinvested ? 'Reinvested' : 'Withdrawn';

  Map<String, dynamic> toMap() => {
    'partnerId': partnerId,
    'name': name,
    'ratio': ratio,
    'share': share,
    'choice': choice,
  };

  factory MonthShare.fromMap(Map<String, dynamic> m) => MonthShare(
    partnerId: s(m['partnerId']),
    name: s(m['name']),
    ratio: d(m['ratio']),
    share: n(m['share']),
    choice: s(m['choice']).isEmpty ? 'withdraw' : s(m['choice']),
  );
}

class FarmMonth {
  FarmMonth({
    required this.id,
    required this.status,
    required this.openingCash,
    this.closedAt,
    this.arIncluded,
    this.profit,
    this.sales,
    this.purchases,
    this.expenses,
    this.receivables,
    this.assets,
    this.shares = const [],
  });

  final String id; // YYYY-MM
  final String status; // open | closed
  final num openingCash;
  final DateTime? closedAt;
  final bool? arIncluded;
  final num? profit;
  final num? sales;
  final num? purchases;
  final num? expenses;
  final num? receivables;

  /// Cattle and equipment bought that month — held out of the running costs
  /// when the all-time figures are added up.
  final num? assets;

  final List<MonthShare> shares;

  bool get isClosed => status == 'closed';

  /// "AR counted" / "AR rolled" tag on the closed-months list.
  String get arLabel => arIncluded == true ? 'AR counted' : 'AR rolled';

  factory FarmMonth.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return FarmMonth(
      id: doc.id,
      status: s(m['status']).isEmpty ? 'open' : s(m['status']),
      openingCash: n(m['openingCash']),
      closedAt: dt(m['closedAt']),
      arIncluded: m['arIncluded'] == null ? null : b(m['arIncluded']),
      profit: m['profit'] == null ? null : n(m['profit']),
      sales: m['sales'] == null ? null : n(m['sales']),
      purchases: m['purchases'] == null ? null : n(m['purchases']),
      expenses: m['expenses'] == null ? null : n(m['expenses']),
      receivables: m['receivables'] == null ? null : n(m['receivables']),
      assets: m['assets'] == null ? null : n(m['assets']),
      shares: ((m['shares'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => MonthShare.fromMap(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}
