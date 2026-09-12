import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/staff_store.dart';
import '../../theme/tokens.dart';
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
  OrderFilter _filter = OrderFilter.pending;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StaffStore>();
    final orders = _filter.apply(store.allOpenOrdersAndDone);
    final waiting = store.allOpenOrders.where((o) => !o.isApproved).length;

    return PageBody(
      children: [
        Text(
          'What is coming. Milk is marked delivered on the round, where the '
          'day and the money are.',
          style: T.meta,
        ),
        const SizedBox(height: 10),
        Segmented<OrderFilter>(
          value: _filter,
          options: [for (final f in OrderFilter.values) (f, f.label)],
          onChanged: (v) => setState(() => _filter = v),
        ),
        if (waiting > 0) ...[
          const SizedBox(height: 8),
          Text(
            '$waiting ${waiting == 1 ? 'order is' : 'orders are'} waiting for '
            'a co-founder to approve. They reach the round after that.',
            style: T.meta.copyWith(color: T.accent800),
          ),
        ],
        const SizedBox(height: T.pad),
        if (orders.isEmpty)
          const EmptyNote('Nothing here.')
        else
          for (final o in orders)
            OrderCard(order: o, busy: _busyId == o.id, showAddress: true),
      ],
    );
  }
}
