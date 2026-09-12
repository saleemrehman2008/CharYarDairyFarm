import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/delivery_repo.dart';
import '../../services/order_repo.dart';
import '../../state/round_data.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';

/// The daily milk round, one row per khaata customer.
///
/// Built to be used standing at a gate with one hand: each customer's usual
/// litres are already filled in, so an ordinary day is a single tap per house,
/// and only the exceptions need typing.
class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({super.key, this.asTab = false});

  /// True when a root already provides the chrome, as it does for staff.
  final bool asTab;

  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen> {
  DateTime _day = DateTime.now();

  /// Which round is on screen. Nothing is locked to the clock: a customer
  /// missed in the morning is marked from the morning list at nine at night,
  /// and the day still reads correctly afterwards.
  String _slot = DateTime.now().hour >= 12 ? 'evening' : 'morning';

  bool get _isToday {
    final now = DateTime.now();
    return _day.year == now.year &&
        _day.month == now.month &&
        _day.day == now.day;
  }

  void _shiftDay(int days) {
    final next = _day.add(Duration(days: days));
    // The round cannot be done in advance.
    if (next.isAfter(DateTime.now())) return;
    setState(() => _day = next);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RoundData>();
    final customers = store.khaataCustomers;
    final dayKey = Delivery.dayKey(_day);
    final marked = {
      for (final d in store.monthDeliveries)
        if (Delivery.dayKey(d.date) == dayKey) d.customerId: d,
    };

    bool inSlot(String slot, String theirs) =>
        (theirs == 'evening') == (slot == 'evening');

    // One list of doors, not two. The rider walks a street, not a category —
    // so a khaata house and an order house sit in the same list, in name
    // order, each saying which it is and what has to be collected.
    List<_Stop> stopsIn(String slot) => <_Stop>[
      for (final c in customers)
        if (inSlot(slot, c.slot))
          _Stop(name: c.name, account: c, delivery: marked[c.uid]),
      for (final o in store.roundOrders)
        if (o.dueOn(dayKey) && inSlot(slot, o.slot))
          _Stop(name: o.customerName, order: o),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final stops = stopsIn(_slot);
    final left = stops.where((x) => !x.done(dayKey)).length;

    // What has to come back in the rider's pocket. Khaata milk is billed at
    // month end, so only orders are counted.
    final toCollect = stops
        .where((x) => !x.done(dayKey))
        .fold<num>(0, (a, x) => a + (x.order?.toCollectOn(dayKey) ?? 0));

    final litres = marked.values.fold<num>(0, (a, d) => a + d.litres);
    final amount = marked.values.fold<num>(0, (a, d) => a + d.amount);

    int leftIn(String slot) =>
        stopsIn(slot).where((x) => !x.done(dayKey)).length;

    final body = PageBody(
      children: [
        RegCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => _shiftDay(-1),
                    icon: const Icon(Icons.chevron_left, size: 20),
                    tooltip: 'Previous day',
                  ),
                  Expanded(
                    child: Text(
                      _isToday ? 'Today · ${fmtDate(_day)}' : fmtDateFull(_day),
                      textAlign: TextAlign.center,
                      style: T.cardTitle,
                    ),
                  ),
                  IconButton(
                    onPressed: _isToday ? null : () => _shiftDay(1),
                    icon: const Icon(Icons.chevron_right, size: 20),
                    tooltip: 'Next day',
                  ),
                ],
              ),
              const Divider(height: 16),
              Text(
                '${marked.length} khaata houses done · ${qty(litres)} L · '
                '${rs(amount)}',
                style: T.meta,
              ),
              if (toCollect > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '${rs(toCollect)} still to collect from orders',
                  style: T.bodyMid.copyWith(color: T.accent800),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: T.pad),

        // Two rounds a day, so two lists. Either can be opened at any hour —
        // the morning list is where a morning customer is marked off, even if
        // it is being done in the evening.
        Segmented<String>(
          value: _slot,
          options: [
            ('morning', 'Morning ${_count(leftIn('morning'))}'),
            ('evening', 'Evening ${_count(leftIn('evening'))}'),
          ],
          onChanged: (v) => setState(() => _slot = v),
        ),
        const SizedBox(height: 6),
        Text(
          left == 0
              ? 'This round is done.'
              : '$left still to go on the $_slot round.',
          style: T.meta,
        ),
        const SizedBox(height: T.pad),

        if (stops.isEmpty)
          const EmptyNote(
            'Nothing on this round. Khaata customers appear here every day '
            'once a co-founder approves them, and shop orders appear on the '
            'days the customer asked for.',
          )
        else
          for (final stop in stops)
            if (stop.account != null)
              _RoundRow(
                key: ValueKey('${stop.account!.uid}_$dayKey'),
                account: stop.account!,
                delivery: stop.delivery,
                day: _day,
              )
            else
              _OrderRow(
                key: ValueKey('${stop.order!.id}_$dayKey'),
                order: stop.order!,
                dayKey: dayKey,
              ),
      ],
    );

    if (widget.asTab) return body;
    return FarmScaffold(title: 'Daily round', showBack: true, body: body);
  }

  /// "· 3 left", or nothing at all when the round is clear.
  static String _count(int left) => left == 0 ? '' : '· $left';
}

