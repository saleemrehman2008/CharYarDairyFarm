import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/db.dart';
import '../../services/rider_repo.dart';
import '../../state/session.dart';
import '../../state/staff_store.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';

/// The rider's day on one page: what to load, what was sold at the roadside,
/// and what has to be handed in at the end.
///
/// Two lines have to close before the day does — the milk and the money — and
/// both are added up as the round happens rather than remembered afterwards.
class RiderDayScreen extends StatelessWidget {
  const RiderDayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StaffStore>();
    final uid = context.watch<Session>().user?.uid ?? '';
    final dayKey = dayKeyOf(DateTime.now());

    return StreamBuilder<RiderDay?>(
      stream: Db.watchRiderDay(uid, dayKey),
      builder: (context, snap) {
        final day = snap.data;
        return PageBody(
          children: [
            _LoadCard(day: day, store: store, dayKey: dayKey),
            const SizedBox(height: T.pad),
            _SpotCard(store: store, dayKey: dayKey),
            const SizedBox(height: T.pad),
            _HandoverCard(day: day, store: store, dayKey: dayKey),
          ],
        );
      },
    );
  }
}

/// What today's round needs, and what the rider actually took.
class _LoadCard extends StatefulWidget {
  const _LoadCard({
    required this.day,
    required this.store,
    required this.dayKey,
  });

  final RiderDay? day;
  final StaffStore store;
  final String dayKey;

  @override
  State<_LoadCard> createState() => _LoadCardState();
}

class _LoadCardState extends State<_LoadCard> {
  final _litres = TextEditingController();
  bool _busy = false;
  bool _filled = false;

  @override
  void dispose() {
    _litres.dispose();
    super.dispose();
  }

  List<LoadLine> _sheet(String slot) => RiderRepo.loadSheet(
    khaata: widget.store.khaataCustomers,
    orders: widget.store.roundOrders,
    dayKey: widget.dayKey,
    slot: slot,
  );

  Future<void> _save(num litres) async {
    setState(() => _busy = true);
    try {
      await RiderRepo.setLoad(
        context.read<Session>().actor,
        dayKey: widget.dayKey,
        litres: litres,
      );
      if (mounted) toast(context, '${qty(litres)} L noted');
    } catch (e) {
      if (mounted) toast(context, 'Could not save it. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final morning = _sheet('morning');
    final evening = _sheet('evening');
    final needed =
        morning.fold<num>(0, (a, l) => a + l.total) +
        evening.fold<num>(0, (a, l) => a + l.total);

    final loaded = widget.day?.loadedLitres ?? 0;
    if (!_filled && loaded > 0) {
      _litres.text = qty(loaded);
      _filled = true;
    }

    final typed = num.tryParse(_litres.text.trim()) ?? 0;

    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Kicker('Today\'s load')),
              if (loaded > 0) Tag('${qty(loaded)} L out', tone: TagTone.accent),
            ],
          ),
          const SizedBox(height: 8),
          Text(qty(needed), style: T.num30),
          const SizedBox(height: 2),
          Text('litres the round needs', style: T.meta),

          if (morning.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Kicker('Morning'),
            for (final l in morning) _LoadRow(line: l),
          ],
          if (evening.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Kicker('Evening'),
            for (final l in evening) _LoadRow(line: l),
          ],
          if (morning.isEmpty && evening.isEmpty) ...[
            const SizedBox(height: 8),
            Text('Nothing on the round today.', style: T.meta),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Field(
            label: 'Litres you are taking',
            controller: _litres,
            keyboardType: TextInputType.number,
            hint: qty(needed),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 5),
          Text(
            typed > needed && needed > 0
                ? 'That is ${qty(typed - needed)} L more than the round needs. '
                      'Sell it on the way or bring it back.'
                : 'Take extra if you want — sell it on the way, or bring it '
                      'back at the end.',
            style: T.meta,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: loaded > 0 ? 'Change it' : 'Loaded',
                  busy: _busy,
                  onPressed: typed > 0 ? () => _save(typed) : null,
                ),
              ),
              if (needed > 0 && typed != needed) ...[
                const SizedBox(width: 8),
                GhostButton(
                  label: 'Just ${qty(needed)}',
                  compact: true,
                  onPressed: _busy
                      ? null
                      : () {
                          _litres.text = qty(needed);
                          setState(() {});
                        },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadRow extends StatelessWidget {
  const _LoadRow({required this.line});

  final LoadLine line;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 64,
          child: Text('${qty(line.litres)} L', style: T.bodyMid),
        ),
        Expanded(
          child: Text(
            line.stops == 1 ? '1 stop' : '${line.stops} stops',
            style: T.meta,
          ),
        ),
        Text('${qty(line.total)} L', style: T.bodyMid),
      ],
    ),
  );
}

