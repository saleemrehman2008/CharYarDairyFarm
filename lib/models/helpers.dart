import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore values arrive loosely typed; these keep the models tidy.
DateTime? dt(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

DateTime dtOr(Object? v, [DateTime? fallback]) =>
    dt(v) ?? fallback ?? DateTime.now();

num n(Object? v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
int i(Object? v) => n(v).round();
double d(Object? v) => n(v).toDouble();
String s(Object? v) => v is String ? v : '';
bool b(Object? v) => v == true;

/// `YYYY-MM` id for a date, in the farm's own calendar.
String monthIdOf(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

/// `YYYY-MM-DD` for one day, which is how a day is written down and matched.
String dayKeyOf(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// A `YYYY-MM-DD` back into a date, for showing it.
DateTime? dayFromKey(String key) => DateTime.tryParse(key);

/// A Firestore list field as strings, however it comes back.
List<String> strings(Object? v) => v is List
    ? v.map((e) => '$e').where((e) => e.isNotEmpty).toList()
    : const [];

/// How many days this date's month has — 28, 29, 30 or 31. Day zero of next
/// month is the last day of this one.
int daysInMonth(DateTime date) => DateTime(date.year, date.month + 1, 0).day;

/// True on the 30th of September, the 31st of October, the 28th of February —
/// whichever day happens to end that month. Bills fall due on it.
bool isLastDayOfMonth(DateTime date) => date.day == daysInMonth(date);