/// One door on the round: either a khaata house or a shop order.
class _Stop {
  const _Stop({required this.name, this.account, this.delivery, this.order});

  final String name;
  final UdhaarAccount? account;
  final Delivery? delivery;
  final FarmOrder? order;

  bool done(String dayKey) =>
      account != null ? delivery != null : order!.deliveredOn(dayKey);
}

/// One shop order on the round, for one of its days.
///
/// A week's order shows up here every day it was ordered for, and each day is
/// delivered and paid for on its own.
class _OrderRow extends StatefulWidget {
  const _OrderRow({super.key, required this.order, required this.dayKey});

  final FarmOrder order;
  final String dayKey;

  @override
  State<_OrderRow> createState() => _OrderRowState();
}

class _OrderRowState extends State<_OrderRow> {
  bool _busy = false;

  Future<void> _deliver() async {
    final o = widget.order;
    final settlement = o.isUdhaar
        ? const Settlement(payVia: PayVia.cash, handledBy: '')
        : await askSettlement(
            context,
            incoming: true,
            party: o.customerName,
            amount: o.amountOn(widget.dayKey),
            allowUnpaid: true,
          );
    if (settlement == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await OrderRepo.deliverDay(
        context.read<Session>().actor,
        o,
        dayKey: widget.dayKey,
        collected: !o.isUdhaar && settlement.collected,
        payVia: settlement.payVia ?? PayVia.cash,
        handledBy: settlement.handledBy,
      );
      if (mounted) toast(context, '#${o.number} delivered');
    } catch (e) {
      if (mounted) toast(context, 'Could not save it. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final which = o.dayLabel(widget.dayKey);

    return Padding(
      padding: const EdgeInsets.only(bottom: T.gap),
      child: RegCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    o.customerName,
                    style: T.cardTitle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Tag('Order #${o.number}', tone: TagTone.warn),
              ],
            ),
            const SizedBox(height: 2),
            Text(o.itemsTextOn(widget.dayKey), style: T.body),
            if (which.isNotEmpty) Text(which, style: T.meta),
            const SizedBox(height: 8),

            // The one thing the rider must not get wrong: an order is paid at
            // the door, a khaata order is not.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: o.isUdhaar ? Colors.transparent : T.accent100,
                border: T.hair,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.isUdhaar
                        ? 'Nothing to collect'
                        : 'Collect ${rs(o.amountOn(widget.dayKey))}',
                    style: T.bodyMid.copyWith(
                      color: o.isUdhaar ? T.n700 : T.accent800,
                    ),
                  ),
                  Text(
                    o.isUdhaar
                        ? 'Goes on their khaata — billed at month end'
                        : o.pay.short,
                    style: T.meta,
                  ),
                ],
              ),
            ),
            if (o.address.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('${o.address} · ${o.mobile}', style: T.meta),
            ],
            const SizedBox(height: 10),
            GhostButton(
              label: 'Delivered',
              icon: Icons.check,
              compact: true,
              onPressed: _busy ? null : _deliver,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundRow extends StatefulWidget {
  const _RoundRow({
    super.key,
    required this.account,
    required this.delivery,
    required this.day,
  });

  final UdhaarAccount account;
  final Delivery? delivery;
  final DateTime day;

  @override
  State<_RoundRow> createState() => _RoundRowState();
}

class _RoundRowState extends State<_RoundRow> {
  late final TextEditingController _litres = TextEditingController(
    text: qty(widget.delivery?.litres ?? widget.account.litresPerDay),
  );
  bool _busy = false;

  @override
  void dispose() {
    _litres.dispose();
    super.dispose();
  }

  bool get _delivered => widget.delivery != null;

  Future<void> _save({required bool clear}) async {
    final litres = clear ? 0 : (num.tryParse(_litres.text.trim()) ?? 0);
    if (!clear && litres <= 0) {
      toast(context, 'How many litres?');
      return;
    }
    // An account approved before rates existed has none, and the milk would be
    // recorded at zero. Better to stop than to bill nothing.
    if (!clear && widget.account.rate <= 0) {
      toast(
        context,
        'Set ${widget.account.name}\'s rate first — Khaata registrations.',
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await DeliveryRepo.mark(
        context.read<Session>().actor,
        widget.account,
        litres: litres,
        date: widget.day,
      );
      if (!mounted) return;
      // On the last day of the month marking a delivery also raises that
      // customer's bill, so say so — the delivery man should know the customer
      // has just been told what they owe.
      final lastDay = !clear && isLastDayOfMonth(widget.day);
      toast(
        context,
        clear
            ? '${widget.account.name} cleared'
            : lastDay
            ? '${widget.account.name} · ${qty(litres)} L · bill raised'
            : '${widget.account.name} · ${qty(litres)} L',
      );
    } catch (e) {
      if (mounted) toast(context, 'Could not save it. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    final litres = num.tryParse(_litres.text.trim()) ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: T.gap),
      child: RegCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    a.name,
                    style: T.cardTitle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Tag('Khaata', tone: TagTone.neutral),
                const SizedBox(width: 6),
                if (_delivered)
                  const Tag('Delivered', tone: TagTone.good)
                else
                  const Tag('Not yet', tone: TagTone.neutral),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              a.rate <= 0
                  ? 'No rate set · usually ${qty(a.litresPerDay)} L · '
                        'nothing to collect, billed at month end'
                  : '${rs(a.rate)} / L · usually ${qty(a.litresPerDay)} L · '
                        'nothing to collect, billed at month end',
              style: T.meta.copyWith(color: a.rate <= 0 ? T.alert : T.n700),
            ),
            if (a.rate <= 0) ...[
              const SizedBox(height: 4),
              Text(
                'Set a rate in Khaata registrations before delivering, or this '
                'milk is billed at nothing.',
                style: T.meta.copyWith(color: T.alert),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 92,
                  child: Field(
                    label: 'Litres',
                    controller: _litres,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      litres > 0 ? rs(litres * a.rate) : '',
                      style: T.bodyMid,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: GhostButton(
                    label: _delivered ? 'Update' : 'Delivered',
                    icon: _delivered ? null : Icons.check,
                    compact: true,
                    onPressed: _busy ? null : () => _save(clear: false),
                  ),
                ),
              ],
            ),
            if (_delivered) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'by ${widget.delivery!.deliveredByName}',
                      style: T.meta,
                    ),
                  ),
                  GhostButton(
                    label: 'Not delivered',
                    compact: true,
                    danger: true,
                    onPressed: _busy ? null : () => _save(clear: true),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
