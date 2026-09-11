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
