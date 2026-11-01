import 'package:flutter/material.dart';

import '../models/models.dart';
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
    required this.daysOff,
    required this.payingFor,
    required this.onMonth,
    required this.onSpan,
    this.spanFrom,
    this.spanTo,
    required this.onPicked,
    required this.onDaysOff,
    this.advance = false,
    this.owesAdvance,
    this.alreadyPaid,
    this.cut = 0,
    this.cutBox,
    this.onCut,
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
  final int daysOff;

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
  final DateTime? spanFrom;
  final DateTime? spanTo;
  final void Function(DateTime? from, DateTime? to) onSpan;

  /// Picked, with what the card says is left to hand him and how much of
  /// his advance that figure has taken off.
  final void Function(Employee who, num toHand, num cut) onPicked;

  /// Days off changed, with the figure that leaves.
  final void Function(Employee who, int days, num toHand) onDaysOff;

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

  DateTime get _monthStart =>
      spanFrom ?? DateTime(payingFor.year, payingFor.month, 1);

  DateTime get _monthEnd =>
      spanTo ?? DateTime(payingFor.year, payingFor.month + 1, 0);

  /// Whether this payment covers something other than the one whole month.
  bool get _spanned => spanFrom != null || spanTo != null;

  /// What is actually handed over: the wage for the days being paid for,
  /// less what he has already drawn against them, and never less than
  /// nothing.
  ///
  /// The one place this sum is done. It was done twice — here to show the
  /// farm and again on the form to fill the box — from the same functions
  /// over the same window, which agreed today and is exactly the shape of
  /// every figure this app has ever given two answers to.
  num _toHand(Employee who, {required int daysOff, required num cut}) =>
      wageToHand(
        who: who,
        from: _monthStart,
        to: _monthEnd,
        daysOff: daysOff,
        drawn: _held(who, daysOff: daysOff, cut: cut),
      );

  /// A deduction held to what he owes and to what the wage can carry.
  ///
  /// Done through one function — [advanceComingOff] — because every place
  /// that needs this figure used to work it out for itself: the box as it
  /// was typed, the days-off buttons from what was typed before the days
  /// came off, and the saved entry again on the form.
  num _held(Employee who, {required int daysOff, required num cut}) =>
      advanceComingOff(
        asked: cut,
        owed: owesAdvance?.call(who) ?? 0,
        wage: who.payForWindow(
          from: _monthStart,
          to: _monthEnd,
          daysOff: daysOff,
        ),
      );

  /// What the farm would take off if nobody said otherwise: the whole of
  /// what he owes, or the whole of the wage, whichever runs out first.
  ///
  /// Offered, not imposed. Zero is a real answer — the farm may want a man
  /// to keep his whole wage this month and the advance to wait — and so is
  /// any figure between. What is not taken stays owed, so nothing is lost
  /// by leaving it.
  num _wouldTake(Employee who, {required int daysOff}) =>
      _held(who, daysOff: daysOff, cut: owesAdvance?.call(who) ?? 0);

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
        final daysOn = who?.daysOnBetween(_monthStart, _monthEnd) ?? 0;
        final allOfIt = _monthEnd.difference(_monthStart).inDays + 1;
        final partMonth = who != null && (daysOn < allOfIt || _spanned);

        // Wage money he has already taken against this month. It comes off
        // by itself, which is the whole point — the farm has always said yes
        // to an advance and then had to remember, so whether it was deducted
        // depended on who was doing the paying at month end.
        final owed = who == null ? 0 : (owesAdvance?.call(who) ?? 0);
        final settled = who != null && (alreadyPaid?.call(who) ?? false);
        final wage = who == null
            ? 0
            : who.payForWindow(
                from: _monthStart,
                to: _monthEnd,
                daysOff: daysOff,
              );
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
        final comesOff = who == null
            ? 0
            : _held(who, daysOff: daysOff, cut: cut);
        final carried = owed - comesOff;
        final toHand = who == null
            ? 0
            : _toHand(who, daysOff: daysOff, cut: comesOff);

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
                  _spanned
                      ? '${fmtDateFull(_monthStart)} to '
                            '${fmtDateFull(_monthEnd)}'
                      : 'The month he worked, not the day he is handed it. '
                            'October\'s wage is October\'s whether it goes '
                            'out on the 31st, the 1st or the 5th of November.',
                  style: T.meta.copyWith(color: _spanned ? T.accent700 : null),
                ),
                const SizedBox(height: 8),
                // One payment can cover more than a month — the end of
                // October and the whole of November together — so that an
                // advance drawn in October comes off it. Asked a month at a
                // time, that advance sat in a month nobody was paying for.
                Row(
                  children: [
                    Expanded(
                      child: _Day(
                        label: _spanned ? fmtDateFull(_monthStart) : 'Pay from',
                        onTap: () => _pickSpan(context, start: true),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: _Day(
                        label: _spanned ? fmtDateFull(_monthEnd) : 'Pay to',
                        onTap: () => _pickSpan(context, start: false),
                      ),
                    ),
                    if (_spanned) ...[
                      const SizedBox(width: 7),
                      _Day(
                        label: 'Whole month',
                        onTap: () => onSpan(null, null),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 11),
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
                        // Offered in full the moment he is picked, so the
                        // common case — take the lot — needs nothing typed.
                        final take = _wouldTake(e, daysOff: 0);
                        onPicked(e, _toHand(e, daysOff: 0, cut: take), take);
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

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        who.allowance > 0
                            ? '${rs(who.basic)} wage · '
                                  '${rs(who.allowance)} allowance'
                            : 'A full month',
                        style: T.meta,
                      ),
                    ),
                    Text(rs(who.monthly), style: T.bodyMid),
                  ],
                ),

                if (partMonth) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: T.accent600.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(T.radiusXs),
                      border: Border.all(
                        color: T.accent600.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          daysOn == 1
                              ? 'Here 1 day of this month'
                              : 'Here $daysOn days of this month',
                          style: T.bodyMid.copyWith(color: T.accent700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          who.leftOn != null
                              ? 'Started ${fmtDate(who.joinedOn)}, last day '
                                    '${fmtDate(who.leftOn!)}. Counted off his '
                                    'record rather than on anybody\'s fingers.'
                              : 'Started ${fmtDate(who.joinedOn)}, so this is '
                                    'only part of a month. Counted off his '
                                    'record.',
                          style: T.meta,
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 11),
                Kicker(
                  partMonth ? 'Days off on top of that' : 'Days off this month',
                ),
                const SizedBox(height: 6),
                Text(
                  'Counted against a thirty day month, which is how the farm '
                  'has always counted it. The days come off the whole month, '
                  'allowance and all.',
                  style: T.meta,
                ),
                const SizedBox(height: 8),
                _Days(
                  days: daysOff,
                  onPick: (d) =>
                      onDaysOff(who, d, _toHand(who, daysOff: d, cut: cut)),
                ),

                if (daysOff > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          daysOff == 1 ? '1 day off' : '$daysOff days off',
                          style: T.meta.copyWith(color: T.moneyDue),
                        ),
                      ),
                      Text(
                        '− ${rs(who.payForWindow(from: _monthStart, to: _monthEnd) - wage)}',
                        style: T.bodyMid.copyWith(color: T.moneyDue),
                      ),
                    ],
                  ),
                ],

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
                        final take = said < 0
                            ? 0
                            : said > wage
                            ? wage
                            : said;
                        onCut?.call(
                          who,
                          take,
                          _toHand(who, daysOff: daysOff, cut: take),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    carried <= 0
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
                  'Filled in above and still yours to change. The farm '
                  'settles up with a man, not with a sum.',
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
  Future<void> _pickSpan(BuildContext context, {required bool start}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _monthStart : _monthEnd,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      helpText: start ? 'Pay from which day' : 'Pay up to which day',
    );
    if (picked == null) return;

    // The other end follows rather than arguing: a start after the finish
    // is a man picking the far end first.
    final a = start ? picked : _monthStart;
    final b = start ? _monthEnd : picked;
    onSpan(a.isAfter(b) ? b : a, b.isBefore(a) ? a : b);
  }
}

