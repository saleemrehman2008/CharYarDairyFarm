import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/accounting.dart';
import '../../state/farm_store.dart';
import '../../state/round_data.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/decision_banner.dart';
import '../../widgets/ui.dart';
import '../shared/accounts_screen.dart';
import '../shared/bills_screen.dart';
import '../shared/deliveries_screen.dart';
import '../shared/new_entry_screen.dart';
import '../shared/products_screen.dart';
import '../shared/report_screen.dart';
import 'activity_log_screen.dart';
import 'cattle_screen.dart';
import 'close_month_screen.dart';
import 'handovers_screen.dart';
import 'udhaar_registrations_screen.dart';
import 'users_screen.dart';

/// Sends the person to another tab by name.
///
/// By name rather than by number because the bottom bar is no longer a fixed
/// list — the master can switch parts of the farm off, and Orders may simply
/// not be there.
typedef GoTab = void Function(String tabId, {AccountsFilter? accountsFilter});

class MasterHome extends StatelessWidget {
  const MasterHome({super.key, required this.onGo});

  final GoTab onGo;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final l = L.of(context);
    final f = store.features;
    final books = store.books;

    return PageBody(
      children: [
        const DecisionBanner(),
        HeroCard(
          label: l.t('Cash in hand'),
          value: rs(books.cash),
          note: books.withRider > 0
              ? l.t2('%s is still with the rider', rs(books.withRider))
              : l.t('Everything the farm can spend today.'),
          trailing: Tag(monthShort(store.month.id), tone: TagTone.accent),
        ),
        const SizedBox(height: T.gap),

        // Two pairs of tiles: what the period has done, and what is still
        // owed either way. Colour carries the meaning — deep for money that
        // has moved, pale for money that has not.
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: l.t('Sales'),
                value: rs(books.sales),
                tone: T.moneyIn,
                note: monthShort(store.month.id),
                onTap: () =>
                    onGo('accounts', accountsFilter: AccountsFilter.sales),
              ),
            ),
            const SizedBox(width: T.gap),
            Expanded(
              child: StatTile(
                label: l.t('Running costs'),
                value: rs(books.costs),
                tone: T.moneyOut,
                note: books.assetsBought > 0
                    ? l.t2('+ %s assets', rs(books.assetsBought))
                    : l.t('feed, salaries, bills'),
                onTap: () =>
                    onGo('accounts', accountsFilter: AccountsFilter.expenses),
              ),
            ),
          ],
        ),
        const SizedBox(height: T.gap),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: l.t('To receive'),
                value: rs(books.receivable),
                tone: T.moneyGet,
                note: l.t2('%s unpaid', store.receivablesDue.length),
                onTap: () =>
                    onGo('accounts', accountsFilter: AccountsFilter.receivable),
              ),
            ),
            const SizedBox(width: T.gap),
            Expanded(
              child: StatTile(
                label: l.t('To pay'),
                value: rs(books.payable),
                tone: T.moneyDue,
                note: l.t2('%s bills', store.payablesDue.length),
                onTap: () =>
                    onGo('accounts', accountsFilter: AccountsFilter.payable),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        SectionTitle(l.t('Do')),
        const SizedBox(height: 4),
        ActionGrid(tiles: _actions(context, store, l, f)),
        const SizedBox(height: 20),

        _PeriodCard(store: store),
        const SizedBox(height: 20),

        _MoneyCard(money: store.money),
        const SizedBox(height: 20),

        SectionTitle(l.t('Needs attention')),
        const SizedBox(height: 4),
        ..._attention(context, store, l, f),
      ],
    );
  }

  List<ActionTile> _actions(
    BuildContext context,
    FarmStore store,
    L l,
    Features f,
  ) => [
    ActionTile(
      icon: Icons.add,
      label: l.t('New entry'),
      tone: T.accent600,
      onTap: () => _push(context, store, const NewEntryScreen()),
    ),
    if (f.rider)
      ActionTile(
        icon: Icons.local_shipping_outlined,
        label: l.t('Round'),
        tone: T.moneyIn,
        badge: store.roundLeft,
        onTap: () => _push(context, store, const DeliveriesScreen()),
      ),
    if (f.khaata)
      ActionTile(
        icon: Icons.receipt_outlined,
        label: l.t('Khaata bills'),
        tone: T.moneyGet,
        badge: store.unpaidBills.length,
        onTap: () => _push(context, store, const BillsScreen()),
      ),
    if (f.khaata)
      ActionTile(
        icon: Icons.handshake_outlined,
        label: l.t('Khaata sign-ups'),
        tone: T.moneyDue,
        badge: store.pendingUdhaar.length,
        onTap: () => _push(context, store, const UdhaarRegistrationsScreen()),
      ),
    if (f.rider)
      ActionTile(
        icon: Icons.account_balance_wallet_outlined,
        label: l.t('Handover'),
        tone: T.accent700,
        badge: store.handoversWaiting.length,
        onTap: () => _push(context, store, const HandoversScreen()),
      ),
    if (f.cattle)
      ActionTile(
        icon: Icons.pets_outlined,
        label: l.t('Cattle'),
        tone: const Color(0xFF6544B0),
        badge: store.dueChecks.length,
        onTap: () => _push(context, store, const CattleScreen()),
      ),
    ActionTile(
      icon: Icons.bar_chart,
      label: l.t('Report'),
      tone: T.moneyIn,
      onTap: () => _push(context, store, const ReportScreen()),
    ),
    ActionTile(
      icon: Icons.sell_outlined,
      label: l.t('Rates'),
      tone: T.accent500,
      onTap: () =>
          _push(context, store, const ProductsScreen(asSubScreen: true)),
    ),
    ActionTile(
      icon: Icons.manage_accounts_outlined,
      label: l.t('Users'),
      tone: T.n600,
      badge: store.pendingUsers.length,
      onTap: () => _push(context, store, const UsersScreen()),
    ),
    ActionTile(
      icon: Icons.history,
      label: l.t('Activity log'),
      tone: T.moneyDue,
      onTap: () => _push(context, store, const ActivityLogScreen()),
    ),
  ];

  List<Widget> _attention(
    BuildContext context,
    FarmStore store,
    L l,
    Features f,
  ) {
    final rows = <Widget>[];

    if (f.orders) {
      for (final o in store.pendingOrders) {
        rows.add(
          _AttentionRow(
            tag: l.t('Order'),
            tone: TagTone.warn,
            text: '#${o.number} · ${o.customerName} · ${rs(o.total)}',
            meta: o.itemsText,
            onTap: () => onGo('orders'),
          ),
        );
      }
    }
    if (f.khaata) {
      for (final u in store.pendingUdhaar) {
        rows.add(
          _AttentionRow(
            tag: l.t('Khaata'),
            tone: TagTone.warn,
            text: l.t2('%s wants a monthly account', u.name),
            meta:
                '${qty(u.litresPerDay)} L/day · ${rs(u.monthlyEstimate)} '
                '${l.t('a month')}',
            onTap: () =>
                _push(context, store, const UdhaarRegistrationsScreen()),
          ),
        );
      }
    }
    for (final u in store.pendingUsers) {
      rows.add(
        _AttentionRow(
          tag: l.t('User'),
          tone: TagTone.neutral,
          text: l.t2('%s signed up', u.name),
          meta: u.email,
          onTap: () => _push(context, store, const UsersScreen()),
        ),
      );
    }
    for (final t in store.payablesDue) {
      rows.add(
        _AttentionRow(
          tag: l.t('To pay'),
          tone: TagTone.bad,
          text: '${t.party} · ${rs(t.amount)}',
          meta: '${t.category} · ${fmtDate(t.date)}',
          onTap: () => onGo('accounts', accountsFilter: AccountsFilter.payable),
        ),
      );
    }

    if (rows.isEmpty) {
      return [EmptyNote(l.t('Nothing waiting. The farm is up to date.'))];
    }
    return rows;
  }

  void _push(BuildContext context, FarmStore store, Widget screen) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MultiProvider(
            providers: [
              ChangeNotifierProvider<FarmStore>.value(value: store),
              ChangeNotifierProvider<RoundData>.value(value: store),
            ],
            child: screen,
          ),
        ),
      );
}

