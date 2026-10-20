import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../util/money.dart';
import 'db.dart';
import 'log_service.dart';

/// The wage list: who the farm pays, what it pays them, and since when.
///
/// Every change here is written to the activity log with a name against it,
/// the same as a figure on a co-founder's card. A wage is the one cost the
/// farm pays every month without an invoice to check it against, so the only
/// thing standing behind it is a record somebody wrote down and three other
/// people can read.
class EmployeeRepo {
  EmployeeRepo._();

  static Future<String> add(
    Actor actor, {
    required String name,
    required num basic,
    num allowance = 0,
    String cnic = '',
    String mobile = '',
    DateTime? joinedOn,

    /// Where somebody is written down after he has already gone — the farm
    /// catching up on a man it paid last month and never recorded.
    DateTime? leftOn,
    String note = '',
  }) async {
    final to = name.trim();
    if (to.isEmpty) throw StateError('Who is this?');
    if (basic < 0) throw StateError('A wage cannot be less than nothing.');
    if (allowance < 0) throw StateError('An allowance cannot be negative.');

    final badCnic = cnicWrong(cnic);
    if (badCnic != null) throw StateError(badCnic);
    final badMobile = mobileWrong(mobile);
    if (badMobile != null) throw StateError(badMobile);

    final doc = await Db.employees.add({
      'name': to,
      'cnic': cnicDigits(cnic),
      'mobile': mobileDigits(mobile),
      'basic': basic,
      'allowance': allowance,
      'joinedOn': Timestamp.fromDate(joinedOn ?? DateTime.now()),
      'leftOn': leftOn == null ? null : Timestamp.fromDate(leftOn),
      'note': note.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await Log.write(
      actor,
      LogKind.settings,
      'put $to on the wage list at ${rs(basic + allowance)} a month',
      refType: 'employee',
      refId: doc.id,
    );
    return doc.id;
  }

  /// Correcting the record, and raising a wage.
  ///
  /// A raise is the same act as a correction as far as the books go, and
  /// both go in the log with what the figure was before — which is the half
  /// of it the farm will want in six months, when somebody asks what he was
  /// on last year.
  static Future<void> edit(
    Actor actor,
    Employee who, {
    String? name,
    num? basic,
    num? allowance,
    String? cnic,
    String? mobile,
    DateTime? joinedOn,
    String? note,

    /// His last day, and whether to take it off again.
    ///
    /// The day a man leaves gets typed from memory a week later and it gets
    /// typed wrong, and it is the one date his last wage is worked out from.
    /// It has to be correctable like any other figure here.
    DateTime? leftOn,
    bool stillHere = false,
  }) async {
    final to = (name ?? who.name).trim();
    if (to.isEmpty) throw StateError('Who is this?');
    if ((basic ?? who.basic) < 0) {
      throw StateError('A wage cannot be less than nothing.');
    }
    if ((allowance ?? who.allowance) < 0) {
      throw StateError('An allowance cannot be negative.');
    }
    if (cnic != null) {
      final bad = cnicWrong(cnic);
      if (bad != null) throw StateError(bad);
    }
    if (mobile != null) {
      final bad = mobileWrong(mobile);
      if (bad != null) throw StateError(bad);
    }

    // A man cannot leave before he arrives, and a last month worked out
    // from those two dates would come to nothing while looking fine.
    final starts = joinedOn ?? who.joinedOn;
    if (!stillHere && leftOn != null && leftOn.isBefore(starts)) {
      throw StateError('He cannot have left before he started.');
    }

    final was = who.monthly;
    await Db.employees.doc(who.id).update({
      'name': to,
      if (cnic != null) 'cnic': cnicDigits(cnic),
      if (mobile != null) 'mobile': mobileDigits(mobile),
      'basic': ?basic,
      'allowance': ?allowance,
      if (joinedOn != null) 'joinedOn': Timestamp.fromDate(joinedOn),
      if (note != null) 'note': note.trim(),
      if (stillHere)
        'leftOn': null
      else if (leftOn != null)
        'leftOn': Timestamp.fromDate(leftOn),
    });

    final now = (basic ?? who.basic) + (allowance ?? who.allowance);
    final leftChanged =
        stillHere ||
        (leftOn != null &&
            (who.leftOn == null || !_sameDay(leftOn, who.leftOn!)));

    await Log.write(
      actor,
      LogKind.settings,
      leftChanged
          ? (stillHere
                ? '$to is back on the wage list'
                : 'set $to\'s last day to ${fmtDate(leftOn!)}')
          : now == was
          ? 'changed the record for $to on the wage list'
          : 'changed $to from ${rs(was)} a month to ${rs(now)}',
      refType: 'employee',
      refId: who.id,
    );
  }

  /// He has left.
  ///
  /// The record stays. He was paid for the months he worked and those
  /// payments sit in months that are closed; taking the record away would
  /// leave those figures pointing at nobody.
  static Future<void> left(Actor actor, Employee who, {DateTime? on}) async {
    final day = on ?? DateTime.now();
    await Db.employees.doc(who.id).update({'leftOn': Timestamp.fromDate(day)});
    await Log.write(
      actor,
      LogKind.settings,
      '${who.name} left the farm on ${fmtDate(day)}',
      refType: 'employee',
      refId: who.id,
    );
  }

  /// He is back, or he never left and somebody tapped the wrong row.
  static Future<void> backOn(Actor actor, Employee who) async {
    await Db.employees.doc(who.id).update({'leftOn': null});
    await Log.write(
      actor,
      LogKind.settings,
      '${who.name} is back on the wage list',
      refType: 'employee',
      refId: who.id,
    );
  }

  /// Master only, and only for a record nothing has ever been paid against.
  ///
  /// A duplicate typed in twice on the same morning is worth removing. One
  /// with a wage behind it is not — see [left].
  static Future<void> remove(Actor actor, Employee who) async {
    await Db.employees.doc(who.id).delete();
    await Log.write(
      actor,
      LogKind.settings,
      'took ${who.name} off the wage list',
      refType: 'employee',
      refId: who.id,
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static Stream<List<Employee>> watch() => Db.employees.snapshots().map(
    (s) => onTheBooks([for (final d in s.docs) Employee.fromDoc(d)]),
  );
}