/// One end of a run of days.
class _Day extends StatelessWidget {
  const _Day({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GhostButton(
    label: label,
    icon: Icons.event_outlined,
    compact: true,
    onPressed: onTap,
  );
}

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

/// Days off, as taps rather than as typing.
///
/// A man is away one, two, three days; the farm picks the number far more
/// often than it types it, and every tap is a figure that cannot be fat
/// fingered into thirty when it meant three.
class _Days extends StatelessWidget {
  const _Days({required this.days, required this.onPick});

  final int days;
  final void Function(int days) onPick;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _Step(
        icon: Icons.remove,
        on: days > 0,
        onTap: days > 0 ? () => onPick(days - 1) : null,
      ),
      Expanded(
        child: Center(
          child: Text(
            '$days',
            style: T.num22.copyWith(color: days > 0 ? T.moneyDue : T.n600),
          ),
        ),
      ),
      _Step(
        icon: Icons.add,
        on: days < 30,
        onTap: days < 30 ? () => onPick(days + 1) : null,
      ),
    ],
  );
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.on, required this.onTap});

  final IconData icon;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(T.radiusXs),
    child: Container(
      width: 44,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: T.surface,
        borderRadius: BorderRadius.circular(T.radiusXs),
        border: Border.all(color: T.divider),
      ),
      child: Icon(icon, size: 19, color: on ? T.n900 : T.n400),
    ),
  );
}
