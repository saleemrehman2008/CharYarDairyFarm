import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/tokens.dart';

/// A month at a time, tap a day to add it to the order, tap it again to drop
/// it.
///
/// Built for the customer who wants milk on Monday, Wednesday and Friday as
/// much as for the one who wants it every day this week — a date range would
/// only serve the second. Yesterday cannot be ordered for, and the shortcuts
/// underneath cover what most people actually want.
class DayPicker extends StatefulWidget {
  const DayPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.maxDays = 31,
  });

  /// The chosen days, `YYYY-MM-DD`.
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  /// How far ahead an order may be placed at once.
  final int maxDays;

  @override
  State<DayPicker> createState() => _DayPickerState();
}

class _DayPickerState extends State<DayPicker> {
  late DateTime _month = DateTime(_today.year, _today.month);

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  void _toggle(DateTime day) {
    final key = dayKeyOf(day);
    final next = {...widget.selected};
    if (!next.remove(key)) {
      if (next.length >= widget.maxDays) return;
      next.add(key);
    }
    widget.onChanged(next);
  }

  void _run(int days, {int from = 0}) {
    final next = <String>{};
    for (var i = from; i < from + days; i++) {
      next.add(dayKeyOf(_today.add(Duration(days: i))));
    }
    widget.onChanged(next);
    setState(() => _month = DateTime(_today.year, _today.month));
  }

  bool get _canGoBack => _month.isAfter(DateTime(_today.year, _today.month));

  @override
  Widget build(BuildContext context) {
    final first = DateTime(_month.year, _month.month);
    final days = daysInMonth(first);
    // Monday first, the way a Pakistani wall calendar reads.
    final lead = first.weekday - 1;
    final limit = _today.add(const Duration(days: 120));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _canGoBack
                  ? () => setState(
                      () => _month = DateTime(_month.year, _month.month - 1),
                    )
                  : null,
              icon: const Icon(Icons.chevron_left, size: 20),
              tooltip: 'Previous month',
            ),
            Expanded(
              child: Text(
                _monthName(first),
                textAlign: TextAlign.center,
                style: T.cardTitle,
              ),
            ),
            IconButton(
              onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month + 1),
              ),
              icon: const Icon(Icons.chevron_right, size: 20),
              tooltip: 'Next month',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: T.meta.copyWith(fontSize: 10),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var week = 0; week * 7 < lead + days; week++)
          Row(
            children: [
              for (var slot = 0; slot < 7; slot++)
                Expanded(
                  child: Builder(
                    builder: (_) {
                      final dayNum = week * 7 + slot - lead + 1;
                      if (dayNum < 1 || dayNum > days) {
                        return const SizedBox(height: 40);
                      }
                      final day = DateTime(first.year, first.month, dayNum);
                      final past = day.isBefore(_today);
                      final tooFar = day.isAfter(limit);
                      return _Day(
                        number: dayNum,
                        on: widget.selected.contains(dayKeyOf(day)),
                        today: day == _today,
                        off: past || tooFar,
                        onTap: past || tooFar ? null : () => _toggle(day),
                      );
                    },
                  ),
                ),
            ],
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _Quick('Today', () => _run(1)),
            _Quick('Tomorrow', () => _run(1, from: 1)),
            _Quick('This week', () => _run(7)),
            _Quick('Next 30 days', () => _run(30)),
            _Quick('Clear', () => widget.onChanged(const {})),
          ],
        ),
      ],
    );
  }

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String _monthName(DateTime d) => '${_months[d.month - 1]} ${d.year}';
}

class _Day extends StatelessWidget {
  const _Day({
    required this.number,
    required this.on,
    required this.today,
    required this.off,
    required this.onTap,
  });

  final int number;
  final bool on;
  final bool today;
  final bool off;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: 40,
      margin: const EdgeInsets.all(1.5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? T.accent700 : Colors.transparent,
        border: Border.all(
          color: on
              ? T.accent700
              : today
              ? T.accent300
              : T.divider,
        ),
      ),
      child: Text(
        '$number',
        style: T.body.copyWith(
          color: on
              ? Colors.white
              : off
              ? T.n400
              : T.n800,
          fontWeight: today && !on ? FontWeight.w600 : null,
        ),
      ),
    ),
  );
}

class _Quick extends StatelessWidget {
  const _Quick(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(border: T.hair),
      child: Text(label, style: T.meta),
    ),
  );
}
