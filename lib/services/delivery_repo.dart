import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../util/money.dart';
import 'bill_repo.dart';
import 'db.dart';
import 'log_service.dart';
import 'rider_repo.dart';

/// The daily milk round.
///
/// One record per customer per day, keyed by both, so the same day marked twice
/// from two phones settles on one answer instead of billing the milk twice.
class DeliveryRepo {
  DeliveryRepo._();

  /// Records the day's milk for one khaata customer. Passing zero litres
  /// removes the day — that is how a missed delivery is undone.
  static Future<void> mark(
    Actor actor,
    UdhaarAccount account, {
    required num litres,
    required DateTime date,
  }) async {
    final id = Delivery.idFor(account.uid, date);

    // What was already marked, so a correction moves the tally by the
    // difference rather than counting the milk twice.
    Delivery? before;
    try {
      final snap = await Db.deliveries.doc(id).get();
      if (snap.exists) before = Delivery.fromDoc(snap);
    } catch (_) {
      // Nothing there, or unreadable — treat it as a first mark.
    }

    if (litres <= 0) {
      await Db.deliveries.doc(id).delete();
      await RiderRepo.countDelivery(
        actor,
        dayKey: dayKeyOf(date),
        litres: -(before?.litres ?? 0),
      );
      await Log.write(
        actor,
        LogKind.udhaar,
        'cleared ${account.name}\'s delivery for ${fmtDate(date)}',
        refType: 'delivery',
        refId: id,
      );
      return;
    }

    await Db.deliveries.doc(id).set({
      'customerId': account.uid,
      'customerName': account.name,
      'date': Timestamp.fromDate(date),
      'monthId': monthIdOf(date),
      'litres': litres,
      'rate': account.rate,
      'slot': account.slot,
      'deliveredBy': actor.uid,
      'deliveredByName': actor.name,
      'billed': false,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // The milk leaves the van whoever marks it, so the day's tally follows
    // the delivery rather than waiting to be typed in at the end. Khaata milk
    // is not paid for at the door, so no cash is counted here.
    await RiderRepo.countDelivery(
      actor,
      dayKey: dayKeyOf(date),
      litres: litres - (before?.litres ?? 0),
    );

    await Log.write(
      actor,
      LogKind.udhaar,
      'delivered ${qty(litres)} L to ${account.name} '
      '(${rs(litres * account.rate)})',
      refType: 'delivery',
      refId: id,
    );

    // The last can of the month. Bill this customer there and then, so they
    // know what they owe the same evening instead of waiting on somebody to
    // remember. Anyone missed tonight is picked up by the 11 o'clock run.
    if (isLastDayOfMonth(date)) {
      try {
        await BillRepo.raiseForCustomer(
          actor,
          account: account,
          monthId: monthIdOf(date),
        );
      } catch (_) {
        // The milk is recorded, which is the part that matters. The bill is
        // raised by the next run either way.
      }
    }
  }

  /// What a customer has taken so far in one month.
  static num litresIn(List<Delivery> deliveries, String customerId) =>
      deliveries
          .where((d) => d.customerId == customerId)
          .fold<num>(0, (a, d) => a + d.litres);

  static num amountIn(List<Delivery> deliveries, String customerId) =>
      deliveries
          .where((d) => d.customerId == customerId)
          .fold<num>(0, (a, d) => a + d.amount);
}
