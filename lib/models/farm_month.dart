import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers.dart';

/// One partner's slice of a period, and how much of it they were handed.
///
/// There is no decision in here any more. Version 1 asked each co-founder what
/// they wanted doing with their share and would not close until all four had
/// answered — which is a fine rule and a bad one to live under when the answer
/// is the same every month for a year. The four of them have agreed to keep
/// the lot in and buy more buffaloes with it, so the master now sets one
/// percentage for everybody at the close and this records what that came to.
///
/// The same percentage for all four is not a convenience, it is what makes the
/// ratio fair: everyone keeps back the same proportion, so nobody ends up with
/// more of their money working in the farm than their share of it reflects.
class MonthShare {
  const MonthShare({
    required this.partnerId,
    required this.name,
    required this.ratio,
    required this.share,
    this.taken = 0,
  });

  final String partnerId;
  final String name;
  final double ratio;

  /// Their slice of what the period made — or lost, in which case it is
  /// negative and nothing is handed out.
  final num share;

  /// How much of it actually left the farm.
  final num taken;

  /// What stayed in, and went into their profit account.
  num get held => share - taken;

  bool get isLoss => share < 0;

  Map<String, dynamic> toMap() => {
    'partnerId': partnerId,
    'name': name,
    'ratio': ratio,
    'share': share,
    'taken': taken,
  };

  MonthShare handing(num taken) => MonthShare(
    partnerId: partnerId,
    name: name,
    ratio: ratio,
    share: share,
    taken: taken,
  );

  factory MonthShare.fromMap(Map<String, dynamic> m) => MonthShare(
    partnerId: s(m['partnerId']),
    name: s(m['name']),
    ratio: d(m['ratio']),
    share: n(m['share']),
    // Version 1 called it a withdrawal, because it was one — the co-founder
    // had asked for it. Months closed then still say so.
    taken: m['taken'] == null ? n(m['withdraw']) : n(m['taken']),
  );
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
    this.seen = const {},
    this.sharedPercent,
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

  /// When each co-founder opened the closed period and said they had seen it.
  final Map<String, DateTime> seen;

  /// What proportion of the profit the master handed out at the close, as a
  /// whole number. Null on a period that has not been closed yet.
  ///
  /// One figure for all four. It is on the period rather than worked out
  /// backwards from the slices so that a close which handed out nothing can
  /// still say it meant to.
  final int? sharedPercent;

  bool get isOpen => status == 'open';
  bool get isSealed => status == 'sealed';
  bool get isClosed => status == 'closed';

  /// Sealed or closed: no new entry may be booked into it.
  bool get isFrozen => !isOpen;

  /// What it cost to run the farm in this period, from the figures frozen at
  /// the seal.
  ///
  /// Sales plus other income less profit, because that is what the costs were
  /// by definition — the three were written down together and the fourth
  /// follows from them. Adding the stored purchases and expenses instead
  /// quietly drops a rent that went out as a plain payment, and then the
  /// figures on one line stop adding up to each other.
  ///
  /// The fallback is for a period sealed before profit was stored.
  num get runningCosts {
    final s = sales, p = profit;
    if (s != null && p != null) return s + (otherIncome ?? 0) - p;
    return (purchases ?? 0) + (expenses ?? 0) - (assets ?? 0);
  }

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

  /// A period that lost money. Nothing is handed out and every slice is
  /// negative — which is not hidden, at Saleem's word: a loss that is not
  /// written down is a loss somebody finds out about later.
  bool get isLoss => (profit ?? 0) < 0;

  num get totalTaken => shares.fold<num>(0, (a, s) => a + s.taken);
  num get totalHeld => shares.fold<num>(0, (a, s) => a + s.held);

  /// Which of the four have opened the close and seen the figures.
  ///
  /// Not a gate. The master closes when he closes; this is the record that
  /// the other three were shown what it came to and when. Four friends in
  /// business need that written down more than they need a veto.
  bool seenBy(String partnerId) => seen.containsKey(partnerId);

  List<MonthShare> get notSeen =>
      shares.where((s) => !seenBy(s.partnerId)).toList();

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
      seen: _readSeen(m),
      sharedPercent: m['sharedPercent'] == null
          ? null
          : n(m['sharedPercent']).round(),
    );
  }
}

/// The frozen slices with each co-founder's own decision laid over them.
///
/// Two fields rather than one, because two different people write them and
/// the database has to be able to tell them apart. The master writes the
/// slices at the seal; each co-founder writes only their own key under
/// `decisions`, as version 1 called it. The master writes the slices and what
/// each of them came to; each co-founder writes only their own key, and it now
/// says they have seen it rather than what they want done.
List<MonthShare> _readShares(Map<String, dynamic> m) =>
    ((m['shares'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => MonthShare.fromMap(e.cast<String, dynamic>()))
        .toList();

/// When each co-founder opened the closed period, by partner id.
Map<String, DateTime> _readSeen(Map<String, dynamic> m) {
  final raw = (m['seen'] as Map?)?.cast<String, dynamic>() ?? const {};
  final out = <String, DateTime>{};
  raw.forEach((k, v) {
    final at = dt(v);
    if (at != null) out[k] = at;
  });
  return out;
}
