import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/accounting.dart';
import '../../state/farm_store.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';
import '../shared/accounts_screen.dart';
import 'close_month_screen.dart';
import 'udhaar_registrations_screen.dart';
import 'users_screen.dart';

typedef GoTab = void Function(int index, {AccountsFilter? accountsFilter});

class MasterHome extends StatelessWidget {
  const MasterHome({super.key, required this.onGo});

  final GoTab onGo;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final books = store.books;

    return PageBody(
      children: [
        // ---- Current balance ----
        RegCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Kicker(
                      'Current balance · ${monthName(store.month.id)}',
                    ),
                  ),
                  const Tag('Open', tone: TagTone.accent),
                ],
              ),
              const SizedBox(height: 8),
              Text(rs(books.cash), style: T.num36),
              const SizedBox(height: 6),
              Text(
                'Cash the farm has in hand right now. The breakdown is below.',
                style: T.meta,
              ),
            ],
          ),
        ),
        const SizedBox(height: T.gap),

        // ---- Where the money is ----
        _MoneyCard(money: store.money),
        const SizedBox(height: T.gap),

        // ---- KPI grid ----
        Row(
          children: [
            Expanded(
              child: _Kpi(
                label: 'Sales MTD',
                value: rs(books.sales),
                onTap: () => onGo(2, accountsFilter: AccountsFilter.sales),
              ),
            ),
            const SizedBox(width: T.gap),
            Expanded(
              child: _Kpi(
                label: 'Running costs',
                value: rs(books.costs),
                note: books.assetsBought > 0
                    ? '+ ${rs(books.assetsBought)} assets'
                    : 'feed, salaries, bills',
                onTap: () => onGo(2, accountsFilter: AccountsFilter.expenses),
              ),
            ),
          ],
        ),
        const SizedBox(height: T.gap),
        Row(
          children: [
            Expanded(
              child: _Kpi(
                label: 'Accounts receivable',
                value: rs(books.receivable),
                note: '${store.receivablesDue.length} unpaid sales',
                onTap: () => onGo(2, accountsFilter: AccountsFilter.receivable),
              ),
            ),
            const SizedBox(width: T.gap),
            Expanded(
              child: _Kpi(
                label: 'Accounts payable',
                value: rs(books.payable),
                note: '${store.payablesDue.length} unpaid bills',
                onTap: () => onGo(2, accountsFilter: AccountsFilter.payable),
              ),
            ),
          ],
        ),
        const SizedBox(height: T.gap),

        // ---- Month to date ----
        RegCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Kicker('${monthShort(store.month.id)} — earned, not held'),
              const SizedBox(height: 8),
              Text(rs(books.profit), style: T.num28),
              const SizedBox(height: 4),
              Text(
                'Sales ${rs(books.sales)} − Running costs ${rs(books.costs)}',
                style: T.meta,
              ),
              if (books.assetsBought > 0) ...[
                const SizedBox(height: 2),
                Text(
                  '${rs(books.assetsBought)} of cattle & equipment bought this '
                  'month is not counted here — the farm still owns it.',
                  style: T.meta,
                ),
              ],
              if (books.profit < 0) ...[
                const SizedBox(height: 6),
                Text(
                  'This month has spent more than it has sold. That is not '
                  'money lost — the farm still holds ${rs(books.cash)} in cash. '
                  'It is normal while stocking up: feed is bought in one go and '
                  'eaten over months, while milk sells a little each day.',
                  style: T.meta.copyWith(color: T.accent700),
                ),
              ],
              const SizedBox(height: 10),
              RatioBar(fraction: books.profitBar),
              const SizedBox(height: 14),
              PrimaryButton(
                label: 'Close ${monthShort(store.month.id)} & share profit',
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
                  'Add co-founders before closing a month — there is nobody to '
                  'share the profit with yet.',
                  style: T.meta,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),

        // ---- Needs attention ----
        const SectionTitle('Needs attention'),
        ..._attention(context, store),
      ],
    );
  }

  List<Widget> _attention(BuildContext context, FarmStore store) {
    final rows = <Widget>[];

    for (final o in store.pendingOrders) {
      rows.add(
        _AttentionRow(
          tag: 'Order',
          tone: TagTone.warn,
          text: '#${o.number} · ${o.customerName} · ${rs(o.total)}',
          meta: o.itemsText,
          onTap: () => onGo(1),
        ),
      );
    }
    for (final u in store.pendingUdhaar) {
      rows.add(
        _AttentionRow(
          tag: 'Khaata',
          tone: TagTone.warn,
          text: '${u.name} wants a monthly account',
          meta:
              '${qty(u.litresPerDay)} L/day · about '
              '${rs(u.monthlyEstimate)} a month',
          onTap: () => _push(context, store, const UdhaarRegistrationsScreen()),
        ),
      );
    }
    for (final u in store.pendingUsers) {
      rows.add(
        _AttentionRow(
          tag: 'User',
          tone: TagTone.neutral,
          text: '${u.name} signed up',
          meta: u.email,
          onTap: () => _push(context, store, const UsersScreen()),
        ),
      );
    }
    for (final t in store.payablesDue) {
      rows.add(
        _AttentionRow(
          tag: 'Payable',
          tone: TagTone.bad,
          text: '${t.party} · ${rs(t.amount)}',
          meta: '${t.category} · booked ${fmtDate(t.date)}',
          onTap: () => onGo(2, accountsFilter: AccountsFilter.payable),
        ),
      );
    }

    if (rows.isEmpty) {
      return const [EmptyNote('Nothing waiting. The farm is up to date.')];
    }
    return rows;
  }

  void _push(BuildContext context, FarmStore store, Widget screen) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChangeNotifierProvider.value(value: store, child: screen),
        ),
      );
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, this.note, this.onTap});

  final String label;
  final String value;
  final String? note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => RegCard(
    onTap: onTap,
    padding: const EdgeInsets.all(13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 28, child: Kicker(label)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: T.num22),
        ),
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(note!, style: T.meta.copyWith(fontSize: 11)),
        ],
      ],
    ),
  );
}

