import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/order_repo.dart';
import '../../state/session.dart';
import '../../state/staff_store.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/order_card.dart';
import '../../widgets/ui.dart';

/// The orders a delivery person still has to do something about.
///
/// Only approved and still-open orders appear: an order waiting on a
/// co-founder's approval is not theirs to act on, and a delivered one is done.
class StaffOrdersScreen extends StatefulWidget {
  const StaffOrdersScreen({super.key});

  @override
  State<StaffOrdersScreen> createState() => _StaffOrdersScreenState();
}

class _StaffOrdersScreenState extends State<StaffOrdersScreen> {
  String? _busyId;

  Future<void> _advance(FarmOrder order) async {
    final next = order.status.next;
    if (next == null) return;

    var collected = true;
    var payVia = PayVia.cash;
    var handledBy = '';

    // Delivery is when the money is handed over — ask unless it goes on the
    // customer's khaata.
    if (next == OrderStatus.delivered && !order.isUdhaar) {
      final settled = await askSettlement(
        context,
        incoming: true,
        party: order.customerName,
        amount: order.total,
        allowUnpaid: true,
      );
      if (settled == null || !mounted) return;
      collected = settled.collected;
      payVia = settled.payVia ?? PayVia.cash;
      handledBy = settled.handledBy;
    }

    setState(() => _busyId = order.id);
    try {
      await OrderRepo.advance(
        context.read<Session>().actor,
        order,
        collected: collected,
        payVia: payVia,
        handledBy: handledBy,
      );
      if (!mounted) return;
      toast(
        context,
        next == OrderStatus.delivered && !collected
            ? 'Delivered · ${rs(order.total)} still to collect'
            : 'Order #${order.number} · ${next.label.toLowerCase()}',
      );
    } catch (e) {
      if (mounted) toast(context, 'Could not update the order. $e');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<StaffStore>().openOrders;

    return PageBody(
      children: [
        if (orders.isEmpty)
          const EmptyNote(
            'Nothing to deliver right now. Approved orders appear here.',
          )
        else
          for (final o in orders)
            OrderCard(
              order: o,
              busy: _busyId == o.id,
              onAdvance: () => _advance(o),
            ),
      ],
    );
  }
}
