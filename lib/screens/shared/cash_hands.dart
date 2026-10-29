import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/accounting.dart';
import '../../services/contribution_repo.dart';
import '../../services/transfer_repo.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/entry_actions.dart';
import '../../widgets/refund_card.dart';
import '../../widgets/square_card.dart';
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
      // Cash handed over and not yet acknowledged. Left out here, this card
      // disagreed with every other page that asks the same question — the
      // account strip and the co-founder cards all count it, because a man
      // who has handed money on is not holding it any more.
      moving: store.transfers,
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
                        child: BehindTap(
                          title: l.t('In their hands'),
                          figure: held,
                          note: l.t(
                            'every entry the four of them have taken money '
                            'in on',
                          ),
                          rows: [
                            for (final h in hands)
                              if (h.holding > 0)
                                ...store.heldBy(h.who).map(Behind.hand),
                          ],
                          child: _Total(
                            label: l.t('In their hands'),
                            value: rs(held),
                            tone: T.moneyIn,
                          ),
                        ),
                      ),
                    if (held > 0 && owed > 0) const SizedBox(width: 10),
                    if (owed > 0)
                      Expanded(
                        child: BehindTap(
                          title: l.t('Out of their pockets'),
                          figure: owed,
                          note: l.t(
                            'every farm cost one of them paid for himself',
                          ),
                          rows: [
                            for (final h in hands)
                              if (h.outOfPocket)
                                ...store.spentBy(h.who).map(Behind.hand),
                          ],
                          child: _Total(
                            label: l.t('Out of their pockets'),
                            value: rs(owed),
                            tone: T.moneyDue,
                          ),
                        ),
                      ),
                  ],
                ),
                const SquareOldBooksCard(),
                const CountPocketsButton(),
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
        IfCanWrite(
          child: GhostButton(
            label: l.t('Hand cash to somebody'),
            icon: Icons.swap_horiz,
            onPressed: () => showHandover(context),
          ),
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
    final store = context.watch<FarmStore>();
    final owedIn = store.owedToFarmBy(hand.who);

    // The entries this man's figure was added up from, both ways. The row
    // is not a reading of a total any more: press it and it says which
    // entries it is, the same as every row in the ledger does.
    final took = store.heldBy(hand.who).map(Behind.hand).toList();
    final gave = store.spentBy(hand.who).map(Behind.hand).toList();

    // His holding is what he took in, less what he handed out, less what he
    // has passed on and nobody has acknowledged yet. All three or the
    // sentence does not reach the figure above it.
    final sum = [
      l.t3('%s taken in, less %s handed out', rs(hand.received), rs(hand.paid)),
      if (hand.onItsWay > 0)
        l.t2('less %s on its way to somebody', rs(hand.onItsWay)),
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BehindTap(
          title: hand.who,
          figure: hand.holding.abs(),
          note: sum,
          rows: [...took, ...gave],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(hand.who, style: T.bodyMid)),
                  Text(
                    rs(hand.holding.abs()),
                    style: T.num22.copyWith(color: tone),
                  ),
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
                    // The farm owing itself money is not a sentence. Its own
                    // account below nothing means it has paid out more than
                    // has come into it, which is worth saying and is a
                    // different thing from a man being out of pocket.
                    !hand.outOfPocket
                        ? l.t('in their hand')
                        : partyKey(hand.who) == partyKey(farmAccountName)
                        ? l.t('paid out more than came in')
                        : l.t('farm owes them'),
                    style: T.meta.copyWith(color: tone),
                  ),
                ],
              ),
            ],
          ),
        ),
        // What he has taken in of the farm's money and not passed on. Shown
        // on its own, never knocked off what he has spent of his own: the
        // farm's earnings have to reach its account or there is nothing to
        // close a month on, and netting the two is how they stop arriving.
        if (owedIn > 0) ...[
          const SizedBox(height: 5),
          BehindTap(
            title: hand.who,
            figure: owedIn,
            note: l.t('farm money taken in, still to be paid into its account'),
            rows: took,
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_outlined,
                  size: 13,
                  color: T.moneyOut,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    l.t2('%s of it to pay into the farm account', rs(owedIn)),
                    style: T.meta.copyWith(color: T.moneyOut),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Farm money sitting in a man's pocket. It is the farm's until the
        // month closes and the profit is shared, so it belongs in the farm
        // account — the thousand rupees Rafeeq collected from Urooj is the
        // farm's thousand rupees, not Rafeeq's.
        if (!hand.outOfPocket &&
            hand.holding > 0 &&
            partyKey(hand.who) != partyKey(farmAccountName)) ...[
          const SizedBox(height: 7),
          IfCanWrite(
            child: GhostButton(
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

  /// The day it changed hands, which is not always the day it is written
  /// down. Money taken at the gate on the 12th and paid into the farm when
  /// somebody next opened the app belongs on the 12th.
  DateTime _on = DateTime.now();

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

  void _retotal(List<InHand> all) {
    final sum = all
        .where((r) => _picked.contains(r.txnId))
        .fold<num>(0, (a, r) => a + r.amount);
    _amount.text = sum > 0 ? sum.toStringAsFixed(0) : '';
  }

  void _toggle(InHand row, List<InHand> all) {
    setState(() {
      if (!_picked.remove(row.txnId)) _picked.add(row.txnId);
      _retotal(all);
    });
  }

  /// Everything from one shop at once.
  ///
  /// Urooj paid 8,600 and it reached the books as four separate receipts,
  /// because that is how it was handed over at the gate. Handing it on is
  /// one act, so it should be one tap — the farm asked for exactly this.
  void _toggleParty(List<InHand> party, List<InHand> all) {
    final free = party.where((r) => !r.isSpokenFor).toList();
    if (free.isEmpty) return;
    final allOn = free.every((r) => _picked.contains(r.txnId));
    setState(() {
      for (final r in free) {
        if (allOn) {
          _picked.remove(r.txnId);
        } else {
          _picked.add(r.txnId);
        }
      }
      _retotal(all);
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
        on: _on,
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
      // With what is on its way, like every other page that asks. Left out
      // here, the sheet that hands cash over was the one place still
      // telling a man he was holding money he had already sent.
      for (final h in cashInHands(
        store.ledger,
        putIn: store.contributions,
        moving: store.transfers,
      ))
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
                    if (has > 0) {
                      return Text(
                        l.t3('%s has %s in hand.', _from!, rs(has)),
                        style: T.meta.copyWith(color: T.moneyIn),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          has < 0
                              ? l.t3(
                                  '%s is holding none of the farm\'s cash — '
                                  'he is %s out of his own pocket.',
                                  _from!,
                                  rs(has.abs()),
                                )
                              : l.t2(
                                  '%s is not holding anything the books know '
                                  'about. That is fine if the money has only '
                                  'just come in.',
                                  _from!,
                                ),
                          style: T.meta.copyWith(color: T.moneyDue),
                        ),
                        if (has < 0) ...[
                          const SizedBox(height: 3),
                          Text(
                            l.t(
                              'What came in through him has gone out again on '
                              'the farm\'s costs. Anything he hands over now '
                              'is his own money, and the farm will owe him '
                              'that much more.',
                            ),
                            style: T.meta.copyWith(color: T.moneyDue),
                          ),
                        ],
                      ],
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
                        'Tap a shop to take everything of theirs at once, or '
                        'single entries. The amount fills itself in. Leave '
                        'them alone to hand over a plain figure instead.',
                      ),
                      rows: rows,
                      picked: _picked,
                      onTap: (r) => _toggle(r, rows),
                      onTapParty: (party) => _toggleParty(party, rows),
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
                      onTapParty: null,
                    );
                  },
                ),

              const SizedBox(height: T.pad),
              Kicker(l.t('The day it changed hands')),
              const SizedBox(height: 5),
              GhostButton(
                label: fmtDateFull(_on),
                icon: Icons.event_outlined,
                compact: true,
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _on,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 400),
                    ),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null && context.mounted) {
                    setState(() => _on = picked);
                  }
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
/// Counting what the four of them have paid for themselves as money they
/// have put in, all at once.
///
/// The farm's question, looking at Rs 73,690 sitting under "out of their
/// pockets": why is this not on their investment, and what do I do so it
/// goes there instead of being owed back to them.
///
/// The answer is that the farm had never been told. An entry says who found
/// the money for it, which is how the app knows a man is out of pocket at
/// all; it does not say whether that was his own money going into the farm
/// or the farm's money he expects back. Only the four of them know that, and
/// three of them have been paying their promise this way since the start.
///
/// So this asks once and writes it for all of them. Each man's own rule
/// applies — against his promise while he still owes on it, owed back only
/// once that promise is paid in full — so a man who has already paid his
/// share in full is not quietly stripped of what the farm really does owe
/// him. Each gets his own line with his own figure on it.
class CountPocketsButton extends StatefulWidget {
  const CountPocketsButton({super.key});

  @override
  State<CountPocketsButton> createState() => _CountPocketsButtonState();
}

class _CountPocketsButtonState extends State<CountPocketsButton> {
  bool _busy = false;

  Future<void> _count(List<(Partner, num)> owed) async {
    final l = L.read(context);
    final lines = <String>[];
    num toInvestment = 0;
    num stillOwed = 0;

    for (final (p, amount) in owed) {
      final cut = splitByPledge(
        amount: amount,
        pledged: p.pledged,
        alreadyIn: p.invested,
      );
      toInvestment += cut.investment;
      stillOwed += cut.refundable;
      lines.add('${p.name} — ${rs(amount)}');
    }

    final ok = await confirm(
      context,
      title: l.t('Count it as money they have put in?'),
      body:
          '${lines.join('\n')}\n\n'
          '${l.t2('%s goes onto what they have put in.', rs(toInvestment))}'
          '${stillOwed > 0 ? '\n${l.t2('%s is more than they promised, so the farm still owes that back.', rs(stillOwed))}' : ''}'
          '\n\n'
          '${l.t('Each gets a line of his own, dated today. What they are holding of the farm\'s cash comes back to nothing.')}',
      confirmLabel: l.t('Count it'),
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      final actor = context.read<Session>().actor;
      for (final (p, amount) in owed) {
        await ContributionRepo.putIn(
          actor,
          partner: p,
          amount: amount,
          source: ContributionSource.spent,
          date: DateTime.now(),
          note: 'What he had already paid for out of his own pocket',
        );
      }
      if (mounted) toast(context, l.t('Counted'));
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<Session>().role != Role.master) {
      return const SizedBox.shrink();
    }
    final store = context.watch<FarmStore>();
    final l = L.of(context);

    // Co-founders only. A worker who took money at the gate is out of
    // pocket in exactly the same arithmetic and it means something else
    // entirely — the farm owes him, and he has no promise to put it against.
    final owed = <(Partner, num)>[];
    for (final p in store.partners) {
      final held = store.handsOf(p.name)?.holding ?? 0;
      if (held < 0) owed.add((p, -held));
    }
    if (owed.isEmpty) return const SizedBox.shrink();

    final total = owed.fold<num>(0, (a, e) => a + e.$2);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GhostButton(
            label: l.t2('Count %s as money put in', rs(total)),
            icon: Icons.playlist_add_check_outlined,
            onPressed: _busy ? null : () => _count(owed),
          ),
          const SizedBox(height: 5),
          Text(
            l.t(
              'Money of their own that the farm has had the use of. Until '
              'somebody says so it sits here as a debt the farm owes them, '
              'because an entry says who found the money and not whose it '
              'was. Counted, it goes against what each of them is in for, '
              'and only what is over a man\'s promise stays owed to him.',
            ),
            style: T.meta,
          ),
        ],
      ),
    );
  }
}

