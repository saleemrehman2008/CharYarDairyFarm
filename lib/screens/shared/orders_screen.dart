import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/links.dart';
import '../../services/order_repo.dart';
import '../../services/udhaar_repo.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/order_card.dart';
import '../../widgets/ui.dart';

enum OrderFilter { all, open, fresh }

/// Orders for the master; the same list is the co-founder's Approvals tab.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, this.showUdhaarRequests = false});

  /// The co-founder's Approvals tab also lists udhaar registrations.
  final bool showUdhaarRequests;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  OrderFilter _filter = OrderFilter.all;
  String? _busyId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final orders = switch (_filter) {
      OrderFilter.all => store.orders,
      OrderFilter.open => store.openOrders,
      OrderFilter.fresh =>
        store.orders.where((o) => o.status == OrderStatus.newOrder).toList(),
    };

    return PageBody(
      children: [
        Segmented<OrderFilter>(
          value: _filter,
          options: const [
            (OrderFilter.all, 'All'),
            (OrderFilter.open, 'Open'),
            (OrderFilter.fresh, 'New'),
          ],
          onChanged: (v) => setState(() => _filter = v),
        ),
        const SizedBox(height: T.pad),

        if (widget.showUdhaarRequests && store.pendingUdhaar.isNotEmpty) ...[
          const SectionTitle('Khaata registrations'),
          for (final u in store.pendingUdhaar) _UdhaarRequestCard(account: u),
          const SizedBox(height: 10),
          const SectionTitle('Orders'),
        ],

        if (orders.isEmpty)
          const EmptyNote('No orders here yet.')
        else
          for (final o in orders)
            OrderCard(
              order: o,
              busy: _busyId == o.id,
              onApprove: () => _run(o, approve: true),
              onAdvance: () => _run(o, approve: false),
            ),
      ],
    );
  }

  Future<void> _run(FarmOrder order, {required bool approve}) async {
    final actor = context.read<Session>().actor;
    final store = context.read<FarmStore>();
    setState(() => _busyId = order.id);
    try {
      if (approve) {
        await OrderRepo.approve(actor, order);
        if (!mounted) return;
        toast(context, 'Order #${order.number} approved');
        await _offerWhatsApp(order, store);
      } else {
        final label = order.status.next?.label ?? '';
        await OrderRepo.advance(actor, order);
        if (!mounted) return;
        toast(context, 'Order #${order.number} · ${label.toLowerCase()}');
      }
    } catch (e) {
      if (mounted) toast(context, 'Could not update the order. $e');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// The approver is offered a WhatsApp message for the customer and the other
  /// co-founders; push notifications go out from Cloud Functions regardless.
  Future<void> _offerWhatsApp(FarmOrder order, FarmStore store) async {
    final numbers = store.settings.whatsappNumbers;
    if (numbers.isEmpty || !mounted) return;

    final send = await confirm(
      context,
      title: 'Tell the others on WhatsApp?',
      body:
          'Opens WhatsApp with a ready message about order '
          '#${order.number}.',
      confirmLabel: 'Open WhatsApp',
    );
    if (!send) return;

    await Links.whatsapp(
      numbers.first,
      'Order #${order.number} for ${order.customerName} is approved.\n'
      '${order.itemsText}\n'
      '${order.modeLabel} · ${order.slotLabel}',
    );
  }
}

class _UdhaarRequestCard extends StatelessWidget {
  const _UdhaarRequestCard({required this.account});

  final UdhaarAccount account;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: T.gap),
    child: RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(account.name, style: T.cardTitle)),
              Tag(account.status.label, tone: TagTone.warn),
            ],
          ),
          const SizedBox(height: 6),
          Text(account.address, style: T.body),
          const SizedBox(height: 4),
          Text(
            '${account.mobile} · ${account.slotLabel} · '
            '${account.litresPerDay} L/day · limit Rs ${account.limit}',
            style: T.meta,
          ),
          const SizedBox(height: 10),
          Text(
            'Awaiting approval · all co-founders notified',
            style: T.meta.copyWith(color: T.accent700),
          ),
          const SizedBox(height: 12),
          _ApproveUdhaarButton(account: account),
        ],
      ),
    ),
  );
}

class _ApproveUdhaarButton extends StatefulWidget {
  const _ApproveUdhaarButton({required this.account});

  final UdhaarAccount account;

  @override
  State<_ApproveUdhaarButton> createState() => _ApproveUdhaarButtonState();
}

class _ApproveUdhaarButtonState extends State<_ApproveUdhaarButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => GhostButton(
    label: 'Approve khaata',
    icon: Icons.check,
    onPressed: _busy ? null : _approve,
  );

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      final actor = context.read<Session>().actor;
      await UdhaarRepo.approve(actor, widget.account);
      if (mounted) {
        toast(context, '${widget.account.name} now has a khaata');
      }
    } catch (e) {
      if (mounted) toast(context, 'Could not approve. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
