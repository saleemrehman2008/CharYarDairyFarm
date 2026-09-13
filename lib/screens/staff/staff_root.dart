import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../state/round_data.dart';
import '../../state/staff_store.dart';
import '../../widgets/app_shell.dart';
import '../../state/session.dart';
import '../notice_screen.dart';
import '../shared/bills_screen.dart';
import '../shared/deliveries_screen.dart';
import 'staff_orders_screen.dart';
import 'rider_day_screen.dart';

/// The delivery person's whole app: the round, the orders to drop off, and the
/// money to collect. Nothing about the farm's books is reachable from here, and
/// [StaffStore] never asks Firestore for it either.
class StaffRoot extends StatelessWidget {
  const StaffRoot({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<StaffStore>(
    create: (_) => StaffStore(),
    child: Consumer<StaffStore>(
      // The shared round and bills screens read RoundData, so the same store is
      // offered under that name too.
      builder: (context, store, _) => ChangeNotifierProvider<RoundData>.value(
        value: store,
        child: const _StaffTabs(),
      ),
    ),
  );
}

class _StaffTabs extends StatefulWidget {
  const _StaffTabs();

  @override
  State<_StaffTabs> createState() => _StaffTabsState();
}

class _StaffTabsState extends State<_StaffTabs> {
  String _tab = 'round';

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final store = context.watch<StaffStore>();
    final l = L.of(context);
    final f = session.features;

    // The round is switched off at the farm — no orders, no khaata, nothing
    // to load. Tell the rider that instead of showing him four empty tabs.
    if (!f.rider) {
      return NoticeScreen(
        title: l.t('No round today'),
        body: l.t(
          'The farm has deliveries switched off at the moment, so there is '
          'nothing to take out. This screen will fill up again as soon as the '
          'master switches them back on.',
        ),
        secondaryLabel: l.t('Sign out'),
        onSecondary: session.signOut,
      );
    }

    final tabs = <TabDef>[
      if (f.khaata)
        TabDef(
          id: 'round',
          label: l.t('Round'),
          icon: Icons.local_shipping_outlined,
          title: l.t('Daily round'),
          badge: store.roundLeft,
          body: const DeliveriesScreen(asTab: true),
        ),
      if (f.orders)
        TabDef(
          id: 'orders',
          label: l.t('Orders'),
          icon: Icons.receipt_long_outlined,
          title: l.t('Orders to deliver'),
          badge: store.openOrders.length,
          body: const StaffOrdersScreen(),
        ),
      TabDef(
        id: 'day',
        label: l.t('My day'),
        icon: Icons.inventory_2_outlined,
        title: l.t('My day'),
        body: const RiderDayScreen(),
      ),
      if (f.khaata)
        TabDef(
          id: 'collect',
          label: l.t('Collect'),
          icon: Icons.payments_outlined,
          title: l.t('Money to collect'),
          badge: store.unpaidBills.length,
          body: const BillsScreen(asTab: true),
        ),
    ];

    final index = tabIndexOf(tabs, _tab);

    return FarmScaffold(
      title: tabs[index].title,
      body: IndexedStack(
        index: index,
        children: [for (final t in tabs) t.body],
      ),
      bottomBar: FarmTabBar(
        tabs: tabs,
        index: index,
        onChanged: (i) => setState(() => _tab = tabs[i].id),
      ),
    );
  }
}
