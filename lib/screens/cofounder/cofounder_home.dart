import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/db.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/decision_banner.dart';
import '../../widgets/ui.dart';

/// What this co-founder has put in and what the farm owes them so far.
class CofounderHome extends StatelessWidget {
  const CofounderHome({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final session = context.watch<Session>();
    final books = store.books;
    final me = store.partnerFor(session.user?.uid ?? '');
    final ratio = me == null ? 0.0 : (store.ratios[me.id] ?? 0);
    final projected = (books.profit * ratio).round();

    return PageBody(
      children: [
        const DecisionBanner(),
        RegCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Kicker('Your share · ${(ratio * 100).toStringAsFixed(0)}%'),
              const SizedBox(height: 8),
              Text(rs(projected), style: T.num36),
              const SizedBox(height: 6),
              Text(
                'from ${rs(books.profit)} profit to date · '
                '${monthName(store.month.id)}',
                style: T.meta,
              ),
            ],
          ),
        ),
        const SizedBox(height: T.gap),

        Row(
          children: [
            Expanded(
              child: RegCard(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Kicker('Your capital'),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(rs(me?.capital ?? 0), style: T.num22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'incl. ${rs(me?.reinvested ?? 0)} reinvested',
                      style: T.meta.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: T.gap),
            Expanded(
              child: RegCard(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Kicker('Farm balance'),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(rs(books.cash), style: T.num22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AR ${rs(books.receivable)} · AP ${rs(books.payable)}',
                      style: T.meta.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        const SectionTitle('Awaiting approval'),
        if (store.pendingOrders.isEmpty && store.pendingUdhaar.isEmpty)
          const EmptyNote('Nothing needs your approval right now.')
        else ...[
          for (final o in store.pendingOrders)
            _Row(
              tag: 'Order',
              text: '#${o.number} · ${o.customerName} · ${rs(o.total)}',
              meta: o.itemsText,
            ),
          for (final u in store.pendingUdhaar)
            _Row(
              tag: 'Khaata',
              text: '${u.name} wants a monthly account',
              meta:
                  '${qty(u.litresPerDay)} L/day · about '
                  '${rs(u.monthlyEstimate)} a month',
            ),
          const SizedBox(height: 8),
          Text('Open the Approvals tab to act on these.', style: T.meta),
        ],

        const SizedBox(height: 22),
        const SectionTitle('Your profit history'),
        if (me == null)
          const EmptyNote('No capital recorded for you yet.')
        else
          StreamBuilder<List<FarmMonth>>(
            stream: Db.watchClosedMonths(),
            builder: (context, snap) {
              final months = snap.data ?? const <FarmMonth>[];
              final mine = <(FarmMonth, MonthShare)>[];
              for (final m in months) {
                for (final s in m.shares) {
                  if (s.partnerId == me.id) mine.add((m, s));
                }
              }
              if (mine.isEmpty) {
                return const EmptyNote('No month has been closed yet.');
              }
              return Column(
                children: [
                  for (final (m, s) in mine)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: T.divider, width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(monthName(m.id), style: T.bodyMid),
                          ),
                          Tag(
                            s.choiceLabel,
                            tone: s.isReinvested
                                ? TagTone.accent
                                : TagTone.neutral,
                          ),
                          const SizedBox(width: 8),
                          Text(rs(s.share), style: T.bodyMid),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.tag, required this.text, required this.meta});

  final String tag;
  final String text;
  final String meta;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: T.divider, width: 1)),
    ),
    child: Row(
      children: [
        SizedBox(width: 66, child: Tag(tag, tone: TagTone.warn)),
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
      ],
    ),
  );
}
