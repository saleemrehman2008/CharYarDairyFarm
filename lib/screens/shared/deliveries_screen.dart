import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/delivery_repo.dart';
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
    final today = {
      for (final d in store.monthDeliveries)
        if (Delivery.dayKey(d.date) == dayKey) d.customerId: d,
    };

    final morning = customers.where((c) => c.slot != 'evening').toList();
    final evening = customers.where((c) => c.slot == 'evening').toList();
    final done = customers.where((c) => today.containsKey(c.uid)).length;
    final litres = today.values.fold<num>(0, (a, d) => a + d.litres);
    final amount = today.values.fold<num>(0, (a, d) => a + d.amount);

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
                '$done of ${customers.length} delivered · ${qty(litres)} L · '
                '${rs(amount)}',
                style: T.meta,
              ),
            ],
          ),
        ),
        const SizedBox(height: T.pad),

        if (customers.isEmpty)
          const EmptyNote(
            'No khaata customers yet. Once someone registers and a co-founder '
            'approves them, they appear here every day.',
          ),

        if (morning.isNotEmpty) ...[
          const SectionTitle('Morning 6–9'),
          for (final c in morning)
            _RoundRow(
              key: ValueKey('${c.uid}_$dayKey'),
              account: c,
              delivery: today[c.uid],
              day: _day,
            ),
          const SizedBox(height: 10),
        ],

        if (evening.isNotEmpty) ...[
          const SectionTitle('Evening 5–8'),
          for (final c in evening)
            _RoundRow(
              key: ValueKey('${c.uid}_$dayKey'),
              account: c,
              delivery: today[c.uid],
              day: _day,
            ),
        ],
      ],
    );

    if (widget.asTab) return body;
    return FarmScaffold(title: 'Daily round', showBack: true, body: body);
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
                        'owes ${rs(a.balance)}'
                  : '${rs(a.rate)} / L · usually ${qty(a.litresPerDay)} L · '
                        'owes ${rs(a.balance)}',
              style: T.meta.copyWith(
                color: a.rate <= 0 ? const Color(0xFF8C2F20) : T.n700,
              ),
            ),
            if (a.rate <= 0) ...[
              const SizedBox(height: 4),
              Text(
                'Set a rate in Khaata registrations before delivering, or this '
                'milk is billed at nothing.',
                style: T.meta.copyWith(color: const Color(0xFF8C2F20)),
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
