import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/customer_store.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/order_card.dart';
import '../../widgets/ui.dart';

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<CustomerStore>().orders;

    return PageBody(
      children: [
        if (orders.isEmpty)
          const EmptyNote('No orders yet. Your first one will show up here.')
        else
          for (final o in orders) OrderCard(order: o),
      ],
    );
  }
}
