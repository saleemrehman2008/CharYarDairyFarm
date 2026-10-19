import 'package:flutter/material.dart';

import '../i18n/words.dart';
import '../services/accounting.dart';
import '../theme/tokens.dart';
import '../util/money.dart';
import 'day_chart.dart';
import 'ui.dart';

/// Which way the farm is going, one column a period.
///
/// The dashboard could say what this month has done and nothing at all about
/// the month before it. Four figures tell a farm where it stands; six columns
/// tell it which way it is heading, and that is the question actually asked
/// at the gate — not "what did we sell" but "are we doing better than last
/// month".
///
/// Two bars a period rather than one net bar, for the same reason the day
/// chart has two: a month that sold nine lakh and spent eight is a different
/// month from one that sold two and spent one, and a net bar draws them the
/// same. What each one made is written underneath in its own colour, because
/// that is the figure somebody reads out loud.
class MonthChart extends StatelessWidget {
  const MonthChart({super.key, required this.bars});

  final List<PeriodBar> bars;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (bars.isEmpty) {
      return RegCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Kicker(l.t('Month by month')),
            const SizedBox(height: 8),
            Text(l.t('No period has been settled yet.'), style: T.meta),
          ],
        ),
      );
    }

    final peak = bars.fold<num>(0, (a, b) => b.most > a ? b.most : a);

    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Kicker(l.t('Month by month'))),
              ChartKey(colour: T.moneyIn, label: l.t('Sold')),
              const SizedBox(width: 12),
              ChartKey(colour: T.moneyOut, label: l.t('Spent')),
            ],
          ),
          const SizedBox(height: 14),

          SizedBox(
            height: 112,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final bar in bars)
                  Expanded(
                    child: _Column(bar: bar, peak: peak),
                  ),
              ],
            ),
          ),

          const Divider(height: 18),

          // What each one made, under the column it belongs to.
          Row(
            children: [
              for (final bar in bars)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        bar.label,
                        style: T.meta.copyWith(
                          color: bar.isOpen ? T.accent700 : T.n500,
                        ),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          bar.isOpen
                              ? l.t('so far')
                              : shortRs(bar.profit, signed: true),
                          style: T.meta.copyWith(
                            color: bar.isOpen
                                ? T.accent700
                                : bar.profit < 0
                                ? T.moneyOut
                                : T.moneyIn,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),
          Text(
            l.t(
              'Settled periods are drawn from the figures frozen into them. '
              'The last column is the period still running, so it is faint — '
              'half a month against six whole ones proves nothing.',
            ),
            style: T.meta,
          ),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.bar, required this.peak});

  final PeriodBar bar;
  final num peak;

  /// Nothing is drawn as nothing, and the smallest real figure still gets a
  /// mark — a column of one pixel reads as an error, and a column of none
  /// reads as a month that never happened.
  double _height(num value) {
    if (peak <= 0 || value <= 0) return 0;
    final h = (value / peak) * 88;
    return h < 3 ? 3 : h.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final faint = bar.isOpen ? 0.45 : 1.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _Bar(height: _height(bar.sales), colour: T.moneyIn, alpha: faint),
        const SizedBox(width: 3),
        _Bar(height: _height(bar.costs), colour: T.moneyOut, alpha: faint),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.colour, required this.alpha});

  final double height;
  final Color colour;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: height,
    decoration: BoxDecoration(
      color: colour.withValues(alpha: alpha),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
    ),
  );
}
