import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers.dart';

/// Where a rider's day stands.
enum RiderDayStatus {
  /// Out on the round, or not started.
  open,

  /// The rider has handed over and is waiting for a founder to take it.
  handedOver,

  /// A founder has counted it and taken it in. The day is closed.
  received;

  static RiderDayStatus parse(Object? v) => switch (s(v)) {
    'handedOver' => RiderDayStatus.handedOver,
    'received' => RiderDayStatus.received,
    _ => RiderDayStatus.open,
  };

  String get label => switch (this) {
    RiderDayStatus.open => 'Out on the round',
    RiderDayStatus.handedOver => 'Waiting to be taken in',
    RiderDayStatus.received => 'Handed in',
  };
}

/// One rider's day: what milk went out with him, what came back, and what
/// money he is holding until a founder takes it.
///
/// Two lines have to close at the end of the day, and the app shows both:
///
/// ```
/// loaded  =  delivered + spot sold + returned      (the milk)
/// cash    =  collected + spot cash − handed in     (the money)
/// ```
///
/// Until a founder marks the handover received, the cash is the rider's
/// responsibility and is kept out of the farm's own cash — the farm cannot
/// spend what is in somebody else's pocket.
class RiderDay {
  RiderDay({
    required this.id,
    required this.riderId,
    required this.riderName,
    required this.dayKey,
    required this.status,
    this.loadedLitres = 0,
    this.deliveredLitres = 0,
    this.spotLitres = 0,
    this.spotCash = 0,
    this.collectedCash = 0,
    this.returnedLitres = 0,
    this.handedCash = 0,
    this.handedTo,
    this.handedToName,
    this.handedAt,
    this.receivedBy,
    this.receivedByName,
    this.receivedAt,
    this.receivedCash = 0,
    this.receivedLitres = 0,
    this.note = '',
    required this.createdAt,
  });

  /// `riderUid_YYYY-MM-DD`, so a day can only ever have one record.
  final String id;
  final String riderId;
  final String riderName;
  final String dayKey;
  final RiderDayStatus status;

  /// What the rider says he took out.
  final num loadedLitres;

  /// Milk actually handed to customers, khaata and orders together. Counted
  /// as it is marked, so it is never a guess at the end of the day.
  final num deliveredLitres;

  /// Sold at the roadside to whoever wanted it. No name, just litres and cash.
  final num spotLitres;
  final num spotCash;

  /// Cash taken at doors — orders paid on delivery. Khaata milk is not here:
  /// nothing is taken for it.
  final num collectedCash;

  /// Brought back to the farm.
  final num returnedLitres;

  /// What the rider says he is handing over.
  final num handedCash;
  final String? handedTo;
  final String? handedToName;
  final DateTime? handedAt;

  /// What the founder actually counted and took.
  final String? receivedBy;
  final String? receivedByName;
  final DateTime? receivedAt;
  final num receivedCash;
  final num receivedLitres;

  final String note;
  final DateTime createdAt;

  /// Money the rider is holding right now.
  num get cashInHand => collectedCash + spotCash - receivedCash;

  /// Milk still unaccounted for: taken out, minus everywhere it went.
  ///
  /// Zero means the day adds up. Anything else is a real gap, and the founder
  /// sees it before taking the money in.
  num get milkUnaccounted =>
      loadedLitres - deliveredLitres - spotLitres - returnedLitres;

  bool get milkAddsUp => milkUnaccounted.abs() < 0.001;

  /// What the rider says he has versus what he says he is handing over.
  num get cashShort => cashInHand - handedCash;

  bool get isOpen => status == RiderDayStatus.open;
  bool get isWaiting => status == RiderDayStatus.handedOver;
  bool get isClosed => status == RiderDayStatus.received;

  /// Nothing has happened on this day yet.
  bool get isEmpty =>
      loadedLitres == 0 &&
      deliveredLitres == 0 &&
      spotLitres == 0 &&
      collectedCash == 0;

  static String idFor(String riderId, String dayKey) => '${riderId}_$dayKey';

  factory RiderDay.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return RiderDay(
      id: doc.id,
      riderId: s(m['riderId']),
      riderName: s(m['riderName']),
      dayKey: s(m['dayKey']),
      status: RiderDayStatus.parse(m['status']),
      loadedLitres: n(m['loadedLitres']),
      deliveredLitres: n(m['deliveredLitres']),
      spotLitres: n(m['spotLitres']),
      spotCash: n(m['spotCash']),
      collectedCash: n(m['collectedCash']),
      returnedLitres: n(m['returnedLitres']),
      handedCash: n(m['handedCash']),
      handedTo: m['handedTo'] == null ? null : s(m['handedTo']),
      handedToName: m['handedToName'] == null ? null : s(m['handedToName']),
      handedAt: dt(m['handedAt']),
      receivedBy: m['receivedBy'] == null ? null : s(m['receivedBy']),
      receivedByName: m['receivedByName'] == null
          ? null
          : s(m['receivedByName']),
      receivedAt: dt(m['receivedAt']),
      receivedCash: n(m['receivedCash']),
      receivedLitres: n(m['receivedLitres']),
      note: s(m['note']),
      createdAt: dtOr(m['createdAt']),
    );
  }
}

/// One line of the load sheet: how many stops want this much milk.
///
/// Grouped by the quantity each stop takes rather than by bag size, because
/// the bags follow the order — three houses on five litres is three fives,
/// and the rider knows how to pack that better than the app does.
class LoadLine {
  const LoadLine({required this.litres, required this.stops});

  final num litres;
  final int stops;

  num get total => litres * stops;
}
