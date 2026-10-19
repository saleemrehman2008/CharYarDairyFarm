import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/accounting.dart';
import '../../services/contribution_repo.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/ui.dart';

/// The three things a co-founder's own money needs: a way in, a promise to
/// measure it against, and a list of every rupee of it.
///
/// None of these existed. What there was instead was a number on a card that
/// the master typed over, which told nobody when the money came, who took it,
/// or what it paid for — and could be changed without leaving a mark. The
/// farm's own rule now is that no figure moves without a line behind it, and
/// these are where the lines are written and read.
Future<void> showMoneyInSheet(BuildContext context, Partner partner) {
  final store = context.read<FarmStore>();
  return _sheet(context, store, _MoneyInSheet(partner: partner));
}

Future<void> showPledgeSheet(BuildContext context, Partner partner) {
  final store = context.read<FarmStore>();
  return _sheet(context, store, _PledgeSheet(partner: partner));
}

Future<void> showMoneyLines(BuildContext context, Partner partner) {
  final store = context.read<FarmStore>();
  return _sheet(context, store, _LinesSheet(partner: partner));
}

Future<void> _sheet(BuildContext context, FarmStore store, Widget child) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: T.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.radius)),
      ),
      builder: (_) =>
          ChangeNotifierProvider<FarmStore>.value(value: store, child: child),
    );

Widget _grip() => Center(
  child: Container(
    width: 38,
    height: 4,
    decoration: BoxDecoration(
      color: T.n400,
      borderRadius: BorderRadius.circular(T.pill),
    ),
  ),
);

/// Money handed to the farm.
///
/// The other half of how a promise gets paid: part of it goes on cattle and
/// feed directly, and the rest is counted out and handed to whoever keeps the
/// cash. Any amount — what is left of the promise, less than it, or more. The
/// app has no business refusing a man who wants to put more in.
class _MoneyInSheet extends StatefulWidget {
  const _MoneyInSheet({required this.partner});

  final Partner partner;

  @override
  State<_MoneyInSheet> createState() => _MoneyInSheetState();
}

