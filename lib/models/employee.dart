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
    this.allowanceFor = '',
    this.loanMonthly = 0,
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

  /// What the allowance is for, in the farm's own words — doodh, chai,
  /// kamra, petrol.
  ///
  /// An allowance with no name is a figure nobody can argue with six
  /// months later, and on this farm every figure has to be one somebody
  /// can be asked about. It rides along onto the wage and onto the slip,
  /// so the man being paid reads the same words the record carries.
  final String allowanceFor;

  /// What was agreed, when a loan was given him, to come off each month.
  ///
  /// Offered on the wage and never imposed: the farm may want to take
  /// less this month, and what it leaves stays on his name. Zero means
  /// nothing was agreed, and the box opens empty.
  final num loanMonthly;

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

  /// What one day of his is worth.
  ///
  /// A month over thirty, whatever month it is. The farm chose this over
  /// counting each month against its own length, and chose it knowing what
  /// it costs: half of February comes out at fourteen thousand rather than
  /// fifteen. What it buys is a figure the farm can check on its fingers —
  /// thirty thousand a month is a thousand a day — and a wage a man can
  /// check for himself is worth more here than the last rupee of
  /// proportion.
  ///
  /// A whole month is never worked out from this. It pays the whole wage,
  /// so a 31-day month does not pay thirty-one thousand and a February
  /// does not pay twenty-eight.
  static const daysInAWageMonth = 30;

  num get aDay => monthly / daysInAWageMonth;

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

      // A whole month pays the whole wage whatever its length; a part of
      // one is counted a day at a time at the flat rate.
      final len = monthEnd.day;
      whole += on >= len ? monthly : aDay * on;
    }
    if (whole <= 0) return 0;

    // Leave comes off at the same flat rate the days are paid at.
    final cut = daysOff > 0 ? aDay * daysOff : 0;
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

  /// The day his next month begins, counting from one that has.
  ///
  /// The same day of the next month, held to that month's last day: a man
  /// taken on the 31st of January begins his next on the 28th of February,
  /// because there is no 31st to begin it on.
  static DateTime _nextCycle(DateTime from) {
    final len = DateTime(from.year, from.month + 2, 0).day;
    final day = from.day > len ? len : from.day;
    return DateTime(from.year, from.month + 1, day);
  }

  /// What he has earned from the day he started up to [to], both counted.
  ///
  /// Every whole month of his own pays a whole wage, whatever the calendar
  /// says that run holds — the farm settled that and it holds here: 20
  /// October to 19 November is thirty-one days and one month's pay. What
  /// is left over at the end, short of a whole month, is counted a day at
  /// a time at [aDay].
  ///
  /// The day he left, if he has, is the furthest this goes — settling a
  /// man up to today when he stopped three weeks ago would pay him for
  /// three weeks he was not here.
  num earnedTo(DateTime to) {
    final start = _day(joinedOn);
    var end = _day(to);
    if (leftOn != null && _day(leftOn!).isBefore(end)) end = _day(leftOn!);
    if (end.isBefore(start)) return 0;

    var earned = 0 as num;
    var cursor = start;
    // A man is not paid five years in one go, and a loop over his wages
    // should not be the thing that hangs the phone if a date goes wrong.
    for (var guard = 0; guard < 600; guard++) {
      final next = _nextCycle(cursor);
      final last = next.subtract(const Duration(days: 1));
      if (!last.isAfter(end)) {
        earned += monthly;
        cursor = next;
        continue;
      }
      earned += aDay * (end.difference(cursor).inDays + 1);
      break;
    }
    return earned.round();
  }

  /// How many days he has been here, from his first to [to], both counted.
  int daysTo(DateTime to) {
    final start = _day(joinedOn);
    var end = _day(to);
    if (leftOn != null && _day(leftOn!).isBefore(end)) end = _day(leftOn!);
    if (end.isBefore(start)) return 0;
    return end.difference(start).inDays + 1;
  }

  /// The run of days his wage for the month ending in [anyDayInIt] covers.
  ///
  /// Named by the month it ends in, which is what the farm calls it: a man
  /// taken on the 20th works 20 October to 19 November and is paid
  /// November's wage for it. A man taken on the first works the calendar
  /// month, and nothing about him changes.
  ({DateTime from, DateTime to}) cycleEndingIn(DateTime anyDayInIt) {
    final d = joinedOn.day;
    if (d == 1) {
      return (
        from: DateTime(anyDayInIt.year, anyDayInIt.month, 1),
        to: DateTime(anyDayInIt.year, anyDayInIt.month + 1, 0),
      );
    }
    final thisLen = DateTime(anyDayInIt.year, anyDayInIt.month + 1, 0).day;
    final prevLen = DateTime(anyDayInIt.year, anyDayInIt.month, 0).day;
    return (
      from: DateTime(
        anyDayInIt.year,
        anyDayInIt.month - 1,
        d > prevLen ? prevLen : d,
      ),
      to: DateTime(
        anyDayInIt.year,
        anyDayInIt.month,
        d - 1 > thisLen ? thisLen : d - 1,
      ),
    );
  }

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
      allowanceFor: s(m['allowanceFor']),
      loanMonthly: n(m['loanMonthly']),
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
    String? allowanceFor,
    num? loanMonthly,
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
    allowanceFor: allowanceFor ?? this.allowanceFor,
    loanMonthly: loanMonthly ?? this.loanMonthly,
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

/// How much of a standing advance a wage actually takes off.
///
/// [asked] is what somebody typed, and it is held to two things it cannot
/// go past. It cannot be more than he owes: typing fifty thousand against
/// a sixteen thousand advance would have the farm recover money it never
/// advanced and under-pay a man by the difference. And it cannot be more
/// than the wage can carry: above that it is not a deduction but a figure,
/// and the part the wage could not reach has to stay owed.
///
/// Zero is a real answer, and the common one the farm asked for: leave the
/// advance alone this month and let it come off a later wage. Nothing is
/// lost by it — what is not recovered is still owed, and the next wage
/// finds it.
///
/// One function because the figure is needed in three places — the card
/// that shows it, the box it is typed in, and the entry that is saved —
/// and three clamps against three slightly different wages is exactly how
/// this app has ever come to show one number and store another.
num advanceComingOff({
  required num asked,
  required num owed,
  required num wage,
}) {
  if (asked <= 0 || owed <= 0 || wage <= 0) return 0;
  final ceiling = owed < wage ? owed : wage;
  return asked > ceiling ? ceiling : asked;
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
