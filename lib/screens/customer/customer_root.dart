import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/cart.dart';
import '../../state/customer_store.dart';
import '../../state/session.dart';
import '../../widgets/app_shell.dart';
import 'checkout_screen.dart';
import 'my_orders_screen.dart';
import 'shop_screen.dart';
import 'udhaar_account_screen.dart';

class CustomerRoot extends StatelessWidget {
  const CustomerRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<Session>().user?.uid ?? '';
    return ChangeNotifierProvider(
      create: (_) => CustomerStore(uid: uid),
      child: const _CustomerTabs(),
    );
  }
}

class _CustomerTabs extends StatefulWidget {
  const _CustomerTabs();

  @override
  State<_CustomerTabs> createState() => _CustomerTabsState();
}

class _CustomerTabsState extends State<_CustomerTabs> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CustomerStore>();
    final cart = context.watch<Cart>();

    final tabs = <TabDef>[
      TabDef(
        label: 'Shop',
        icon: Icons.storefront_outlined,
        title: 'Shop',
        body: ShopScreen(onGoToCart: () => setState(() => _index = 1)),
      ),
      TabDef(
        label: 'Cart',
        icon: Icons.shopping_basket_outlined,
        title: 'Checkout',
        badge: cart.lineCount,
        body: CheckoutScreen(onOrdered: () => setState(() => _index = 2)),
      ),
      TabDef(
        label: 'Orders',
        icon: Icons.receipt_long_outlined,
        title: 'My orders',
        badge: store.openOrderCount,
        body: const MyOrdersScreen(),
      ),
      const TabDef(
        label: 'Udhaar',
        icon: Icons.handshake_outlined,
        title: 'Udhaar account',
        body: UdhaarAccountScreen(),
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
