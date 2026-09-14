import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/accounting.dart';
import '../../services/db.dart';
import '../../services/txn_repo.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';
import 'new_entry_screen.dart';

/// The five ways of looking at the ledger, each with its own colour.
///
/// The colour is the point. Five identically blue chips meant that once the
/// page had scrolled you could no longer tell which one you had pressed, so
/// the chosen filter now paints the figure at the top of the page as well as
/// its own chip. The colours are the money colours, not new ones: what has
/// come in is green, what has gone out is red, what is still owed either way
/// is pale.
enum AccountsFilter {
  all('All', T.accent600),
  sales('Sales', T.moneyIn),
  expenses('Expenses', T.moneyOut),
  receivable('To receive', T.moneyGet),
  payable('To pay', T.moneyDue);

  const AccountsFilter(this.label, this.tone);

  final String label;
  final Color tone;

  /// The one figure this view is about.
  num totalFrom(Books books) => switch (this) {
    AccountsFilter.all => books.cash,
    AccountsFilter.sales => books.sales,
    AccountsFilter.expenses => books.costs,
    AccountsFilter.receivable => books.receivable,
    AccountsFilter.payable => books.payable,
  };

  String get heading => switch (this) {
    AccountsFilter.all => 'Cash in hand',
    AccountsFilter.sales => 'Sales this period',
    AccountsFilter.expenses => 'Running costs',
    AccountsFilter.receivable => 'Still to collect',
    AccountsFilter.payable => 'Still to pay',
  };
}

