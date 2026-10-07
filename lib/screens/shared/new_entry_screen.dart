import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/month_repo.dart';
import '../../services/txn_repo.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/category_field.dart';
import '../../widgets/party_field.dart';
import '../../widgets/ui.dart';

/// One form for every kind of money that moves, opened in one of two
/// directions.
///
/// It used to open on five buttons — Sale, Purchase, Expense, Receipt,
/// Payment — and the farm said plainly that the five words did not tell
/// anybody what they did. They were right. The difference between them is
/// not a difference between things that happen on a farm; it is a difference
/// in what the books do afterwards, and no button can carry that.
///
/// So the question the form asks is the one the person can answer without
/// being taught anything: did the money come in, or did it go out. The
/// heading decides the rest — see [MoneyFlow.typeOf] — and a line under it
/// says out loud what this entry is about to do to the profit.
class NewEntryScreen extends StatefulWidget {
  const NewEntryScreen({super.key, required this.flow});

  final MoneyFlow flow;

  @override
  State<NewEntryScreen> createState() => _NewEntryScreenState();
}

class _NewEntryScreenState extends State<NewEntryScreen> {
  late String _category = widget.flow.categories.first;

  /// What the books will record this as, worked out from the heading rather
  /// than asked. A typed heading falls back to earned or spent, whichever
  /// way the money went.
  TxnType get _type => widget.flow.typeOf(_category);

  /// Set only when the category was written out rather than picked, because
  /// only then is there no list to read the answer off. See [Txn.capital].
  bool? _capital;
  String _unit = 'L';

  /// Which milking, on a milk entry. Null until picked, and save refuses
  /// while it is — see [_shiftNeeded].
  MilkShift? _shift;
  bool _paid = true;
  PayVia _payVia = PayVia.cash;
  bool _busy = false;

  final _party = TextEditingController();
  final _qty = TextEditingController();
  final _rate = TextEditingController();
  final _total = TextEditingController();
  final _note = TextEditingController();
  final _handledBy = TextEditingController();

  /// Guards the qty/rate/total loop so each edit only drives the others once.
  bool _syncing = false;

  @override
  void dispose() {
    _party.dispose();
    _qty.dispose();
    _rate.dispose();
    _total.dispose();
    _note.dispose();
    _handledBy.dispose();
    super.dispose();
  }

  num get _amount => num.tryParse(_total.text.trim()) ?? 0;

  /// Something the farm keeps. Off the list when it was picked off the list,
  /// and off what was said at the time when it was written out.
  bool get _isAsset => _capital ?? assetCategories.contains(_category);

  /// True when this entry is milk moving in or out, and so has to say which
  /// milking it came from.
  bool get _shiftNeeded =>
      (_type == TxnType.sale && _category == milkCategory) ||
      (_type == TxnType.purchase && _category == milkBoughtInCategory);

  /// Quantity times rate fills the total.
  void _fromQtyRate() {
    if (_syncing) return;
    final q = num.tryParse(_qty.text.trim());
    final r = num.tryParse(_rate.text.trim());
    if (q == null || r == null) return;
    _syncing = true;
    _total.text = (q * r) % 1 == 0
        ? (q * r).toInt().toString()
        : (q * r).toStringAsFixed(2);
    _syncing = false;
    setState(() {});
  }

  /// Editing the total back-solves the rate — that is how bulk pricing is
  /// entered ("240 litres for Rs 45,000").
  void _fromTotal() {
    if (_syncing) return;
    final q = num.tryParse(_qty.text.trim());
    final t = num.tryParse(_total.text.trim());
    setState(() {});
    if (q == null || q == 0 || t == null) return;
    _syncing = true;
    final rate = t / q;
    _rate.text = rate % 1 == 0
        ? rate.toInt().toString()
        : rate.toStringAsFixed(2);
    _syncing = false;
  }

  void _setCategory(String category, bool? capital) {
    setState(() {
      _category = category;
      _capital = capital;
      // A receipt or a payment settles rather than owes, so there is no
      // credit side to it — the money has moved by definition.
      if (_type.isSettlement) _paid = true;
    });
  }

