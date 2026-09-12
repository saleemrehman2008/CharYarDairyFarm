import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers.dart';

/// The things that happen to an animal and are worth writing down.
enum EventKind {
  illness('Fell ill', true),
  treatment('Treatment', true),
  vaccination('Vaccination', true),
  calving('Gave birth', false),
  insemination('Insemination / IVF', true),
  pregnancyCheck('Pregnancy check', true),
  milkReading('Milk reading', false),
  weight('Weight', false),
  bought('Bought', true),
  sold('Sold', false),
  died('Died', false),
  note('Note', true);

  const EventKind(this.label, this.costable);

  final String label;

  /// Whether this kind normally costs the farm money. A milk reading does not;
  /// a vet visit does.
  final bool costable;

  static EventKind parse(Object? v) => switch (s(v)) {
    'illness' => EventKind.illness,
    'treatment' => EventKind.treatment,
    'vaccination' => EventKind.vaccination,
    'calving' => EventKind.calving,
    'insemination' => EventKind.insemination,
    'pregnancyCheck' => EventKind.pregnancyCheck,
    'milkReading' => EventKind.milkReading,
    'weight' => EventKind.weight,
    'bought' => EventKind.bought,
    'sold' => EventKind.sold,
    'died' => EventKind.died,
    _ => EventKind.note,
  };

  /// Kinds a person picks from when adding an entry by hand. Bought, sold and
  /// died are written by the register itself, not chosen from a list.
  static const chooseable = [
    EventKind.illness,
    EventKind.treatment,
    EventKind.vaccination,
    EventKind.calving,
    EventKind.insemination,
    EventKind.pregnancyCheck,
    EventKind.milkReading,
    EventKind.weight,
    EventKind.note,
  ];

  /// Vaccinations and pregnancy checks come round again; the form offers a
  /// next date for these.
  bool get repeats =>
      this == EventKind.vaccination || this == EventKind.pregnancyCheck;
}

/// One line in an animal's history.
///
/// Anything that cost money can carry the id of the expense it was booked as,
/// so the farm's books and the animal's record are never two different
/// stories about the same rupees.
class AnimalEvent {
  AnimalEvent({
    required this.id,
    required this.animalId,
    required this.animalTag,
    required this.kind,
    required this.date,
    required this.what,
    required this.cost,
    required this.createdAt,
    this.litres = 0,
    this.weightKg = 0,
    this.txnId,
    this.photoUrl = '',
    this.thumb = '',
    this.nextDueOn,
    this.calfId,
    this.calfTag,
    this.byName = '',
  });

  final String id;
  final String animalId;
  final String animalTag;
  final EventKind kind;
  final DateTime date;

  /// What happened, in the farm's own words: "mastitis, left quarter".
  final String what;

  /// What it cost the farm. Zero when it cost nothing.
  final num cost;

  /// Litres, on a milk reading.
  final num litres;
  final num weightKg;

  /// The expense this was booked as, when it cost money.
  final String? txnId;

  final String photoUrl;

  /// The small picture kept on the entry itself.
  final String thumb;

  /// When the next dose or check falls due.
  final DateTime? nextDueOn;

  /// The calf, on a birth.
  final String? calfId;
  final String? calfTag;

  /// Who wrote it down.
  final String byName;

  final DateTime createdAt;

  bool get hasCost => cost > 0;
  bool get isBooked => txnId != null && txnId!.isNotEmpty;

  factory AnimalEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return AnimalEvent(
      id: doc.id,
      animalId: s(m['animalId']),
      animalTag: s(m['animalTag']),
      kind: EventKind.parse(m['kind']),
      date: dtOr(m['date']),
      what: s(m['what']),
      cost: n(m['cost']),
      litres: n(m['litres']),
      weightKg: n(m['weightKg']),
      txnId: m['txnId'] == null ? null : s(m['txnId']),
      photoUrl: s(m['photoUrl']),
      thumb: s(m['thumb']),
      nextDueOn: dt(m['nextDueOn']),
      calfId: m['calfId'] == null ? null : s(m['calfId']),
      calfTag: m['calfTag'] == null ? null : s(m['calfTag']),
      byName: s(m['byName']),
      createdAt: dtOr(m['createdAt']),
    );
  }
}
