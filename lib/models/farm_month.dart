import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers.dart';

/// What one partner does with their slice of a period.
///
/// The choice is theirs, not the master's. It arrives here when they make it,
/// and the master can only fill it in for them after speaking to them — which
/// is recorded, so the farm can always see who actually decided.
class MonthShare {
  const MonthShare({
    required this.partnerId,
    required this.name,
    required this.ratio,
    required this.share,
    required this.choice,
    this.withdraw = 0,
    this.decidedAt,
    this.decidedBy = '',
    this.byPhone = false,
  });

  final String partnerId;
  final String name;
  final double ratio;

  /// The whole slice, frozen when the master sent it out.
  final num share;

  /// Kept for the months closed under the old all-or-nothing rule, where a
  /// partner either took the lot or left the lot.
  final String choice; // withdraw | reinvest | split

  /// How much of [share] this partner is taking out. The rest is added to
  /// their investment.
  final num withdraw;

  /// Set once they have actually decided. Until then the master cannot close.
  final DateTime? decidedAt;

  /// Whose finger pressed it. Their own uid normally; the master's when
  /// [byPhone].
  final String decidedBy;

  /// The master entered this after ringing them, because they had not
  /// answered in the app.
  final bool byPhone;

  bool get decided => decidedAt != null;

  /// What goes back into the farm.
  num get reinvest => share - withdraw;

  bool get isReinvested => withdraw <= 0;
  bool get takesAll => withdraw >= share;

  String get choiceLabel => switch (true) {
    _ when takesAll => 'Withdrawing',
    _ when isReinvested => 'Reinvesting',
    _ => 'Part out, part in',
  };

  MonthShare decide({
    required num withdraw,
    required String by,
    bool byPhone = false,
  }) => MonthShare(
    partnerId: partnerId,
    name: name,
    ratio: ratio,
    share: share,
    choice: withdraw <= 0
        ? 'reinvest'
        : withdraw >= share
        ? 'withdraw'
        : 'split',
    withdraw: withdraw.clamp(0, share),
    decidedAt: DateTime.now(),
    decidedBy: by,
    byPhone: byPhone,
  );

  Map<String, dynamic> toMap() => {
    'partnerId': partnerId,
    'name': name,
    'ratio': ratio,
    'share': share,
    'choice': choice,
    'withdraw': withdraw,
    if (decidedAt != null) 'decidedAt': Timestamp.fromDate(decidedAt!),
    'decidedBy': decidedBy,
    'byPhone': byPhone,
  };

  factory MonthShare.fromMap(Map<String, dynamic> m) {
    final share = n(m['share']);
    final choice = s(m['choice']).isEmpty ? 'withdraw' : s(m['choice']);
    return MonthShare(
      partnerId: s(m['partnerId']),
      name: s(m['name']),
      ratio: d(m['ratio']),
      share: share,
      choice: choice,
      // A period closed before split decisions existed recorded only the
      // choice, so read the amount back out of it.
      withdraw: m['withdraw'] == null
          ? (choice == 'reinvest' ? 0 : share)
          : n(m['withdraw']),
      decidedAt: dt(m['decidedAt']),
      decidedBy: s(m['decidedBy']),
      byPhone: b(m['byPhone']),
    );
  }
}

/// One stretch of trading the farm settles up at the end of.
///
/// Usually a calendar month, which is why the id looks like `2026-09` and the
/// class is still called a month. It does not have to be: the farm can settle
/// mid-month, and then September has two periods — `2026-09` running to the
/// 14th and `2026-09b` running to the 30th. [from] and [to] are what the
/// period actually covers; the id is only its name.
class FarmMonth {
  FarmMonth({
    required this.id,
    required this.status,
    required this.openingCash,
    this.from,
    this.to,
    this.sealedAt,
    this.sealedBy = '',
    this.sealedByName = '',
    this.closedAt,
    this.arIncluded,
    this.profit,
    this.profitShared,
    this.sales,
    this.purchases,
    this.expenses,
    this.receivables,
    this.assets,
    this.shares = const [],
  });

  final String id;

  /// `open` while entries land in it, `sealed` once the master has sent the
  /// figures to the co-founders, `closed` once the shares are posted.
  final String status;

  final num openingCash;

  /// When the period began taking entries, and when it stopped.
  final DateTime? from;
  final DateTime? to;

  /// The moment the figures froze.
  final DateTime? sealedAt;
  final String sealedBy;
  final String sealedByName;

  final DateTime? closedAt;
  final bool? arIncluded;

  /// The figures as they stood at [sealedAt]. Written once and never
  /// recomputed, so a co-founder deciding two days late is deciding about the
  /// same money the first one saw.
  final num? profit;
  final num? profitShared;
  final num? sales;
  final num? purchases;
  final num? expenses;
  final num? receivables;

  /// Cattle and equipment bought in the period — held out of the running
  /// costs when the all-time figures are added up.
  final num? assets;

  final List<MonthShare> shares;

  bool get isOpen => status == 'open';
  bool get isSealed => status == 'sealed';
  bool get isClosed => status == 'closed';

  /// Sealed or closed: no new entry may be booked into it.
  bool get isFrozen => !isOpen;

  /// Everyone has said what they want. Until then the master cannot close.
  bool get allDecided => shares.isNotEmpty && shares.every((s) => s.decided);

  List<MonthShare> get undecided =>
      shares.where((s) => !s.decided).toList();

  num get totalWithdraw =>
      shares.fold<num>(0, (a, s) => a + s.withdraw);
  num get totalReinvest =>
      shares.fold<num>(0, (a, s) => a + s.reinvest);

  MonthShare? shareFor(String partnerId) {
    for (final s in shares) {
      if (s.partnerId == partnerId) return s;
    }
    return null;
  }

  /// "AR counted" / "AR rolled" tag on the closed-periods list.
  String get arLabel => arIncluded == true ? 'AR counted' : 'AR rolled';

  factory FarmMonth.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return FarmMonth(
      id: doc.id,
      status: s(m['status']).isEmpty ? 'open' : s(m['status']),
      openingCash: n(m['openingCash']),
      from: dt(m['from']),
      to: dt(m['to']),
      sealedAt: dt(m['sealedAt']),
      sealedBy: s(m['sealedBy']),
      sealedByName: s(m['sealedByName']),
      closedAt: dt(m['closedAt']),
      arIncluded: m['arIncluded'] == null ? null : b(m['arIncluded']),
      profit: m['profit'] == null ? null : n(m['profit']),
      profitShared: m['profitShared'] == null ? null : n(m['profitShared']),
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
