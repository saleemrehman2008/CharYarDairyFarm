import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/order_repo.dart';
import '../../state/customer_store.dart';
import '../../state/session.dart';
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

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<CustomerStore>().orders;

    return PageBody(
      children: [
        if (orders.isEmpty)
          const EmptyNote('No orders yet. Your first one will show up here.')
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