/// Milk sold at the roadside. No name — just litres, at the shop's rate.
class _SpotCard extends StatefulWidget {
  const _SpotCard({required this.store, required this.dayKey});

  final StaffStore store;
  final String dayKey;

  @override
  State<_SpotCard> createState() => _SpotCardState();
}

class _SpotCardState extends State<_SpotCard> {
  final _litres = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _litres.dispose();
    super.dispose();
  }

  Future<void> _sell(num litres, num rate) async {
    setState(() => _busy = true);
    try {
      await RiderRepo.spotSale(
        context.read<Session>().actor,
        dayKey: widget.dayKey,
        litres: litres,
        rate: rate,
      );
      if (!mounted) return;
      _litres.clear();
      setState(() {});
      toast(context, '${qty(litres)} L sold · ${rs(litres * rate)} in hand');
    } catch (e) {
      if (mounted) toast(context, 'Could not save it. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rate = widget.store.milkRate;
    final litres = num.tryParse(_litres.text.trim()) ?? 0;

    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Kicker('Spot sale'),
          const SizedBox(height: 6),
          Text(
            'Milk sold to whoever wants it on the road. No name needed — the '
            'cash goes in with the rest at the end of the day.',
            style: T.meta,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 110,
                child: Field(
                  label: 'Litres',
                  controller: _litres,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    litres > 0
                        ? '${rs(litres * rate)}  ·  ${rs(rate)} / L'
                        : '${rs(rate)} / L, the shop rate',
                    style: litres > 0 ? T.num22 : T.meta,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Sold',
            busy: _busy,
            onPressed: litres > 0 && rate > 0
                ? () => _sell(litres, rate)
                : null,
          ),
        ],
      ),
    );
  }
}

/// End of the round: hand in the cash and whatever milk came back.
class _HandoverCard extends StatefulWidget {
  const _HandoverCard({
    required this.day,
    required this.store,
    required this.dayKey,
  });

  final RiderDay? day;
  final StaffStore store;
  final String dayKey;

  @override
  State<_HandoverCard> createState() => _HandoverCardState();
}

class _HandoverCardState extends State<_HandoverCard> {
  final _cash = TextEditingController();
  final _back = TextEditingController();
  String? _to;
  bool _busy = false;
  bool _filled = false;

  @override
  void dispose() {
    _cash.dispose();
    _back.dispose();
    super.dispose();
  }

  Future<void> _hand(FarmPerson founder) async {
    setState(() => _busy = true);
    try {
      await RiderRepo.handOver(
        context.read<Session>().actor,
        dayKey: widget.dayKey,
        cash: num.tryParse(_cash.text.trim()) ?? 0,
        returnedLitres: num.tryParse(_back.text.trim()) ?? 0,
        toUid: founder.uid,
        toName: founder.name,
      );
      if (mounted) toast(context, 'Given to ${founder.name} — waiting on them');
    } catch (e) {
      if (mounted) toast(context, 'Could not save it. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final founders = widget.store.founders;

    if (day == null || day.isEmpty) {
      return RegCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Kicker('Hand in'),
            const SizedBox(height: 6),
            Text(
              'Nothing to hand in yet. This fills itself in as the round goes.',
              style: T.meta,
            ),
          ],
        ),
      );
    }

