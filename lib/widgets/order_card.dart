import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/tokens.dart';
import '../util/money.dart';
import '../util/phone.dart';
import 'ui.dart';

/// The order card used on Orders, Approvals and the customer's My orders.
/// Pass no callbacks and it renders read-only, which is what customers see.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    this.onApprove,
    this.onAdvance,
    this.onCancel,
    this.busy = false,
    this.showAddress = false,
  });

  final FarmOrder order;
  final VoidCallback? onApprove;
  final VoidCallback? onAdvance;

  /// Offered to the customer while the order is still theirs to call off.
  final VoidCallback? onCancel;

  final bool busy;

  /// The round needs the address; the customer already knows it.
  final bool showAddress;

  @override
  Widget build(BuildContext context) {
    final needsApproval = order.status == OrderStatus.newOrder;
    final canApprove = needsApproval && !order.isApproved && onApprove != null;
    // A week's order is delivered a day at a time, from the round.
    final advanceLabel = order.isMultiDay && order.status == OrderStatus.out
        ? null
        : order.status.advanceLabel;
    final canCancel = onCancel != null && needsApproval && !order.isApproved;
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
            // Which days it is for. Each item has its own, so a week of milk
            // and one kilo of ghee sit on the same order.
            const SizedBox(height: 4),
            Text(
              order.isMultiDay
                  ? '${order.daysText} · '
                        '${order.doneDays.length} of ${order.dayKeys.length} '
                        'delivered'
                  : 'For ${order.daysText}',
              style: T.meta.copyWith(
                color: order.isMultiDay ? T.accent700 : T.n600,
              ),
            ),
            // Where it goes, for whoever is doing the round.
            if (showAddress && order.address.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(order.address, style: T.bodyMid),
              if (order.mobile.isNotEmpty)
                Text(Phone.pretty(order.mobile), style: T.meta),
            ],
            const SizedBox(height: 8),
            // Where the money stands, which is the other half of "where is my
            // order" and the half a customer actually worries about.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: order.isUdhaar
                    ? T.n100
                    : order.leftToPay <= 0
                    ? T.doneWash
                    : T.accent100,
                border: T.hair,
              ),
              child: Text(
                order.isUdhaar
                    ? 'On your khaata — it goes onto the month\'s bill.'
                    : order.paidSoFar <= 0
                    ? '${rs(order.total)} to pay, as each day comes.'
                    : order.leftToPay <= 0
                    ? 'Paid in full · ${rs(order.paidSoFar)}'
                    : '${rs(order.paidSoFar)} paid · '
                          '${rs(order.leftToPay)} still to pay',
                style: T.meta.copyWith(
                  color: order.leftToPay <= 0 && !order.isUdhaar
                      ? T.done
                      : T.n800,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (order.isMultiDay)
              _DayTicks(order: order)
            else
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

            // Only while the farm has not started on it.
            if (canCancel) ...[
              const SizedBox(height: 12),
              GhostButton(
                label: 'Cancel this order',
                compact: true,
                danger: true,
                onPressed: busy ? null : onCancel,
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

/// A tick per day of a multi-day order, so the customer can see which days
/// have come and which are still to come.
class _DayTicks extends StatelessWidget {
  const _DayTicks({required this.order});

  final FarmOrder order;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 5,
    runSpacing: 5,
    children: [
      for (final key in order.dayKeys)
        Builder(
          builder: (_) {
            final done = order.deliveredOn(key);
            final date = dayFromKey(key);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: done ? T.accent100 : Colors.transparent,
                border: Border.all(color: done ? T.accent300 : T.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    done ? Icons.check : Icons.schedule,
                    size: 11,
                    color: done ? T.accent700 : T.n500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    date == null ? key : fmtDate(date),
                    style: T.meta.copyWith(color: done ? T.accent800 : T.n600),
                  ),
                ],
              ),
            );
          },
        ),
    ],
  );
}
