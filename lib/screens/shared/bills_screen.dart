import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/bill_repo.dart';
import '../../state/round_data.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';

/// Monthly khaata bills and the money taken against them.
class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key, this.asTab = false});

  /// True when a root already provides the chrome, as it does for staff.
  final bool asTab;

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  bool _onlyUnpaid = true;
  bool _busy = false;

  Future<void> _raiseAll() async {
    final store = context.read<RoundData>();
    final ok = await confirm(
      context,
      title: 'Raise bills for ${monthName(store.monthId)}?',
      body:
          'Each khaata customer gets a bill for the milk taken this month, '
          'plus anything still owing from before. Running it again is safe — '
          'nothing gets billed twice.',
      confirmLabel: 'Raise bills',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      final count = await BillRepo.raiseAll(
        context.read<Session>().actor,
        monthId: store.monthId,
        accounts: store.khaataCustomers,
        monthDeliveries: store.monthDeliveries,
      );
      if (mounted) {
        toast(
          context,
          count == 0 ? 'Nothing to bill yet.' : '$count bills raised',
        );
      }
    } catch (e) {
      if (mounted) toast(context, 'Could not raise the bills. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RoundData>();
    final isPartner = context.watch<Session>().role.isPartner;
    final bills = _onlyUnpaid ? store.unpaidBills : store.bills;
    final owed = store.unpaidBills.fold<num>(0, (a, b) => a + b.balance);

    final body = PageBody(
      children: [
        RegCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Kicker('Still owed to the farm'),
              const SizedBox(height: 6),
              Text(rs(owed), style: T.num28),
              const SizedBox(height: 4),
              Text(
                '${store.unpaidBills.length} bills not fully paid',
                style: T.meta,
              ),
              // Raising a bill is the farm's decision; staff collect against
              // the ones already raised.
              if (isPartner) ...[
                const SizedBox(height: 14),
                PrimaryButton(
                  label: 'Raise ${monthShort(store.monthId)} bills',
                  busy: _busy,
                  onPressed: store.khaataCustomers.isEmpty ? null : _raiseAll,
                ),
                const SizedBox(height: 8),
                Text(
                  'Bills are raised automatically when the month is closed. '
                  'Use this to send them out early.',
                  style: T.meta,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: T.pad),

        Segmented<bool>(
          value: _onlyUnpaid,
          compact: true,
          options: const [(true, 'Unpaid'), (false, 'All')],
          onChanged: (v) => setState(() => _onlyUnpaid = v),
        ),
        const SizedBox(height: T.pad),

        if (bills.isEmpty)
          EmptyNote(
            _onlyUnpaid
                ? 'Every bill is settled.'
                : 'No bills yet. Raise them above, or close the month.',
          )
        else
          for (final b in bills) _BillCard(key: ValueKey(b.id), bill: b),
      ],
    );

    if (widget.asTab) return body;
    return FarmScaffold(title: 'Khaata bills', showBack: true, body: body);
  }
}

class _BillCard extends StatefulWidget {
  const _BillCard({super.key, required this.bill});

  final Bill bill;

  @override
  State<_BillCard> createState() => _BillCardState();
}

class _BillCardState extends State<_BillCard> {
  bool _busy = false;

  Future<void> _takePayment() async {
    final bill = widget.bill;
    final amount = await _askAmount(bill);
    if (amount == null || !mounted) return;

    final settled = await askSettlement(
      context,
      incoming: true,
      party: bill.customerName,
      amount: amount,
    );
    if (settled == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await BillRepo.takePayment(
        context.read<Session>().actor,
        bill: bill,
        amount: amount,
        payVia: settled.payVia ?? PayVia.cash,
        handledBy: settled.handledBy,
      );
      if (!mounted) return;
      final left = bill.balance - amount;
      toast(
        context,
        left > 0
            ? '${rs(amount)} taken · ${rs(left)} still owing'
            : '${bill.customerName} is fully paid',
      );
    } catch (e) {
      if (mounted) toast(context, 'Could not record it. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Pre-filled with the full balance, because most people pay in full.
  Future<num?> _askAmount(Bill bill) {
    final controller = TextEditingController(text: '${bill.balance.round()}');
    return showModalBottomSheet<num>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: T.pad,
          right: T.pad,
          top: T.pad,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + T.pad,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment from ${bill.customerName}', style: T.screenTitle),
            const SizedBox(height: 4),
            Text('Owing ${rs(bill.balance)}', style: T.meta),
            const SizedBox(height: T.pad),
            Field(
              label: 'Amount taken (Rs)',
              controller: controller,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 6),
            Text(
              'Taking less than the full amount is fine — the rest stays on '
              'their khaata and shows on the next bill.',
              style: T.meta,
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Continue',
              onPressed: () => Navigator.pop(
                sheetContext,
                num.tryParse(controller.text.trim()),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bill;
    return Padding(
      padding: const EdgeInsets.only(bottom: T.gap),
      child: RegCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    b.customerName,
                    style: T.cardTitle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Tag(
                  b.statusLabel,
                  tone: b.isSettled
                      ? TagTone.good
                      : b.isPartPaid
                      ? TagTone.warn
                      : TagTone.bad,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(monthName(b.monthId), style: T.meta),
            const SizedBox(height: 12),
            _Line(
              label: '${qty(b.litres)} L this month',
              value: rs(b.thisMonth),
            ),
            if (b.previousBalance > 0)
              _Line(label: 'Carried over', value: rs(b.previousBalance)),
            const Divider(height: 16),
            _Line(label: 'Bill', value: rs(b.total), strong: true),
            if (b.paid > 0) _Line(label: 'Paid', value: rs(b.paid)),
            if (!b.isSettled)
              _Line(label: 'Still owing', value: rs(b.balance), strong: true),
            if (!b.isSettled) ...[
              const SizedBox(height: 12),
              GhostButton(
                label: 'Take payment',
                icon: Icons.payments_outlined,
                onPressed: _busy ? null : _takePayment,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label, style: strong ? T.cardTitle : T.body)),
        Text(value, style: strong ? T.num22 : T.bodyMid),
      ],
    ),
  );
}
