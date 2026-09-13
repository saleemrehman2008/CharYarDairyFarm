import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/words.dart';
import '../screens/shared/share_decision_screen.dart';
import '../state/farm_store.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../util/money.dart';
import 'ui.dart';

/// "Your share is waiting on you" — the top of a co-founder's home while a
/// period is out for decisions.
///
/// The period cannot close until every co-founder has answered, so this is the
/// one thing on the screen that anybody is waiting for. Once they have
/// answered it stays, quietly, showing what they chose, because they can still
/// change it until the master closes.
class DecisionBanner extends StatelessWidget {
  const DecisionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<FarmStore>();
    final session = context.watch<Session>();

    final period = store.sealedPeriod;
    if (period == null) return const SizedBox.shrink();

    final me = store.partnerFor(session.user?.uid ?? '');
    if (me == null) return const SizedBox.shrink();

    final share = period.shareFor(me.id);
    if (share == null) return const SizedBox.shrink();

    void open() => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: store,
          child: ShareDecisionScreen(
            periodId: period.id,
            partnerId: me.id,
          ),
        ),
      ),
    );

    if (!share.decided) {
      return Padding(
        padding: const EdgeInsets.only(bottom: T.gap),
        child: RegCard(
          stripe: T.moneyDue,
          wash: T.moneyDueWash,
          onTap: open,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Kicker(
                      l.t2('%s is settled', periodLabel(period)),
                    ),
                  ),
                  Tag(l.t('Waiting on you'), tone: TagTone.warn),
                ],
              ),
              const SizedBox(height: 8),
              Text(rs(share.share), style: T.num30),
              const SizedBox(height: 4),
              Text(
                l.t(
                  'Your share. Say how much of it you want to take out — the '
                  'rest is added to your investment. Nothing moves until every '
                  'co-founder has answered.',
                ),
                style: T.body,
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: l.t('Decide'),
                icon: Icons.arrow_forward,
                onPressed: open,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: T.gap),
      child: RegCard(
        stripe: T.moneyIn,
        onTap: open,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Kicker(l.t2('%s share', periodLabel(period))),
                ),
                Tag(l.t('Decided'), tone: TagTone.good),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(l.t('Taking out'), style: T.body)),
                Money(share.withdraw, incoming: false, settled: false),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(l.t('Into investment'), style: T.body),
                ),
                Money(share.reinvest, incoming: true, settled: false),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              share.byPhone
                  ? l.t(
                      'Entered by the master after speaking to you. Tap to '
                      'change it while the period is still open.',
                    )
                  : l.t('Tap to change it until the master closes the period.'),
              style: T.meta,
            ),
          ],
        ),
      ),
    );
  }
}
