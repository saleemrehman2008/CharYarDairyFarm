import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/farm_store.dart';
import '../../widgets/app_shell.dart';
import '../shared/accounts_screen.dart';
import '../shared/cofounders_screen.dart';
import '../shared/orders_screen.dart';
import '../shared/products_screen.dart';
import 'cofounder_home.dart';

class CofounderRoot extends StatelessWidget {
  const CofounderRoot({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => FarmStore(isMaster: false),
    child: const _CofounderTabs(),
  );
}

class _CofounderTabs extends StatefulWidget {
  const _CofounderTabs();

  @override
  State<_CofounderTabs> createState() => _CofounderTabsState();
}

class _CofounderTabsState extends State<_CofounderTabs> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();

    final tabs = <TabDef>[
      const TabDef(
        label: 'Home',
        icon: Icons.cottage_outlined,
        title: 'Your share',
        body: CofounderHome(),
      ),
      TabDef(
        label: 'Approvals',
        icon: Icons.check_circle_outline,
        title: 'Approvals',
        badge: store.approvalCount,
        body: const OrdersScreen(showUdhaarRequests: true),
      ),
      const TabDef(
        label: 'Accounts',
        icon: Icons.account_balance_wallet_outlined,
        title: 'Accounts',
        body: AccountsScreen(),
      ),
      const TabDef(
        label: 'Co-founders',
        icon: Icons.groups_outlined,
        title: 'Co-founders',
        body: CofoundersScreen(),
      ),
      const TabDef(
        label: 'Products',
        icon: Icons.sell_outlined,
        title: 'Products & rates',
        body: ProductsScreen(),
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
