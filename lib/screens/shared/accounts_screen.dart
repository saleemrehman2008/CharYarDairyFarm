import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
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
    final isMaster = context.watch<Session>().role == Role.master;
    final books = store.books;
    final rows = _rows(store);

    return PageBody(
      children: [
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

  List<Txn> _rows(FarmStore store) => switch (_filter) {
    AccountsFilter.all => store.monthTxns,
    AccountsFilter.sales =>
      store.monthTxns.where((t) => t.type == TxnType.sale).toList(),
    AccountsFilter.expenses =>
      store.monthTxns
          .where((t) => t.type == TxnType.purchase || t.type == TxnType.expense)
          .toList(),
    AccountsFilter.receivable => store.receivablesDue,
    AccountsFilter.payable => store.payablesDue,
  };

  Future<void> _markPaid(Txn txn) async {
    setState(() => _busyId = txn.id);
    try {
      await TxnRepo.markPaid(context.read<Session>().actor, txn);
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
                  [txn.type.label, txn.category, ?qtyLine].join(' · '),
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