/// The farm ledger: everything bought and sold, and what is still outstanding.
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key, this.initialFilter = AccountsFilter.all});

  final AccountsFilter initialFilter;

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  late AccountsFilter _filter = widget.initialFilter;
  String? _busyId;

  @override
  void didUpdateWidget(AccountsScreen old) {
    super.didUpdateWidget(old);
    // A tile on Home can jump straight to a preset filter.
    if (old.initialFilter != widget.initialFilter) {
      setState(() => _filter = widget.initialFilter);
    }
  }

  /// The whole ledger as one running account, newest first.
  ///
  /// It used to be shown a period at a time, behind a row of month chips.
  /// That was wrong in the way that matters: the moment a period was settled
  /// its entire ledger left the screen — and a period that was sealed but not
  /// yet closed had no chip at all, so it could not be reached from anywhere.
  /// The farm's books are read as one account. Where a period ended is drawn
  /// as a line through the list.
  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final isMaster = context.watch<Session>().role == Role.master;
    final l = L.of(context);
    final books = store.books;

    return StreamBuilder<List<Txn>>(
      stream: Db.watchLedger(),
      builder: (context, ledger) {
        return StreamBuilder<List<FarmMonth>>(
          stream: Db.watchPeriods(),
          builder: (context, periodSnap) {
            final all = ledger.data;
            final periods = periodSnap.data ?? const <FarmMonth>[];
            final rows = all == null ? const <Txn>[] : _rows(all, store);

            return PageBody(
              children: [
                HeroCard(
                  label: l.t(_filter.heading),
                  value: rs(_total(books, rows)),
                  gradient: T.washOf(_filter.tone),
                  note: all == null
                      ? l.t('Loading…')
                      : l.t2('%s entries', rows.length),
                  trailing: Tag(periodLabel(store.month, short: true)),
                ),
                const SizedBox(height: T.pad),

                _FilterBar(
                  filter: _filter,
                  onPick: (f) => setState(() => _filter = f),
                ),
                const SizedBox(height: 12),

                GhostButton(
                  label: l.t('Add an entry'),
                  icon: Icons.add,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: store,
                        child: const NewEntryScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  l.t(
                    'All farm money in one place: milk & product sales, '
                    'cattle, feed, bills, rent, food, salaries. Anything sold '
                    'or bought on credit stays unpaid until you mark it paid.',
                  ),
                  style: T.meta,
                ),
                const SizedBox(height: 14),

                if (all == null)
                  EmptyNote(l.t('Loading…'))
                else if (rows.isEmpty)
                  EmptyNote(l.t('Nothing booked here yet. Tap Add to start.'))
                else
                  ..._withDividers(rows, periods, l, isMaster),
              ],
            );
          },
        );
      },
    );
  }

  /// The rows, with a line drawn wherever the period changes.
  ///
  /// Grouped by the period each entry was booked into rather than by its date,
  /// because those two part company on purpose: an entry made the evening a
  /// period was sealed carries that evening's date and belongs to the period
  /// that opened, and the line has to fall where the books say it does.
  List<Widget> _withDividers(
    List<Txn> rows,
    List<FarmMonth> periods,
    L l,
    bool isMaster,
  ) {
    final out = <Widget>[];
    String? current;

    for (final txn in rows) {
      if (txn.monthId != current) {
        current = txn.monthId;
        final period = periods.where((p) => p.id == current).firstOrNull;
        out.add(_divider(period, current, l));
      }
      out.add(
        _LedgerRow(
          txn: txn,
          isMaster: isMaster,
          busy: _busyId == txn.id,
          onMarkPaid: () => _markPaid(txn),
          onDelete: () => _delete(txn),
        ),
      );
    }
    return out;
  }

  Widget _divider(FarmMonth? period, String id, L l) {
    if (period == null) {
      // A period document the farm never wrote, from before periods were
      // recorded. Name it from the id and say nothing else about it.
      return PeriodDivider(
        label: monthName(id),
        state: l.t('earlier'),
        tone: T.n600,
      );
    }

    // The days it covered, written out. "September 2026" does not say whether
    // that was to the 30th or to the 14th.
    final dates = periodDates(period);

    if (period.isOpen) {
      return PeriodDivider(
        label: periodLabel(period),
        state: l.t('open now'),
        tone: T.moneyIn,
        note: dates.isEmpty ? null : l.t2('Started %s', dates),
      );
    }

    final shared = period.profitShared ?? 0;
    final money = shared > 0
        ? l.t2('%s shared between the co-founders', rs(shared))
        : l.t('Nothing was shared out of this one.');

    return PeriodDivider(
      label: periodLabel(period),
      state: period.isSealed
          ? l.t('sealed — waiting on the co-founders')
          : l.t('closed here'),
      tone: period.isSealed ? T.moneyDue : T.accent700,
      note: dates.isEmpty ? money : '$dates\n$money',
    );
  }

  /// The one figure above the list, matching whatever the filter is showing.
  num _total(Books books, List<Txn> rows) => switch (_filter) {
    // Balances, which belong to the farm rather than to a period.
    AccountsFilter.all => books.cash,
    AccountsFilter.receivable => books.receivable,
    AccountsFilter.payable => books.payable,
    // Totals of what is actually on screen.
    _ => rows.fold<num>(0, (a, t) => a + t.amount),
  };

  List<Txn> _rows(List<Txn> monthTxns, FarmStore store) => switch (_filter) {
    AccountsFilter.all => monthTxns,
    AccountsFilter.sales =>
      monthTxns.where((t) => t.type == TxnType.sale).toList(),
    // Loose payments are in here too: money that went out with no cost
    // booked against it anywhere else is a cost, and hiding it from this
    // list is how the farm lost track of a rent payment.
    AccountsFilter.expenses =>
      monthTxns
          .where(
            (t) =>
                t.type == TxnType.purchase ||
                t.type == TxnType.expense ||
                t.isLoosePayment,
          )
          .toList(),
    AccountsFilter.receivable => store.receivablesDue,
    AccountsFilter.payable => store.payablesDue,
  };

  Future<void> _markPaid(Txn txn) async {
    // Ask how the money moved before booking it — a month later nobody will
    // remember whether it was cash or a transfer.
    final settled = await askSettlement(
      context,
      incoming: txn.type.isIncoming,
      party: txn.party,
      amount: txn.amount,
    );
    if (settled == null || !mounted) return;

    setState(() => _busyId = txn.id);
    try {
      await TxnRepo.markPaid(
        context.read<Session>().actor,
        txn,
        payVia: settled.payVia ?? PayVia.cash,
        handledBy: settled.handledBy,
      );
      if (mounted) toast(context, '${txn.party} marked paid');
    } catch (e) {
      if (mounted) toast(context, 'Could not mark it paid. $e');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(Txn txn) async {
    final ok = await confirm(
      context,
      title: 'Delete this entry?',
      body:
          '${txn.type.label} · ${txn.party} · ${rs(txn.amount)}\n\n'
          'It disappears from the app and is marked deleted in the Sheet.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;

    setState(() => _busyId = txn.id);
    try {
      await TxnRepo.softDelete(context.read<Session>().actor, txn);
      if (mounted) toast(context, 'Entry deleted');
    } catch (e) {
      if (mounted) toast(context, 'Could not delete it. $e');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }
}

/// The row of filters. Each chip wears its own colour when chosen, and the
/// figure above the list wears it too.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter, required this.onPick});

  final AccountsFilter filter;
  final ValueChanged<AccountsFilter> onPick;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in AccountsFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: _FilterChip(
                label: l.t(f.label),
                tone: f.tone,
                selected: f == filter,
                onTap: () => onPick(f),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.tone,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color tone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(T.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 36,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: selected ? tone : Colors.white,
          borderRadius: BorderRadius.circular(T.pill),
          border: Border.all(color: selected ? tone : T.n300, width: 1.3),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: tone.withValues(alpha: 0.32),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: T.bodyMid.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : T.n700,
          ),
        ),
      ),
    ),
  );
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.txn,
    required this.isMaster,
    required this.busy,
    required this.onMarkPaid,
    required this.onDelete,
  });

  final Txn txn;
  final bool isMaster;
  final bool busy;
  final VoidCallback onMarkPaid;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final qtyLine = txn.qtyLine;
    // Every entry wears the colour of what it is and whether the money has
    // actually moved, down its own edge — so a page of them can be read down
    // the left margin without reading a word of it.
    final tone = T.money(incoming: txn.type.isIncoming, settled: txn.paid);

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: RegCard(
        stripe: tone,
        padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 46, child: Text(fmtDate(txn.date), style: T.meta)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.party.isEmpty ? txn.category : txn.party,
                    style: T.bodyMid,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    [
                      txn.type.label,
                      txn.category,
                      ?qtyLine,
                      if (txn.handOverLine.isNotEmpty) txn.handOverLine,
                    ].join(' · '),
                    style: T.meta,
                    maxLines: 2,
                  ),
                  if (txn.note.isNotEmpty)
                    Text(
                      txn.note,
                      style: T.meta.copyWith(color: T.n500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (txn.isCapitalAsset) ...[
                    const SizedBox(height: 6),
                    Tag(l.t('farm asset · not a cost'), tone: TagTone.accent),
                  ],
                  if (!txn.paid) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Tag(
                          l.t(
                            txn.type.isIncoming ? 'not received' : 'not paid',
                          ),
                          tone: txn.type.isIncoming
                              ? TagTone.neutral
                              : TagTone.warn,
                        ),
                        const SizedBox(width: 8),
                        GhostButton(
                          label: l.t('Mark paid'),
                          compact: true,
                          onPressed: busy ? null : onMarkPaid,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Deep when the money has moved, pale when it is still owed.
                Text(
                  signedRs(txn.amount, incoming: txn.type.isIncoming),
                  style: T.bodyMid.copyWith(
                    color: T.money(
                      incoming: txn.type.isIncoming,
                      settled: txn.paid,
                    ),
                    fontWeight: T.moneyWeight(txn.paid),
                  ),
                ),
                if (isMaster)
                  SizedBox(
                    height: 30,
                    child: IconButton(
                      onPressed: busy ? null : onDelete,
                      icon: const Icon(Icons.close, size: 15, color: T.n400),
                      padding: EdgeInsets.zero,
                      tooltip: l.t('Delete entry'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
