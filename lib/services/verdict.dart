import '../models/models.dart';
import 'accounting.dart';
import 'zones.dart';

/// Reading the books the way somebody who knows farms would read them.
///
/// The farm asked for a page that does the thinking: is the farm going at
/// the right speed, and which zone is losing money. The figures to answer
/// that were all already in the app, in six different cards, and nobody was
/// going to put them together on a phone at nine at night.
///
/// So this puts them together. It is arithmetic, not a machine that thinks
/// — every line it produces can be checked by hand against the ledger, and
/// that is the point: a verdict nobody can check is worth nothing between
/// four partners. What it adds is the reading: which figure matters most
/// this month, and what it is saying.
///
/// The words are not here. This hands back what it found and the page says
/// it, so the same finding reads in all three languages.

/// How a figure is doing.
enum Tone {
  /// Where it should be.
  good,

  /// Not wrong, worth an eye.
  watch,

  /// Past where it should be.
  bad,
}

/// What the books had to say, in one finding.
enum Note {
  /// It cost more to run than it earned.
  losing,

  /// It earned, but not enough of what came in to call it a good month.
  thin,

  /// It earned properly.
  healthy,

  /// Running cost has eaten nearly everything that came in.
  spendHigh,

  /// One zone is past the share a dairy usually keeps it inside.
  zoneOver,

  /// Better than the stretch before it.
  faster,

  /// Worse than the stretch before it.
  slower,

  /// Much the same as the stretch before it.
  steady,

  /// Money still to come in.
  toCome,

  /// Money still to go out.
  toPay,

  /// More is owed out than is coming in.
  owingMore,
}

/// One thing the books said.
class Finding {
  const Finding({
    required this.note,
    required this.tone,
    this.amount = 0,
    this.share = 0,
    this.zone,
  });

  final Note note;
  final Tone tone;

  /// The rupees it is about, when it is about rupees.
  final num amount;

  /// The share it is about, when it is about a share.
  final double share;

  /// The zone it names, on [Note.zoneOver].
  final Zone? zone;
}

/// What a stretch of the books comes to, read.
class MonthRead {
  const MonthRead({
    required this.zones,
    required this.toCome,
    required this.toPay,
    required this.netBefore,
    required this.hasBefore,
    required this.findings,
  });

  /// Where the money went, and what the shares were.
  final SpendZones zones;

  /// Still to come in, and still to go out — not of this stretch, but what
  /// the farm stands at today. A month can look fine and have four lakh
  /// sitting in other people's pockets.
  final num toCome;
  final num toPay;

  /// What the stretch before this one made, for the pace.
  final num netBefore;

  /// False when there is nothing before to compare against — the first
  /// month of the books, where any talk of pace would be invented.
  final bool hasBefore;

  /// Worst first. The thing to do something about is at the top.
  final List<Finding> findings;

  num get net => zones.profit;

  /// How much better or worse than the stretch before, as a share of it.
  /// Zero when there is nothing to compare against.
  double get pace {
    if (!hasBefore || netBefore == 0) return 0;
    return (net - netBefore) / netBefore.abs();
  }

  /// The one word for the whole stretch: the worst tone in it.
  Tone get tone {
    if (findings.any((f) => f.tone == Tone.bad)) return Tone.bad;
    if (findings.any((f) => f.tone == Tone.watch)) return Tone.watch;
    return Tone.good;
  }

  bool get isEmpty => zones.isEmpty;
}

/// A change of less than this either way is not a change, it is a month.
const _steady = 0.10;

/// What is still owed on a list of entries.
num stillOwed(List<Txn> rows) =>
    rows.where((t) => !t.isDeleted).fold<num>(0, (a, t) => a + t.outstanding);

