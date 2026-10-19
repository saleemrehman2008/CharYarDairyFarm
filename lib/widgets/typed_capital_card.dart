import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/contribution_repo.dart';
import '../state/farm_store.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../util/money.dart';
import 'ui.dart';

/// Figures that were typed onto co-founders' cards before any line was kept,
/// sitting in the wrong column.
///
/// The farm ran for months on one number per man that the master typed in.
/// Nobody had handed that money over: it was what each of them had undertaken
/// to put in. Read as money already in, it did two things wrong at once — it
/// said the farm held cash it did not hold, and it counted every rupee twice
/// the moment somebody wrote down which purchase that man had actually paid
/// for. The farm found the second one itself, splitting a seventeen lakh
/// cattle entry and watching four cards go up by money that had already been
/// spent.
///
/// So this offers to put it right once: the typed figure becomes the promise,
/// and what each has put in goes back to the sum of his own lines.
class TypedCapitalCard extends StatefulWidget {
  const TypedCapitalCard({super.key});

  @override
  State<TypedCapitalCard> createState() => _TypedCapitalCardState();
}

class _TypedCapitalCardState extends State<TypedCapitalCard> {
  bool _busy = false;

  Future<void> _adopt(FarmStore store, List<Partner> affected) async {
    final ok = await confirm(
      context,
      title: 'Were these promises?',
      body:
          '${affected.map((p) => '${p.name} — ${rs(p.invested)}').join('\n')}'
          '\n\n'
          'Each of these becomes what that man is in for. What he has put in '
          'goes back to the sum of his own lines, which is what the books can '
          'actually account for.\n\n'
          'The farm\'s cash will read low until you write down who paid for '
          'what — the entry for the cattle is on the books and the money that '
          'bought them is not. Splitting those entries puts it right.',
      confirmLabel: 'They were promises',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      final actor = context.read<Session>().actor;
      for (final p in affected) {
        await ContributionRepo.adoptTypedCapital(
          actor,
          partner: p,
          lines: store.contributions,
        );
      }
      if (mounted) toast(context, 'Moved to what each of them is in for');
    } catch (e) {
      if (mounted) toast(context, 'Could not move them. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    if (context.watch<Session>().role != Role.master) {
      return const SizedBox.shrink();
    }

    // Only where a card claims more has been put in than its lines account
    // for, which is exactly what a typed figure looks like.
    final affected = [
      for (final p in store.partners)
        if (p.invested > investedFrom(store.contributions, p.id)) p,
    ];
    if (affected.isEmpty) return const SizedBox.shrink();

    final total = affected.fold<num>(0, (a, p) => a + p.invested);

    return Padding(
      padding: const EdgeInsets.only(bottom: T.pad),
      child: RegCard(
        stripe: T.moneyDue,
        wash: T.moneyDueWash,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.swap_vert_rounded, size: 20, color: T.moneyDue),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${rs(total)} is in the wrong column',
                        style: T.cardTitle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'These figures were typed onto the cards before any '
                        'line was kept, and they sit under "put in" as though '
                        'the money had arrived. It had not — it is what each '
                        'of them undertook to put in.',
                        style: T.meta,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final p in affected)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(p.name, style: T.body)),
                    Text(rs(p.invested), style: T.bodyMid),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Left where they are, every rupee gets counted twice the moment '
              'somebody writes down which purchase that man paid for — which '
              'is what happened when the cattle entry was split.',
              style: T.meta.copyWith(color: T.moneyDue),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'These were promises, not money in',
              icon: Icons.handshake_outlined,
              busy: _busy,
              onPressed: _busy ? null : () => _adopt(store, affected),
            ),
          ],
        ),
      ),
    );
  }
}
