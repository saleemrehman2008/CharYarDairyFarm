import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/accounting.dart';
import '../../services/transfer_repo.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/refund_card.dart';
import '../../widgets/ui.dart';

/// Who is holding the farm's cash, and who is out of pocket.
///
/// Four friends run this farm and none of them is an accountant. The money
/// from a shop is taken at the gate by whoever is standing there; the feed is
/// paid for out of whoever's pocket is nearest; and one of them has been
/// asked to keep the cash until everybody's investment is paid in. By the end
/// of a week none of them can say what is owed to whom without an argument,
/// and an argument about money between four friends is the one thing this app
/// was written to prevent.
///
/// None of it is new information. Every entry already carries the name of the
/// person who actually handled the money — the form has asked for it from the
/// first day, and it is a different question from who typed the entry in. It
/// had simply never been added up.
class CashHands extends StatelessWidget {
  const CashHands({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<FarmStore>();
    final hands = cashInHands(
      store.ledger,
      unnamed: l.t('Nobody named'),
      putIn: store.contributions,
    );

    if (hands.isEmpty) {
      return RegCard(
        child: Text(
          l.t(
            'Nobody has handled any money yet. Every entry asks who took it '
            'in or handed it over, and that is what this is counted from.',
          ),
          style: T.meta,
        ),
      );
    }

    final held = hands
        .where((h) => h.holding > 0)
        .fold<num>(0, (a, h) => a + h.holding);
    final owed = hands
        .where((h) => h.outOfPocket)
        .fold<num>(0, (a, h) => a - h.holding);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RegCard(
          stripe: T.accent600,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.t('Who is holding the money'),
                      style: T.cardTitle,
                    ),
                  ),
                  Tag(l.t2('%s people', hands.length)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l.t(
                  'Taken in, less handed out, for every entry with a name '
                  'against it. Below nothing means they have paid the farm\'s '
                  'costs out of their own pocket and the farm owes them.',
                ),
                style: T.meta,
              ),
              const SizedBox(height: 12),
              for (final h in hands) ...[
                _HandRow(hand: h),
                if (h != hands.last) const Divider(height: 18),
              ],
              if (held > 0 || owed > 0) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (held > 0)
                      Expanded(
                        child: _Total(
                          label: l.t('In their hands'),
                          value: rs(held),
                          tone: T.moneyIn,
                        ),
                      ),
                    if (held > 0 && owed > 0) const SizedBox(width: 10),
                    if (owed > 0)
                      Expanded(
                        child: _Total(
                          label: l.t('Out of their pockets'),
                          value: rs(owed),
                          tone: T.moneyDue,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        // Capital nobody can account for by name. Not an error — the money
        // is real and the books balance — but the per-person picture is
        // short by exactly this, and this is how the farm finds that out
        // instead of wondering why the figures look thin.
        if (capitalWithoutLines(
              capital: store.capitalIn,
              putIn: store.contributions,
            ) >
            0) ...[
          const SizedBox(height: 10),
          RegCard(
            stripe: T.accent600,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.t('Investment with no line against it'),
                        style: T.bodyMid,
                      ),
                    ),
                    Text(
                      rs(
                        capitalWithoutLines(
                          capital: store.capitalIn,
                          putIn: store.contributions,
                        ),
                      ),
                      style: T.num22.copyWith(color: T.accent700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l.t(
                    'Capital that went in without anything saying where. '
                    'The farm has the money and the books balance; it is '
                    'the list above that is short by this much. Write the '
                    'lines and it comes down to nothing.',
                  ),
                  style: T.meta,
                ),
              ],
            ),
          ),
        ],
        // What is on its way and has not been acknowledged. Named apart
        // from every balance above it, because it is in nobody's hands.
        if (store.cashInTransit > 0) ...[
          const SizedBox(height: 10),
          RegCard(
            stripe: T.moneyDue,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(l.t('On its way'), style: T.bodyMid)),
                    Text(
                      rs(store.cashInTransit),
                      style: T.num22.copyWith(color: T.moneyDue),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final t in store.transfers.where((t) => t.isWaiting))
                  Text(
                    '${l.t3('%s → %s', t.from, t.to)} · ${rs(t.amount)}',
                    style: T.meta,
                  ),
                const SizedBox(height: 4),
                Text(
                  l.t(
                    'Handed over and not yet acknowledged, so it is in '
                    'neither pair of hands. It joins the other man the '
                    'moment he says he has it.',
                  ),
                  style: T.meta,
                ),
              ],
            ),
          ),
        ],
        const RefundNotices(),
        const SizedBox(height: 10),
        GhostButton(
          label: l.t('Hand cash to somebody'),
          icon: Icons.swap_horiz,
          onPressed: () => showHandover(context),
        ),
        const SizedBox(height: 5),
        Text(
          l.t(
            'Money passing between the four of them: taken at the gate by '
            'one and kept by another. The farm has exactly as much before '
            'and after, so nothing moves except who is answerable for it.',
          ),
          style: T.meta,
        ),
      ],
    );
  }
}

