import 'package:flutter/material.dart';

import '../i18n/words.dart';
import '../models/models.dart';
import '../theme/tokens.dart';
import '../util/money.dart';
import 'ui.dart';

class InvestmentCard extends StatelessWidget {
  const InvestmentCard({
    super.key,
    required this.partners,
    required this.ratios,
  });

  final List<Partner> partners;
  final Map<String, double> ratios;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final pockets = partners.fold<num>(0, (a, p) => a + p.invested);
    final left = partners.fold<num>(0, (a, p) => a + p.profitHeld);
    final total = pockets + left;
    final out = partners.fold<num>(0, (a, p) => a + p.withdrawn);

    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(l.t('What the co-founders have in')),
          const SizedBox(height: 10),
          if (partners.isEmpty)
            Text(l.t('No co-founders yet.'), style: T.meta)
          else ...[
            for (final p in partners)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: T.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            p.profitHeld > 0
                                ? l.t2(
                                    'incl. %s left in from profit',
                                    rs(p.profitHeld),
                                  )
                                : l.t('put in from their own pocket'),
                            style: T.meta.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tag(
                      '${((ratios[p.id] ?? 0) * 100).toStringAsFixed(0)}%',
                      tone: TagTone.accent,
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 96,
                      child: Text(
                        rs(p.inTheFarm),
                        textAlign: TextAlign.right,
                        style: T.bodyMid,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 18),
            // Two different sums, and the difference between them is the
            // whole point of leaving profit in. One is what came out of four
            // pockets; the other is what those four now own. They are only
            // the same number on the first day.
            TotalRow(
              label: l.t('Put in from their pockets'),
              value: pockets,
              tone: T.n700,
            ),
            if (left > 0)
              TotalRow(
                label: l.t('Profit left in the farm'),
                value: left,
                tone: T.moneyIn,
              ),
            const SizedBox(height: 2),
            TotalRow(
              label: l.t('Total investment'),
              value: total,
              tone: T.accent700,
              strong: true,
            ),
            if (out > 0)
              TotalRow(
                label: l.t('Taken out so far'),
                value: out,
                tone: T.moneyOut,
              ),
          ],
        ],
      ),
    );
  }
}

/// One figure on its own line under a rule, the way a total is written.
class TotalRow extends StatelessWidget {
  const TotalRow({
    super.key,
    required this.label,
    required this.value,
    required this.tone,
    this.strong = false,
  });

  final String label;
  final num value;
  final Color tone;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label, style: strong ? T.cardTitle : T.body)),
        Text(
          rs(value),
          style: (strong ? T.num22 : T.bodyMid).copyWith(color: tone),
        ),
      ],
    ),
  );
}
