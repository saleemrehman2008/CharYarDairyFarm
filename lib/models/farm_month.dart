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

  /// The frozen slice, as the master writes it at the seal. The decision is
  /// not in here: it belongs to the co-founder and is written separately, so
  /// the database itself can hold each of them to their own row.
  Map<String, dynamic> toMap() => {
    'partnerId': partnerId,
    'name': name,
    'ratio': ratio,
    'share': share,
  };

  /// What one co-founder decided, as stored under their own key.
  Map<String, dynamic> decisionMap() => {
    'withdraw': withdraw,
    'decidedAt': decidedAt == null ? null : Timestamp.fromDate(decidedAt!),
    'decidedBy': decidedBy,
    'byPhone': byPhone,
  };

  /// The same slice with a decision laid over it.
  MonthShare withDecision(Map<String, dynamic> m) => MonthShare(
    partnerId: partnerId,
    name: name,
    ratio: ratio,
    share: share,
    choice: choice,
    withdraw: n(m['withdraw']).clamp(0, share),
    decidedAt: dt(m['decidedAt']),
    decidedBy: s(m['decidedBy']),
    byPhone: b(m['byPhone']),
  );

  factory MonthShare.fromMap(Map<String, dynamic> m) {
    final share = n(m['share']);
    // A period closed before decisions were split out carried the whole
    // answer in one word. A period sealed since carries no answer at all
    // until its co-founder writes one, and an unanswered share takes nothing.
    final legacy = m.containsKey('choice');
    final choice = legacy ? s(m['choice']) : 'reinvest';
    return MonthShare(
      partnerId: s(m['partnerId']),
      name: s(m['name']),
      ratio: d(m['ratio']),
      share: share,
      choice: choice,
      withdraw: legacy ? (choice == 'reinvest' ? 0 : share) : 0,
      decidedAt: legacy ? dt(m['decidedAt']) ?? DateTime(2000) : null,
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
    this.otherIncome,
    this.purchases,
    this.expenses,
    this.receivables,
    this.carriedReceivable,
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

  /// Money in with no sale against it. Counted in [profit] like any other
  /// income, and kept so the all-time costs can be read back correctly.
  final num? otherIncome;
  final num? purchases;
  final num? expenses;
  final num? receivables;

  /// Receivables this period held back from the sharing because the master
  /// chose to roll them. The next period adds them back in, so money booked on
  /// credit is shared when it is collected rather than never.
  final num? carriedReceivable;

  /// Cattle and equipment bought in the period — held out of the running
  /// costs when the all-time figures are added up.
  final num? assets;

  final List<MonthShare> shares;

  bool get isOpen => status == 'open';
  bool get isSealed => status == 'sealed';
  bool get isClosed => status == 'closed';

  /// Sealed or closed: no new entry may be booked into it.
  bool get isFrozen => !isOpen;

  /// A period that made nothing has nothing to hand out.
  ///
  /// It still has to close — the books have to roll forward, and a farm that
  /// spent more than it sold this month is an ordinary thing, not a reason to
  /// jam the app shut. Nobody is asked to decide about nothing.
  ///
  /// Read from the slices themselves rather than from the profit figure, so
  /// it is true of what was actually sent out and not of what was calculated
  /// on the way there.
  bool get nothingToShare =>
      shares.isEmpty || shares.every((s) => s.share <= 0);

  /// Everyone has said what they want. Until then the master cannot close.
  bool get allDecided =>
      nothingToShare || (shares.isNotEmpty && shares.every((s) => s.decided));

  List<MonthShare> get undecided => shares.where((s) => !s.decided).toList();

  num get totalWithdraw => shares.fold<num>(0, (a, s) => a + s.withdraw);
  num get totalReinvest => shares.fold<num>(0, (a, s) => a + s.reinvest);

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
      otherIncome: m['otherIncome'] == null ? null : n(m['otherIncome']),
      purchases: m['purchases'] == null ? null : n(m['purchases']),
      expenses: m['expenses'] == null ? null : n(m['expenses']),
      receivables: m['receivables'] == null ? null : n(m['receivables']),
      carriedReceivable: m['carriedReceivable'] == null
          ? null
          : n(m['carriedReceivable']),
      assets: m['assets'] == null ? null : n(m['assets']),
      shares: _readShares(m),
    );
  }
}

/// The frozen slices with each co-founder's own decision laid over them.
///
/// Two fields rather than one, because two different people write them and
/// the database has to be able to tell them apart. The master writes the
/// slices at the seal; each co-founder writes only their own key under
/// `decisions`. Nobody can touch anybody else's, and that is enforced by the
/// rules rather than by the app being polite.
List<MonthShare> _readShares(Map<String, dynamic> m) {
  final decisions =
      (m['decisions'] as Map?)?.cast<String, dynamic>() ?? const {};
  return ((m['shares'] as List?) ?? const [])
      .whereType<Map>()
      .map((e) => MonthShare.fromMap(e.cast<String, dynamic>()))
      .map((base) {
        final d = (decisions[base.partnerId] as Map?)?.cast<String, dynamic>();
        return d == null ? base : base.withDecision(d);
      })
      .toList();
}