/// What the open period has earned, and the way out of it.
class _PeriodCard extends StatelessWidget {
  const _PeriodCard({required this.store});

  final FarmStore store;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final books = store.books;

    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Kicker(l.t('Earned, not held'))),
              Tag(monthName(store.month.id), tone: TagTone.accent),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rs(books.profit),
            style: T.num28.copyWith(
              color: books.profit < 0 ? T.moneyOut : T.moneyIn,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${l.t('Sales')} ${rs(books.sales)} − ${l.t('costs')} '
            '${rs(books.costs)}',
            style: T.meta,
          ),
          if (books.assetsBought > 0) ...[
            const SizedBox(height: 2),
            Text(
              l.t2(
                '%s of cattle & equipment bought is not counted here — the '
                'farm still owns it.',
                rs(books.assetsBought),
              ),
              style: T.meta,
            ),
          ],
          if (books.profit < 0) ...[
            const SizedBox(height: 6),
            Text(
              l.t2(
                'This period has spent more than it has sold. That is not '
                'money lost — the farm still holds %s in cash. It is normal '
                'while stocking up: feed is bought in one go and eaten over '
                'months, while milk sells a little each day.',
                rs(books.cash),
              ),
              style: T.meta.copyWith(color: T.accent700),
            ),
          ],
          const SizedBox(height: 12),
          RatioBar(
            fraction: books.profitBar,
            color: books.profit < 0 ? T.moneyOut : T.moneyIn,
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: store.sealedPeriod == null
                ? l.t('Work out shares')
                : l.t2(
                    '%s is out for decisions',
                    periodLabel(store.sealedPeriod!, short: true),
                  ),
            icon: store.sealedPeriod == null
                ? Icons.pie_chart_outline
                : Icons.how_to_vote_outlined,
            onPressed: store.partners.isEmpty
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: store,
                        child: const CloseMonthScreen(),
                      ),
                    ),
                  ),
          ),
          if (store.partners.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              l.t(
                'Add co-founders before closing a period — there is nobody to '
                'share the profit with yet.',
              ),
              style: T.meta,
            ),
          ],
        ],
      ),
    );
  }
}