class _HandRow extends StatelessWidget {
  const _HandRow({required this.hand});

  final HandsOn hand;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tone = hand.outOfPocket ? T.moneyDue : T.moneyIn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(hand.who, style: T.bodyMid)),
            Text(rs(hand.holding.abs()), style: T.num22.copyWith(color: tone)),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(
                l.t3(
                  '%s taken in · %s handed out',
                  rs(hand.received),
                  rs(hand.paid),
                ),
                style: T.meta,
              ),
            ),
            Text(
              hand.outOfPocket ? l.t('farm owes them') : l.t('in their hand'),
              style: T.meta.copyWith(color: tone),
            ),
          ],
        ),
        // Farm money sitting in a man's pocket. It is the farm's until the
        // month closes and the profit is shared, so it belongs in the farm
        // account — the thousand rupees Rafeeq collected from Urooj is the
        // farm's thousand rupees, not Rafeeq's.
        if (!hand.outOfPocket &&
            hand.holding > 0 &&
            partyKey(hand.who) != partyKey(farmAccountName)) ...[
          const SizedBox(height: 7),
          GhostButton(
            label: l.t('Into the farm account'),
            icon: Icons.account_balance_outlined,
            compact: true,
            onPressed: () => showHandover(
              context,
              from: hand.who,
              to: farmAccountName,
              amount: hand.holding,
            ),
          ),
        ],
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value, required this.tone});

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: tone.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(T.radiusXs),
      border: Border.all(color: tone.withValues(alpha: 0.28)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: T.meta.copyWith(color: tone)),
        const SizedBox(height: 2),
        Text(value, style: T.bodyMid.copyWith(color: tone)),
      ],
    ),
  );
}

/// Handing cash from one pair of hands to another.
///
/// It opens filled in when the farm already knows the answer — the button
/// beside a man's holding says where the money is going, so the sheet should
/// not then ask him again.
Future<void> showHandover(
  BuildContext context, {
  String? from,
  String? to,
  num? amount,
}) {
  final store = context.read<FarmStore>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: T.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(T.radius)),
    ),
    builder: (_) => ChangeNotifierProvider<FarmStore>.value(
      value: store,
      child: _HandoverSheet(from: from, to: to, amount: amount),
    ),
  );
}

class _HandoverSheet extends StatefulWidget {
  const _HandoverSheet({this.from, this.to, this.amount});

  final String? from;
  final String? to;
  final num? amount;

  @override
  State<_HandoverSheet> createState() => _HandoverSheetState();
}