/// A man's own entries, latest first, to pick from or just to read.
///
/// Grouped by who the money was with, because that is how the farm thinks of
/// it. Urooj paid 8,600 and it reached the books as four separate receipts,
/// since that is how it was handed over at the gate — but handing it on is
/// one act, so one tap on the shop takes the lot.
class _EntryPick extends StatelessWidget {
  const _EntryPick({
    required this.title,
    required this.note,
    required this.rows,
    required this.picked,
    required this.onTap,
    required this.onTapParty,
  });

  final String title;
  final String note;
  final List<InHand> rows;
  final Set<String> picked;
  final void Function(InHand row)? onTap;
  final void Function(List<InHand> party)? onTapParty;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tone = rows.first.incoming ? T.moneyIn : T.moneyDue;

    // The shops keep the order their entries are in, which is latest first.
    final parties = <String, List<InHand>>{};
    for (final r in rows) {
      parties.putIfAbsent(r.what, () => []).add(r);
    }

    final picks = rows.where((r) => picked.contains(r.txnId)).toList();
    final total = picks.fold<num>(0, (a, r) => a + r.amount);
    final whole = rows.fold<num>(0, (a, r) => a + r.amount);

    return Padding(
      padding: const EdgeInsets.only(top: T.pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Kicker(title)),
              Text('${_count(l, rows.length)} · ${rs(whole)}', style: T.meta),
            ],
          ),
          const SizedBox(height: 4),
          Text(note, style: T.meta),
          const SizedBox(height: 10),

          // Enough to see several without the sheet becoming a ledger of its
          // own; the rest is a scroll away.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 272),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final e in parties.entries) ...[
                  _PartyLine(
                    name: e.key,
                    rows: e.value,
                    picked: picked,
                    tone: tone,
                    onTap: onTapParty == null
                        ? null
                        : () => onTapParty!(e.value),
                  ),
                  const SizedBox(height: 6),
                  for (final r in e.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _EntryLine(
                        row: r,
                        on: picked.contains(r.txnId),
                        tone: tone,
                        selectable: onTap != null,
                        onTap: onTap == null ? null : () => onTap!(r),
                      ),
                    ),
                  const SizedBox(height: 5),
                ],
              ],
            ),
          ),

          // What has been picked so far, added up. Four receipts of a
          // thousand-odd each are hard to total in the head, and the figure
          // in the box above is the one that will be handed over.
          if (picks.isNotEmpty) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(T.radiusXs),
                border: Border.all(color: tone.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.t2('%s picked', _count(l, picks.length)),
                      style: T.bodyMid.copyWith(color: tone),
                    ),
                  ),
                  Text(rs(total), style: T.num22.copyWith(color: tone)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _count(L l, int n) => l.t2(n == 1 ? '%s entry' : '%s entries', '$n');

/// One shop's whole takings, as a single line to tap.
class _PartyLine extends StatelessWidget {
  const _PartyLine({
    required this.name,
    required this.rows,
    required this.picked,
    required this.tone,
    required this.onTap,
  });

  final String name;
  final List<InHand> rows;
  final Set<String> picked;
  final Color tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final free = rows.where((r) => !r.isSpokenFor).toList();
    final allOn =
        free.isNotEmpty && free.every((r) => picked.contains(r.txnId));
    final total = rows.fold<num>(0, (a, r) => a + r.amount);

    return InkWell(
      onTap: free.isEmpty ? null : onTap,
      borderRadius: BorderRadius.circular(T.radiusXs),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            if (onTap != null) ...[
              Icon(
                allOn ? Icons.done_all : Icons.playlist_add,
                size: 18,
                color: free.isEmpty ? T.n400 : tone,
              ),
              const SizedBox(width: 7),
            ],
            Expanded(
              child: Text(
                name,
                style: T.bodyMid,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_count(l, rows.length)} · ${rs(total)}',
              style: T.meta.copyWith(color: tone),
            ),
          ],
        ),
      ),
    );
  }
}

/// One entry of it.
class _EntryLine extends StatelessWidget {
  const _EntryLine({
    required this.row,
    required this.on,
    required this.tone,
    required this.selectable,
    required this.onTap,
  });

  final InHand row;
  final bool on;
  final Color tone;
  final bool selectable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final r = row;
    final dead = r.isSpokenFor || !selectable;

    return Padding(
      padding: const EdgeInsets.only(left: 15),
      child: InkWell(
        onTap: dead ? null : onTap,
        borderRadius: BorderRadius.circular(T.radiusXs),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: on ? tone.withValues(alpha: 0.10) : T.surface,
            borderRadius: BorderRadius.circular(T.radiusXs),
            border: Border.all(
              color: on ? tone.withValues(alpha: 0.55) : T.divider,
            ),
          ),
          child: Row(
            children: [
              if (selectable) ...[
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
                child: Text(
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
              ),
              const SizedBox(width: 8),
              Text(
                rs(r.amount),
                style: T.bodyMid.copyWith(color: r.isSpokenFor ? T.n400 : tone),
              ),
            ],
          ),
        ),
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
