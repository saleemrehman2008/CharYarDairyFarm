import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/words.dart';
import '../models/models.dart';
import '../services/contribution_repo.dart';
import '../state/farm_store.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../util/money.dart';
import 'ui.dart';

/// Money of his own that the farm owes him, offered back out of farm cash
/// already in his hands.
///
/// The farm's own way of doing it, described by the man who does it: he pays
/// for a load of feed out of his pocket, and a week later forty thousand of
/// milk money passes through his hands. Rather than handing over all forty
/// and asking for twenty back, he keeps his twenty and the farm's twenty goes
/// on. Both halves are written down, and nothing is owed either way
/// afterwards.
///
/// It only appears when both things are true at once — the farm owes him, and
/// he is holding farm cash. Either alone is not an opportunity: a man who is
/// owed money and holding none has nothing to take it out of, and a man
/// holding money he is not owed has nothing to take.
class RefundCard extends StatefulWidget {
  const RefundCard({super.key});

  @override
  State<RefundCard> createState() => _RefundCardState();
}

class _RefundCardState extends State<RefundCard> {
  bool _busy = false;

  Future<void> _fromFarm(FarmStore store, Partner me, num amount) async {
    final l = L.read(context);
    final ok = await confirm(
      context,
      title: l.t('Take it out of the farm account?'),
      body: l.t2(
        'The farm pays you %s out of its own account and stops owing it. '
        'That is where the farm\'s earnings sit, and it is what the account '
        'is for — nothing of anybody else\'s is touched.',
        rs(amount),
      ),
      confirmLabel: l.t('Pay it'),
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await ContributionRepo.repay(
        context.read<Session>().actor,
        partner: me,
        lines: store.contributions,
        amount: amount,
        handledBy: farmAccountName,
      );
      if (mounted) toast(context, l.t2('%s taken back', rs(amount)));
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _take(FarmStore store, Partner me, num amount) async {
    final l = L.read(context);
    final ok = await confirm(
      context,
      title: l.t('Take it out of what you are holding?'),
      body: l.t2(
        '%s of the farm\'s cash in your hands becomes yours, and the farm '
        'stops owing it. Both halves are written down, and the rest of the '
        'farm can see it.',
        rs(amount),
      ),
      confirmLabel: l.t('Take it'),
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await ContributionRepo.repay(
        context.read<Session>().actor,
        partner: me,
        lines: store.contributions,
        amount: amount,
        handledBy: me.name,
      );
      if (mounted) toast(context, l.t2('%s taken back', rs(amount)));
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<FarmStore>();
    final uid = context.watch<Session>().user?.uid ?? '';
    if (uid.isEmpty) return const SizedBox.shrink();

    final me = store.partners.where((p) => p.userId == uid).firstOrNull;
    if (me == null) return const SizedBox.shrink();

    final owed = store.owedToFounder(me.id);
    final holding = store.handsOf(me.name)?.holding ?? 0;

    // Two places it can come from, and the farm's account is the proper
    // one. The farm's earnings go in there so that a month can be closed
    // on them, and a man who has paid his promise in full is refunded what
    // is over it out of there. Keeping cash he happens to be holding is
    // the shortcut the four of them actually use between visits.
    final inFarm = store.handsOf(farmAccountName)?.holding ?? 0;
    if (owed <= 0 || (holding <= 0 && inFarm <= 0)) {
      return const SizedBox.shrink();
    }

    // Only as much as both sides allow. He cannot take out more than the
    // farm owes him, and he cannot take out money that is not there.
    final can = owed < holding ? owed : holding;
    final fromFarm = owed < inFarm ? owed : inFarm;

    return Padding(
      padding: const EdgeInsets.only(bottom: T.gap),
      child: RegCard(
        stripe: T.moneyDue,
        wash: T.moneyDueWash,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.undo_rounded, size: 20, color: T.moneyDue),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.t2('The farm owes you %s', rs(owed)),
                        style: T.cardTitle,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        holding > 0
                            ? l.t3(
                                'You are holding %s of the farm\'s cash. Keep '
                                '%s of it and the farm stops owing you.',
                                rs(holding),
                                rs(can),
                              )
                            : l.t2(
                                'The farm\'s own account has %s in it, which '
                                'is what it is for.',
                                rs(inFarm),
                              ),
                        style: T.meta,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (fromFarm > 0) ...[
              PrimaryButton(
                label: l.t2('Pay %s from the farm account', rs(fromFarm)),
                icon: Icons.account_balance_outlined,
                busy: _busy,
                onPressed: _busy ? null : () => _fromFarm(store, me, fromFarm),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                if (can > 0) ...[
                  Expanded(
                    child: GhostButton(
                      label: l.t2('Or keep %s you are holding', rs(can)),
                      icon: Icons.check,
                      onPressed: _busy ? null : () => _take(store, me, can),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                GhostButton(
                  label: l.t('Not now'),
                  onPressed: _busy
                      ? null
                      : () => toast(
                          context,
                          l.t('It stays owed. The card will be back.'),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What the four of them have taken back out of their own hands lately.
///
/// The accountant asked to be told when somebody does this, and there is no
/// way to make a phone ring — so it is said where he is already looking, on
/// the page about who is holding what. Every one of them is in the activity
/// log too, under the corrections, with a name and a time against it.
class RefundNotices extends StatelessWidget {
  const RefundNotices({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<FarmStore>();

    final since = DateTime.now().subtract(const Duration(days: 14));
    final lately =
        store.ledger
            .where((t) => t.isFounderRepaid && !t.isDeleted)
            .where((t) => t.date.isAfter(since))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    if (lately.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: RegCard(
        stripe: T.accent600,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.t('Taken back lately'), style: T.bodyMid),
            const SizedBox(height: 6),
            for (final t in lately)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '${l.t3('%s took back %s', t.party, rs(t.amount))} '
                  '· ${fmtDate(t.date)}',
                  style: T.meta,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              l.t(
                'Money of their own the farm was holding, taken out of farm '
                'cash already in their hands. Every one is in the activity '
                'log as well.',
              ),
              style: T.meta,
            ),
          ],
        ),
      ),
    );
  }
}