class _HandoverSheetState extends State<_HandoverSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _from;
  String? _to;
  PayVia _via = PayVia.cash;
  bool _busy = false;

  /// The entries picked out of the sender's hands.
  ///
  /// Picking any of them drives the amount, because the whole point is that
  /// the figure and the entries agree. Leave them alone and it is a typed
  /// sum like before — a man may well hand over a round amount out of a
  /// pocket holding a dozen entries' worth.
  final _picked = <String>{};

  @override
  void initState() {
    super.initState();
    _from = widget.from;
    _to = widget.to;
    if (widget.amount != null && widget.amount! > 0) {
      _amount.text = widget.amount!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Everywhere the farm's money can be: its own account, the co-founders,
  /// and anybody else who has handled money for it. One list, held by the
  /// store, so this sheet and the entry form can never offer different
  /// answers to the same question.
  List<String> _people(FarmStore store) => store.moneyHolders;

  void _toggle(InHand row, List<InHand> all) {
    setState(() {
      if (!_picked.remove(row.txnId)) _picked.add(row.txnId);
      final sum = all
          .where((r) => _picked.contains(r.txnId))
          .fold<num>(0, (a, r) => a + r.amount);
      _amount.text = sum > 0 ? sum.toStringAsFixed(0) : '';
    });
  }

  Future<void> _save(FarmStore store) async {
    final l = L.read(context);
    final from = _from;
    final to = _to;
    final amount = num.tryParse(_amount.text.trim()) ?? 0;

    if (from == null || to == null) {
      toast(context, l.t('Who handed it over, and who took it?'));
      return;
    }
    if (amount <= 0) {
      toast(context, l.t('How much was handed over?'));
      return;
    }

    setState(() => _busy = true);
    try {
      // Sent, not done. Nothing reaches the books until the other man
      // says he has it — see [TransferRepo].
      await TransferRepo.send(
        context.read<Session>().actor,
        from: from,
        to: to,
        amount: amount,
        payVia: _via,
        note: _note.text.trim(),
        txnIds: _picked.toList(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, l.t3('%s sent to %s — waiting on him', rs(amount), to));
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
    final people = _people(store);
    final hands = {
      for (final h in cashInHands(store.ledger, putIn: store.contributions))
        partyKey(h.who): h,
    };

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
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: T.n400,
                    borderRadius: BorderRadius.circular(T.pill),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(l.t('Hand cash over'), style: T.screenTitle),
              const SizedBox(height: 4),
              Text(
                l.t(
                  'Nothing is earned and nothing is spent. The farm has the '
                  'same money before and after — this only says whose hands '
                  'it is in now.',
                ),
                style: T.meta,
              ),
              const SizedBox(height: T.pad),

              _Pick(
                label: l.t('Handed over by'),
                value: _from,
                people: people,
                hands: hands,
                onPicked: (v) => setState(() => _from = v),
              ),
              const SizedBox(height: T.gap),
              _Pick(
                label: l.t('Taken by'),
                value: _to,
                people: people,
                hands: hands,
                onPicked: (v) => setState(() => _to = v),
              ),

              const SizedBox(height: T.gap),
              Field(
                label: l.t('How much (Rs)'),
                controller: _amount,
                keyboardType: TextInputType.number,
                hint: '0',
                onChanged: (_) => setState(() {}),
              ),
              // What the giver is actually holding, so nobody hands over
              // money the books say they do not have.
              if (_from != null) ...[
                const SizedBox(height: 5),
                Builder(
                  builder: (context) {
                    final has = hands[partyKey(_from!)]?.holding ?? 0;
                    return Text(
                      has > 0
                          ? l.t3('%s has %s in hand.', _from!, rs(has))
                          : l.t2(
                              '%s is not holding anything the books know '
                              'about. That is fine if the money has only '
                              'just come in.',
                              _from!,
                            ),
                      style: T.meta.copyWith(
                        color: has > 0 ? T.moneyIn : T.moneyDue,
                      ),
                    );
                  },
                ),
              ],

              // The entries the money is made of. The farm asked for it:
              // Ghulam Ali took four payments from Urooj at the gate, and
              // handing over 8,600 should be able to say it is those four
              // rather than 8,600 of an indistinguishable pile. Latest
              // first, because the money most likely to be handed over this
              // morning is the money that came in last night.
              if (_from != null)
                Builder(
                  builder: (context) {
                    final rows = store.heldBy(_from!);
                    if (rows.isEmpty) return const SizedBox.shrink();
                    return _EntryPick(
                      title: l.t2('What %s took in', _from!),
                      note: l.t(
                        'Tap the ones being handed over and the amount '
                        'fills itself in. Leave them alone to hand over a '
                        'plain figure instead.',
                      ),
                      rows: rows,
                      picked: _picked,
                      onTap: (r) => _toggle(r, rows),
                    );
                  },
                ),

              // And the other side of it. A co-founder who has paid for
              // things out of his own pocket is owed that money, and the
              // farm wanted to see which entries they are — without them
              // being settled here. They are not the farm's to give back
              // until his own promise is paid in full; see [splitByPledge].
              if (_to != null)
                Builder(
                  builder: (context) {
                    final owed = hands[partyKey(_to!)]?.holding ?? 0;
                    if (owed >= 0) return const SizedBox.shrink();
                    final rows = store
                        .spentBy(_to!)
                        .where((r) => !r.isSpokenFor)
                        .toList();
                    if (rows.isEmpty) return const SizedBox.shrink();
                    return _EntryPick(
                      title: l.t2('What %s paid for himself', _to!),
                      note: l.t(
                        'What the farm owes him, entry by entry. Nothing '
                        'here is settled by this handover: his own spending '
                        'goes against what he is in for until that is paid '
                        'in full, and only what is over it is his to take '
                        'back.',
                      ),
                      rows: rows,
                      picked: const <String>{},
                      onTap: null,
                    );
                  },
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

              const SizedBox(height: T.gap),
              Field(
                label: l.t('Note'),
                controller: _note,
                hint: l.t('Anything worth remembering'),
              ),

              const SizedBox(height: T.pad),
              PrimaryButton(
                label: l.t('Save the handover'),
                icon: Icons.swap_horiz,
                busy: _busy,
                onPressed: _busy ? null : () => _save(store),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the two names on a handover.
/// A man's own entries, latest first, to pick from or just to read.
class _EntryPick extends StatelessWidget {
  const _EntryPick({
    required this.title,
    required this.note,
    required this.rows,
    required this.picked,
    required this.onTap,
  });

  final String title;
  final String note;
  final List<InHand> rows;
  final Set<String> picked;
  final void Function(InHand row)? onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tone = rows.first.incoming ? T.moneyIn : T.moneyDue;

    return Padding(
      padding: const EdgeInsets.only(top: T.pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(title),
          const SizedBox(height: 4),
          Text(note, style: T.meta),
          const SizedBox(height: 8),
          // Enough to see several without the sheet becoming a ledger of
          // its own; the rest is a scroll away.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 232),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final r = rows[i];
                final on = picked.contains(r.txnId);
                final dead = r.isSpokenFor || onTap == null;
                return InkWell(
                  onTap: dead ? null : () => onTap!(r),
                  borderRadius: BorderRadius.circular(T.radiusXs),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: on ? tone.withValues(alpha: 0.10) : T.surface,
                      borderRadius: BorderRadius.circular(T.radiusXs),
                      border: Border.all(
                        color: on ? tone.withValues(alpha: 0.55) : T.divider,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (onTap != null) ...[
                          Icon(
                            r.isSpokenFor
                                ? Icons.lock_outline
                                : on
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            size: 18,
                            color: r.isSpokenFor
                                ? T.n400
                                : on
                                ? tone
                                : T.n400,
                          ),
                          const SizedBox(width: 9),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.what,
                                style: T.bodyMid,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                r.isSpokenFor
                                    ? l.t3(
                                        '%s · already handed to %s',
                                        fmtDate(r.date),
                                        r.handedOnTo,
                                      )
                                    : '${fmtDate(r.date)} · ${l.t(r.detail)}',
                                style: T.meta,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          rs(r.amount),
                          style: T.bodyMid.copyWith(
                            color: r.isSpokenFor ? T.n400 : tone,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Pick extends StatelessWidget {
  const _Pick({
    required this.label,
    required this.value,
    required this.people,
    required this.hands,
    required this.onPicked,
  });

  final String label;
  final String? value;
  final List<String> people;
  final Map<String, HandsOn> hands;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Kicker(label),
      const SizedBox(height: 6),
      Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final p in people)
            _Chip(
              label: p,
              note: () {
                final held = hands[partyKey(p)]?.holding ?? 0;
                return held > 0 ? rs(held) : null;
              }(),
              selected: p == value,
              onTap: () => onPicked(p),
            ),
        ],
      ),
    ],
  );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.note,
  });

  final String label;
  final String? note;
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: T.bodyMid.copyWith(
                fontSize: 12.5,
                color: selected ? T.onFill : T.n700,
              ),
            ),
            if (note != null) ...[
              const SizedBox(width: 6),
              Text(
                note!,
                style: T.meta.copyWith(color: selected ? T.onFill : T.moneyIn),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
