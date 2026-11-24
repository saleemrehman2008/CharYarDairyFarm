import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/accounting.dart';
import '../services/employee_repo.dart';
import '../theme/tokens.dart';
import '../util/money.dart';
import 'ui.dart';

/// Paying somebody their wage, worked out from their record.
///
/// A wage used to be an expense entry with a name typed into it and a figure
/// typed beside it, which made it the one cost the farm paid every month with
/// nothing at all standing behind the number. Two things went wrong with
/// that. A name typed two ways was two men as far as the books were
/// concerned, so nobody could add up what one man had been paid in a year.
/// And a month where somebody was away a week was worked out on the back of
/// a receipt, differently each time, by whoever happened to be doing it.
///
/// So the name comes off the wage list and the figure comes off his record:
/// what he is on, less the days he was away. It stays editable afterwards,
/// because the farm settles up with a man rather than with a formula — but
/// what the formula said is on the screen beside it while they do.
class SalaryPicker extends StatelessWidget {
  const SalaryPicker({
    super.key,
    required this.chosen,
    required this.payingFor,
    required this.onMonth,
    required this.onPicked,
    this.paidThisMonth,
    this.advance = false,
    this.owesAdvance,
    this.alreadyPaid,
    this.wage = 0,
    this.wageBox,
    this.onWage,
    this.cut = 0,
    this.cutBox,
    this.onCut,
    this.owesLoan,
    this.loanMonthly,
    this.loanCut = 0,
    this.loanBox,
    this.onLoanCut,
  });

  /// Handing out part of a wage before the month is out, rather than paying
  /// the wage itself.
  ///
  /// The same list of names, and nothing else: how much he is given is
  /// between him and whoever he asked, and the only thing the farm needs
  /// written down is which man it was. The wage at month end finds it.
  final bool advance;

  /// The name in the party field, which is what ties this to the entry.
  final String chosen;

  /// What this month's wage comes to, typed.
  ///
  /// The card used to work it out: his record times the days of the
  /// window, less a tap for each day off, capped at a whole month. It was
  /// right every time and the farm still asked for it to go. A wage is
  /// settled between two men — a short week forgiven, a good month paid
  /// over, a day's help from his brother — and a figure that argues back
  /// is a figure somebody works around. So the sum is theirs and the card
  /// only holds what it is told.
  ///
  /// What his record says he is on is still shown beside it, because a
  /// figure typed from memory is worth checking against one that was
  /// agreed.
  final num wage;

  /// The box it is typed into, owned by the form so what is typed and
  /// what is saved are one thing.
  final TextEditingController? wageBox;

  /// Typed, with the figure that leaves after his advance comes off.
  final void Function(Employee who, num wage, num toHand)? onWage;

  /// The month whose wage this is, which is not the day it is handed over.
  ///
  /// October's wage gets paid on the 31st, or on the 1st, or — when the farm
  /// is busy — on the 5th of November. All three are October's wage: the
  /// days he worked are October's days and the advance he drew on the 15th
  /// is October's advance. Guessed from the entry's date, because paying in
  /// the first days of a month almost always means the month just gone, and
  /// then changeable, because almost always is not always.
  final DateTime payingFor;

  /// Moving it to another month.
  final void Function(DateTime month) onMonth;

  /// The run of days this payment covers, where it is not one whole month.
  ///
  /// The farm's own case: a man taken on on the 20th of October, paid at
  /// the end of November for the whole of it, so the advance he drew in
  /// October comes off the same payment. Asked a month at a time, that
  /// advance sat in a month nobody was paying for.

  /// Picked, with what the card says is left to hand him and how much of
  /// his advance that figure has taken off.
  final void Function(Employee who, num toHand, num cut) onPicked;

  /// What he still owes against advances already drawn. Handed in by the
  /// screen, which has the ledger.
  final num Function(Employee who)? owesAdvance;

  /// How much of that debt is coming off this wage.
  ///
  /// It used to be all of it, with no say in the matter: sixteen thousand
  /// off a twenty-four thousand wage left a man eight thousand for the
  /// month. The farm settles up with a man — so the figure is offered in
  /// full and then it is theirs, and what is not taken stays owed.
  final num cut;

  /// The box that figure is typed into, owned by the form so what is typed
  /// and what is saved are one thing.
  final TextEditingController? cutBox;

  /// Changed by hand, with the figure that leaves.
  final void Function(Employee who, num cut, num toHand)? onCut;

