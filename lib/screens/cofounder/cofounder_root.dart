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
import '../master/more_screen.dart';
import 'cofounder_home.dart';

class CofounderRoot extends StatelessWidget {
  const CofounderRoot({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => FarmStore(isMaster: false)),
      ChangeNotifierProvider(create: (_) => ChatStore()),
    ],
    child: const _CofounderTabs(),
  );
}

class _CofounderTabs extends StatefulWidget {
  const _CofounderTabs();

  @override
  State<_CofounderTabs> createState() => _CofounderTabsState();
}

class _CofounderTabsState extends State<_CofounderTabs> {
  String _tab = 'home';

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
        title: l.t('Your share'),
        body: const CofounderHome(),
      ),
      // Approvals covers shop orders and khaata sign-ups. With both switched
      // off there is nothing that can arrive here, so the tab goes too.
      if (f.orders || f.khaata)
        TabDef(
          id: 'approvals',
          label: l.t('Approvals'),
          icon: Icons.check_circle_outline,
          title: l.t('Approvals'),
          badge: store.approvalCount,
          body: const OrdersScreen(showUdhaarRequests: true),
        ),
      TabDef(
        id: 'accounts',
        label: l.t('Accounts'),
        icon: Icons.account_balance_wallet_outlined,
        title: l.t('Accounts'),
        body: const AccountsScreen(),
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
        badge: f.khaata ? store.unpaidBills.length : 0,
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
