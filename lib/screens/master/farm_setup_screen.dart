import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../services/log_service.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';

/// Which parts of the farm are running. Master only.
///
/// Switching something off is not a permission change and not a delete: the
/// tab disappears from every phone on the farm — customer, rider and
/// co-founder alike — the notifications stop, and every record stays exactly
/// where it is. Switching it back on brings it all back untouched.
class FarmSetupScreen extends StatefulWidget {
  const FarmSetupScreen({super.key});

  @override
  State<FarmSetupScreen> createState() => _FarmSetupScreenState();
}

class _FarmSetupScreenState extends State<FarmSetupScreen> {
  bool _busy = false;

  Future<void> _set(Feature feature, bool on, Features current) async {
    final l = L.read(context);
    final session = context.read<Session>();

    // Switching a delivery channel off takes the rider with it if nothing is
    // left to deliver, which is a bigger change than the switch looks. Say so
    // before doing it rather than letting the round vanish unannounced.
    final next = current.with_(feature, on);
    if (!on && current.rider && !next.riderPossible) {
      final ok = await confirm(
        context,
        title: l.t('Switch the round off too?'),
        body: l.t(
          'With neither online orders nor khaata running there is nothing for '
          'the rider to take out, so the round, spot sales, the handover and '
          'the collection screens all go with it.\n\nNothing is deleted. It '
          'all comes back when you switch a delivery channel on again.',
        ),
        confirmLabel: l.t('Switch off'),
      );
      if (!ok) return;
    }

    setState(() => _busy = true);
    try {
      await Db.farmSettings.set({
        'features': next.ids,
        'featuresChangedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await Log.write(
        session.actor,
        LogKind.settings,
        '${on ? 'switched on' : 'switched off'} ${feature.id}',
        refType: 'settings',
        refId: 'farm',
      );
    } catch (e) {
      if (mounted) toast(context, l.t2('Could not save that. %s', e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final f = context.watch<Session>().features;

    return FarmScaffold(
      title: l.t('What the farm runs'),
      showBack: true,
      body: PageBody(
        children: [
          RegCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(l.t('Selling')),
                const SizedBox(height: 10),
                SwitchRow(
                  title: l.t('Online orders'),
                  note: l.t('Shop, cart, and orders going out to doors'),
                  value: f.orders,
                  enabled: !_busy,
                  onChanged: (v) => _set(Feature.orders, v, f),
                ),
                const Divider(height: 22),
                SwitchRow(
                  title: l.t('Khaata'),
                  note: l.t('Daily milk on account, billed once a month'),
                  value: f.khaata,
                  enabled: !_busy,
                  onChanged: (v) => _set(Feature.khaata, v, f),
                ),
              ],
            ),
          ),
          const SizedBox(height: T.gap),

          RegCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(l.t('Out on the round')),
                const SizedBox(height: 10),
                SwitchRow(
                  title: l.t("The rider's work"),
                  note: l.t('Round, spot sale, handover, collection'),
                  value: f.rider,
                  enabled: !_busy && f.riderPossible,
                  why: l.t(
                    'Online orders and khaata are both off, so there is '
                    'nothing for a rider to take out. Switch one of them on '
                    'and this comes back by itself.',
                  ),
                  onChanged: (v) => _set(Feature.rider, v, f),
                ),
              ],
            ),
          ),
          const SizedBox(height: T.gap),

          RegCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(l.t('The farm itself')),
                const SizedBox(height: 10),
                SwitchRow(
                  title: l.t('Cattle register'),
                  note: l.t('Animals, tags, milk yield, vet visits'),
                  value: f.cattle,
                  enabled: !_busy,
                  onChanged: (v) => _set(Feature.cattle, v, f),
                ),
                const Divider(height: 22),
                SwitchRow(
                  title: l.t('Books'),
                  note: l.t('Entries, accounts, reports, closing a period'),
                  value: true,
                  enabled: false,
                  why: l.t(
                    'The books always run. Everything else can be switched '
                    'off; the farm still has to know what it has.',
                  ),
                  onChanged: null,
                ),
              ],
            ),
          ),
          const SizedBox(height: T.gap),

          RegCard(
            wash: T.accent100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.t('What switching off does'), style: T.cardTitle),
                const SizedBox(height: 8),
                Text(
                  l.t(
                    'The tab disappears from every phone on the farm and the '
                    'notifications stop. Nothing is deleted — every khaata, '
                    'order and bill stays exactly where it is, and comes back '
                    'untouched when you switch it on again.',
                  ),
                  style: T.body,
                ),
                const SizedBox(height: 8),
                Text(
                  l.t(
                    'Only you can see this screen. Co-founders, riders and '
                    'customers have no such setting.',
                  ),
                  style: T.meta,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
