import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../util/money.dart';
import 'db.dart';
import 'log_service.dart';
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

  static Future<String> place({
    required Actor actor,
    required List<OrderItem> items,
    required num total,
    required String mode,
    required String slot,
    required String repeat,
    required PayMethod pay,
  }) async {
    final number = await _nextNumber();
    final doc = await Db.orders.add({
      'number': number,
      'customerId': actor.uid,
      'customerName': actor.name,
      'items': {for (final i in items) i.productId: i.toMap()},
      'total': total,
      'mode': mode,
      'slot': slot,
      'repeat': repeat,
      'pay': pay.name,
      'status': OrderStatus.newOrder.key,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // "Daily" turns the order into a standing subscription; a scheduled Cloud
    // Function raises the next day's order from it at 04:00 PKT.
    if (repeat == 'daily') {
      await Db.subscriptions.add({
        'customerId': actor.uid,
        'customerName': actor.name,
        'items': {for (final i in items) i.productId: i.toMap()},
        'total': total,
        'slot': slot,
        'mode': mode,
        'pay': pay.name,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await Log.write(
      actor,
      LogKind.order,
      'placed order #$number for ${rs(total)}',
      refType: 'order',
      refId: doc.id,
    );
    return doc.id;
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

    final now = DateTime.now();
    await Db.orders.doc(order.id).update({
      'status': next.key,
      if (next == OrderStatus.delivered) 'deliveredAt': Timestamp.fromDate(now),
    });

    if (next == OrderStatus.delivered) {
      await TxnRepo.add(
        actor: actor,
        monthId: monthIdOf(now),
        type: TxnType.sale,
        party: order.customerName,
        customerId: order.customerId,
        category: _categoryFor(order),
        amount: order.total,
        // A khaata order always goes on the account; anything else is paid at
        // the door unless the person delivering says otherwise.
        paid: !order.isUdhaar && collected,
        note: 'Order #${order.number} · ${order.itemsText}',
        orderId: order.id,
        payVia: payVia,
        handledBy: handledBy,
        date: now,
      );

      if (order.isUdhaar) {
        await Db.udhaarAccounts.doc(order.customerId).set({
          'balance': FieldValue.increment(order.total),
        }, SetOptions(merge: true));
      }
    }

    await Log.write(
      actor,
      LogKind.order,
      'moved order #${order.number} to ${next.label.toLowerCase()}',
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
