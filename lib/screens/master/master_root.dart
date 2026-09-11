import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/farm_store.dart';
import '../../widgets/app_shell.dart';
import '../shared/accounts_screen.dart';
import '../shared/cofounders_screen.dart';
import '../shared/orders_screen.dart';
import 'master_home.dart';
import 'more_screen.dart';

class MasterRoot extends StatelessWidget {
  const MasterRoot({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => FarmStore(isMaster: true),
    child: const _MasterTabs(),
  );
}

class _MasterTabs extends StatefulWidget {
  const _MasterTabs();

  @override
  State<_MasterTabs> createState() => _MasterTabsState();
}

class _MasterTabsState extends State<_MasterTabs> {
  int _index = 0;

  /// Jumping between tabs from a card tap (a KPI card, or a "Needs attention"
  /// row) goes through here so the bottom bar stays in step.
  void _go(int index, {AccountsFilter? accountsFilter}) {
    setState(() {
      _index = index;
      if (accountsFilter != null) _accountsFilter = accountsFilter;
    });
  }

  AccountsFilter _accountsFilter = AccountsFilter.all;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();

    final tabs = <TabDef>[
      TabDef(
        label: 'Home',
        icon: Icons.cottage_outlined,
        title: 'Farm dashboard',
        body: MasterHome(onGo: _go),
      ),
      TabDef(
        label: 'Orders',
        icon: Icons.receipt_long_outlined,
        title: 'Orders',
        badge: store.pendingOrders.length,
        body: const OrdersScreen(),
      ),
      TabDef(
        label: 'Accounts',
        icon: Icons.account_balance_wallet_outlined,
        title: 'Accounts',
        body: AccountsScreen(initialFilter: _accountsFilter),
      ),
      TabDef(
        label: 'Co-founders',
        icon: Icons.groups_outlined,
        title: 'Co-founders',
        body: const CofoundersScreen(),
      ),
      TabDef(
        label: 'More',
        icon: Icons.more_horiz,
        title: 'More',
        badge: store.pendingUsers.length + store.pendingUdhaar.length,
        body: const MoreScreen(),
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