    if (day.isClosed) {
      return RegCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Kicker('Handed in')),
                const Tag('Done', tone: TagTone.good),
              ],
            ),
            const SizedBox(height: 8),
            Text(rs(day.receivedCash), style: T.num28),
            const SizedBox(height: 4),
            Text(
              'Taken in by ${day.receivedByName ?? 'a co-founder'}'
              '${day.receivedLitres > 0 ? ' with ${qty(day.receivedLitres)} L back' : ''}',
              style: T.meta,
            ),
          ],
        ),
      );
    }

    if (!_filled) {
      _cash.text = day.cashInHand.round().toString();
      final left = day.milkUnaccounted;
      if (left > 0) _back.text = qty(left);
      _filled = true;
    }

    final handing = num.tryParse(_cash.text.trim()) ?? 0;
    final back = num.tryParse(_back.text.trim()) ?? 0;
    final unaccounted =
        day.loadedLitres - day.deliveredLitres - day.spotLitres - back;

    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Kicker('The day so far')),
              Tag(
                day.status.label,
                tone: day.isWaiting ? TagTone.warn : TagTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 10),

          _Line('Took out', '${qty(day.loadedLitres)} L'),
          _Line('Delivered', '${qty(day.deliveredLitres)} L'),
          if (day.spotLitres > 0)
            _Line(
              'Sold on the road',
              '${qty(day.spotLitres)} L · ${rs(day.spotCash)}',
            ),
          const Divider(height: 18),
          _Line('Cash in your hand', rs(day.cashInHand), strong: true),

          if (day.isWaiting) ...[
            const SizedBox(height: 12),
            Text(
              'Given to ${day.handedToName ?? 'a co-founder'} — waiting for '
              'them to take it in.',
              style: T.meta.copyWith(color: T.accent800),
            ),
            const SizedBox(height: 10),
            GhostButton(
              label: 'Take it back',
              compact: true,
              onPressed: _busy
                  ? null
                  : () async {
                      await RiderRepo.cancelHandover(
                        context.read<Session>().actor,
                        day,
                      );
                      if (context.mounted) setState(() => _filled = false);
                    },
            ),
          ] else ...[
            const SizedBox(height: 14),
            Field(
              label: 'Cash you are handing over',
              controller: _cash,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: T.gap),
            Field(
              label: 'Milk coming back (litres)',
              controller: _back,
              keyboardType: TextInputType.number,
              hint: '0',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            if (unaccounted.abs() >= 0.001)
              Text(
                unaccounted > 0
                    ? '${qty(unaccounted)} L is not accounted for. Check the '
                          'round, the spot sales and what you are bringing back.'
                    : '${qty(-unaccounted)} L more than you took out. Check '
                          'the numbers.',
                style: T.meta.copyWith(color: T.alert),
              )
            else
              Text('The milk adds up.', style: T.meta.copyWith(color: T.done)),
            if (handing != day.cashInHand) ...[
              const SizedBox(height: 4),
              Text(
                handing < day.cashInHand
                    ? '${rs(day.cashInHand - handing)} stays with you.'
                    : '${rs(handing - day.cashInHand)} more than the round '
                          'took. Check it.',
                style: T.meta.copyWith(color: T.alert),
              ),
            ],
            const SizedBox(height: 14),
            const Kicker('Give it to'),
            const SizedBox(height: 6),
            if (founders.isEmpty)
              Text(
                'No co-founder to hand to yet.',
                style: T.meta.copyWith(color: T.alert),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in founders)
                    _Pick(
                      label: f.name,
                      on: _to == f.uid,
                      onTap: () => setState(() => _to = f.uid),
                    ),
                ],
              ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Hand over',
              busy: _busy,
              onPressed: _to == null || founders.isEmpty
                  ? null
                  : () => _hand(founders.firstWhere((f) => f.uid == _to)),
            ),
            const SizedBox(height: 6),
            Text(
              'It stays yours until they take it in on their own phone.',
              style: T.meta,
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.strong = false});

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

class _Pick extends StatelessWidget {
  const _Pick({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: on ? T.fill : Colors.transparent,
        border: Border.all(color: on ? T.fill : T.divider),
      ),
      child: Text(label, style: T.body.copyWith(color: on ? T.onFill : T.n800)),
    ),
  );
}
