import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../util/money.dart';
import 'db.dart';
import 'log_service.dart';
import 'rider_repo.dart';
import 'month_repo.dart';
import 'txn_repo.dart';

class OrderRepo {
  OrderRepo._();

  /// Human-readable order numbers come from a counter on `settings/farm`, so
  /// the farm can say "order 1042" on the phone.
  static Future<String> _nextNumber() async {
    try {
      return await Db.fs.runTransaction<String>((tx) async {
        final snap = await tx.get(Db.farmSettings);
        final current = ((snap.data() ?? const {})['orderSeq'] as num?) ?? 1000;
        final next = current.toInt() + 1;
        tx.set(Db.farmSettings, {'orderSeq': next}, SetOptions(merge: true));
        return next.toString();
      });
    } catch (_) {
      // Counter unavailable (offline, or rules) — fall back to a time stamp.
      return DateTime.now().millisecondsSinceEpoch.remainder(100000).toString();
    }
  }

  /// Places an order. Each item carries the days it is wanted on.
  ///
  /// A basket of milk every morning and a kilo of ghee on Friday is one order
  /// the round sees on every one of those days — with only that day's items on
  /// it, and only that day's money.
  static Future<String> place({
    required Actor actor,
    required List<OrderItem> items,
    required String mode,
    required String slot,
    required PayMethod pay,
    required String address,
    required String mobile,
  }) async {
    final dayKeys = <String>{for (final i in items) ...i.dayKeys}.toList()
      ..sort();
    final total = items.fold<num>(0, (a, i) => a + i.total);
    final number = await _nextNumber();

    final doc = await Db.orders.add({
      'number': number,
      'customerId': actor.uid,
      'customerName': actor.name,
      'address': address,
      'mobile': mobile,
      'items': {for (final i in items) i.productId: i.toMap()},
      'total': total,
      'mode': mode,
      'slot': slot,
      'repeat': dayKeys.length > 1 ? 'days' : 'once',
      'dayKeys': dayKeys,
      'doneDays': <String>[],
      'pay': pay.name,
      'status': OrderStatus.newOrder.key,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await Log.write(
      actor,
      LogKind.order,
      'placed order #$number for ${rs(total)}'
      '${dayKeys.length > 1 ? ' over ${dayKeys.length} days' : ''}',
      refType: 'order',
      refId: doc.id,
    );
    return doc.id;
  }

  /// Called off before the farm has started on it.
  ///
  /// Only while the order is still new: once a co-founder has approved it the
  /// milk is being got ready, and that is a conversation, not a button.
  static Future<void> cancel(Actor actor, FarmOrder order) async {
    if (order.status != OrderStatus.newOrder || order.isApproved) return;
    await Db.orders.doc(order.id).update({'status': OrderStatus.cancelled.key});
    await Log.write(
      actor,
      LogKind.order,
      'cancelled order #${order.number}',
      refType: 'order',
      refId: order.id,
    );
  }

  /// The first co-founder or the master to tap Approve owns the approval.
  static Future<void> approve(Actor actor, FarmOrder order) async {
    if (order.isApproved) return;
    await Db.orders.doc(order.id).update({
      'approvedBy': actor.uid,
      'approvedByName': actor.name,
      'approvedAt': FieldValue.serverTimestamp(),
    });
    await Log.write(
      actor,
      LogKind.order,
      'approved order #${order.number} (${order.customerName})',
      refType: 'order',
      refId: order.id,
    );
  }

  /// Moves an order one step along New → Preparing → Out → Delivered.
  ///
  /// Delivering an udhaar order books the sale as an unpaid receivable against
  /// the customer and raises their udhaar balance.
  /// [payVia] and [handledBy] describe the money taken on delivery. Leave
  /// [collected] false when the customer did not pay — the sale is then booked
  /// as a receivable, exactly like a khaata order.
  static Future<void> advance(
    Actor actor,
    FarmOrder order, {
    bool collected = true,
    PayVia payVia = PayVia.cash,
    String handledBy = '',
  }) async {
    final next = order.status.next;
    if (next == null) return;

    // The last step is a delivery, and a delivery always belongs to a day.
    if (next == OrderStatus.delivered) {
      final day = order.daysLeft.isEmpty
          ? dayKeyOf(DateTime.now())
          : order.daysLeft.first;
      return deliverDay(
        actor,
        order,
        dayKey: day,
        collected: collected,
        payVia: payVia,
        handledBy: handledBy,
      );
    }

    await Db.orders.doc(order.id).update({'status': next.key});

    await Log.write(
      actor,
      LogKind.order,
      'moved order #${order.number} to ${next.label.toLowerCase()}',
      refType: 'order',
      refId: order.id,
    );
  }

  /// Marks one day of an order delivered, and books that day's money.
  ///
  /// A week's order is seven deliveries. Each one is its own sale on the day
  /// the milk actually goes out, which is the only way the books can say what
  /// the farm earned on a Tuesday. The order is finished when its last day is.
  ///
  /// Safe to run twice: a day already marked is left alone, so two phones on
  /// the round cannot book the same milk twice.
  static Future<void> deliverDay(
    Actor actor,
    FarmOrder order, {
    required String dayKey,
    bool collected = true,
    PayVia payVia = PayVia.cash,
    String handledBy = '',
  }) async {
    if (order.deliveredOn(dayKey)) return;

    final now = DateTime.now();
    final last = order.daysLeft.length <= 1;
    // Only what is going out today: milk on an ordinary morning, milk and the
    // ghee on the day the ghee was asked for.
    final amount = order.amountOn(dayKey);
    final which = order.dayLabel(dayKey);

    await Db.orders.doc(order.id).update({
      'doneDays': FieldValue.arrayUnion([dayKey]),
      'status': last ? OrderStatus.delivered.key : OrderStatus.out.key,
      if (last) 'deliveredAt': Timestamp.fromDate(now),
    });

    await TxnRepo.add(
      actor: actor,
      monthId: MonthRepo.bookingId,
      type: TxnType.sale,
      party: order.customerName,
      customerId: order.customerId,
      category: _categoryFor(order),
      amount: amount,
      // A khaata order always goes on the account; anything else is paid at
      // the door unless the person delivering says otherwise.
      paid: !order.isUdhaar && collected,
      note:
          'Order #${order.number} · ${order.itemsTextOn(dayKey)}'
          '${which.isEmpty ? '' : ' · $which'}',
      orderId: order.id,
      payVia: payVia,
      handledBy: handledBy,
      date: now,
    );

    if (order.isUdhaar) {
      await Db.udhaarAccounts.doc(order.customerId).set({
        'balance': FieldValue.increment(amount),
      }, SetOptions(merge: true));
    }

    // The day's tally: the milk that left the van, and the cash that came
    // back. A khaata order takes no money at the door.
    await RiderRepo.countDelivery(
      actor,
      dayKey: dayKey,
      litres: RiderRepo.milkIn(order, dayKey),
      cash: order.isUdhaar || !collected ? 0 : amount,
    );

    await Log.write(
      actor,
      LogKind.order,
      'delivered order #${order.number}'
      '${which.isEmpty ? '' : ' ($which)'} — ${rs(amount)}',
      refType: 'order',
      refId: order.id,
    );
  }

  /// Master only: takes back a day that was marked delivered by mistake.
  ///
  /// The mark is not the whole of it. Marking a day delivered books a sale,
  /// and on a khaata order it raises what the customer owes — so undoing it
  /// has to reverse both, or the books and the round tell different stories.
  ///
  /// Nothing is erased. The sale is marked deleted, which keeps it in the log
  /// and the backup with a line through it, so a correction can always be
  /// told apart from something that never happened.
  static Future<void> undoDay(
    Actor actor,
    FarmOrder order, {
    required String dayKey,
  }) async {
    if (!order.deliveredOn(dayKey)) return;
    final amount = order.amountOn(dayKey);

    // The sale this day booked, found by the order and the amount.
    try {
      final sales = await Db.transactions
          .where('orderId', isEqualTo: order.id)
          .get();
      for (final doc in sales.docs) {
        final t = Txn.fromDoc(doc);
        if (t.isDeleted || t.type != TxnType.sale) continue;
        if ((t.amount - amount).abs() > 0.01) continue;
        await TxnRepo.softDelete(actor, t);
        break;
      }
    } catch (_) {
      // The day still comes back off the order; the entry can be deleted by
      // hand from the ledger if this could not find it.
    }

    if (order.isUdhaar) {
      await Db.udhaarAccounts.doc(order.customerId).set({
        'balance': FieldValue.increment(-amount),
      }, SetOptions(merge: true));
    }

    await Db.orders.doc(order.id).update({
      'doneDays': FieldValue.arrayRemove([dayKey]),
      'status': OrderStatus.out.key,
      'deliveredAt': null,
    });

    await Log.write(
      actor,
      LogKind.order,
      'undid the delivery of order #${order.number} for '
      '$dayKey — ${rs(amount)} taken back out',
      refType: 'order',
      refId: order.id,
    );
  }

  /// Orders of mixed goods are booked under the biggest line's category.
  static String _categoryFor(FarmOrder order) {
    if (order.items.isEmpty) return 'Other sale';
    final biggest = order.items.reduce((a, b) => a.total >= b.total ? a : b);
    final name = biggest.name.toLowerCase();
    for (final c in TxnType.sale.categories) {
      if (name.contains(c.toLowerCase())) return c;
    }
    if (name.contains('milk') || name.contains('doodh')) return 'Milk';
    if (name.contains('yogurt') || name.contains('dahi')) return 'Dahi';
    return 'Other sale';
  }
}
