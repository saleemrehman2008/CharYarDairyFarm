import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers.dart';

/// Somebody the farm pays a wage to.
///
/// Not a co-founder and not a user of the app: a man who milks, feeds and
/// cleans, and takes a wage at the end of the month. The farm has been paying
/// them by typing a name into the salary entry every time, which means a
/// month where somebody typed "Jalbani" and a month where somebody typed
/// "jalbani sb" are two different men as far as the books are concerned, and
/// neither of them has a wage on record to check the payment against.
///
/// So they are written down once: what they are owed a month, when they
/// started, and — when it comes to it — when they left. The salary entry then
/// picks a name off that list and works the figure out from the record rather
/// than from memory.
class Employee {
  Employee({
    required this.id,
    required this.name,
    this.cnic = '',
    this.mobile = '',
    required this.basic,
    this.allowance = 0,
    required this.joinedOn,
    this.leftOn,
    this.note = '',
    required this.createdAt,
  });

  final String id;
  final String name;

  /// Thirteen digits, kept without its dashes.
  ///
  /// Stored bare because that is the only form two people typing the same
  /// card number will agree on — see [cnicDigits]. It is shown with its
  /// dashes wherever it is read.
  final String cnic;

  /// Eleven digits beginning 03, kept without its dash.
  final String mobile;

  /// The wage itself, before anything is added to or taken off it.
  final num basic;

  /// Whatever is paid on top every month — tea, fuel, a room.
  ///
  /// Kept apart from [basic] rather than rolled into it because a day's
  /// absence is worked out from the month's whole pay, and because the two
  /// are argued about separately when a wage is raised.
  final num allowance;

  final DateTime joinedOn;

  /// The day he stopped working here, if he has.
  ///
  /// A man who leaves is not deleted. He was paid for the months he worked
  /// and those payments are in a closed month's figures; taking his record
  /// away would leave them pointing at nobody.
  final DateTime? leftOn;

  final String note;
  final DateTime createdAt;

  /// What a full month comes to.
  num get monthly => basic + allowance;

  bool get isWorking => leftOn == null;

  /// How long a month actually is: 28, 29, 30 or 31.
  ///
  /// The farm used to count every month as thirty. It is the convention
  /// everybody knows, and it is wrong in both directions: a full February
  /// came out at 22,400 of a 24,000 wage, short by sixteen hundred rupees
  /// of a man's money, and a full 31-day month had to be capped on the way
  /// past to stop it paying more than a month's wage for a month's work.
  ///
  /// A wage is a wage. Twenty-four thousand is twenty-four thousand whether
  /// the month is February or October — so a whole month pays the whole
  /// wage, and a part month is worked out against that month's own length.
  /// Over a year each month pays the same and every part of one is fair to
  /// the day.
  static int lengthOf(DateTime anyDayInIt) =>
      DateTime(anyDayInIt.year, anyDayInIt.month + 1, 0).day;

  /// How many days of a window he was actually on the farm.
  ///
  /// A man taken on partway through the month, or one who left partway
  /// through it, is owed for the days he was here and no more. The farm was
  /// counting these on its fingers — "rakha 7 October ko, last day 19
  /// October" — and his record already holds both dates, so it can count
  /// them itself.
  ///
  /// Both ends count as worked: a man who starts on the 7th and leaves on
  /// the 19th was here on the 7th and on the 19th, which is thirteen days.
  int daysOnIn(DateTime from, DateTime to) {
    final start = _day(joinedOn).isAfter(_day(from))
        ? _day(joinedOn)
        : _day(from);
    final end = leftOn != null && _day(leftOn!).isBefore(_day(to))
        ? _day(leftOn!)
        : _day(to);
    if (end.isBefore(start)) return 0;
    return end.difference(start).inDays + 1;
  }

