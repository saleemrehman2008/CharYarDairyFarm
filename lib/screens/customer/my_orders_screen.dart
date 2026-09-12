import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/order_repo.dart';
import '../../state/customer_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/order_card.dart';
import '../../widgets/ui.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  String? _busyId;

  /// A customer may call off an order the farm has not started on yet. Once a
  /// co-founder has approved it the milk is being got ready, so that becomes a
  /// phone call rather than a button.
  Future<void> _cancel(FarmOrder order) async {
    final ok = await confirm(
      context,
      title: 'Cancel order #${order.number}?',
      body: '${order.itemsText}\n\nThe farm will not prepare it.',
      confirmLabel: 'Cancel it',
    );
    if (!ok || !mounted) return;

    setState(() => _busyId = order.id);
    try {
      await OrderRepo.cancel(context.read<Session>().actor, order);
      if (mounted) toast(context, 'Order #${order.number} cancelled');
    } catch (e) {
      if (mounted) toast(context, 'Could not cancel it. $e');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  OrderFilter _filter = OrderFilter.pending;

  @override
  Widget build(BuildContext context) {
    final all = context.watch<CustomerStore>().orders;
    final orders = _filter.apply(all);

    return PageBody(
      children: [
        Segmented<OrderFilter>(
          value: _filter,
          options: [for (final f in OrderFilter.values) (f, f.label)],
          onChanged: (v) => setState(() => _filter = v),
        ),
        const SizedBox(height: T.pad),
        if (orders.isEmpty)
          EmptyNote(switch (_filter) {
            OrderFilter.pending =>
              all.isEmpty
                  ? 'No orders yet. Your first one will show up here.'
                  : 'Nothing on its way right now.',
            OrderFilter.completed => 'Nothing delivered yet.',
            OrderFilter.all =>
              'No orders yet. Your first one will show up here.',
          })
        else
          for (final o in orders)
            OrderCard(
              order: o,
              busy: _busyId == o.id,
              onCancel: () => _cancel(o),
            ),
      ],
    );
  }
}