  /// Whether his wage for this month has already been paid, in which case
  /// the advance has come off it and must not come off again.
  final bool Function(Employee who)? alreadyPaid;

  /// What he still owes against loans, which the farm keeps apart from
  /// advances because the men do.
  final num Function(Employee who)? owesLoan;

  /// The instalment agreed when the loan was given — what the box offers
  /// before anybody changes it.
  final num Function(Employee who)? loanMonthly;

  final num loanCut;
  final TextEditingController? loanBox;
  final void Function(Employee who, num cut)? onLoanCut;

  /// What has already gone out against the month on screen.
  ///
  /// The farm pays a wage in pieces and the form used to ask for the whole
  /// of it every time, with nothing on the screen saying what had already
  /// been handed over — so the man typing had to hold it in his head, and
  /// a month paid twice looked exactly like a month paid once.
  final num Function(Employee who)? paidThisMonth;

  DateTime get _monthStart => DateTime(payingFor.year, payingFor.month, 1);

  DateTime get _monthEnd => DateTime(payingFor.year, payingFor.month + 1, 0);

  /// What is actually handed over: the wage for the days being paid for,
  /// less what he has already drawn against them, and never less than
  /// nothing.
  ///
  /// The one place this sum is done. It was done twice — here to show the
  /// farm and again on the form to fill the box — from the same functions
  /// over the same window, which agreed today and is exactly the shape of
  /// every figure this app has ever given two answers to.
  /// What is actually handed over: the wage typed for this month, less
  /// whatever of his advance is coming off it, and never less than
  /// nothing.
  num _toHand(Employee who, {required num wage, required num cut}) {
    final left = wage - _held(who, wage: wage, cut: cut);
    return left < 0 ? 0 : left;
  }

  /// A deduction held to what he owes and to what the wage can carry.
  ///
  /// Done through one function — [advanceComingOff] — because every place
  /// that needs this figure used to work it out for itself: the box as it
  /// was typed, and the saved entry again on the form.
  num _held(Employee who, {required num wage, required num cut}) =>
      advanceComingOff(
        asked: cut,
        owed: owesAdvance?.call(who) ?? 0,
        wage: wage,
      );

