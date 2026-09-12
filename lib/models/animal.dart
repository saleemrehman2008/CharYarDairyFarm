import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers.dart';

/// What kind of animal, which decides the tag letter.
enum Species {
  buffalo('B', 'Buffalo'),
  cow('C', 'Cow'),
  goat('G', 'Goat'),
  qurbani('Q', 'Qurbani'),
  other('X', 'Other');

  const Species(this.tagLetter, this.label);

  /// The letter stamped on the ear tag: B-01, C-04, G-11.
  final String tagLetter;
  final String label;

  static Species parse(Object? v) => switch (s(v)) {
    'buffalo' => Species.buffalo,
    'cow' => Species.cow,
    'goat' => Species.goat,
    'qurbani' => Species.qurbani,
    _ => Species.other,
  };

  /// Only these are worth asking about milk for.
  bool get milks => this == Species.buffalo || this == Species.cow;
}

enum Sex {
  female('Female'),
  male('Male');

  const Sex(this.label);

  final String label;

  static Sex parse(Object? v) => s(v) == 'male' ? Sex.male : Sex.female;
}

/// Where an animal stands today. Sold and dead ones stay in the register —
/// their history, and what they cost, is part of the farm's record.
enum AnimalStatus {
  onFarm('On farm'),
  sold('Sold'),
  dead('Died'),
  slaughtered('Qurbani done');

  const AnimalStatus(this.label);

  final String label;

  static AnimalStatus parse(Object? v) => switch (s(v)) {
    'sold' => AnimalStatus.sold,
    'dead' => AnimalStatus.dead,
    'slaughtered' => AnimalStatus.slaughtered,
    _ => AnimalStatus.onFarm,
  };

  bool get isHere => this == AnimalStatus.onFarm;
}

/// One animal on the farm, from the day it is bought or born.
///
/// The tag is the point of it: a number on the ear that matches a number in
/// the app, so a buffalo can be pointed at and looked up. Everything else —
/// the photo, the mother, the milk, the illnesses, what the IVF cost — hangs
/// off that one number.
class Animal {
  Animal({
    required this.id,
    required this.tag,
    required this.name,
    required this.species,
    required this.sex,
    required this.status,
    required this.photoUrl,
    required this.dailyLitres,
    required this.createdAt,
    this.bornOn,
    this.boughtOn,
    this.price = 0,
    this.motherId,
    this.motherTag,
    this.note = '',
    this.lastEventAt,
    this.nextDueOn,
    this.nextDueWhat,
  });

  final String id;

  /// `B-03`, and what goes on the physical tag.
  final String tag;

  /// What the farm calls her. Optional — the tag is the real name.
  final String name;

  final Species species;
  final Sex sex;
  final AnimalStatus status;
  final String photoUrl;

  /// Litres a day at the last milk reading. Zero for anything not milking.
  final num dailyLitres;

  final DateTime? bornOn;
  final DateTime? boughtOn;

  /// What she cost. Bought animals are an asset of the farm; one born here
  /// costs nothing to acquire.
  final num price;

  /// Born on the farm out of another animal in this register.
  final String? motherId;
  final String? motherTag;

  final String note;
  final DateTime createdAt;

  /// Kept on the animal so the register can be listed without reading every
  /// animal's history.
  final DateTime? lastEventAt;

  /// The next vaccination or check due, so nothing quietly lapses.
  final DateTime? nextDueOn;
  final String? nextDueWhat;

  bool get isMilking => dailyLitres > 0 && status.isHere;
  bool get bornHere => motherId != null;

  /// Overdue or due within the week.
  bool dueSoon([DateTime? now]) {
    final due = nextDueOn;
    if (due == null || !status.isHere) return false;
    final today = now ?? DateTime.now();
    return due.isBefore(DateTime(today.year, today.month, today.day + 8));
  }

  bool overdue([DateTime? now]) {
    final due = nextDueOn;
    if (due == null || !status.isHere) return false;
    final today = now ?? DateTime.now();
    return due.isBefore(DateTime(today.year, today.month, today.day));
  }

  /// "Buffalo · female · 4 yrs" — the line under the tag.
  String get summary {
    final bits = <String>[species.label, sex.label];
    final age = ageLabel;
    if (age != null) bits.add(age);
    return bits.join(' · ');
  }

  /// Age from the date of birth, in years and months, however rough.
  String? get ageLabel {
    final born = bornOn;
    if (born == null) return null;
    final now = DateTime.now();
    var months = (now.year - born.year) * 12 + now.month - born.month;
    if (now.day < born.day) months--;
    if (months < 0) return null;
    if (months < 24) return '$months mo';
    return '${months ~/ 12} yr';
  }

  /// `B-03 Kaali`, or just `B-03` when she has no name.
  String get label => name.isEmpty ? tag : '$tag $name';

  /// Register order: the letter, then the number counted as a number, so B-2
  /// comes before B-10 rather than after it.
  static int byTag(Animal a, Animal b) {
    final ap = a.tag.split('-'), bp = b.tag.split('-');
    if (ap.length < 2 || bp.length < 2) return a.tag.compareTo(b.tag);
    final letters = ap.first.compareTo(bp.first);
    if (letters != 0) return letters;
    final an = int.tryParse(ap.last), bn = int.tryParse(bp.last);
    if (an == null || bn == null) return a.tag.compareTo(b.tag);
    return an.compareTo(bn);
  }

  factory Animal.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return Animal(
      id: doc.id,
      tag: s(m['tag']),
      name: s(m['name']),
      species: Species.parse(m['species']),
      sex: Sex.parse(m['sex']),
      status: AnimalStatus.parse(m['status']),
      photoUrl: s(m['photoUrl']),
      dailyLitres: n(m['dailyLitres']),
      bornOn: dt(m['bornOn']),
      boughtOn: dt(m['boughtOn']),
      price: n(m['price']),
      motherId: m['motherId'] == null ? null : s(m['motherId']),
      motherTag: m['motherTag'] == null ? null : s(m['motherTag']),
      note: s(m['note']),
      createdAt: dtOr(m['createdAt']),
      lastEventAt: dt(m['lastEventAt']),
      nextDueOn: dt(m['nextDueOn']),
      nextDueWhat: m['nextDueWhat'] == null ? null : s(m['nextDueWhat']),
    );
  }
}
