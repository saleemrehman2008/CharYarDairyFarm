import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/accounting.dart';
import '../../services/month_repo.dart';
import '../../services/txn_repo.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/category_field.dart';
import '../../widgets/party_field.dart';
import '../../widgets/photo.dart';
import '../../widgets/salary_picker.dart';
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

  /// Which day the entry is for. Today unless somebody says otherwise.
  ///
  /// Two dates are kept on every entry and this is the one that matters to
  /// the books: the day the milk went out or the feed came in. The other is
  /// the moment this form was saved, which the app writes itself and nobody
  /// can type over — so an entry put in two days late reads as what it is,
  /// Monday's trade written on Wednesday.
  DateTime _day = DateTime.now();

  /// The receipt that came with the money, if there was one.
  File? _receipt;

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

  /// The month a wage belongs to, kept apart from the day it goes out.
  ///
  /// October's wage is October's whether it is handed over on the 31st, on
  /// the 1st, or — when the farm is busy — on the 5th of November. Null
  /// until somebody moves it, when it follows the guess below.
  DateTime? _payMonth;

  /// Paying in the first days of a month almost always means the month just
  /// gone. Almost always is not always, so the card lets it be moved.
  DateTime get _wageMonth =>
      _payMonth ??
      (_when.day <= 10
          ? DateTime(_when.year, _when.month - 1, 1)
          : DateTime(_when.year, _when.month, 1));

  DateTime get _payStart => DateTime(_wageMonth.year, _wageMonth.month, 1);
  DateTime get _payEnd => DateTime(_wageMonth.year, _wageMonth.month + 1, 0);

  num _drawnBy(Employee who) => advanceTaken(
    context.read<FarmStore>().ledger,
    who: who.name,
    from: _payStart,
    to: _payEnd,
  );

  bool _wageDone(Employee who) => wagePaidIn(
    context.read<FarmStore>().ledger,
    who: who.name,
    from: _payStart,
    to: _payEnd,
  );

  /// What is actually handed over: the month's wage, less what he has
  /// already drawn against it, and never less than nothing.
  num _toHand(Employee who, int daysOn, int daysOff) {
    final wage = who.payFor(daysOff: daysOff, daysOn: daysOn);
    final off = _wageDone(who) ? 0 : _drawnBy(who);
    final left = wage - off;
    return left < 0 ? 0 : left;
  }

  /// Days off to come out of this month's wage.
  ///
  /// The one thing about a wage that changes month to month, and the one
  /// thing the farm was working out on the back of a receipt every time.
  int _daysOff = 0;

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

  Future<void> _pickReceipt(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      // Big enough that an account number on a bank slip survives, and
      // shrunk properly once it is read — see [PhotoKind.receipt].
      maxWidth: 2000,
      imageQuality: 88,
    );
    if (picked == null || !mounted) return;
    setState(() => _receipt = File(picked.path));
  }

  bool get _isToday => _sameDay(_day, DateTime.now());

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// The day the entry carries, with a time of day on it.
  ///
  /// Today's entries are stamped with the clock, so a morning sale and an
  /// evening one stay in the order they happened. A day gone by is stamped at
  /// noon: the hour is not known and pretending to it would put a back-dated
  /// entry either side of entries written at the time for no reason.
  DateTime get _when =>
      _isToday ? DateTime.now() : DateTime(_day.year, _day.month, _day.day, 12);

  /// How far back this person may date an entry.
  ///
  /// A founder may go back to the start of the period that is open — far
  /// enough for the milk nobody wrote down on Tuesday, and no further. The
  /// day before that belongs to a period whose figures have been sent round
  /// and agreed, and an entry appearing inside it would change a statement
  /// four people have already read. The master can go further back, because
  /// somebody has to be able to.
  DateTime _floor(FarmStore store, bool isMaster) {
    if (isMaster) {
      final now = DateTime.now();
      return DateTime(now.year - 2, now.month, now.day);
    }
    return periodFirstDay(store.month);
  }

  Future<void> _pickDay(FarmStore store, bool isMaster) async {
    final now = DateTime.now();
    final floor = _floor(store, isMaster);
    final picked = await showDatePicker(
      context: context,
      initialDate: _day.isBefore(floor) ? floor : _day,
      firstDate: floor,
      // Nothing is dated forward. Milk that has not been sold is not an
      // entry.
      lastDate: now,
      helpText: 'Which day is this for?',
    );
    if (picked != null && mounted) setState(() => _day = picked);
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
    if (_category == securityBackCategory) {
      final held = context.read<FarmStore>().securityHeldFrom(party);
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
    if (_category == securityRefundCategory) {
      final owed = context.read<FarmStore>().securityOutWith(party);
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

    // The same rule the correction sheet runs and the server enforces. The
    // picker already keeps the days it offers inside it; this is for the
    // entry left sitting open across midnight, or across a period close.
    final refused = dateMoveRefusal(
      isMaster: context.read<Session>().role == Role.master,
      to: _day,
      periodStart: periodFirstDay(store.month),
    );
    if (refused != null) {
      toast(context, refused);
      return;
    }

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
        // The day the trade happened. The moment it was typed is written
        // alongside it by the server, and neither can be had without the
        // other.
        date: _when,
        receipt: _receipt,
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

          // Which day the entry is for, which is today unless somebody says
          // otherwise. The milk nobody wrote down on Tuesday is still
          // Tuesday's milk, and before this it could only be entered as
          // today's — so a day's sales were wrong in both directions at once
          // and the only record of why was in somebody's head.
          DayPicker(
            day: _day,
            isToday: _isToday,
            floor: _floor(
              context.watch<FarmStore>(),
              context.watch<Session>().role == Role.master,
            ),
            period: monthName(context.watch<FarmStore>().month.id),
            onPick: () => _pickDay(
              context.read<FarmStore>(),
              context.read<Session>().role == Role.master,
            ),
            onToday: () => setState(() => _day = DateTime.now()),
          ),
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
          // A wage. The farm keeps a list of who it pays and what they are
          // owed — see [WagesScreen] — so the name comes off that list and
          // the figure is worked out from his record rather than from
          // somebody's memory of what he is on.
          // Part of a wage, handed out before the month is out. The only
          // thing the farm needs written down is which man it was — the wage
          // at month end finds the advance by itself.
          if (_category == salaryAdvanceCategory) ...[
            const SizedBox(height: 10),
            SalaryPicker(
              chosen: _party.text.trim(),
              daysOff: 0,
              payingFor: _when,
              onMonth: (_) {},
              advance: true,
              drawnAlready: (who) => advanceTaken(
                context.read<FarmStore>().ledger,
                who: who.name,
                from: DateTime(_when.year, _when.month, 1),
                to: DateTime(_when.year, _when.month + 1, 0),
              ),
              onPicked: (who, _) => setState(() => _party.text = who.name),
              onDaysOff: (_, _, _) {},
            ),
          ],
          if (_category == salariesCategory) ...[
            const SizedBox(height: 10),
            SalaryPicker(
              chosen: _party.text.trim(),
              daysOff: _daysOff,
              payingFor: _wageMonth,
              onMonth: (m) => setState(() => _payMonth = m),
              drawnAlready: _drawnBy,
              alreadyPaid: _wageDone,
              onPicked: (who, daysOn) {
                setState(() {
                  _party.text = who.name;
                  _daysOff = 0;
                  _total.text = '${_toHand(who, daysOn, 0).round()}';
                });
                _fromTotal();
              },
              onDaysOff: (who, daysOn, days) {
                setState(() {
                  _daysOff = days;
                  _total.text = '${_toHand(who, daysOn, days).round()}';
                });
                _fromTotal();
              },
            ),
          ],
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
          if (_category == securityBackCategory) ...[
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final name = _party.text.trim();
                final held = context.watch<FarmStore>().securityHeldFrom(name);
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
          if (_category == securityRefundCategory) ...[
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final name = _party.text.trim();
                final owed = context.watch<FarmStore>().securityOutWith(name);
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

          // The receipt that came with the money. A bank slip, a chit from
          // the mandi — the one thing that settles an argument about a
          // transfer three months later, when nobody can remember.
          const SizedBox(height: T.pad),
          const Kicker('Receipt'),
          const SizedBox(height: 6),
          if (_receipt == null)
            Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: 'Take a photo',
                    icon: Icons.photo_camera_outlined,
                    compact: true,
                    onPressed: _busy
                        ? null
                        : () => _pickReceipt(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GhostButton(
                    label: 'From the gallery',
                    icon: Icons.photo_outlined,
                    compact: true,
                    onPressed: _busy
                        ? null
                        : () => _pickReceipt(ImageSource.gallery),
                  ),
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FarmPhotoView(file: _receipt, size: 64),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'It goes on the entry and opens full size when '
                        'anybody taps it.',
                        style: T.meta,
                      ),
                      const SizedBox(height: 7),
                      GhostButton(
                        label: 'Take it off',
                        compact: true,
                        onPressed: () => setState(() => _receipt = null),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 5),
          Text(
            'Not required. Worth it on a bank transfer, where the slip is '
            'the only proof there is.',
            style: T.meta,
          ),
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
        ],
      ),
    );
  }
}