  /// Every month a run of days touches, each with its own first and last day.
  static List<(DateTime, DateTime)> monthsBetween(DateTime from, DateTime to) {
    final out = <(DateTime, DateTime)>[];
    var cursor = DateTime(from.year, from.month, 1);
    final last = DateTime(to.year, to.month, 1);
    while (!cursor.isAfter(last)) {
      out.add((cursor, DateTime(cursor.year, cursor.month + 1, 0)));
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
      if (out.length > 60) break; // nobody is paid five years in one go
    }
    return out;
  }

  /// What he is owed for a run of days, which need not be one month.
  ///
  /// Two things the farm asked for, and they are the same sum.
  ///
  /// A payment can cover more than a month: a man taken on on the 20th of
  /// October, paid at the end of November for the whole of it, so that the
  /// advance he drew in October comes off the same payment. Asked a month at
  /// a time, that advance sat in a month nobody was paying for.
  ///
  /// And a whole month pays a whole wage whatever its length. Each month in
  /// the run is asked on its own, against its own number of days, so a
  /// February he worked right through pays the same as an October — and
  /// twelve days of a 31-day October are twelve thirty-firsts of a wage.
  ///
  /// [daysOff] is leave taken out of the whole run. It comes off at the rate
  /// of the month the payment is made in, and off the month's whole pay —
  /// the allowance with the wage, because a day's absence is a day of the
  /// month and taking it off the basic alone would quietly pay a man who was
  /// away more per working day than one who was not.
  num payForWindow({
    required DateTime from,
    required DateTime to,
    int daysOff = 0,
  }) {
    var whole = 0 as num;
    for (final (monthStart, monthEnd) in monthsBetween(from, to)) {
      final a = monthStart.isBefore(from) ? from : monthStart;
      final b = monthEnd.isAfter(to) ? to : monthEnd;
      final on = daysOnIn(a, b);
      if (on <= 0) continue;

      final len = monthEnd.day;
      whole += on >= len ? monthly : monthly * on / len;
    }
    if (whole <= 0) return 0;

    final cut = daysOff > 0 ? monthly * daysOff / lengthOf(to) : 0;
    final left = whole - cut;
    return left <= 0 ? 0 : left.round();
  }

  /// How many days of a run of days he was actually here.
  int daysOnBetween(DateTime from, DateTime to) {
    var days = 0;
    for (final (monthStart, monthEnd) in monthsBetween(from, to)) {
      final a = monthStart.isBefore(from) ? from : monthStart;
      final b = monthEnd.isAfter(to) ? to : monthEnd;
      days += daysOnIn(a, b);
    }
    return days;
  }

  /// What a run of days has taken off a whole month's pay.
  num cutForWindow({
    required DateTime from,
    required DateTime to,
    int daysOff = 0,
  }) => monthly - payForWindow(from: from, to: to, daysOff: daysOff);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  Map<String, dynamic> toMap() => {
    'name': name,
    'cnic': cnic,
    'mobile': mobile,
    'basic': basic,
    'allowance': allowance,
    'joinedOn': Timestamp.fromDate(joinedOn),
    'leftOn': leftOn == null ? null : Timestamp.fromDate(leftOn!),
    'note': note,
  };

  factory Employee.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return Employee(
      id: doc.id,
      name: s(m['name']),
      cnic: s(m['cnic']),
      mobile: s(m['mobile']),
      basic: n(m['basic']),
      allowance: n(m['allowance']),
      joinedOn: dtOr(m['joinedOn']),
      leftOn: dt(m['leftOn']),
      note: s(m['note']),
      createdAt: dtOr(m['createdAt']),
    );
  }

  Employee copyWith({
    String? name,
    String? cnic,
    String? mobile,
    num? basic,
    num? allowance,
    DateTime? joinedOn,
    DateTime? leftOn,
    bool clearLeft = false,
    String? note,
  }) => Employee(
    id: id,
    name: name ?? this.name,
    cnic: cnic ?? this.cnic,
    mobile: mobile ?? this.mobile,
    basic: basic ?? this.basic,
    allowance: allowance ?? this.allowance,
    joinedOn: joinedOn ?? this.joinedOn,
    leftOn: clearLeft ? null : (leftOn ?? this.leftOn),
    note: note ?? this.note,
    createdAt: createdAt,
  );
}

