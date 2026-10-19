import 'package:flutter/material.dart';

import '../i18n/words.dart';
import '../services/accounting.dart';
import '../theme/tokens.dart';
import '../util/money.dart';
import 'ui.dart';

/// Where the farm's money is sitting, in one bar.
///
/// The dashboard already lists every figure that makes up the farm's worth,
/// one under another, and a list of six figures is a thing you add up rather
/// than a thing you see. The one fact that matters is a proportion: nearly
/// all of this farm is standing in the shed on four legs, and the cash that
/// can actually be spent this week is a sliver of it. A bar says that before
/// a word is read; a column of figures never has.
///
/// What is owed is drawn apart from the rest, under the bar rather than in
/// it, because it is not somewhere the farm's money is — it is money that is
/// going to leave.
class WorthBar extends StatelessWidget {
  const WorthBar({super.key, required this.money});

  final MoneySummary money;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    final cash = money.cash + money.withRider;
    final toCome = money.receivable + money.loansOut + money.securitiesOut;
    final owned = money.assets;
    final owed = money.payable + money.securitiesHeld + money.owedToFounders;

    final has = cash + toCome + owned;
    final parts = <(String, num, Color)>[
      (l.t('Cash — in the box and in their hands'), cash, T.moneyIn),
      (l.t('Still to come in'), toCome, T.moneyGet),
      (l.t('Cattle & equipment'), owned, const Color(0xFF8B6FE0)),
    ].where((p) => p.$2 > 0).toList();

    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(l.t('What the farm is worth')),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(rs(has - owed), style: T.num30),
          ),
          const SizedBox(height: 12),

          if (has > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(T.radiusXs),
              child: SizedBox(
                height: 15,
                child: Row(
                  children: [
                    for (final (_, value, colour) in parts)
                      Expanded(
                        // Rounded to whole thousandths so a sliver still
                        // draws: a farm with two thousand rupees of cash
                        // against twenty lakh of cattle has to see that
                        // sliver, not a bar of one colour.
                        flex: ((value / has) * 1000).round().clamp(1, 1000),
                        child: ColoredBox(color: colour),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final (label, value, colour) in parts)
              _Line(label: label, value: value, colour: colour),
          ],

          if (owed > 0) ...[
            const Divider(height: 18),
            _Line(
              label: l.t('Owed out — bills, securities, co-founders'),
              value: -owed,
              colour: T.moneyDue,
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, required this.colour});

  final String label;
  final num value;
  final Color colour;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: colour,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(child: Text(label, style: T.body.copyWith(fontSize: 13))),
        const SizedBox(width: 8),
        Text(
          value < 0 ? '− ${rs(value.abs())}' : rs(value),
          style: T.bodyMid.copyWith(
            color: value < 0 ? T.moneyDue : T.text,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}
