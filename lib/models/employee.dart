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

  /// What he is owed for a month he was away part of.
  ///
  /// A thirty-day month whatever the calendar says, because that is how the
  /// farm has always counted it and how the man expects it to be counted.
  /// Arguing that February should divide by 28 costs more in trust than it
  /// saves in rupees.
  num payFor({int daysOff = 0}) {
    if (daysOff <= 0) return monthly;
    if (daysOff >= 30) return 0;
    final cut = monthly * daysOff / 30;
    return (monthly - cut).round();
  }

  /// What a given number of days off takes off the wage.
  num cutFor({int daysOff = 0}) => monthly - payFor(daysOff: daysOff);

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
