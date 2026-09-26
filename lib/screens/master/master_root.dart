import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../state/chat_store.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../widgets/app_shell.dart';
import '../shared/accounts_screen.dart';
import '../shared/chat_screen.dart';
import '../shared/cofounders_screen.dart';
import '../shared/orders_screen.dart';
import 'master_home.dart';
import 'more_screen.dart';

class MasterRoot extends StatelessWidget {
  const MasterRoot({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => FarmStore(isMaster: true)),
      // Listened to from here rather than from inside the tab, because the
      // dot has to appear on a tab that is not open.
      ChangeNotifierProvider(create: (_) => ChatStore()),
    ],
    child: const _MasterTabs(),
  );
}

class _MasterTabs extends StatefulWidget {
  const _MasterTabs();

  @override
  State<_MasterTabs> createState() => _MasterTabsState();
}

class _MasterTabsState extends State<_MasterTabs> {
  /// Which tab is open, by name.
  ///
  /// Held by name rather than by number because the master can switch parts
  /// of the farm off: Orders may be there this minute and gone the next, and
  /// a stored number would then point at whatever slid into its place.
  String _tab = 'home';
  AccountsFilter _accountsFilter = AccountsFilter.all;

  void _go(String tabId, {AccountsFilter? accountsFilter}) {
    setState(() {
      _tab = tabId;
      if (accountsFilter != null) _accountsFilter = accountsFilter;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final chat = context.watch<ChatStore>();
    final me = context.watch<Session>().user;
    final l = L.of(context);
    final f = store.features;

    final tabs = <TabDef>[
      TabDef(
        id: 'home',
        label: l.t('Home'),
        icon: Icons.cottage_outlined,
        title: l.t('Farm dashboard'),
        body: MasterHome(onGo: _go),
      ),
      if (f.orders)
        TabDef(
          id: 'orders',
          label: l.t('Orders'),
          icon: Icons.receipt_long_outlined,
          title: l.t('Orders'),
          badge: store.pendingOrders.length,
          body: const OrdersScreen(),
        ),
      TabDef(
        id: 'accounts',
        label: l.t('Accounts'),
        icon: Icons.account_balance_wallet_outlined,
        title: l.t('Accounts'),
        body: AccountsScreen(initialFilter: _accountsFilter),
      ),
      TabDef(
        id: 'partners',
        label: l.t('Co-founders'),
        icon: Icons.groups_outlined,
        title: l.t('Co-founders'),
        body: const CofoundersScreen(),
      ),
      TabDef(
        id: 'chat',
        label: l.t('Chat'),
        icon: Icons.forum_outlined,
        title: l.t('Farm room'),
        badge: chat.unreadFor(me?.uid ?? '', me?.chatSeenAt),
        body: ChatScreen(active: _tab == 'chat'),
      ),
      TabDef(
        id: 'more',
        label: l.t('More'),
        icon: Icons.more_horiz,
        title: l.t('More'),
        badge: store.pendingUsers.length + store.pendingUdhaar.length,
        body: const MoreScreen(),
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
