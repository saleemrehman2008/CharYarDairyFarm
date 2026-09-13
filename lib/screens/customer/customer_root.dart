import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../state/cart.dart';
import '../../state/customer_store.dart';
import '../../state/session.dart';
import '../../widgets/app_shell.dart';
import '../notice_screen.dart';
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
  String _tab = 'shop';

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final store = context.watch<CustomerStore>();
    final cart = context.watch<Cart>();
    final l = L.of(context);
    final f = session.features;

    // Nothing is being sold yet. Say so rather than show a shop with no
    // shelves and a khaata with no account.
    if (!f.anythingForCustomers) {
      return NoticeScreen(
        title: l.t('The farm is not taking orders yet'),
        body: l.t(
          'Char Yar Dairy Farm has not opened online ordering or monthly '
          'khaata accounts yet. You will be able to order here as soon as it '
          'does.',
        ),
        secondaryLabel: l.t('Sign out'),
        onSecondary: session.signOut,
      );
    }

    final tabs = <TabDef>[
      if (f.orders) ...[
        TabDef(
          id: 'shop',
          label: l.t('Shop'),
          icon: Icons.storefront_outlined,
          title: l.t('Shop'),
          body: ShopScreen(onGoToCart: () => setState(() => _tab = 'cart')),
        ),
        TabDef(
          id: 'cart',
          label: l.t('Cart'),
          icon: Icons.shopping_basket_outlined,
          title: l.t('Checkout'),
          badge: cart.lineCount,
          body: CheckoutScreen(onOrdered: () => setState(() => _tab = 'orders')),
        ),
        TabDef(
          id: 'orders',
          label: l.t('Orders'),
          icon: Icons.receipt_long_outlined,
          title: l.t('My orders'),
          badge: store.openOrderCount,
          body: const MyOrdersScreen(),
        ),
      ],
      if (f.khaata)
        TabDef(
          id: 'khaata',
          label: l.t('Khaata'),
          icon: Icons.handshake_outlined,
          title: l.t('Khaata'),
          // A bill waiting to be paid puts a mark on the tab, so it is noticed
          // without having to go looking.
          badge: store.unpaidBills.length,
          body: const UdhaarAccountScreen(),
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
