import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/rider_repo.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';

/// Cash and milk coming back off the round.
///
/// A rider's takings are his responsibility until a co-founder has counted
/// them, so they are kept out of the farm's cash until somebody here says the
/// money is in their hand. What the founder counts is what is recorded — not
/// what the rider said.
class HandoversScreen extends StatelessWidget {
  const HandoversScreen({super.key, this.asTab = false});

  final bool asTab;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final waiting = store.handoversWaiting;
    final out = store.ridersOut;

    final body = PageBody(
      children: [
        RegCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Kicker('Out with the riders'),
              const SizedBox(height: 6),
              Text(rs(store.cashWithRiders), style: T.num28),
              const SizedBox(height: 4),
              Text(
                'Taken at doors and not handed in yet. This is not counted as '
                'the farm\'s cash — it is in somebody\'s pocket.',
                style: T.meta,
              ),
              if (store.milkWithRiders > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '${qty(store.milkWithRiders)} L still unaccounted for on the '
                  'road',
                  style: T.meta.copyWith(color: T.alert),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: T.pad),

        if (waiting.isEmpty && out.isEmpty)
          const EmptyNote('Nothing out on the road.'),

        if (waiting.isNotEmpty) ...[
          const SectionTitle('Waiting for you'),
          for (final d in waiting) _HandoverCard(key: ValueKey(d.id), day: d),
          const SizedBox(height: 10),
        ],

        if (out.isNotEmpty) ...[
          const SectionTitle('Still on the round'),
          for (final d in out) _OutRow(day: d),
        ],
      ],
    );

    if (asTab) return body;
    return FarmScaffold(title: 'Handovers', showBack: true, body: body);
  }
}

class _HandoverCard extends StatefulWidget {
  const _HandoverCard({super.key, required this.day});

  final RiderDay day;

  @override
  State<_HandoverCard> createState() => _HandoverCardState();
}

class _HandoverCardState extends State<_HandoverCard> {
  late final _cash = TextEditingController(
    text: widget.day.handedCash.round().toString(),
  );
  late final _litres = TextEditingController(
    text: widget.day.returnedLitres > 0 ? qty(widget.day.returnedLitres) : '0',
  );
  bool _busy = false;

  @override
  void dispose() {
    _cash.dispose();
    _litres.dispose();
    super.dispose();
  }

  Future<void> _receive(num cash, num litres) async {
    final d = widget.day;
    final ok = await confirm(
      context,
      title: 'Take in ${rs(cash)}?',
      body: cash == d.handedCash
          ? 'From ${d.riderName}. It goes into the farm\'s cash now.'
          : '${d.riderName} said ${rs(d.handedCash)}. Recording ${rs(cash)} — '
                'the difference stays against their name.',
      confirmLabel: 'Received',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await RiderRepo.receive(
        context.read<Session>().actor,
        d,
        cash: cash,
        litres: litres,
      );
      if (mounted) toast(context, '${rs(cash)} taken in from ${d.riderName}');
    } catch (e) {
      if (mounted) toast(context, 'Could not save it. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.day;
    final cash = num.tryParse(_cash.text.trim()) ?? 0;
    final litres = num.tryParse(_litres.text.trim()) ?? 0;
    final gap = d.loadedLitres - d.deliveredLitres - d.spotLitres - litres;

    return Padding(
      padding: const EdgeInsets.only(bottom: T.gap),
      child: RegCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(d.riderName, style: T.cardTitle)),
                Tag(fmtDate(dayFromKey(d.dayKey) ?? d.createdAt)),
              ],
            ),
            const SizedBox(height: 10),

            _Row('Took out', '${qty(d.loadedLitres)} L'),
            _Row('Delivered', '${qty(d.deliveredLitres)} L'),
            if (d.spotLitres > 0)
              _Row(
                'Sold on the road',
                '${qty(d.spotLitres)} L · ${rs(d.spotCash)}',
              ),
            _Row('Says he is bringing back', '${qty(d.returnedLitres)} L'),
            const Divider(height: 18),
            _Row('Says he is handing over', rs(d.handedCash), strong: true),

            const SizedBox(height: 14),
            Text(
              'Count it yourself. What you type is what goes in the books.',
              style: T.meta,
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Field(
                    label: 'Cash you counted',
                    controller: _cash,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Field(
                    label: 'Milk back (L)',
                    controller: _litres,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (gap.abs() >= 0.001)
              Text(
                gap > 0
                    ? '${qty(gap)} L is missing: out ${qty(d.loadedLitres)}, '
                          'delivered ${qty(d.deliveredLitres)}, sold '
                          '${qty(d.spotLitres)}, back ${qty(litres)}.'
                    : '${qty(-gap)} L more than went out. Check it.',
                style: T.meta.copyWith(color: T.alert),
              )
            else
              Text('The milk adds up.', style: T.meta.copyWith(color: T.done)),
            if (cash != d.cashInHand) ...[
              const SizedBox(height: 4),
              Text(
                'The round took ${rs(d.cashInHand)}. '
                '${cash < d.cashInHand ? '${rs(d.cashInHand - cash)} would stay against ${d.riderName}.' : 'This is more than the round took.'}',
                style: T.meta.copyWith(color: T.alert),
              ),
            ],
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Received ${rs(cash)}',
              busy: _busy,
              onPressed: cash > 0 ? () => _receive(cash, litres) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _OutRow extends StatelessWidget {
  const _OutRow({required this.day});

  final RiderDay day;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: T.gap),
    child: RegCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(day.riderName, style: T.cardTitle)),
              Text(rs(day.cashInHand), style: T.bodyMid),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Out ${qty(day.loadedLitres)} L · delivered '
            '${qty(day.deliveredLitres)} L'
            '${day.spotLitres > 0 ? ' · sold ${qty(day.spotLitres)} L' : ''}',
            style: T.meta,
          ),
        ],
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label, style: strong ? T.bodyMid : T.body)),
        Text(value, style: strong ? T.num22 : T.bodyMid),
      ],
    ),
  );
}