class _MoneyInSheetState extends State<_MoneyInSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _to;
  PayVia _via = PayVia.cash;
  DateTime _day = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _day = picked);
  }

  Future<void> _save() async {
    final l = L.read(context);
    final amount = num.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0) {
      toast(context, l.t('How much went in?'));
      return;
    }
    if (_to == null) {
      toast(context, l.t('Who took the money?'));
      return;
    }
    setState(() => _busy = true);
    try {
      await ContributionRepo.putIn(
        context.read<Session>().actor,
        partner: widget.partner,
        amount: amount,
        source: ContributionSource.cash,
        receivedBy: _to!,
        date: _day,
        payVia: _via,
      );
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, l.t3('%s in from %s', rs(amount), widget.partner.name));
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<FarmStore>();
    final p = widget.partner;
    final amount = num.tryParse(_amount.text.trim()) ?? 0;

    // Everybody the farm has a name for, so the money lands in a pair of
    // hands the cash card already knows about.
    final people = <String, String>{
      for (final x in store.partners) partyKey(x.name): x.name,
    };
    for (final h in cashInHands(store.ledger, putIn: store.contributions)) {
      people.putIfAbsent(partyKey(h.who), () => h.who);
    }
    final names = people.values.toList()..sort();

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(T.pad, 14, T.pad, T.pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _grip(),
              const SizedBox(height: 14),
              Text(l.t2('Money in from %s', p.name), style: T.screenTitle),
              const SizedBox(height: 4),
              Text(
                p.pledged > 0
                    ? l.t3(
                        'He is in for %s and has put in %s.',
                        rs(p.pledged),
                        rs(p.invested),
                      )
                    : l.t2('He has put in %s so far.', rs(p.invested)),
                style: T.meta,
              ),
              const SizedBox(height: T.pad),

              Field(
                label: l.t('How much (Rs)'),
                controller: _amount,
                keyboardType: TextInputType.number,
                hint: '0',
                onChanged: (_) => setState(() {}),
              ),
              if (p.stillToPayIn > 0) ...[
                const SizedBox(height: 7),
                GhostButton(
                  label: l.t2('Fill in %s', rs(p.stillToPayIn)),
                  icon: Icons.south_west,
                  compact: true,
                  onPressed: () {
                    _amount.text = '${p.stillToPayIn.round()}';
                    setState(() {});
                  },
                ),
              ],

              const SizedBox(height: T.pad),
              Kicker(l.t('Who took the money?')),
              const SizedBox(height: 6),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final name in names)
                    _Chip(
                      label: name,
                      selected: name == _to,
                      onTap: () => setState(() => _to = name),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                l.t(
                  'Whoever is keeping the farm\'s cash, usually. It goes '
                  'into their hands on the co-founders page.',
                ),
                style: T.meta,
              ),

              const SizedBox(height: T.pad),
              Kicker(l.t('How')),
              const SizedBox(height: 6),
              Segmented<PayVia>(
                value: _via,
                compact: true,
                options: [for (final v in PayVia.values) (v, l.t(v.label))],
                onChanged: (v) => setState(() => _via = v),
              ),

              const SizedBox(height: T.pad),
              Kicker(l.t('Which day')),
              const SizedBox(height: 6),
              GhostButton(
                label: fmtDateFull(_day),
                icon: Icons.event_outlined,
                compact: true,
                onPressed: _busy ? null : _pickDay,
              ),

              const SizedBox(height: T.gap),
              Field(
                label: l.t('Note'),
                controller: _note,
                hint: l.t('Anything worth remembering'),
              ),

              // What the farm's rule does with it, said rather than asked.
              if (amount > 0) ...[
                const SizedBox(height: T.gap),
                Builder(
                  builder: (context) {
                    final cut = splitByPledge(
                      amount: amount,
                      pledged: p.pledged,
                      alreadyIn: p.invested,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (cut.investment > 0)
                          Text(
                            l.t3(
                              'Put in: %s → %s',
                              rs(p.invested),
                              rs(p.invested + cut.investment),
                            ),
                            style: T.meta.copyWith(color: T.accent700),
                          ),
                        if (cut.refundable > 0)
                          Text(
                            l.t2(
                              'His promise is already paid, so the farm owes '
                              'him %s of this back.',
                              rs(cut.refundable),
                            ),
                            style: T.meta.copyWith(color: T.moneyDue),
                          ),
                      ],
                    );
                  },
                ),
              ],

              const SizedBox(height: T.pad),
              PrimaryButton(
                label: l.t('Save it'),
                icon: Icons.check,
                busy: _busy,
                onPressed: _busy ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What this one is in for.
class _PledgeSheet extends StatefulWidget {
  const _PledgeSheet({required this.partner});

  final Partner partner;

  @override
  State<_PledgeSheet> createState() => _PledgeSheetState();
}

class _PledgeSheetState extends State<_PledgeSheet> {
  late final _amount = TextEditingController(
    text: widget.partner.pledged == 0
        ? ''
        : '${widget.partner.pledged.round()}',
  );
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = L.read(context);
    final amount = num.tryParse(_amount.text.trim()) ?? 0;
    if (amount < 0) return;
    setState(() => _busy = true);
    try {
      await ContributionRepo.setPledge(
        context.read<Session>().actor,
        widget.partner,
        amount,
      );
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, l.t3('%s is in for %s', widget.partner.name, rs(amount)));
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<FarmStore>();
    final p = widget.partner;
    final typed = num.tryParse(_amount.text.trim()) ?? 0;

    // What this promise would make his share, worked out the way a close
    // works it out — because that is the only reason the figure matters.
    final others = store.partners
        .where((x) => x.id != p.id)
        .fold<num>(0, (a, x) => a + x.ratioBase);
    final base = typed > p.invested ? typed : p.invested;
    final total = others + base;
    final share = total <= 0 ? 0.0 : base / total;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(T.pad, 14, T.pad, T.pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _grip(),
              const SizedBox(height: 14),
              Text(l.t2('What %s is in for', p.name), style: T.screenTitle),
              const SizedBox(height: 4),
              Text(
                l.t(
                  'The share is worked out from this, not from what has '
                  'arrived — the four of them chose it that way so a share '
                  'is settled once rather than creeping up with every '
                  'instalment. Raise it and the share moves from today.',
                ),
                style: T.meta,
              ),
              const SizedBox(height: T.pad),

              Field(
                label: l.t('In for (Rs)'),
                controller: _amount,
                keyboardType: TextInputType.number,
                hint: '0',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),

              if (typed > 0) ...[
                Text(
                  l.t3(
                    'Put in %s · still to come %s',
                    rs(p.invested),
                    rs(typed > p.invested ? typed - p.invested : 0),
                  ),
                  style: T.meta,
                ),
                const SizedBox(height: 3),
                Text(
                  l.t3(
                    'His share would be %s%, from %s',
                    (share * 100).toStringAsFixed(1),
                    rs(base),
                  ),
                  style: T.bodyMid.copyWith(color: T.accent700),
                ),
                if (typed < p.invested) ...[
                  const SizedBox(height: 6),
                  Text(
                    l.t2(
                      'He has already put in more than that. The share '
                      'follows his %s, because nobody is given a smaller '
                      'share than his own money is paying for.',
                      rs(p.invested),
                    ),
                    style: T.meta.copyWith(color: T.moneyDue),
                  ),
                ],
              ],

              const SizedBox(height: T.pad),
              PrimaryButton(
                label: l.t('Save it'),
                icon: Icons.check,
                busy: _busy,
                onPressed: _busy ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every rupee one of them has put in, line by line.
class _LinesSheet extends StatefulWidget {
  const _LinesSheet({required this.partner});

  final Partner partner;

  @override
  State<_LinesSheet> createState() => _LinesSheetState();
}

class _LinesSheetState extends State<_LinesSheet> {
  String? _busyId;

  Future<void> _flip(Contribution line) async {
    final l = L.read(context);
    final actor = context.read<Session>().actor;
    setState(() => _busyId = line.id);
    try {
      if (line.isLoan) {
        await ContributionRepo.countAsInvestment(
          actor,
          line,
          partner: widget.partner,
        );
        if (mounted) toast(context, l.t('Counted as his investment'));
      } else {
        await ContributionRepo.countAsOwed(
          actor,
          line,
          partner: widget.partner,
        );
        if (mounted) toast(context, l.t('The farm owes it back now'));
      }
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _remove(Contribution line) async {
    final l = L.read(context);
    final ok = await confirm(
      context,
      title: l.t('Take this line out?'),
      body: l.t3(
        '%s · %s\n\nIt comes off what he has put in, and off the farm\'s '
        'cash with it.',
        fmtDateFull(line.date),
        rs(line.amount),
      ),
      confirmLabel: l.t('Take it out'),
    );
    if (!ok || !mounted) return;
    setState(() => _busyId = line.id);
    try {
      await ContributionRepo.remove(
        context.read<Session>().actor,
        line,
        partner: widget.partner,
      );
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<FarmStore>();
    final isMaster = context.watch<Session>().role == Role.master;
    final p =
        store.partners.where((x) => x.id == widget.partner.id).firstOrNull ??
        widget.partner;
    final lines = store.contributionsOf(p.id);
    final owed = store.owedToFounder(p.id);
    final recorded = investedFrom(lines, p.id);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(T.pad, 14, T.pad, T.pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _grip(),
            const SizedBox(height: 14),
            Text(l.t2('%s — money in', p.name), style: T.screenTitle),
            const SizedBox(height: 4),
            Text(
              p.pledged > 0
                  ? l.t3('In for %s · put in %s', rs(p.pledged), rs(p.invested))
                  : l.t2('Put in %s', rs(p.invested)),
              style: T.meta,
            ),
            if (p.stillToPayIn > 0)
              Text(
                l.t2('%s still to come', rs(p.stillToPayIn)),
                style: T.meta.copyWith(color: T.moneyDue),
              ),
            if (owed > 0)
              Text(
                l.t2('The farm owes him %s', rs(owed)),
                style: T.meta.copyWith(color: T.moneyDue),
              ),
            const SizedBox(height: T.pad),

            if (lines.isEmpty && p.invested == 0)
              EmptyNote(
                l.t(
                  'Nothing written down yet. Money he hands over, and his '
                  'share of anything the farm buys, both appear here.',
                ),
              )
            else
              for (final c in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: RegCard(
                    stripe: c.isInvestment ? T.accent600 : T.moneyDue,
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                fmtDateFull(c.date),
                                style: T.bodyMid,
                              ),
                            ),
                            Text(
                              rs(c.amount),
                              style: T.bodyMid.copyWith(
                                color: c.isInvestment
                                    ? T.accent700
                                    : T.moneyDue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            l.t(c.source.label),
                            if (c.wasHandedOver)
                              l.t2('taken by %s', c.receivedBy),
                            if (c.note.trim().isNotEmpty) c.note,
                          ].join(' · '),
                          style: T.meta,
                        ),
                        if (c.isLoan)
                          Text(
                            l.t('The farm owes this back'),
                            style: T.meta.copyWith(color: T.moneyDue),
                          ),
                        if (isMaster &&
                            c.source != ContributionSource.opening) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: GhostButton(
                                  label: c.isLoan
                                      ? l.t('Count as investment')
                                      : l.t('The farm owes it'),
                                  compact: true,
                                  onPressed: _busyId == null
                                      ? () => _flip(c)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GhostButton(
                                label: l.t('Remove'),
                                compact: true,
                                danger: true,
                                onPressed: _busyId == null
                                    ? () => _remove(c)
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

            // What the card already said before any of this was kept.
            // Not a line anybody wrote — it is the difference between his
            // total and what the lines come to, shown so the list always
            // adds up to the figure above it. It shrinks to nothing as the
            // farm writes real lines, and the day it does, every rupee of
            // his capital has a date and a reason against it.
            if (recorded < p.invested) ...[
              const SizedBox(height: 4),
              RegCard(
                stripe: T.n400,
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.t(ContributionSource.opening.label),
                            style: T.bodyMid,
                          ),
                        ),
                        Text(
                          rs(p.invested - recorded),
                          style: T.bodyMid.copyWith(color: T.n600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.t(
                        'What this record said before every rupee was given '
                        'a line of its own. Nobody wrote it; it is what is '
                        'left over.',
                      ),
                      style: T.meta,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(T.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? T.fill : T.surface,
          borderRadius: BorderRadius.circular(T.pill),
          border: Border.all(color: selected ? T.fill : T.n300, width: 1.3),
        ),
        child: Text(
          label,
          style: T.bodyMid.copyWith(
            fontSize: 12.5,
            color: selected ? T.onFill : T.n700,
          ),
        ),
      ),
    ),
  );
}
