import 'package:intl/intl.dart';

import '../models/models.dart';

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

/// Nought to ninety-nine, the way it is said out loud. Urdu has its own word
/// for every one of them — none of it is built out of tens and units — so
/// there is no shorter way to hold this than to list it.
const _spoken = [
  'sifar',
  'ek',
  'do',
  'teen',
  'chaar',
  'paanch',
  'chhe',
  'saat',
  'aath',
  'nau',
  'das',
  'gyarah',
  'barah',
  'terah',
  'chaudah',
  'pandrah',
  'solah',
  'satrah',
  'atharah',
  'unnees',
  'bees',
  'ikkees',
  'bais',
  'teis',
  'chaubees',
  'pachees',
  'chhabees',
  'sattais',
  'atthais',
  'untees',
  'tees',
  'ikattees',
  'battees',
  'taintees',
  'chauntees',
  'paintees',
  'chhattees',
  'saintees',
  'adhtees',
  'untaalees',
  'chalees',
  'iktalees',
  'bayalees',
  'tentalees',
  'chawalees',
  'paintalees',
  'chhiyalees',
  'saintalees',
  'adhtalees',
  'unchaas',
  'pachaas',
  'ikyawan',
  'bawan',
  'tirpan',
  'chauwan',
  'pachpan',
  'chhappan',
  'sattawan',
  'atthawan',
  'unsath',
  'saath',
  'iksath',
  'basath',
  'tirsath',
  'chausath',
  'painsath',
  'chhiyasath',
  'sarsath',
  'arsath',
  'unhattar',
  'sattar',
  'ikhattar',
  'bahattar',
  'tihattar',
  'chauhattar',
  'pachhattar',
  'chhihattar',
  'sathattar',
  'athhattar',
  'unasi',
  'assi',
  'ikyasi',
  'bayasi',
  'tirasi',
  'chaurasi',
  'pachasi',
  'chhiyasi',
  'satasi',
  'athasi',
  'nawasi',
  'nawway',
  'ikyanway',
  'banway',
  'tiranway',
  'chauranway',
  'pachanway',
  'chhiyanway',
  'satanway',
  'athanway',
  'ninyanway',
];

/// An amount written out the way it would be said, or put on a receipt:
/// `Rs 1,20,000` reads back as "Ek lakh bees hazaar rupay".
///
/// Crore, lakh, hazaar, sau — the Pakistani scale, not the western one, so a
/// hundred thousand is a lakh and not "one hundred thousand". Money is counted
/// out loud here before it is written down, and a figure the farm can say is a
/// figure it can check.
String rsInWords(num value) {
  var left = value.abs().round();
  if (left == 0) return 'sifar rupay';

  final parts = <String>[];
  void take(int size, String name) {
    final count = left ~/ size;
    if (count == 0) return;
    parts.add('${_spoken[count]} $name');
    left -= count * size;
  }

  take(10000000, 'crore');
  take(100000, 'lakh');
  take(1000, 'hazaar');
  take(100, 'sau');
  if (left > 0) parts.add(_spoken[left]);

  final said = '${parts.join(' ')} rupay';
  final sentence = said[0].toUpperCase() + said.substring(1);
  return value < 0 ? 'Manfi $said' : sentence;
}

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
  // A second period inside one month is `2026-09b`, so the month part can
  // carry a letter. Read the digits and ignore the rest.
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
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

/// The id for the period that opens when `monthId` is sealed on `sealedOn`.
///
/// Settle on the last day of the month and the next period is next month, as
/// it always was. Settle in the middle and the rest of the month is a period
/// of its own, so September gets `2026-09b`, then `2026-09c`. The letters sort
/// after the bare id and before the next month, which is what the "oldest open
/// period" lookup relies on.
String nextPeriodId(String monthId, DateTime sealedOn) {
  if (isLastDayOfMonth(sealedOn)) return nextMonthId(monthId);

  final parts = monthId.split('-');
  if (parts.length < 2) return nextMonthId(monthId);
  final stem = '${parts[0]}-${parts[1].replaceAll(RegExp(r'[^0-9]'), '')}';
  final suffix = parts[1].replaceAll(RegExp(r'[^a-z]'), '');
  // '' -> 'b', 'b' -> 'c'. Twenty-five settlements in one month is not a
  // thing, but wrapping to the next month beats writing '{'.
  if (suffix.isEmpty) return '${stem}b';
  final next = suffix.codeUnitAt(suffix.length - 1) + 1;
  if (next > 'z'.codeUnitAt(0)) return nextMonthId(monthId);
  return stem + String.fromCharCode(next);
}

/// The days a period actually covered, written out in full.
///
/// The name alone is not enough on the line that marks where a period ended:
/// "September 2026" does not say whether that ran to the 30th or to the 14th,
/// and that is exactly what somebody reading down the ledger wants to know.
String periodDates(FarmMonth period) {
  final from = period.from;
  if (from == null) return '';
  final to = period.to;
  if (to == null) return fmtDateFull(from);
  return '${fmtDateFull(from)} — ${fmtDateFull(to)}';
}

/// What to call a period on screen.
///
/// A whole calendar month is just its name. Anything shorter is named by the
/// days it covers, because "September" would be a lie on a period that ran to
/// the 14th.
String periodLabel(FarmMonth period, {bool short = false}) {
  final from = period.from;
  final to = period.to ?? (period.isOpen ? DateTime.now() : null);
  final name = short ? monthShort(period.id) : monthName(period.id);

  if (from == null) return name;
  final wholeMonth =
      from.day == 1 &&
      (to == null || (isLastDayOfMonth(to) && to.month == from.month));
  if (wholeMonth) return name;

  // Inside one month the month is said once, at the end: "1–14 Sep 2026".
  // Across two it goes on both days: "28 Sep–3 Oct".
  final sameMonth =
      to != null && to.month == from.month && to.year == from.year;
  final start = sameMonth ? '${from.day}' : _dayMonth.format(from);
  final end = to == null
      ? 'now'
      : sameMonth
      ? '${to.day}'
      : _dayMonth.format(to);
  return '$start–$end${sameMonth ? ' ${_monthShort.format(from)}' : ''}';
}
