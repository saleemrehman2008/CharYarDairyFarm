import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/words.dart';
import '../models/models.dart';
import '../services/partner_repo.dart';
import '../state/farm_store.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../util/money.dart';
import 'ui.dart';

/// Squaring the old books, where a man's takings and his spending were the
/// same rupees.
///
/// The farm runs on a rule now: whatever of its money a co-founder takes in
/// stands on its own and belongs in its account, and what he spends of his
/// own goes onto his promise. That is right, and it is what keeps the
/// account filling up instead of two figures quietly cancelling each other
/// while the money never moves.
///
/// Looking backwards it is not right. Ghulam Ali took 8,600 from Urooj at
/// the gate and bought fodder with it on the way home, and nobody wrote down
/// that they were the same notes. Asking him now to pay in what he collected
/// while the farm hands him back what he spent is two trips to the same
/// place, and neither trip is going to happen.
///
/// So it is said once, in figures, with a name against it in the log.
/// Nothing in the ledger moves: both rows stay where they are and every
/// balance is still worked out from both. What is recorded is that the four
/// of them looked at it and agreed those were the same rupees. Anything
/// taken in afterwards stands on its own, which is the whole point.
class SquareOldBooksCard extends StatefulWidget {
  const SquareOldBooksCard({super.key});

  @override
  State<SquareOldBooksCard> createState() => _SquareOldBooksCardState();
}

class _SquareOldBooksCardState extends State<SquareOldBooksCard> {
  bool _busy = false;

  Future<void> _square(List<(Partner, num)> who) async {
    final l = L.read(context);
    final lines = [for (final (p, amount) in who) '${p.name} — ${rs(amount)}'];

    final ok = await confirm(
      context,
      title: l.t('Were these the same rupees?'),
      body:
          '${lines.join('\n')}\n\n'
          '${l.t('Each of them took this much of the farm\'s money in and paid at least this much of the farm\'s costs back out. Agreeing it here says those were the same notes, so neither owes the other for them.')}\n\n'
          '${l.t('Nothing in the ledger moves. Every entry stays exactly where it is and every balance is still worked out from all of them — this only writes down what the four of you have agreed.')}\n\n'
          '${l.t('Anything taken in after today stands on its own and still has to be paid into the farm account.')}',
      confirmLabel: l.t('They were the same'),
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      final actor = context.read<Session>().actor;
      for (final (p, amount) in who) {
        await PartnerRepo.squareOldTakings(actor, partner: p, amount: amount);
      }
      if (mounted) toast(context, l.t('Squared'));
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (context.watch<Session>().role != Role.master) {
      return const SizedBox.shrink();
    }

    final store = context.watch<FarmStore>();
    final who = <(Partner, num)>[];
    for (final p in store.partners) {
      final left = store.stillToSquare(p);
      if (left > 0) who.add((p, left));
    }
    if (who.isEmpty) return const SizedBox.shrink();

    final total = who.fold<num>(0, (a, e) => a + e.$2);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: RegCard(
        stripe: T.accent600,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.handshake_outlined, size: 20, color: T.accent700),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.t2('%s of the old books to square', rs(total)),
                        style: T.cardTitle,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l.t(
                          'Money they took in for the farm and spent on the '
                          'farm before the rule was settled — the same notes, '
                          'going out the same day they came in. The books now '
                          'ask them to pay it in and hand it back, which is '
                          'two trips to the same place.',
                        ),
                        style: T.meta,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final (p, amount) in who)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(p.name, style: T.body)),
                    Text(rs(amount), style: T.bodyMid),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            GhostButton(
              label: l.t('These were the same rupees'),
              icon: Icons.done_all,
              onPressed: _busy ? null : () => _square(who),
            ),
            const SizedBox(height: 5),
            Text(
              l.t(
                'Said once, with your name on it in the log. Nothing in the '
                'ledger moves. Anything taken in after today stands on its '
                'own and still has to reach the farm account.',
              ),
              style: T.meta,
            ),
          ],
        ),
      ),
    );
  }
}
