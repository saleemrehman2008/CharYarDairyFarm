import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../state/farm_store.dart';
import '../../state/round_data.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/day_chart.dart';
import '../../widgets/decision_banner.dart';
import '../../widgets/farm_icons.dart';
import '../../widgets/ui.dart';
import '../master/activity_log_screen.dart';
import '../master/cattle_screen.dart';
import '../shared/accounts_screen.dart';
import '../shared/my_account_screen.dart';
import '../shared/report_screen.dart';
import '../shared/statement_screen.dart';

/// A co-founder's own page: their money first, then the farm's.
///
/// Written the way a bank app is, because that is the only app of this kind
/// most of the farm has ever used: your own figure at the top in colour, the
/// four numbers that matter beneath it, and then the detail. A co-founder
/// opens this to answer two questions — how much is mine, and how is the farm
/// doing — and both should be answered before any scrolling.
class CofounderHome extends StatelessWidget {
  const CofounderHome({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final session = context.watch<Session>();
    final l = L.of(context);

    final books = store.books;
    final me = store.partnerFor(session.user?.uid ?? '');
    final ratio = me == null ? 0.0 : (store.ratios[me.id] ?? 0);
    final mine = (books.profit * ratio).round();

    // Profit as a share of what was sold. The farm's own sense of "how are we
    // doing" is this, not the rupee figure — a good month on a small turnover
    // and a bad one on a big turnover can carry the same profit.
    final margin = books.sales <= 0 ? 0.0 : (books.profit / books.sales * 100);

    return PageBody(
      children: [
        const DecisionBanner(),

        // Theirs first.
        HeroCard(
          label: l.t2(
            'Your share · %s',
            '${(ratio * 100).toStringAsFixed(0)}%',
          ),
          value: rs(mine),
          gradient: T.washOf(mine < 0 ? T.moneyOut : T.accent600),
          note: l.t3(
            'of %s made in %s so far',
            rs(books.profit),
            periodLabel(store.month),
          ),
          trailing: Tag(periodLabel(store.month, short: true)),
        ),
        const SizedBox(height: T.gap),

        Row(
          children: [
            Expanded(
              child: StatTile(
                label: l.t('Your capital'),
                value: rs(me?.capital ?? 0),
                tone: T.accent700,
                note: (me?.reinvested ?? 0) > 0
                    ? l.t2('incl. %s left in', rs(me!.reinvested))
                    : l.t('put in from your pocket'),
              ),
            ),
            const SizedBox(width: T.gap),
            Expanded(
              child: StatTile(
                label: l.t('Farm balance'),
                value: rs(books.cash),
                tone: T.moneyIn,
                note: books.withRider > 0
                    ? l.t2('%s with the rider', rs(books.withRider))
                    : l.t('cash in hand'),
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
              ),
            ),
            const SizedBox(width: T.gap),
            Expanded(
              child: StatTile(
                label: l.t('To pay'),
                value: rs(books.payable),
                tone: T.moneyDue,
                note: l.t2('%s bills', store.payablesDue.length),
              ),
            ),
          ],
        ),
        const SizedBox(height: T.gap),

        Row(
          children: [
            Expanded(
              child: StatTile(
                label: l.t('Margin'),
                value: '${margin.toStringAsFixed(0)}%',
                tone: margin < 0 ? T.moneyOut : T.moneyIn,
                note: l.t2('of %s sold', rs(books.sales)),
              ),
            ),
            const SizedBox(width: T.gap),
            Expanded(
              child: StatTile(
                label: l.t('Spent'),
                value: rs(books.costs),
                tone: T.moneyOut,
                note: l.t('feed, salaries, bills'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _MilkCard(store: store),
        const SizedBox(height: T.gap),

        DayChart(days: dayTotals(store.monthTxns)),
        const SizedBox(height: 20),

        SectionTitle(l.t('Look at')),
        const SizedBox(height: 4),
        ActionGrid(
          tiles: [
            ActionTile(
              icon: Icons.bar_chart,
              label: l.t('Report'),
              tone: T.moneyIn,
              onTap: () => _push(context, store, const ReportScreen()),
            ),
            ActionTile(
              icon: Icons.receipt_long_outlined,
              label: l.t('Statement'),
              tone: T.accent700,
              onTap: () => _push(context, store, const StatementScreen()),
            ),
            ActionTile(
              icon: Icons.account_balance_wallet_outlined,
              label: l.t('Accounts'),
              tone: T.accent600,
              onTap: () => _push(context, store, const AccountsScreen()),
            ),
            if (store.features.cattle)
              ActionTile(
                drawn: const CattleIcon(size: 22, color: Color(0xFF6544B0)),
                label: l.t('Cattle'),
                tone: const Color(0xFF6544B0),
                onTap: () => _push(context, store, const CattleScreen()),
              ),
            // Not tucked away under the master. If a figure looks wrong, the
            // co-founder who thinks so can go and read what was done,
            // without having to ask the person they are asking about.
            ActionTile(
              icon: Icons.history,
              label: l.t('Who did what'),
              tone: const Color(0xFFB0562F),
              onTap: () => _push(context, store, const ActivityLogScreen()),
            ),
            ActionTile(
              icon: Icons.person_outline,
              label: l.t('My account'),
              tone: T.n600,
              onTap: () => _push(context, store, const MyAccountScreen()),
            ),
          ],
        ),
        const SizedBox(height: 20),

        SectionTitle(l.t('Awaiting approval')),
        const SizedBox(height: 4),
        ..._approvals(context, store, l),

        const SizedBox(height: 20),
        SectionTitle(l.t('Your profit history')),
        const SizedBox(height: 4),
        _History(partnerId: me?.id),
      ],
    );
  }

  List<Widget> _approvals(BuildContext context, FarmStore store, L l) {
    final f = store.features;
    final orders = f.orders ? store.pendingOrders : const [];
    final khaata = f.khaata ? store.pendingUdhaar : const [];

    if (orders.isEmpty && khaata.isEmpty) {
      return [EmptyNote(l.t('Nothing needs your approval right now.'))];
    }

    return [
      for (final o in orders)
        _WaitingRow(
          tag: l.t('Order'),
          text: '#${o.number} · ${o.customerName} · ${rs(o.total)}',
          meta: o.itemsText,
        ),
      for (final u in khaata)
        _WaitingRow(
          tag: l.t('Khaata'),
          text: l.t2('%s wants a monthly account', u.name),
          meta:
              '${qty(u.litresPerDay)} L/day · ${rs(u.monthlyEstimate)} '
              '${l.t('a month')}',
        ),
      const SizedBox(height: 8),
      Text(l.t('Open the Approvals tab to act on these.'), style: T.meta),
    ];
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

/// How much milk the farm is putting out.
///
/// Read from what was sold, not from what the herd is recorded as giving — the
/// farm books two or three milk sales a day and keeps those up, while the
/// per-animal yield is something it has not started on yet.
class _MilkCard extends StatelessWidget {
  const _MilkCard({required this.store});

  final FarmStore store;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final total = store.milkLitres;
    final perDay = store.milkPerDay;

    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: T.accent100,
                  borderRadius: BorderRadius.circular(T.radiusXs),
                ),
                child: const Icon(
                  Icons.water_drop_outlined,
                  size: 19,
                  color: T.accent600,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Kicker(l.t('Milk out'))),
              Tag(periodLabel(store.month, short: true)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.t('A DAY'), style: T.kicker),
                    const SizedBox(height: 3),
                    Text(
                      '${qty(perDay)} L',
                      style: T.num30.copyWith(color: T.accent600),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.t('THIS PERIOD'), style: T.kicker),
                    const SizedBox(height: 3),
                    Text('${qty(total)} L', style: T.num30),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l.t2(
              'Across %s days of selling. Counted from the milk that was sold.',
              store.periodDays,
            ),
            style: T.meta,
          ),
        ],
      ),
    );
  }
}

/// Every period this co-founder has been paid out of.
class _History extends StatelessWidget {
  const _History({required this.partnerId});

  final String? partnerId;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (partnerId == null) {
      return EmptyNote(l.t('No capital recorded for you yet.'));
    }

    return StreamBuilder<List<FarmMonth>>(
      stream: Db.watchClosedMonths(),
      builder: (context, snap) {
        final months = snap.data ?? const <FarmMonth>[];
        final mine = <(FarmMonth, MonthShare)>[];
        for (final m in months) {
          for (final s in m.shares) {
            if (s.partnerId == partnerId) mine.add((m, s));
          }
        }
        if (mine.isEmpty) {
          return EmptyNote(l.t('No period has been closed yet.'));
        }

        return Column(
          children: [
            for (final (m, share) in mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: RegCard(
                  stripe: share.withdraw > 0 ? T.moneyOut : T.moneyIn,
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              periodLabel(m),
                              style: T.cardTitle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(rs(share.share), style: T.num22),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(l.t('Taken out'), style: T.body),
                          ),
                          Money(share.withdraw, incoming: false, settled: true),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.t('Left in as investment'),
                              style: T.body,
                            ),
                          ),
                          Money(share.reinvest, incoming: true, settled: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _WaitingRow extends StatelessWidget {
  const _WaitingRow({
    required this.tag,
    required this.text,
    required this.meta,
  });

  final String tag;
  final String text;
  final String meta;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: RegCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Tag(tag, tone: TagTone.warn),
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
        ],
      ),
    ),
  );
}