  /// What the farm would take off if nobody said otherwise: the whole of
  /// what he owes, or the whole of the wage, whichever runs out first.
  ///
  /// Offered, not imposed. Zero is a real answer — the farm may want a man
  /// to keep his whole wage this month and the advance to wait — and so is
  /// any figure between. What is not taken stays owed, so nothing is lost
  /// by leaving it.
  ///
  /// Nothing is offered until a wage has been typed, because until then
  /// there is nothing for it to come out of.
  num _wouldTake(Employee who, {required num wage}) =>
      _held(who, wage: wage, cut: owesAdvance?.call(who) ?? 0);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Employee>>(
      stream: EmployeeRepo.watch(),
      builder: (context, snap) {
        final all = snap.data ?? const <Employee>[];
        final working = all.where((e) => e.isWorking).toList();

        // The ones who left are on the list too while their last month is
        // still being paid. A man let go on the 19th is owed for the 19
        // days, and he is owed them after he has gone — which is also when
        // the farm gets round to paying him.
        final owedStill = all.where((e) {
          if (e.isWorking) return false;
          // Only while his last wage is still unpaid. Once it has gone out
          // he is finished with, and a man who left in October has no
          // business on the list every month after it.
          if (alreadyPaid?.call(e) ?? false) return false;
          return e.daysOnIn(_monthStart, _monthEnd) > 0;
        });
        final pickable = [...working, ...owedStill];

        // Nobody to pay is one thing; nobody on the list at all is another,
        // and saying the second when the first is true sends the farm off
        // to write down a man it has already written down. A farm whose one
        // employee left last week has a wage list and somebody to pay out
        // of it.
        if (pickable.isEmpty) {
          return RegCard(
            stripe: T.moneyDue,
            padding: const EdgeInsets.all(12),
            child: Text(
              all.isEmpty
                  ? 'Nobody is on the wage list yet. More → Wages writes them '
                        'down once — what they are owed a month, and when '
                        'they started — and the figure is worked out here '
                        'from that.'
                  : 'Nobody on the wage list worked this month. Move the '
                        'month above, or check the dates on More → Wages.',
              style: T.meta,
            ),
          );
        }

        final who = pickable
            .where((e) => partyKey(e.name) == partyKey(chosen))
            .firstOrNull;
        // Wage money he has already taken against this month. It comes off
        // by itself, which is the whole point — the farm has always said yes
        // to an advance and then had to remember, so whether it was deducted
        // depended on who was doing the paying at month end.
        final owed = who == null ? 0 : (owesAdvance?.call(who) ?? 0);
        final settled = who != null && (alreadyPaid?.call(who) ?? false);
        // Never more than the wage can carry. Anything above it is not a
        // deduction, only a figure — and the part it could not reach is
        // still owed, which is the whole point of counting it this way.
        //
        // A wage already on the books no longer stops this. It had to,
        // once: the deduction was worked out afresh from the month's
        // advances every time, so a second entry would have taken the
        // same money off twice. Now what a wage recovered is written on
        // the wage, and what is left owing is what is left owing — so a
        // second payment can take some of it and the farm is not told no
        // by a rule that was protecting a sum it no longer does.
        final comesOff = who == null ? 0 : _held(who, wage: wage, cut: cut);
        final carried = owed - comesOff;
        final toHand = who == null
            ? 0
            : _toHand(who, wage: wage, cut: comesOff);

        return RegCard(
          stripe: T.accent600,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!advance) ...[
                Row(
                  children: [
                    Expanded(child: Kicker('Whose month')),
                    _Arrow(
                      icon: Icons.chevron_left,
                      onTap: () => onMonth(
                        DateTime(payingFor.year, payingFor.month - 1, 1),
                      ),
                    ),
                    const SizedBox(width: 3),
                    SizedBox(
                      width: 112,
                      child: Text(
                        monthName(
                          '${payingFor.year}-'
                          '${payingFor.month.toString().padLeft(2, '0')}',
                        ),
                        style: T.bodyMid,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 3),
                    _Arrow(
                      icon: Icons.chevron_right,
                      onTap: () => onMonth(
                        DateTime(payingFor.year, payingFor.month + 1, 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'The month he worked, not the day he is handed it. '
                  'October\'s wage is October\'s whether it goes out on the '
                  '31st, the 1st or the 5th of November.',
                  style: T.meta,
                ),
                const SizedBox(height: 8),
              ],
              Kicker(
                advance ? 'Who is being advanced it' : 'Who is being paid',
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final e in pickable)
                    _Who(
                      who: e,
                      on: who?.id == e.id,
                      onTap: () {
                        // Nothing is filled in for him. The wage is typed,
                        // and until it is there is nothing for an advance
                        // to come out of either.
                        final take = _wouldTake(e, wage: wage);
                        onPicked(e, _toHand(e, wage: wage, cut: take), take);
                      },
                    ),
                ],
              ),

              if (who != null && advance) ...[
                const SizedBox(height: 10),
                Text(
                  owed > 0
                      ? 'He is on ${rs(who.monthly)} a month and still owes '
                            '${rs(owed)} against earlier advances. Whatever '
                            'goes out now is added to that.'
                      : 'He is on ${rs(who.monthly)} a month. Whatever goes '
                            'out now comes off that wage at the end of the '
                            'month, by itself — nobody has to remember.',
                  style: T.meta,
                ),
              ],

              if (who != null && !advance) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // What he is on, as a note and nothing more. The card
                // does not fill the figure in from it: a wage is settled
                // between two men, and one worked out by an app is one
                // somebody works around.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        who.allowance > 0
                            ? 'On ${rs(who.basic)} a month plus '
                                  '${rs(who.allowance)} allowance'
                            : 'On ${rs(who.monthly)} a month',
                        style: T.meta,
                      ),
                    ),
                    Text('Started ${fmtDate(who.joinedOn)}', style: T.meta),
                  ],
                ),

                // What the month comes to, what has gone out against it,
                // and what is left. Three lines, because the farm asked
                // the same three questions out loud every time it paid
                // half a wage.
                if (paidThisMonth != null) ...[
                  const SizedBox(height: 10),
                  _Tally(
                    monthly: who.monthly,
                    allowance: who.allowance,
                    allowanceFor: who.allowanceFor,
                    paid: paidThisMonth!(who),
                    // What is in the box right now, so the figure answers
                    // while it is being typed rather than after saving.
                    typing: wage,
                  ),
                ],

                const SizedBox(height: 9),
                if (wageBox != null)
                  Field(
                    label: 'Paying now',
                    controller: wageBox!,
                    keyboardType: TextInputType.number,
                    prefix: 'Rs ',
                    onChanged: (v) {
                      final said = num.tryParse(v.trim()) ?? 0;
                      final paid = said < 0 ? 0 as num : said;
                      onWage?.call(
                        who,
                        paid,
                        _toHand(who, wage: paid, cut: cut),
                      );
                    },
                  ),
                const SizedBox(height: 6),
                Text(
                  'What you are handing over now, before the advance comes '
                  'off it. The month above takes it off as you type; hand '
                  'over part and the rest stays on the month for next time.',
                  style: T.meta,
                ),

                // The advance, and how much of it this wage is taking.
                //
                // It came off whole, every rupee of it, the month it was
                // drawn — a man who took sixteen thousand against a wage of
                // twenty-four was handed eight thousand to live on and had
                // not agreed to that. So the figure is offered in full and
                // then it is theirs to set, and what they leave stays on
                // his name for the next wage to find.
                if (owed > 0) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Advance he still owes',
                          style: T.bodyMid.copyWith(color: T.moneyDue),
                        ),
                      ),
                      Text(
                        rs(owed),
                        style: T.bodyMid.copyWith(color: T.moneyDue),
                      ),
                    ],
                  ),
                  if (cutBox != null) ...[
                    const SizedBox(height: 8),
                    Field(
                      label: 'Coming off this wage',
                      controller: cutBox!,
                      keyboardType: TextInputType.number,
                      prefix: 'Rs ',
                      onChanged: (v) {
                        final said = num.tryParse(v.trim()) ?? 0;
                        final take = _held(who, wage: wage, cut: said);
                        onCut?.call(
                          who,
                          take,
                          _toHand(who, wage: wage, cut: take),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    wage <= 0
                        ? 'Put this month\'s salary in first — an advance '
                              'can only come off something.'
                        : carried <= 0
                        ? 'That clears his advance.'
                        : cut > wage
                        ? 'This month cannot carry more than ${rs(wage)}. '
                              '${rs(carried)} stays on his advance and comes '
                              'off a later wage.'
                        : '${rs(carried)} stays on his advance and comes off '
                              'a later wage. Nothing is lost by leaving it.',
                    style: T.meta.copyWith(
                      color: carried > 0 ? T.moneyDue : null,
                    ),
                  ),
                ],
                // The loan, kept in its own block for the same reason it
                // has its own name: a man who has both wants to see which
                // of them this wage is eating.
                if ((owesLoan?.call(who) ?? 0) > 0) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (_) {
                      final owing = owesLoan!(who);
                      final asked = loanCut < 0 ? 0 as num : loanCut;
                      final room = wage - _held(who, wage: wage, cut: cut);
                      final take = asked > owing
                          ? owing
                          : asked > room
                          ? (room < 0 ? 0 as num : room)
                          : asked;
                      final after = owing - take;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Loan he still owes',
                                  style: T.bodyMid.copyWith(color: T.moneyDue),
                                ),
                              ),
                              Text(
                                rs(owing),
                                style: T.bodyMid.copyWith(color: T.moneyDue),
                              ),
                            ],
                          ),
                          if ((loanMonthly?.call(who) ?? 0) > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${rs(loanMonthly!(who))} a month was agreed.',
                              style: T.meta,
                            ),
                          ],
                          if (loanBox != null) ...[
                            const SizedBox(height: 8),
                            Field(
                              label: 'Loan coming off this wage',
                              controller: loanBox!,
                              keyboardType: TextInputType.number,
                              prefix: 'Rs ',
                              onChanged: (v) => onLoanCut?.call(
                                who,
                                num.tryParse(v.trim()) ?? 0,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            wage <= 0
                                ? 'Put this month\'s salary in first — an '
                                      'instalment can only come off '
                                      'something.'
                                : after <= 0
                                ? 'That clears his loan.'
                                : asked > room
                                ? 'This wage cannot carry more than '
                                      '${rs(room < 0 ? 0 : room)} once the '
                                      'advance has had its share. '
                                      '${rs(after)} stays on his loan.'
                                : '${rs(after)} stays on his loan and comes '
                                      'off a later wage.',
                            style: T.meta.copyWith(
                              color: after > 0 ? T.moneyDue : null,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
                if (settled) ...[
                  const SizedBox(height: 7),
                  Text(
                    'A wage for this month is already on the books. Check '
                    'this is a second part of it and not the same payment '
                    'written twice.',
                    style: T.meta.copyWith(color: T.moneyDue),
                  ),
                ],

                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: T.moneyOut.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(T.radiusXs),
                    border: Border.all(
                      color: T.moneyOut.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          comesOff > 0 ? 'Left to hand him' : 'To pay him',
                          style: T.bodyMid.copyWith(color: T.moneyOut),
                        ),
                      ),
                      Text(
                        rs(toHand < 0 ? 0 : toHand),
                        style: T.num22.copyWith(color: T.moneyOut),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  comesOff > 0
                      ? 'The salary above, less what came off his advance. '
                            'This is what goes in the entry.'
                      : 'This is what goes in the entry.',
                  style: T.meta,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

extension on SalaryPicker {
  /// Picking one end of the run of days this payment covers.
}

/// One end of a run of days.

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(T.radiusXs),
    child: Container(
      width: 34,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(T.radiusXs),
        border: Border.all(color: T.divider),
      ),
      child: Icon(icon, size: 18, color: T.n900),
    ),
  );
}

class _Who extends StatelessWidget {
  const _Who({required this.who, required this.on, required this.onTap});

  final Employee who;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(T.pill),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: on ? T.accent600.withValues(alpha: 0.12) : T.surface,
        borderRadius: BorderRadius.circular(T.pill),
        border: Border.all(
          color: on ? T.accent600 : T.divider,
          width: on ? 1.4 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (on) ...[
            Icon(Icons.check, size: 15, color: T.accent700),
            const SizedBox(width: 5),
          ],
          Text(
            who.name,
            style: T.bodyMid.copyWith(color: on ? T.accent700 : T.n900),
          ),
        ],
      ),
    ),
  );
}

