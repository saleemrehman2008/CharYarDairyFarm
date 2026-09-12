import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../util/money.dart';
import 'db.dart';
import 'log_service.dart';
import 'txn_repo.dart';

/// The rider's day: milk out, milk delivered, milk sold at the roadside, milk
/// back — and the cash he is holding until a founder takes it in.
///
/// The point of all of it is that two lines close at the end of the day, and
/// nobody has to remember anything to make them close. Every delivery already
/// adds itself to the tally as it is marked.
class RiderRepo {
  RiderRepo._();

  /// Today's record for this rider, made the first time anything touches it.
  static Future<void> _touch(Actor actor, String dayKey) async {
    await Db.riderDays.doc(RiderDay.idFor(actor.uid, dayKey)).set({
      'riderId': actor.uid,
      'riderName': actor.name,
      'dayKey': dayKey,
      'status': RiderDayStatus.open.name,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// The rider says how much milk he is taking out.
  ///
  /// Nobody approves it: the milk is in the van either way, and blocking the
  /// app at five in the morning would not stop it. The number checks itself at
  /// the end of the day — whatever does not add up is in front of the founder
  /// before he takes the money in.
  static Future<void> setLoad(
    Actor actor, {
    required String dayKey,
    required num litres,
  }) async {
    await _touch(actor, dayKey);
    await Db.riderDays.doc(RiderDay.idFor(actor.uid, dayKey)).set({
      'loadedLitres': litres,
      'loadedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await Log.write(
      actor,
      LogKind.order,
      'took ${qty(litres)} L out on the round',
      refType: 'riderDay',
      refId: RiderDay.idFor(actor.uid, dayKey),
    );
  }

  /// Adds to the running tally as milk goes out of the van.
  ///
  /// Called by the delivery itself, not by a person — the tally is a
  /// by-product of the round, so there is nothing extra to remember and
  /// nothing to disagree about later.
  static Future<void> countDelivery(
    Actor actor, {
    required String dayKey,
    num litres = 0,
    num cash = 0,
  }) async {
    if (litres == 0 && cash == 0) return;
    try {
      await _touch(actor, dayKey);
      await Db.riderDays.doc(RiderDay.idFor(actor.uid, dayKey)).set({
        if (litres != 0) 'deliveredLitres': FieldValue.increment(litres),
        if (cash != 0) 'collectedCash': FieldValue.increment(cash),
      }, SetOptions(merge: true));
    } catch (_) {
      // The delivery itself is what matters; the tally can be corrected.
    }
  }

  /// Milk sold at the roadside to whoever wanted it.
  ///
  /// No name is taken — that is the point of a spot sale — so the rate is the
  /// shop's own and the app fills it in. The cash joins whatever else the
  /// rider is holding, and is handed in with it.
  static Future<void> spotSale(
    Actor actor, {
    required String dayKey,
    required num litres,
    required num rate,
  }) async {
    if (litres <= 0 || rate <= 0) return;
    final amount = litres * rate;
    final now = DateTime.now();

    await _touch(actor, dayKey);
    await Db.riderDays.doc(RiderDay.idFor(actor.uid, dayKey)).set({
      'spotLitres': FieldValue.increment(litres),
      'spotCash': FieldValue.increment(amount),
    }, SetOptions(merge: true));

    await TxnRepo.add(
      actor: actor,
      monthId: monthIdOf(now),
      type: TxnType.sale,
      party: 'Spot sale',
      category: 'Milk',
      amount: amount,
      paid: true,
      qty: litres,
      unit: 'L',
      rate: rate,
      note: 'Sold on the round by ${actor.name}',
      payVia: PayVia.cash,
      handledBy: actor.name,
      date: now,
    );

    await Log.write(
      actor,
      LogKind.order,
      'sold ${qty(litres)} L on the round for ${rs(amount)}',
      refType: 'riderDay',
      refId: RiderDay.idFor(actor.uid, dayKey),
    );
  }

  /// End of the round: the rider says what he is handing over.
  ///
  /// Nothing moves in the books yet. The money is still his until a founder
  /// has counted it.
  static Future<void> handOver(
    Actor actor, {
    required String dayKey,
    required num cash,
    required num returnedLitres,
    required String toUid,
    required String toName,
    String note = '',
  }) async {
    await Db.riderDays.doc(RiderDay.idFor(actor.uid, dayKey)).set({
      'handedCash': cash,
      'returnedLitres': returnedLitres,
      'handedTo': toUid,
      'handedToName': toName,
      'handedAt': FieldValue.serverTimestamp(),
      'status': RiderDayStatus.handedOver.name,
      'note': note,
    }, SetOptions(merge: true));

    await Log.write(
      actor,
      LogKind.order,
      'handed $toName ${rs(cash)}'
      '${returnedLitres > 0 ? ' and ${qty(returnedLitres)} L back' : ''}',
      refType: 'riderDay',
      refId: RiderDay.idFor(actor.uid, dayKey),
    );
  }

  /// The rider takes his handover back — he had not given it after all.
  static Future<void> cancelHandover(Actor actor, RiderDay day) async {
    if (!day.isWaiting) return;
    await Db.riderDays.doc(day.id).set({
      'status': RiderDayStatus.open.name,
      'handedTo': null,
      'handedToName': null,
      'handedAt': null,
    }, SetOptions(merge: true));

    await Log.write(
      actor,
      LogKind.order,
      'took back the handover for ${day.dayKey}',
      refType: 'riderDay',
      refId: day.id,
    );
  }

  /// A founder counts the money and takes it in. Only now is it the farm's.
  ///
  /// [cash] is what was actually counted, which need not be what the rider
  /// said — a founder counting 8,000 against a claimed 8,400 records 8,000,
  /// and the difference stays against the rider's name.
  static Future<void> receive(
    Actor actor,
    RiderDay day, {
    required num cash,
    required num litres,
  }) async {
    await Db.riderDays.doc(day.id).set({
      'receivedBy': actor.uid,
      'receivedByName': actor.name,
      'receivedAt': FieldValue.serverTimestamp(),
      'receivedCash': FieldValue.increment(cash),
      'receivedLitres': litres,
      'status': RiderDayStatus.received.name,
    }, SetOptions(merge: true));

    await Log.write(
      actor,
      LogKind.order,
      'took in ${rs(cash)} from ${day.riderName}'
      '${litres > 0 ? ' with ${qty(litres)} L back' : ''}'
      '${cash != day.handedCash ? ' (they said ${rs(day.handedCash)})' : ''}',
      refType: 'riderDay',
      refId: day.id,
    );
  }

  /// The load sheet: how much milk today's round needs, grouped by how much
  /// each stop takes.
  ///
  /// Khaata houses take their usual litres; orders take whatever was ordered
  /// for that day, counting only what is measured in litres — a kilo of ghee
  /// is not milk and has no business in this total.
  static List<LoadLine> loadSheet({
    required List<UdhaarAccount> khaata,
    required List<FarmOrder> orders,
    required String dayKey,
    required String slot,
  }) {
    final stops = <num>[];

    for (final c in khaata) {
      if ((c.slot == 'evening') != (slot == 'evening')) continue;
      if (c.litresPerDay > 0) stops.add(c.litresPerDay);
    }

    for (final o in orders) {
      if (!o.dueOn(dayKey) || o.deliveredOn(dayKey)) continue;
      if ((o.slot == 'evening') != (slot == 'evening')) continue;
      final litres = milkIn(o, dayKey);
      if (litres > 0) stops.add(litres);
    }

    final counted = <num, int>{};
    for (final l in stops) {
      counted[l] = (counted[l] ?? 0) + 1;
    }

    return counted.entries
        .map((e) => LoadLine(litres: e.key, stops: e.value))
        .toList()
      ..sort((a, b) => b.litres.compareTo(a.litres));
  }

  /// The milk on one day of an order. Anything not sold by the litre — ghee,
  /// butter — is left out, because this figure exists to load a milk can.
  static num milkIn(FarmOrder order, String dayKey) => order
      .itemsOn(dayKey)
      .where((i) => i.unit.toLowerCase() == 'l')
      .fold<num>(0, (a, i) => a + i.qty);
}
