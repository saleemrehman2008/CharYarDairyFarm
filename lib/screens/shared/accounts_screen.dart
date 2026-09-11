import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/db.dart';
import '../../services/txn_repo.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';
import 'new_entry_screen.dart';

enum AccountsFilter {
  all,
  sales,
  expenses,
  receivable,
  payable;

  String get label => switch (this) {
    AccountsFilter.all => 'All',
    AccountsFilter.sales => 'Sales',
    AccountsFilter.expenses => 'Expenses',
    AccountsFilter.receivable => 'Receivable',
    AccountsFilter.payable => 'Payable',
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

  /// Null means the month the farm is currently booking into.
  String? _viewing;

  @override
  void didUpdateWidget(AccountsScreen old) {
    super.didUpdateWidget(old);
    // A KPI card on Home can jump straight to a preset filter.
    if (old.initialFilter != widget.initialFilter) {
      setState(() => _filter = widget.initialFilter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    // A month that has been closed since this screen was opened.
    final closed = store.closedMonths;
    final viewingId = _viewing;
    final past = viewingId == null
        ? null
        : closed.where((m) => m.id == viewingId).firstOrNull;

    if (viewingId != null && past == null) {
      // The month vanished — fall back to the open one rather than a blank.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _viewing = null);
      });
    }

    return past == null ? _openMonth(store) : _closedMonth(store, past);
  }

  /// The month the farm is booking into: live figures, and everything can be
  /// added to and settled.
  Widget _openMonth(FarmStore store) {
    final isMaster = context.watch<Session>().role == Role.master;
    final books = store.books;
    final rows = _rows(store.monthTxns, store);

    return PageBody(
      children: [
        _MonthPicker(
          months: store.closedMonths,
          openMonthId: store.month.id,
          selected: null,
          onPick: (id) => setState(() => _viewing = id),
        ),
        const SizedBox(height: T.pad),
        Row(
          children: [
            Expanded(
              child: _Mini(label: 'Receivable', value: rs(books.receivable)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Mini(label: 'Payable', value: rs(books.payable)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Mini(label: 'Cash', value: rs(books.cash)),
            ),
          ],
        ),
        const SizedBox(height: T.pad),

        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DecoratedBox(
                  decoration: BoxDecoration(border: T.hair),
                  child: Row(
                    children: [
                      for (final (i, f) in AccountsFilter.values.indexed)
                        _FilterChip(
                          label: f.label,
                          selected: f == _filter,
                          first: i == 0,
                          onTap: () => setState(() => _filter = f),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GhostButton(
              label: 'Add',
              icon: Icons.add,
              compact: true,
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
          ],
        ),
        const SizedBox(height: 12),

        Text(
          'All farm money in one place: milk & product sales, cattle, feed, '
          'bills, rent, food, salaries. Anything sold or bought on credit '
          'stays unpaid until you mark it paid.',
          style: T.meta,
        ),
        const SizedBox(height: 14),

        if (rows.isEmpty)
          const EmptyNote('Nothing booked here yet. Tap Add to start.')
        else
          for (final t in rows)
            _LedgerRow(
              txn: t,
              isMaster: isMaster,
              busy: _busyId == t.id,
              onMarkPaid: () => _markPaid(t),
              onDelete: () => _delete(t),
            ),
      ],
    );
  }

  /// A month already closed: its figures are the ones recorded at the close, so
  /// they read the same today as they did then. Entries can still be settled —
  /// last month's udhaar is often collected this month — but nothing new is
  /// added here, because a new entry belongs to the open month.
  Widget _closedMonth(FarmStore store, FarmMonth month) {
    final isMaster = context.watch<Session>().role == Role.master;

    return StreamBuilder<List<Txn>>(
      stream: Db.watchMonthTxns(month.id),
      builder: (context, snap) {
        final all = snap.data;
        final rows = all == null ? const <Txn>[] : _rows(all, store);

        return PageBody(
          children: [
            _MonthPicker(
              months: store.closedMonths,
              openMonthId: store.month.id,
              selected: month.id,
              onPick: (id) => setState(() => _viewing = id),
            ),
            const SizedBox(height: T.pad),

            RegCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Kicker(monthName(month.id))),
                      const Tag('Closed', tone: TagTone.good),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _ClosedLine(label: 'Sales', value: month.sales),
                  _ClosedLine(
                    label: 'Running costs',
                    value:
                        (month.purchases ?? 0) +
                        (month.expenses ?? 0) -
                        (month.assets ?? 0),
                  ),
                  if ((month.assets ?? 0) > 0)
                    _ClosedLine(
                      label: 'Cattle & equipment bought',
                      value: month.assets,
                    ),
                  const Divider(height: 16),
                  _ClosedLine(
                    label: 'Profit shared',
                    value: month.profit,
                    strong: true,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${month.arLabel} · closed '
                    '${month.closedAt == null ? '' : fmtDateFull(month.closedAt!)}',
                    style: T.meta,
                  ),
                ],
              ),
            ),
            const SizedBox(height: T.pad),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DecoratedBox(
                decoration: BoxDecoration(border: T.hair),
                child: Row(
                  children: [
                    for (final (i, f) in AccountsFilter.values.indexed)
                      _FilterChip(
                        label: f.label,
                        selected: f == _filter,
                        first: i == 0,
                        onTap: () => setState(() => _filter = f),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            if (all == null)
              const EmptyNote('Loading…')
            else if (rows.isEmpty)
              const EmptyNote('Nothing booked in this month.')
            else
              for (final t in rows)
                _LedgerRow(
                  txn: t,
                  isMaster: isMaster,
                  busy: _busyId == t.id,
                  onMarkPaid: () => _markPaid(t),
                  onDelete: () => _delete(t),
                ),
          ],
        );
      },
    );
  }

  /// Receivable and payable are balances, not month figures, so they always
  /// come from what is still outstanding today rather than from the month.
  List<Txn> _rows(List<Txn> monthTxns, FarmStore store) => switch (_filter) {
    AccountsFilter.all => monthTxns,
    AccountsFilter.sales =>
      monthTxns.where((t) => t.type == TxnType.sale).toList(),
    AccountsFilter.expenses =>
      monthTxns
          .where((t) => t.type == TxnType.purchase || t.type == TxnType.expense)
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

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => RegCard(
    padding: const EdgeInsets.all(10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Kicker(label),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: T.cardTitle),
        ),
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.first,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: 36,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: selected ? T.accent : Colors.transparent,
        border: first
            ? null
            : const Border(left: BorderSide(color: T.divider, width: 1)),
      ),
      child: Text(
        label,
        style: T.bodyMid.copyWith(
          fontSize: 12,
          color: selected ? T.accent100 : T.n700,
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
    final qtyLine = txn.qtyLine;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: T.divider, width: 1)),
      ),
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
                  const Tag('farm asset · not a cost', tone: TagTone.accent),
                ],
                if (!txn.paid) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Tag('unpaid', tone: TagTone.bad),
                      const SizedBox(width: 8),
                      GhostButton(
                        label: 'Mark paid',
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
              Text(
                signedRs(txn.amount, incoming: txn.type.isIncoming),
                style: T.bodyMid.copyWith(
                  color: txn.type.isIncoming ? T.accent700 : T.text,
                ),
              ),
              if (isMaster)
                SizedBox(
                  height: 30,
                  child: IconButton(
                    onPressed: busy ? null : onDelete,
                    icon: const Icon(Icons.close, size: 15, color: T.n500),
                    padding: EdgeInsets.zero,
                    tooltip: 'Delete entry',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chips for the open month and every month already closed, newest first.
class _MonthPicker extends StatelessWidget {
  const _MonthPicker({
    required this.months,
    required this.openMonthId,
    required this.selected,
    required this.onPick,
  });

  final List<FarmMonth> months;
  final String openMonthId;

  /// Null while the open month is showing.
  final String? selected;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(
            label: '${monthShort(openMonthId)} · open',
            selected: selected == null,
            onTap: () => onPick(null),
          ),
          for (final m in months)
            _Chip(
              label: monthShort(m.id),
              selected: selected == m.id,
              onTap: () => onPick(m.id),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: InkWell(
      onTap: onTap,
      child: Container(
        height: 34,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? T.accent : Colors.transparent,
          border: T.hair,
        ),
        child: Text(
          label,
          style: T.bodyMid.copyWith(
            fontSize: 12,
            color: selected ? T.accent100 : T.n700,
          ),
        ),
      ),
    ),
  );
}

/// One figure from a closed month's record.
class _ClosedLine extends StatelessWidget {
  const _ClosedLine({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final num? value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, style: strong ? T.cardTitle : T.body)),
        Text(rs(value ?? 0), style: strong ? T.num22 : T.bodyMid),
      ],
    ),
  );
}