/// Read a stretch of the books against the stretch before it.
///
/// [before] is the same length of time immediately before [now], so the
/// pace means what it says. Hand it an empty list and nothing is said
/// about pace at all, which is the honest answer for a first month.
MonthRead readTheBooks({
  required List<Txn> now,
  required List<Txn> before,
  required List<Txn> owedToUs,
  required List<Txn> owedByUs,
}) {
  final zones = spendZones(now);
  final toCome = stillOwed(owedToUs);
  final toPay = stillOwed(owedByUs);

  final hasBefore = before.any((t) => !t.isDeleted);
  final netBefore = hasBefore ? ReportTotals.of(before).net : 0;

  final found = <Finding>[];

  // 1. Did it make money, and enough of it.
  if (zones.profit < 0) {
    found.add(
      Finding(
        note: Note.losing,
        tone: Tone.bad,
        amount: zones.profit.abs(),
        share: zones.profitShare,
      ),
    );
  } else if (zones.sales > 0 && zones.profitShare < SpendZones.profitLeast) {
    found.add(
      Finding(
        note: Note.thin,
        tone: Tone.watch,
        amount: zones.profit,
        share: zones.profitShare,
      ),
    );
  } else if (zones.sales > 0) {
    found.add(
      Finding(
        note: Note.healthy,
        tone: Tone.good,
        amount: zones.profit,
        share: zones.profitShare,
      ),
    );
  }

  // 2. Is the running cost eating everything. Only said when it is also
  // making money — a stretch that lost money has already said this, and
  // saying it twice in different words is how a page stops being read.
  if (zones.profit >= 0 && zones.spendShare > SpendZones.spendMost) {
    found.add(
      Finding(
        note: Note.spendHigh,
        tone: Tone.watch,
        amount: zones.spent,
        share: zones.spendShare,
      ),
    );
  }

  // 3. The zone to go and look at.
  final focus = zones.focus;
  if (focus != null) {
    found.add(
      Finding(
        note: Note.zoneOver,
        // Red only when the zone is actually eating the month. Six
        // thousand past the band on a month that earned twenty-three per
        // cent is worth knowing and is not an emergency, and a page that
        // shouts at that gets ignored the month it matters.
        tone: zones.focusMatters ? Tone.bad : Tone.watch,
        amount: focus.over,
        share: focus.share,
        zone: focus.zone,
      ),
    );
  }

  // 4. The pace. "Are we all right at this speed" was the question, and a
  // stretch on its own cannot answer it — only the one before it can.
  if (hasBefore) {
    final by = zones.profit - netBefore;
    // A tenth either way is not a change, it is a month. Measured against
    // what the stretch before made — and when that was nothing, any
    // movement at all is the change, because there is nothing to be a
    // tenth of.
    final same = netBefore == 0
        ? by == 0
        : by.abs() / netBefore.abs() < _steady;
    found.add(
      Finding(
        note: same
            ? Note.steady
            : by > 0
            ? Note.faster
            : Note.slower,
        tone: by < 0 && !same ? Tone.watch : Tone.good,
        amount: by.abs(),
      ),
    );
  }

  // 5. What is outside the farm: owed to it, and owed by it.
  if (toCome > 0) {
    found.add(Finding(note: Note.toCome, tone: Tone.good, amount: toCome));
  }
  if (toPay > 0) {
    found.add(
      Finding(
        note: toPay > toCome ? Note.owingMore : Note.toPay,
        tone: toPay > toCome ? Tone.watch : Tone.good,
        amount: toPay,
      ),
    );
  }

  // Worst first: a page read from the top down should start with the thing
  // worth doing something about.
  const rank = {Tone.bad: 0, Tone.watch: 1, Tone.good: 2};
  found.sort((a, b) => rank[a.tone]!.compareTo(rank[b.tone]!));

  return MonthRead(
    zones: zones,
    toCome: toCome,
    toPay: toPay,
    netBefore: netBefore,
    hasBefore: hasBefore,
    findings: found,
  );
}

/// The stretch of the same length immediately before [rows].
///
/// Taken off the whole ledger rather than off what is on screen, because
/// what is on screen is this stretch and nothing else. An empty answer is a
/// real answer: there was nothing before.
List<Txn> theStretchBefore(List<Txn> ledger, List<Txn> rows) {
  final live = rows.where((t) => !t.isDeleted).toList();
  if (live.isEmpty) return const [];

  var first = live.first.date;
  var last = live.first.date;
  for (final t in live) {
    if (t.date.isBefore(first)) first = t.date;
    if (t.date.isAfter(last)) last = t.date;
  }

  final from = DateTime(first.year, first.month, first.day);
  final to = DateTime(last.year, last.month, last.day);

  // A whole calendar month looks back at the whole calendar month before
  // it, and not at the thirty days before its first — because "last
  // month" is what the farm means, and 2 October to 31 October is not
  // last month, it is thirty days that happen to be about that long.
  final wholeMonth =
      from.day == 1 &&
      to.month == from.month &&
      to.year == from.year &&
      to.day == DateTime(to.year, to.month + 1, 0).day;

  final DateTime wasFrom;
  final DateTime wasTo;
  if (wholeMonth) {
    wasFrom = DateTime(from.year, from.month - 1, 1);
    wasTo = DateTime(from.year, from.month, 0);
  } else {
    // Both ends counted, so a stretch of one day looks back at one day.
    final days = to.difference(from).inDays + 1;
    wasTo = from.subtract(const Duration(days: 1));
    wasFrom = wasTo.subtract(Duration(days: days - 1));
  }

  final seen = {for (final t in live) t.id};
  return ledger
      .where(
        (t) =>
            !t.isDeleted &&
            !seen.contains(t.id) &&
            !t.date.isBefore(wasFrom) &&
            !t.date.isAfter(
              DateTime(wasTo.year, wasTo.month, wasTo.day, 23, 59, 59),
            ),
      )
      .toList();
}
