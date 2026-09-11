import 'package:intl/intl.dart';

/// Pakistani grouping: the last three digits, then pairs — `Rs 1,23,456`.
String groupPk(num value) {
  final neg = value < 0;
  final whole = value.abs().round().toString();
  if (whole.length <= 3) return neg ? '-$whole' : whole;

  final tail = whole.substring(whole.length - 3);
  var head = whole.substring(0, whole.length - 3);
  final parts = <String>[];
  while (head.length > 2) {
    parts.insert(0, head.substring(head.length - 2));
    head = head.substring(0, head.length - 2);
  }
  if (head.isNotEmpty) parts.insert(0, head);

  final out = '${parts.join(',')},$tail';
  return neg ? '-$out' : out;
}

/// `Rs 1,23,456`
String rs(num value) => 'Rs ${groupPk(value)}';

/// `+ Rs 1,23,456` / `− Rs 1,23,456` for the accounts table.
String signedRs(num value, {required bool incoming}) =>
    '${incoming ? '+' : '−'} ${rs(value.abs())}';

/// Quantities drop a trailing `.0`.
String qty(num value) =>
    value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);

final _dayMonth = DateFormat('d MMM');
final _dayMonthYear = DateFormat('d MMM yyyy');
final _monthName = DateFormat('MMMM yyyy');
final _monthShort = DateFormat('MMM yyyy');
final _timeStamp = DateFormat('d MMM, h:mm a');

String fmtDate(DateTime d) => d.year == DateTime.now().year
    ? _dayMonth.format(d)
    : _dayMonthYear.format(d);

String fmtDateFull(DateTime d) => _dayMonthYear.format(d);

String fmtStamp(DateTime d) => _timeStamp.format(d);

/// `2026-09` -> `September 2026`
String monthName(String monthId) {
  final d = _parseMonthId(monthId);
  return d == null ? monthId : _monthName.format(d);
}

/// `2026-09` -> `Sep 2026`
String monthShort(String monthId) {
  final d = _parseMonthId(monthId);
  return d == null ? monthId : _monthShort.format(d);
}

DateTime? _parseMonthId(String monthId) {
  final parts = monthId.split('-');
  if (parts.length < 2) return null;
  final y = int.tryParse(parts[0]), m = int.tryParse(parts[1]);
  if (y == null || m == null) return null;
  return DateTime(y, m);
}

/// The month after `monthId`, as an id.
String nextMonthId(String monthId) {
  final d = _parseMonthId(monthId) ?? DateTime.now();
  final next = DateTime(d.year, d.month + 1);
  return '${next.year.toString().padLeft(4, '0')}-'
      '${next.month.toString().padLeft(2, '0')}';
}
