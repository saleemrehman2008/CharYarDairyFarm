import '../models/models.dart';
import 'accounting.dart';

/// Where the money goes, and whether too much of it goes there.
///
/// The farm asked the question plainly: what percentage of a business should
/// be rent, what should running cost be, what should be left as profit — and
/// which zone are we overspending in.
///
/// There is no law about this, and anybody who gives one figure is guessing.
/// What there is, for a dairy, is a shape that holds almost everywhere:
/// **feed is the biggest cost by a long way**, wages are second, and
/// everything else together is smaller than either. The studies disagree on
/// the exact share — Pakistani surveys put feed anywhere from 43% to 80% of
/// the cost of producing milk, depending on whether they counted labour and
/// fixed costs — but none of them disagree about the shape.
///
/// So the bands here are working bands, not law: measured against **sales**
/// (not against total cost, which moves when any one cost moves), and wide
/// enough that being inside one means nothing is wrong and being well
/// outside one is worth a look. The farm's own months are the better
/// yardstick once there are a few of them; until then these are a start.
///
/// The one thing this is strict about: the zones add up to exactly what the
/// report calls money out. A page that says where the money went has to
/// account for all of it.
enum Zone {
  /// Wanda, chokar, silage, green fodder. The big one — and the only zone
  /// where a few rupees a bag moves the whole year's profit.
  feed('Fodder / feed', 0.50, 0.65),

  /// Milk bought in to sell on. Its own zone because it is not a farm cost
  /// at all, it is trading: the question about it is the margin, not the
  /// share. So it carries no band.
  milkIn('Milk bought in', null, null),

  /// Wages. The advance and the loan are not here — that money comes back.
  wages('Wages', 0.08, 0.15),

  rent('Rent', 0, 0.08),

  vet('Vet & medicine', 0.02, 0.05),

  power('Utilities (bijli, gas, pani)', 0.03, 0.07),

  /// Transport, repairs, kitchen, and whatever else was typed. Held to a
  /// band of its own because this is where a farm's money quietly leaks:
  /// no single entry looks big enough to argue about.
  other('Everything else', 0.05, 0.12);

  const Zone(this.label, this.least, this.most);

  /// What to call it on screen. Translated like any other word.
  final String label;

  /// The share of sales a dairy usually keeps this zone inside. Null on a
  /// zone there is no honest band for.
  final double? least;
  final double? most;

  bool get hasBand => most != null;
}

/// What one zone came to, against its band.
class ZoneLine {
  const ZoneLine({
    required this.zone,
    required this.spent,
    required this.sales,
  });

  final Zone zone;

  /// What went out on it in the stretch being looked at.
  final num spent;

  /// What came in, which is what the share is measured against.
  final num sales;

  /// Its share of sales, 0 when nothing came in — a month with no sales
  /// has no percentages, only figures.
  double get share => sales <= 0 ? 0 : spent / sales;

  /// How many rupees above the top of its band, and nothing when it is
  /// inside the band, under it, or has no band.
  ///
  /// Rupees and not percentage points, because that is the number worth
  /// acting on: three points over on feed is more money than doubling the
  /// vet bill, and a list ranked by percentage would send the farm after
  /// the wrong one.
  num get over {
    if (!zone.hasBand || sales <= 0) return 0;
    final ceiling = zone.most! * sales;
    return spent > ceiling ? spent - ceiling : 0;
  }

  /// Under the bottom of its band. Not a fault — and worth seeing, because
  /// on feed and on the vet it usually costs more later than it saves now.
  bool get under =>
      zone.hasBand && sales > 0 && spent < zone.least! * sales && spent >= 0;
}

/// Every zone of the farm's spending, and what it says.
class SpendZones {
  const SpendZones({
    required this.sales,
    required this.spent,
    required this.lines,
  });

  /// Everything that came in, as the report counts it.
  final num sales;

  /// What the stretch cost to run — cattle and advances already out of it,
  /// exactly as on the report.
  final num spent;