/// What this month's wage comes to, what has gone out, and what is left.
///
/// The farm hands a wage over in pieces — five thousand one week, a
/// thousand the next — and until now the form asked for the whole figure
/// every time with nothing on the screen to say what had already gone. So
/// it was held in somebody's head, and a month paid twice looked exactly
/// like a month paid once.
///
/// The allowance is named here rather than folded into one figure, because
/// a man is told "twenty-four and six for the milk" and that is what he
/// expects the paper to say.
class _Tally extends StatelessWidget {
  const _Tally({
    required this.monthly,
    required this.allowance,
    required this.allowanceFor,
    required this.paid,
    required this.typing,
  });

  final num monthly;
  final num allowance;
  final String allowanceFor;
  final num paid;

  /// What is in the box this moment, before it is saved.
  ///
  /// The farm asked for this plainly: type twenty-four against a month of
  /// thirty and the form should take it off and say six, there and then.
  /// Waiting until the entry is saved to find out is how a wage gets paid
  /// twice.
  final num typing;

  @override
  Widget build(BuildContext context) {
    final afterThis = paid + (typing > 0 ? typing : 0);
    final left = wageLeftToPay(monthly: monthly, paidSoFar: afterThis);
    final over = afterThis > monthly;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: T.accent600.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(T.radiusXs),
        border: Border.all(color: T.accent600.withValues(alpha: 0.30)),
      ),
      child: Column(
        children: [
          _Row(
            label: allowance > 0
                ? (allowanceFor.trim().isEmpty
                      ? 'The month, with the allowance'
                      : 'The month, with ${allowanceFor.trim()}')
                : 'The month',
            value: monthly,
          ),
          const SizedBox(height: 4),
          if (paid > 0)
            _Row(label: 'Already handed over', value: paid, tone: T.moneyOut),
          if (typing > 0) ...[
            if (paid > 0) const SizedBox(height: 4),
            _Row(label: 'Handing over now', value: typing, tone: T.moneyOut),
          ],
          const Divider(height: 14),
          _Row(
            label: over
                ? 'More than the month comes to'
                : typing > 0
                ? 'Left after this'
                : 'Still to pay',
            value: over ? afterThis - monthly : left,
            tone: over ? T.moneyOut : T.moneyDue,
            strong: true,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.tone,
    this.strong = false,
  });

  final String label;
  final num value;
  final Color? tone;
  final bool strong;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: strong
              ? T.bodyMid.copyWith(color: tone ?? T.accent700)
              : T.meta.copyWith(color: T.accent700),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        rs(value),
        style: strong
            ? T.num22.copyWith(color: tone ?? T.accent700)
            : T.bodyMid.copyWith(color: tone ?? T.accent700),
      ),
    ],
  );
}
