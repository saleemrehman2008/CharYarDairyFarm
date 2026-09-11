import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/tokens.dart';
import '../util/money.dart';
import 'ui.dart';

/// The order card used on Orders, Approvals and the customer's My orders.
/// Pass no callbacks and it renders read-only, which is what customers see.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    this.onApprove,
    this.onAdvance,
    this.busy = false,
  });

  final FarmOrder order;
  final VoidCallback? onApprove;
  final VoidCallback? onAdvance;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final needsApproval = order.status == OrderStatus.newOrder;
    final canApprove = needsApproval && !order.isApproved && onApprove != null;
    final advanceLabel = order.status.advanceLabel;
    final canAdvance =
        onAdvance != null &&
        advanceLabel != null &&
        (order.isApproved || !needsApproval);

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
                    '#${order.number} · ${order.customerName}',
                    style: T.cardTitle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Tag(order.status.label, tone: _tone(order.status)),
              ],
            ),
            const SizedBox(height: 6),
            Text(order.itemsText, style: T.body),
            const SizedBox(height: 4),
            Text(
              '${order.modeLabel} · ${order.slotLabel} · '
              '${order.pay.short} · ${rs(order.total)}',
              style: T.meta,
            ),
            const SizedBox(height: 10),
            StepBar(step: order.status.step),
            const SizedBox(height: 8),
            Text(
              order.isApproved
                  ? 'Approved by ${order.approvedByName ?? 'a co-founder'}'
                  : 'Awaiting approval · all co-founders notified',
              style: T.meta.copyWith(
                color: order.isApproved ? T.n600 : T.accent700,
              ),
            ),
            if (canApprove || canAdvance) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (canApprove)
                    GhostButton(
                      label: 'Approve',
                      icon: Icons.check,
                      onPressed: busy ? null : onApprove,
                    ),
                  if (canApprove && canAdvance) const SizedBox(width: 8),
                  if (canAdvance)
                    GhostButton(
                      label: advanceLabel,
                      onPressed: busy ? null : onAdvance,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static TagTone _tone(OrderStatus s) => switch (s) {
    OrderStatus.newOrder => TagTone.warn,
    OrderStatus.preparing => TagTone.accent,
    OrderStatus.out => TagTone.accent,
    OrderStatus.delivered => TagTone.good,
    OrderStatus.cancelled => TagTone.bad,
  };
}
