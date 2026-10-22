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
    required this.onPicked,
    required this.onDaysOff,
    this.advance = false,
    this.drawnAlready,
    this.alreadyPaid,
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

  final void Function(Employee who, int daysOn) onPicked;
  final void Function(Employee who, int daysOn, int days) onDaysOff;

  /// What he has already drawn against this month, which the wage takes off
  /// by itself. Handed in by the screen, which has the ledger.
  final num Function(Employee who)? drawnAlready;

  /// Whether his wage for this month has already been paid, in which case
  /// the advance has come off it and must not come off again.
  final bool Function(Employee who)? alreadyPaid;

  DateTime get _monthStart => DateTime(payingFor.year, payingFor.month, 1);

  DateTime get _monthEnd => DateTime(payingFor.year, payingFor.month + 1, 0);

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
        final daysOn = who?.daysOnIn(_monthStart, _monthEnd) ?? 0;
        final partMonth = who != null && daysOn < Employee.monthDays;

        // Wage money he has already taken against this month. It comes off
        // by itself, which is the whole point — the farm has always said yes
        // to an advance and then had to remember, so whether it was deducted
        // depended on who was doing the paying at month end.
        final drawn = who == null ? 0 : (drawnAlready?.call(who) ?? 0);
        final settled = who != null && (alreadyPaid?.call(who) ?? false);
        final comesOff = settled ? 0 : drawn;
        final wage = who == null
            ? 0
            : who.payFor(daysOff: daysOff, daysOn: daysOn);
        final toHand = wage - comesOff;

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
                      onTap: () =>
                          onPicked(e, e.daysOnIn(_monthStart, _monthEnd)),
                    ),
                ],
              ),

              if (who != null && advance) ...[
                const SizedBox(height: 10),
                Text(
                  drawn > 0
                      ? 'He is on ${rs(who.monthly)} a month and has already '
                            'taken ${rs(drawn)} against it. Whatever goes out '
                            'now comes off the same wage.'
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
                _Days(days: daysOff, onPick: (d) => onDaysOff(who, daysOn, d)),

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
                        '− ${rs(who.monthly - who.payFor(daysOff: daysOff, daysOn: daysOn))}',
                        style: T.bodyMid.copyWith(color: T.moneyDue),
                      ),
                    ],
                  ),
                ],

                if (comesOff > 0) ...[
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Advance already taken this month',
                          style: T.meta.copyWith(color: T.moneyDue),
                        ),
                      ),
                      Text(
                        '− ${rs(comesOff)}',
                        style: T.bodyMid.copyWith(color: T.moneyDue),
                      ),
                    ],
                  ),
                ],
                if (settled && drawn > 0) ...[
                  const SizedBox(height: 7),
                  Text(
                    'His wage for this month is already on the books, so the '
                    '${rs(drawn)} advance has come off it once. It is not '
                    'taken off again here.',
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
                  toHand < 0
                      ? 'He has drawn ${rs(-toHand)} more than this month '
                            'comes to. Nothing is owed to him now, and that '
                            'much is still to come off next month — put it '
                            'in by hand when you pay it.'
                      : 'Filled in above and still yours to change. The farm '
                            'settles up with a man, not with a sum.',
                  style: T.meta.copyWith(color: toHand < 0 ? T.moneyDue : null),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
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