  Future<void> _save() async {
    final party = _party.text.trim();
    if (party.isEmpty) {
      toast(context, 'Who is this entry for? Add a party name.');
      return;
    }
    if (_amount <= 0) {
      toast(context, 'Add the total amount.');
      return;
    }
    // A buffalo is milked twice a day. Left unanswered, the litres land in
    // neither half and every figure built on the split is short by them.
    if (_shiftNeeded && _shift == null) {
      toast(context, 'Morning or evening? Pick one first.');
      return;
    }
    // Money that moved needs a name against it, or nobody can be asked about
    // it a month later.
    if (_paid && _handledBy.text.trim().isEmpty) {
      toast(context, 'Who handled the money? Fill that in first.');
      return;
    }

    // Nobody can pay back more than they borrowed. The last instalment is
    // where this bites: the figure filled in for them is a whole month, the
    // loan has less than a month left on it, and they press save. Past that
    // point the farm is owed a negative amount, which is not a thing — and
    // the extra would sit in the cash with nothing to account for it.
    //
    // Not quietly trimmed to fit, either. Somebody typing ten thousand should
    // be told what is actually owed, rather than handed a receipt for eight
    // and left to find out later.
    if (_category == loanRepaidCategory) {
      final loan = context.read<FarmStore>().loanFor(party);
      if (loan == null) {
        toast(context, 'No loan is running against that name.');
        return;
      }
      if (_amount > loan.left) {
        toast(context, 'Only ${rs(loan.left)} is left on that loan.');
        return;
      }
    }

    // And nobody can be handed back more advance than they left. Less is
    // ordinary — a contract winding down in stages, or a customer taking
    // part of it and leaving the rest against next month — but more is the
    // farm giving away its own cash under the heading of somebody else's.
    //
    // Past that point the advances held come out negative, which reads as
    // the farm being owed money by a man who is owed money by the farm, and
    // it takes the whole balance check down with it.
    if (_category == advanceReturnCategory) {
      final held = context.read<FarmStore>().advanceHeldFor(party);
      if (held <= 0) {
        toast(context, 'No advance is being held for that name.');
        return;
      }
      if (_amount > held) {
        toast(context, 'Only ${rs(held)} of advance is held for $party.');
        return;
      }
    }

    // And the same the other way round: an advance the farm handed out can
    // only come back as far as nothing. More than that and the farm is
    // taking in money it was never owed, under a heading that keeps it out
    // of the earnings — so it lands in the cash with nothing to account for
    // it, which is the one shape of mistake the balance check cannot name.
    if (_category == advanceBackCategory) {
      final owed = context.read<FarmStore>().advanceOwedBy(party);
      if (owed <= 0) {
        toast(context, 'No advance is outstanding against that name.');
        return;
      }
      if (_amount > owed) {
        toast(context, 'Only ${rs(owed)} of advance is left with $party.');
        return;
      }
    }

    final store = context.read<FarmStore>();
    final actor = context.read<Session>().actor;
    setState(() => _busy = true);
    try {
      await MonthRepo.ensureOpen(store.month.id);
      await TxnRepo.add(
        actor: actor,
        monthId: store.month.id,
        type: _type,
        party: party,
        category: _category,
        capital: _capital,
        shift: _shiftNeeded ? _shift : null,
        amount: _amount,
        paid: _paid,
        qty: num.tryParse(_qty.text.trim()),
        unit: _unit,
        rate: num.tryParse(_rate.text.trim()),
        note: _note.text.trim(),
        payVia: _payVia,
        handledBy: _handledBy.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, '${_type.label} saved · ${rs(_amount)}');
    } catch (e) {
      if (mounted) toast(context, 'Could not save it. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final measured = !_type.isSettlement;

    final coming = widget.flow == MoneyFlow.incoming;
    final tone = coming ? T.moneyIn : T.moneyOut;

    return FarmScaffold(
      title: coming ? 'Money in' : 'Money out',
      showBack: true,
      body: PageBody(
        children: [
          // Which way the money went, said once at the top and then left
          // alone. It cannot be changed here: the two directions are two
          // buttons on the page before this, so a person who picked the
          // wrong one goes back rather than discovering halfway down a
          // filled-in form that everything under it has quietly changed.
          _Heading(flow: widget.flow, tone: tone),
          const SizedBox(height: T.pad),

          // Names come off the books as they are typed, so one customer
          // never ends up written two ways and split across two accounts.
          PartyField(
            label: coming ? 'Who it came from' : 'Who it went to',
            controller: _party,
            hint: coming ? 'Who paid, or who bought it' : 'Who you paid',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: T.gap),

          CategoryField(
            label: 'What for',
            flow: widget.flow,
            value: _category,
            onChanged: _setCategory,
          ),
          // What this is about to do to the books, in one line. The old form
          // never said, so the only way to know whether an entry moved the
          // profit was to know already.
          const SizedBox(height: 7),
          Text(
            entryEffect(type: _type, category: _category, isAsset: _isAsset),
            style: T.meta,
          ),
          // A loan instalment. The figure is filled in for them and stays
          // theirs to change: somebody who can spare more this month should
          // not have to work out what more means, and somebody who can spare
          // less should not have to skip the whole thing.
          if (_category == loanRepaidCategory) ...[
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final loan = context.watch<FarmStore>().loanFor(
                  _party.text.trim(),
                );
                if (loan == null) {
                  return Text(
                    _party.text.trim().isEmpty
                        ? 'Put the name in and the instalment fills itself.'
                        : 'No loan running against that name. Money taken in '
                              'here comes off a loan — if this is something '
                              'else, pick another kind of entry.',
                    style: T.meta.copyWith(color: T.moneyDue),
                  );
                }
                // The last instalment is smaller than the rest, and the
                // button has to say so. Offering a whole month on a loan with
                // less than a month left is offering a figure that will be
                // refused on save, which is a strange way to treat somebody
                // who is finishing paying.
                final due = loan.instalment < loan.left
                    ? loan.instalment
                    : loan.left;
                final last = due >= loan.left;
                return RegCard(
                  wash: T.moneyInWash,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${loan.name} · ${rs(loan.left)} still owed',
                        style: T.bodyMid,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        last
                            ? 'This is the last of it. Nothing more than '
                                  '${rs(loan.left)} can go on this loan.'
                            : 'One month comes to ${rs(due)}. Change it to '
                                  'whatever is actually being handed over — it '
                                  'comes straight off the loan, and it is not '
                                  'income.',
                        style: T.meta,
                      ),
                      const SizedBox(height: 8),
                      GhostButton(
                        label: 'Fill in ${rs(due)}',
                        icon: Icons.south_west,
                        compact: true,
                        onPressed: () {
                          _total.text = '${due.round()}';
                          _fromTotal();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          // Handing an advance back. What is actually being held is put on
          // the screen before anything is typed, because the figure is the
          // one thing nobody carries in their head — a customer leaves an
          // advance once and takes it back a year later.
          //
          // Less than the whole is ordinary: a contract winding down in
          // stages, or somebody taking part of it and leaving the rest
          // against next month. More is not, and save refuses it.
          if (_category == advanceReturnCategory) ...[
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final name = _party.text.trim();
                final held = context.watch<FarmStore>().advanceHeldFor(name);
                if (name.isEmpty) {
                  return Text(
                    'Put the name in and it will say what is being held.',
                    style: T.meta,
                  );
                }
                if (held <= 0) {
                  return Text(
                    'No advance is being held for that name. Money handed '
                    'back here comes off an advance — if this is something '
                    'else, pick another heading.',
                    style: T.meta.copyWith(color: T.moneyDue),
                  );
                }
                return RegCard(
                  wash: T.moneyDueWash,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$name · ${rs(held)} held', style: T.bodyMid),
                      const SizedBox(height: 2),
                      Text(
                        'Hand back all of it or part of it. Nothing more '
                        'than ${rs(held)} can go back, because that is all '
                        'the farm is holding.',
                        style: T.meta,
                      ),
                      const SizedBox(height: 8),
                      GhostButton(
                        label: 'Fill in ${rs(held)}',
                        icon: Icons.north_east,
                        compact: true,
                        onPressed: () {
                          _total.text = '${held.round()}';
                          _fromTotal();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          // Taking back an advance the farm handed out. Same courtesy as
          // handing one back: what is outstanding is on the screen before
          // anything is typed, and more than that is refused.
          if (_category == advanceBackCategory) ...[
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final name = _party.text.trim();
                final owed = context.watch<FarmStore>().advanceOwedBy(name);
                if (name.isEmpty) {
                  return Text(
                    'Put the name in and it will say what is outstanding.',
                    style: T.meta,
                  );
                }
                if (owed <= 0) {
                  return Text(
                    'No advance is outstanding against that name. Money '
                    'taken in here comes off an advance the farm handed '
                    'out — if this is something else, pick another heading.',
                    style: T.meta.copyWith(color: T.moneyDue),
                  );
                }
                return RegCard(
                  wash: T.moneyGetWash,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$name · ${rs(owed)} still out', style: T.bodyMid),
                      const SizedBox(height: 2),
                      Text(
                        'Take back all of it or part of it — stopped out of '
                        'wages or handed over. Nothing more than ${rs(owed)} '
                        'can come back, because that is all that went out.',
                        style: T.meta,
                      ),
                      const SizedBox(height: 8),
                      GhostButton(
                        label: 'Fill in ${rs(owed)}',
                        icon: Icons.south_west,
                        compact: true,
                        onPressed: () {
                          _total.text = '${owed.round()}';
                          _fromTotal();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          if (_isAsset && !_type.isSettlement) ...[
            const SizedBox(height: 6),
            Text(
              'This counts as a farm asset, not a monthly cost. The cash still '
              'leaves the balance, but the profit is not reduced — the farm '
              'owns what it bought.',
              style: T.meta.copyWith(color: T.accent700),
            ),
          ],

          if (measured) ...[
            const SizedBox(height: T.gap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 3,
                  child: Field(
                    label: 'Qty',
                    controller: _qty,
                    keyboardType: TextInputType.number,
                    hint: '0',
                    onChanged: (_) => _fromQtyRate(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: Picker<String>(
                    label: 'Unit',
                    value: _unit,
                    items: [for (final u in txnUnits) (u, u)],
                    onChanged: (v) => setState(() => _unit = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: Field(
                    label: 'Rate / unit',
                    controller: _rate,
                    keyboardType: TextInputType.number,
                    hint: '0',
                    onChanged: (_) => _fromQtyRate(),
                  ),
                ),
              ],
            ),
          ],

          // Which milking. Asked on milk and on nothing else, and left blank
          // until somebody picks — a buffalo gives twice a day and the two
          // are different trades, so a guess here would quietly halve the
          // worth of every figure built on top of it.
          if (_shiftNeeded) ...[
            const SizedBox(height: T.pad),
            const Kicker('Which milking?'),
            const SizedBox(height: 6),
            Segmented<MilkShift?>(
              value: _shift,
              options: [for (final s in MilkShift.values) (s, s.label)],
              onChanged: (v) => setState(() => _shift = v),
            ),
          ],

          const SizedBox(height: T.gap),
          Field(
            label: 'Total amount (Rs)',
            controller: _total,
            keyboardType: TextInputType.number,
            hint: '0',
            onChanged: (_) => _fromTotal(),
          ),
          if (measured) ...[
            const SizedBox(height: 5),
            Text(
              'Qty × rate fills the total. Change the total for a bulk deal '
              'and the rate works itself out.',
              style: T.meta,
            ),
          ],

          if (!_type.isSettlement) ...[
            const SizedBox(height: T.pad),
            const Kicker('Settled?'),
            const SizedBox(height: 6),
            Segmented<bool>(
              value: _paid,
              compact: true,
              options: [(true, 'Paid now'), (false, _type.unpaidLabel)],
              onChanged: (v) => setState(() => _paid = v),
            ),
          ],

          // Only worth asking once the money has actually moved.
          if (_type.isSettlement || _paid) ...[
            const SizedBox(height: T.pad),
            const Kicker('How'),
            const SizedBox(height: 6),
            Segmented<PayVia>(
              value: _payVia,
              compact: true,
              options: [for (final v in PayVia.values) (v, v.label)],
              onChanged: (v) => setState(() => _payVia = v),
            ),
            const SizedBox(height: T.gap),
            WhoField(
              label: _type.isIncoming ? 'Received by' : 'Paid by',
              controller: _handledBy,
              hint: _type.isIncoming
                  ? 'Who took the money'
                  : 'Who handed it over',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 5),
            Text(
              'The person who actually handled the cash — not whoever is '
              'typing this in.',
              style: T.meta,
            ),
          ],

          const SizedBox(height: T.gap),
          Field(
            label: 'Note',
            controller: _note,
            hint: 'Anything worth remembering',
            maxLines: 2,
          ),

          const SizedBox(height: 22),
          PrimaryButton(
            label: 'Save & sync to Sheets',
            busy: _busy,
            onPressed: _save,
          ),
          const SizedBox(height: 10),
          Text(
            'Booked into ${monthName(context.watch<FarmStore>().month.id)}.',
            style: T.meta,
          ),
        ],
      ),
    );
  }
}

/// Which way the money went, stated across the top of the form in that
/// direction's own colour — the same green and red the figures are written
/// in everywhere else, so the page is recognisable before a word is read.
class _Heading extends StatelessWidget {
  const _Heading({required this.flow, required this.tone});

  final MoneyFlow flow;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final coming = flow == MoneyFlow.incoming;
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: T.isDark ? 0.16 : 0.09),
        borderRadius: T.roundSm,
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(T.radiusXs),
            ),
            child: Icon(
              coming ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 21,
              color: tone,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coming ? 'Money in' : 'Money out',
                  style: T.cardTitle.copyWith(color: tone),
                ),
                Text(
                  coming
                      ? 'Somebody handed money to the farm.'
                      : 'The farm handed money to somebody.',
                  style: T.meta,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