/// The whole route the farm's money has taken, laid out so the closing figure
/// can be checked line by line instead of taken on trust.
class _MoneyCard extends StatelessWidget {
  const _MoneyCard({required this.money});

  final MoneySummary money;

  @override
  Widget build(BuildContext context) => RegCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Kicker('Where the money is'),
        const SizedBox(height: 12),
        _MoneyLine(label: 'Co-founders put in', value: money.capital),
        _MoneyLine(
          label: 'Cattle & equipment bought',
          value: -money.assets,
          note: 'the farm still owns these',
        ),
        _MoneyLine(
          label: 'Running costs so far',
          value: -money.runningCosts,
          note: 'feed, salaries, bills',
        ),
        _MoneyLine(label: 'Sales so far', value: money.sales),
        const Divider(height: 20),
        _MoneyLine(label: 'Cash in hand', value: money.cash, strong: true),
        if (money.receivable > 0)
          _MoneyLine(
            label: 'Still to collect',
            value: money.receivable,
            note: 'khaata not collected yet',
          ),
        if (money.payable > 0)
          _MoneyLine(
            label: 'Still to pay',
            value: -money.payable,
            note: 'bills not paid yet',
          ),
      ],
    ),
  );
}

class _MoneyLine extends StatelessWidget {
  const _MoneyLine({
    required this.label,
    required this.value,
    this.note,
    this.strong = false,
  });

  final String label;
  final num value;
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
          style: strong ? T.num22 : T.bodyMid,
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
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: T.divider, width: 1)),
      ),
      child: Row(
        children: [
          SizedBox(width: 66, child: Tag(tag, tone: tone)),
          const SizedBox(width: 8),
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