/// The whole route the farm's money has taken, laid out so the closing figure
/// can be checked line by line instead of taken on trust.
class _MoneyCard extends StatelessWidget {
  const _MoneyCard({required this.money});

  final MoneySummary money;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(l.t('Where the money is')),
          const SizedBox(height: 12),
          _MoneyLine(
            label: l.t('Co-founders put in'),
            value: money.capital,
            tone: T.moneyIn,
          ),
          _MoneyLine(
            label: l.t('Cattle & equipment bought'),
            value: -money.assets,
            note: l.t('the farm still owns these'),
            tone: T.moneyOut,
          ),
          _MoneyLine(
            label: l.t('Running costs so far'),
            value: -money.runningCosts,
            note: l.t('feed, salaries, bills'),
            tone: T.moneyOut,
          ),
          _MoneyLine(
            label: l.t('Sales so far'),
            value: money.sales,
            tone: T.moneyIn,
          ),
          const Divider(height: 20),
          _MoneyLine(
            label: l.t('Cash in hand'),
            value: money.cash,
            strong: true,
            tone: T.text,
          ),
          if (money.withRider > 0)
            _MoneyLine(
              label: l.t('With the rider'),
              value: money.withRider,
              note: l.t('taken at doors, not handed in yet'),
              tone: T.moneyGet,
            ),
          if (money.receivable > 0)
            _MoneyLine(
              label: l.t('Still to collect'),
              value: money.receivable,
              tone: T.moneyGet,
            ),
          if (money.payable > 0)
            _MoneyLine(
              label: l.t('Still to pay'),
              value: -money.payable,
              tone: T.moneyDue,
            ),
        ],
      ),
    );
  }
}

class _MoneyLine extends StatelessWidget {
  const _MoneyLine({
    required this.label,
    required this.value,
    required this.tone,
    this.note,
    this.strong = false,
  });

  final String label;
  final num value;
  final Color tone;
  final String? note;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: strong ? T.cardTitle : T.body),
              if (note != null)
                Text(note!, style: T.meta.copyWith(fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value < 0 ? '− ${rs(value.abs())}' : rs(value),
          style: (strong ? T.num22 : T.bodyMid).copyWith(color: tone),
        ),
      ],
    ),
  );
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({
    required this.tag,
    required this.tone,
    required this.text,
    required this.meta,
    required this.onTap,
  });

  final String tag;
  final TagTone tone;
  final String text;
  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: RegCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Tag(tag, tone: tone),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: T.bodyMid,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  meta,
                  style: T.meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: T.n500),
        ],
      ),
    ),
  );
}