// ---- the two numbers Pakistan writes a particular way ----

/// Just the digits, so two spellings of one card number are one number.
///
/// A CNIC gets typed with dashes, with spaces, or with neither, and a record
/// keyed on what somebody typed would hold the same man three times. Every
/// comparison and everything stored goes through here.
String cnicDigits(String v) => v.replaceAll(RegExp(r'[^0-9]'), '');

/// 42101-1234567-1, which is how it is printed on the card itself.
String cnicShown(String v) {
  final d = cnicDigits(v);
  if (d.length != 13) return v.trim();
  return '${d.substring(0, 5)}-${d.substring(5, 12)}-${d.substring(12)}';
}

/// Thirteen digits, and the first one is never a zero.
///
/// That first digit is the province the card was issued in — 1 through 7 —
/// so a number starting 0 is a typing slip rather than somebody from an
/// unusual place. Blank is allowed: a farm hand may genuinely not have his
/// card to hand on the day he is written down, and refusing to record him
/// until he does is how he ends up unrecorded.
String? cnicWrong(String v) {
  final d = cnicDigits(v);
  if (d.isEmpty) return null;
  if (d.length != 13) return 'A CNIC is 13 digits. This one has ${d.length}.';
  if (d.startsWith('0')) return 'No CNIC starts with a zero.';
  return null;
}

String mobileDigits(String v) => v.replaceAll(RegExp(r'[^0-9]'), '');

/// 0300-1234567.
String mobileShown(String v) {
  final d = mobileDigits(v);
  if (d.length != 11) return v.trim();
  return '${d.substring(0, 4)}-${d.substring(4)}';
}

/// Eleven digits beginning 03.
///
/// Every mobile number in Pakistan does, and a farm number that does not is
/// a landline typed into the wrong box or a digit dropped. Blank is allowed
/// for the same reason as the CNIC.
String? mobileWrong(String v) {
  final d = mobileDigits(v);
  if (d.isEmpty) return null;
  if (!d.startsWith('03')) return 'A mobile number starts 03.';
  if (d.length != 11) {
    return 'A mobile number is 11 digits. This one has ${d.length}.';
  }
  return null;
}

/// What is actually handed to a man on payday.
///
/// The wage for the days being paid for, less what he has already drawn
/// against them, and never less than nothing.
///
/// Written here rather than in either place that needs it. The card shows
/// this figure and the entry form saves it, and while they each worked it
/// out for themselves they agreed — which is true of every figure this app
/// has ever ended up giving two answers to, right up until it was not.
num wageToHand({
  required Employee who,
  required DateTime from,
  required DateTime to,
  int daysOff = 0,
  num drawn = 0,
  bool wagePaidAlready = false,
}) {
  final wage = who.payForWindow(from: from, to: to, daysOff: daysOff);

  // Once the wage is on the books the advance has come off it once, and
  // taking it off again would hand him the same deduction twice.
  final off = wagePaidAlready ? 0 : drawn;
  final left = wage - off;
  return left < 0 ? 0 : left;
}

/// Who is on the wage list today, the longest-serving first.
///
/// The ones who have left go to the bottom rather than off the page: their
/// wages are in months that are closed, and a figure whose name has vanished
/// is the kind of thing that costs an evening to work out two years later.
List<Employee> onTheBooks(List<Employee> all) {
  final out = [...all];
  out.sort((a, b) {
    if (a.isWorking != b.isWorking) return a.isWorking ? -1 : 1;
    return a.joinedOn.compareTo(b.joinedOn);
  });
  return out;
}

/// What the farm is committed to in wages every month.
num monthlyWageBill(List<Employee> all) =>
    all.where((e) => e.isWorking).fold<num>(0, (a, e) => a + e.monthly);
