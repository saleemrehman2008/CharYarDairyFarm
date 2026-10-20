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
    required this.onPicked,
    required this.onDaysOff,
  });

  /// The name in the party field, which is what ties this to the entry.
  final String chosen;
  final int daysOff;
  final void Function(Employee who) onPicked;
  final void Function(Employee who, int days) onDaysOff;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Employee>>(
      stream: EmployeeRepo.watch(),
      builder: (context, snap) {
        final all = snap.data ?? const <Employee>[];
        final working = all.where((e) => e.isWorking).toList();
        if (working.isEmpty) {
          return RegCard(
            stripe: T.moneyDue,
            padding: const EdgeInsets.all(12),
            child: Text(
              'Nobody is on the wage list yet. More → Wages writes them down '
              'once — what they are owed a month, and when they started — '
              'and the figure is worked out here from that.',
              style: T.meta,
            ),
          );
        }

        final who = working
            .where((e) => partyKey(e.name) == partyKey(chosen))
            .firstOrNull;

        return RegCard(
          stripe: T.accent600,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Kicker('Who is being paid'),
              const SizedBox(height: 7),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final e in working)
                    _Who(who: e, on: who?.id == e.id, onTap: () => onPicked(e)),
                ],
              ),

              if (who != null) ...[
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

                const SizedBox(height: 11),
                Kicker('Days off this month'),
                const SizedBox(height: 6),
                Text(
                  'Counted against a thirty day month, which is how the farm '
                  'has always counted it. The days come off the whole month, '
                  'allowance and all.',
                  style: T.meta,
                ),
                const SizedBox(height: 8),
                _Days(days: daysOff, onPick: (d) => onDaysOff(who, d)),

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
                        '− ${rs(who.cutFor(daysOff: daysOff))}',
                        style: T.bodyMid.copyWith(color: T.moneyDue),
                      ),
                    ],
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
                          'To pay him',
                          style: T.bodyMid.copyWith(color: T.moneyOut),
                        ),
                      ),
                      Text(
                        rs(who.payFor(daysOff: daysOff)),
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
