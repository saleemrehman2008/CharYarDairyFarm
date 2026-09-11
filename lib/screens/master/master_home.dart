import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
                'Cash in hand after everything paid so far this month.',
                style: T.meta,
              ),
            ],
          ),
        ),
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
                label: 'Purchases & expenses',
                value: rs(books.costs),
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
              const Kicker('Month to date'),
              const SizedBox(height: 8),
              Text(rs(books.profit), style: T.num28),
              const SizedBox(height: 4),
              Text(
                'Sales ${rs(books.sales)} − Costs ${rs(books.costs)}',
                style: T.meta,
              ),
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
          tag: 'Udhaar',
          tone: TagTone.warn,
          text: '${u.name} wants a monthly account',
          meta: '${qty(u.litresPerDay)} L/day · limit ${rs(u.limit)}',
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
  const _Kpi({
    required this.label,
    required this.value,
    this.note,
    this.onTap,
  });

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
                Text(text, style: T.bodyMid, maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(meta, style: T.meta, maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: T.n500),
        ],
      ),
    ),
  );
}
