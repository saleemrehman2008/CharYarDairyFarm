import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/round_data.dart';
import '../../state/staff_store.dart';
import '../../widgets/app_shell.dart';
import '../shared/bills_screen.dart';
import '../shared/deliveries_screen.dart';
import 'staff_orders_screen.dart';

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
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StaffStore>();

    final tabs = <TabDef>[
      TabDef(
        label: 'Round',
        icon: Icons.local_shipping_outlined,
        title: 'Daily round',
        badge: store.roundLeft,
        body: const DeliveriesScreen(asTab: true),
      ),
      TabDef(
        label: 'Orders',
        icon: Icons.receipt_long_outlined,
        title: 'Orders to deliver',
        badge: store.openOrders.length,
        body: const StaffOrdersScreen(),
      ),
      TabDef(
        label: 'Collect',
        icon: Icons.payments_outlined,
        title: 'Money to collect',
        badge: store.unpaidBills.length,
        body: const BillsScreen(asTab: true),
      ),
    ];

    return FarmScaffold(
      title: tabs[_index].title,
      body: IndexedStack(
        index: _index,
        children: [for (final t in tabs) t.body],
      ),
      bottomBar: FarmTabBar(
        tabs: tabs,
        index: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}