  /// One line a zone, biggest spend first. Zones with nothing against them
  /// are left out: an empty line is a row to read and nothing to learn.
  final List<ZoneLine> lines;

  /// What was left.
  num get profit => sales - spent;

  double get profitShare => sales <= 0 ? 0 : profit / sales;

  /// What the running cost came to as a share of sales. The single figure
  /// that decides whether there is a profit at all: a dairy wants this
  /// under about 0.80.
  double get spendShare => sales <= 0 ? 0 : spent / sales;

  /// A profit this size or better is a month that worked.
  static const profitLeast = 0.15;
  static const profitGood = 0.25;

  /// Running cost above this and the profit has nowhere to come from.
  static const spendMost = 0.80;

  /// The zone to go and look at: the one that is the most rupees above its
  /// band. Null when every zone is inside its band, which is the answer
  /// "nothing is out of place" and should be said rather than hidden.
  ZoneLine? get focus {
    ZoneLine? worst;
    for (final line in lines) {
      if (line.over <= 0) continue;
      if (worst == null || line.over > worst.over) worst = line;
    }
    return worst;
  }

  /// A zone has to be past its band by this much of what came in before
  /// the page says it in red.
  ///
  /// Six thousand rupees past the band on a five-lakh month that earned
  /// twenty-three per cent is worth knowing and is not an emergency, and
  /// a page that shouts at that will be ignored the month it matters. So
  /// the red is kept for a zone that is actually eating the month.
  static const focusIsBig = 0.02;

  /// Whether [focus] is worth the loud colour.
  bool get focusMatters =>
      focus != null && sales > 0 && focus!.over >= sales * focusIsBig;

  bool get isEmpty => sales <= 0 && spent <= 0;
}

/// Which zone a category belongs to.
///
/// Folded the way names are folded, so `rent` and `Rent` are one zone.
/// Anything the farm typed that is not one of the known headings lands in
/// [Zone.other] — which is right: an unknown cost is still a cost, and
/// dropping it would make the zones stop adding up to the money out.
Zone zoneOf(String category) {
  final k = partyKey(category);
  if (k == partyKey('Fodder / feed')) return Zone.feed;
  if (k == partyKey(milkBoughtInCategory)) return Zone.milkIn;
  if (k == partyKey(salariesCategory)) return Zone.wages;
  if (k == partyKey('Rent')) return Zone.rent;
  if (k == partyKey('Vet & medicine')) return Zone.vet;
  if (k == partyKey('Utilities (bijli, gas, pani)')) return Zone.power;
  return Zone.other;
}

/// The farm's spending split into zones, measured against what came in.
///
/// Counted by exactly the rule the report counts by — [countedInReport],
/// less what the farm still owns and less the advances that come back off a
/// wage — so the zones add up to the report's own money-out figure and the
/// two pages can never disagree. That is not a nicety: the last time two
/// pages counted the same money two ways, the farm found a sixteen thousand
/// rupee hole and had to be told which page to believe.
SpendZones spendZones(List<Txn> rows) {
  final counted = rows.where((t) => !t.isDeleted && countedInReport(t));

  final sales = counted
      .where((t) => t.type.isIncoming)
      .fold<num>(0, (a, t) => a + t.amount);

  final spend = <Zone, num>{};
  var spent = 0 as num;

  for (final t in counted) {
    if (t.type.isIncoming) continue;
    // The farm still has the buffalo and the chaff cutter; neither is a
    // running cost. An advance is money lent against a wage still to come,
    // and the cost of it is that wage, in the month it is earned.
    if (t.isCapitalAsset || t.isWageAdvance) continue;
    final zone = zoneOf(t.category);
    spend[zone] = (spend[zone] ?? 0) + t.amount;
    spent += t.amount;
  }

  final lines = [
    for (final e in spend.entries)
      if (e.value != 0) ZoneLine(zone: e.key, spent: e.value, sales: sales),
  ]..sort((a, b) => b.spent.compareTo(a.spent));

  return SpendZones(sales: sales, spent: spent, lines: lines);
}
