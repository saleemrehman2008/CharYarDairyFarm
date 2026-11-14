import 'package:flutter/material.dart';

import '../i18n/words.dart';
import '../models/models.dart';
import '../theme/tokens.dart';
import '../util/money.dart';
import 'ui.dart';

/// What came in and what went out, one column a day.
///
/// Lives here rather than on the report screen because the co-founders' home
/// wants the same picture: the shape of a month is the first thing anybody
/// looks for, and drawing it twice would mean two of them drifting apart.
/// One column of the day-by-day chart: what came in and what went out.
class DayTotals {
  const DayTotals(this.date, this.income, this.spend, {required this.byWeek});

  final DateTime date;
  final num income;
  final num spend;

  /// True when the span was long enough that each column is a whole week.
  final bool byWeek;

  num get most => income > spend ? income : spend;
}

/// Sales against costs, one column a day — the shape of the month.
///
/// Two bars a column rather than one net bar, because a day that sold sixty
/// thousand and spent fifty-five is a different day from one that did neither,
/// and a net bar draws them the same.
class DayChart extends StatelessWidget {
  const DayChart({super.key, required this.days});

  final List<DayTotals> days;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (days.isEmpty) {
      return RegCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Kicker(l.t('Day by day')),
            const SizedBox(height: 8),
            Text(l.t('Nothing booked in this stretch yet.'), style: T.meta),
          ],
        ),
      );
    }

    final peak = days.fold<num>(0, (a, d) => d.most > a ? d.most : a);
    final byWeek = days.first.byWeek;
    final best = days.reduce((a, b) => b.income > a.income ? b : a);

    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Kicker(l.t(byWeek ? 'Week by week' : 'Day by day')),
              ),
              ChartKey(colour: T.moneyIn, label: l.t('In')),
              const SizedBox(width: 12),
              ChartKey(colour: T.moneyOut, label: l.t('Out')),
            ],
          ),
          const SizedBox(height: 12),

          // Scrolls sideways rather than squeezing a month into a phone's
          // width, and opens at the most recent, which is what gets looked at.
          SizedBox(
            height: 150,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              // Oldest first, laid out the way the reader reads. The days
              // used to be reversed and the row forced right-to-left to
              // put the newest at the end, which worked while the app only
              // ran one way — in Urdu it put the month backwards. `reverse`
              // on the scroll already opens at the newest end whichever
              // way the page runs.
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final day in days) _DayColumn(day: day, peak: peak),
                ],
              ),
            ),
          ),
          const Divider(height: 22),

          if (best.income > 0)
            Text(
              byWeek
                  ? l.t3(
                      'Best week: the one from %s, %s',
                      fmtDate(best.date),
                      rs(best.income),
                    )
                  : l.t3(
                      'Best day: %s, %s',
                      fmtDate(best.date),
                      rs(best.income),
                    ),
              style: T.meta,
            ),
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.day, required this.peak});

  final DayTotals day;
  final num peak;

  static const _tall = 110.0;

  double _height(num value) => peak <= 0
      ? 0
      : (value / peak * _tall).clamp(value > 0 ? 3.0 : 0.0, _tall);

  @override
  Widget build(BuildContext context) => Tooltip(
    message:
        '${fmtDate(day.date)}\n${rs(day.income)} in · ${rs(day.spend)} out',
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _tall,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Bar(height: _height(day.income), colour: T.moneyIn),
                const SizedBox(width: 3),
                _Bar(height: _height(day.spend), colour: T.moneyOut),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            day.byWeek ? fmtDate(day.date) : '${day.date.day}',
            style: T.meta.copyWith(fontSize: 10),
          ),
        ],
      ),
    ),
  );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.colour});

  final double height;
  final Color colour;

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: height < 2 ? 2 : height,
    decoration: BoxDecoration(
      color: height <= 0 ? T.n200 : colour,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
    ),
  );
}

/// What came in and what went out on each day of a stretch, oldest first.
///
/// Days with nothing on them are kept, because a gap in the middle of a month
/// is itself worth seeing — it usually means somebody forgot to write the day
/// down. A stretch longer than two months is grouped by the week instead:
/// thirty-one bars fit on a phone, three hundred do not.
List<DayTotals> dayTotals(List<Txn> txns) {
  if (txns.isEmpty) return const [];

  final income = <String, num>{};
  final spend = <String, num>{};
  DateTime? first, last;

  for (final t in txns) {
    if (t.isDeleted) continue;
    if (t.type.isSettlement) continue; // the money is on its own entry
    // Cattle, equipment and anything else the farm keeps are left out, and
    // so is an advance against a wage, which is money lent rather than
    // spent. One buffalo bought for lakhs sets the height of every bar on
    // the chart, and fifty days of real trading — eleven thousand of milk
    // against four of feed — come out as dust along the floor. What is
    // left here is the trading, which is the only thing a day-by-day
    // picture can say anything about.
    if (t.isCapitalAsset || t.isWageAdvance) continue;
    final key = dayKeyOf(t.date);
    if (t.type.isIncoming) {
      income[key] = (income[key] ?? 0) + t.amount;
    } else {
      spend[key] = (spend[key] ?? 0) + t.amount;
    }
    final day = DateTime(t.date.year, t.date.month, t.date.day);
    if (first == null || day.isBefore(first)) first = day;
    if (last == null || day.isAfter(last)) last = day;
  }
  if (first == null || last == null) return const [];

  if (last.difference(first).inDays > 62) {
    return _byWeek(income, spend, first, last);
  }

  final days = <DayTotals>[];
  for (var d = first; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
    final key = dayKeyOf(d);
    days.add(DayTotals(d, income[key] ?? 0, spend[key] ?? 0, byWeek: false));
  }
  return days;
}

List<DayTotals> _byWeek(
  Map<String, num> income,
  Map<String, num> spend,
  DateTime first,
  DateTime last,
) {
  // Start on the Monday of the first week, so every column is a whole week.
  var start = first.subtract(Duration(days: first.weekday - 1));
  final weeks = <DayTotals>[];
  while (!start.isAfter(last)) {
    num inSum = 0, outSum = 0;
    for (var i = 0; i < 7; i++) {
      final key = dayKeyOf(start.add(Duration(days: i)));
      inSum += income[key] ?? 0;
      outSum += spend[key] ?? 0;
    }
    weeks.add(DayTotals(start, inSum, outSum, byWeek: true));
    start = start.add(const Duration(days: 7));
  }
  return weeks;
}

/// A coloured square with a word beside it, for a chart's key.
class ChartKey extends StatelessWidget {
  const ChartKey({
    super.key,
    required this.colour,
    required this.label,
    this.share,
  });

  final Color colour;
  final String label;

  /// This slice's share of the whole, 0 to 1, written after the name.
  ///
  /// A ring says which of two is bigger and never says by how much. The
  /// farm reads this page to settle an argument, and "money in was 51%"
  /// settles one that "the green bit looks bigger" does not.
  final double? share;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: colour,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 7),
      Text(label, style: T.meta.copyWith(fontSize: 12.5)),
      if (share != null) ...[
        const SizedBox(width: 5),
        Text(
          pct(share!),
          style: T.meta.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: colour,
          ),
        ),
      ],
    ],
  );
}

/// A share written the way a person says it: 51%, and 0.4% rather than 0%
/// for something small but real.
String pct(double share) {
  final v = share * 100;
  if (v <= 0) return '0%';
  if (v < 1) return '${v.toStringAsFixed(1)}%';
  return '${v.round()}%';
}
