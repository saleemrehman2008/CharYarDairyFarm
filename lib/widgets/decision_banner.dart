import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/words.dart';
import '../models/models.dart';
import '../screens/shared/share_decision_screen.dart';
import '../state/farm_store.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../util/money.dart';
import 'ui.dart';

/// The month is settled — here is what it came to, and here is your part.
///
/// It used to ask for a decision and hold the close until it got one. It now
/// carries the news instead: the master closes when he closes, and this is
/// how the other three find out, in full, on the screen they open anyway.
/// Tapping through and saying they have seen it puts their name against the
/// figures.
///
/// A phone that buzzes would need a server, and a server needs a card on the
/// billing account, which the farm has chosen not to give. So it waits on the
/// home page instead, which is where the four of them look every day anyway.
class DecisionBanner extends StatelessWidget {
  const DecisionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<FarmStore>();
    final session = context.watch<Session>();

    final me = store.partnerFor(session.user?.uid ?? '');
    if (me == null) return const SizedBox.shrink();

    // The newest closed period this person has not opened yet. Closed, not
    // sealed: until the master has settled it there is nothing to tell them.
    FarmMonth? period;
    for (final m in store.closedMonths) {
      if (m.shareFor(me.id) != null && !m.seenBy(me.id)) {
        period = m;
        break;
      }
    }
    if (period == null) return const SizedBox.shrink();

    final share = period.shareFor(me.id)!;
    final loss = share.isLoss;

    void open() => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: store,
          child: ShareDecisionScreen(periodId: period!.id, partnerId: me.id),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: T.gap),
      child: RegCard(
        stripe: loss ? T.moneyOut : T.moneyIn,
        wash: loss ? T.moneyDueWash : T.moneyInWash,
        onTap: open,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Kicker(l.t2('%s is settled', periodLabel(period))),
                ),
                Tag(l.t('New'), tone: TagTone.warn),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              rs(share.share.abs()),
              style: T.num30.copyWith(color: loss ? T.moneyOut : T.moneyIn),
            ),
            const SizedBox(height: 4),
            Text(
              loss
                  ? l.t(
                      'Your share of what the farm lost this period. It has '
                      'come off what you had kept in the farm.',
                    )
                  : period.sharedPercent == 0
                  ? l.t(
                      'Your share. All of it has stayed in the farm, in your '
                      'name, and it does not change your share of the farm.',
                    )
                  : l.t2(
                      'Your share. %s of it has been handed over and the '
                          'rest has stayed in the farm, in your name.',
                      '${period.sharedPercent}%',
                    ),
              style: T.body,
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: l.t('See the figures'),
              icon: Icons.arrow_forward,
              onPressed: open,
            ),
          ],
        ),
      ),
    );
  }
}