/// Which day the entry is for.
///
/// Today, until somebody taps the date. It matters that this is one tap away
/// rather than hidden: the entry that gets written late is the one nobody had
/// a hand free for at the time — the morning milk, the feed that arrived
/// while the round was out — and a form that can only say "today" moves that
/// trade onto the wrong day and takes the other day's figures down with it.
///
/// Both dates are kept. This one is the trade; the other is the moment the
/// form was saved, which the server writes and nobody can type over. The
/// period the entry is booked into is a third thing again and does not move:
/// it is always the period that is open, which is what keeps a settled
/// month's profit settled.
class DayPicker extends StatelessWidget {
  const DayPicker({
    super.key,
    required this.day,
    required this.isToday,
    required this.floor,
    required this.period,
    required this.onPick,
    required this.onToday,
  });

  final DateTime day;
  final bool isToday;

  /// The earliest day this person may pick, so the form can say so before
  /// the picker refuses it.
  final DateTime floor;

  /// The period the entry will be booked into, whatever its date.
  final String period;

  final VoidCallback onPick;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final tone = isToday ? T.accent600 : T.moneyDue;
    return RegCard(
      stripe: tone,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_outlined, size: 18, color: tone),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Kicker('Which day is this for?'),
                    const SizedBox(height: 3),
                    Text(
                      isToday
                          ? '${fmtDateFull(day)} · today'
                          : fmtDateFull(day),
                      style: T.bodyMid,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GhostButton(
                label: 'Change',
                icon: Icons.edit_calendar_outlined,
                compact: true,
                onPressed: onPick,
              ),
            ],
          ),
          if (!isToday) ...[
            const SizedBox(height: 9),
            Text(
              'This entry will show on ${fmtDateFull(day)}, not today. Both '
              'days are kept on it: the day it happened, and the day it was '
              'typed in.',
              style: T.meta.copyWith(color: T.moneyDue),
            ),
            const SizedBox(height: 8),
            GhostButton(
              label: 'Back to today',
              icon: Icons.today_outlined,
              compact: true,
              onPressed: onToday,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Booked into $period either way. Nothing can be dated before '
            '${fmtDateFull(floor)}.',
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
