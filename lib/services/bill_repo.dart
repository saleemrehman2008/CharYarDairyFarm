import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../util/money.dart';
import 'db.dart';
import 'log_service.dart';
import 'txn_repo.dart';

/// Monthly khaata bills.
///
/// The account carries one running balance, the way a shop's khaata book does.
/// A bill is the month's statement against it: what was taken this month, what
/// was already owing, and what that comes to. Pay part of it and the rest stays
/// on the account, so it turns up on next month's bill instead of quietly
/// disappearing.
class BillRepo {
  BillRepo._();

  /// Raises the month's bill for one customer and rolls their balance forward.
  ///
  /// Safe to run twice: the bill id is the customer and the month, and only
  /// deliveries not already stamped with a bill are counted.
  static Future<Bill?> raise(
    Actor actor, {
    required UdhaarAccount account,
    required String monthId,
    required List<Delivery> monthDeliveries,
  }) async {
    final mine = monthDeliveries
        .where((d) => d.customerId == account.uid && !d.isBilled)
        .toList();
    if (mine.isEmpty && account.balance <= 0) return null;

    final litres = mine.fold<num>(0, (a, d) => a + d.litres);
    final thisMonth = mine.fold<num>(0, (a, d) => a + d.amount);
    final previousBalance = account.balance;
    final billId = Bill.idFor(account.uid, monthId);

    await Db.bills.doc(billId).set({
      'customerId': account.uid,
      'customerName': account.name,
      'monthId': monthId,
      'litres': litres,
      'thisMonth': thisMonth,
      'previousBalance': previousBalance,
      'paid': 0,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // The account now owes last month's leftover plus this month's milk.
    await Db.udhaarAccounts.doc(account.uid).set({
      'balance': previousBalance + thisMonth,
    }, SetOptions(merge: true));

    // Stamp the deliveries so a second run cannot bill them again.
    final batch = Db.fs.batch();
    for (final d in mine) {
      batch.set(Db.deliveries.doc(d.id), {
        'billId': billId,
        'billed': true,
      }, SetOptions(merge: true));
    }
    await batch.commit();

    await Log.write(
      actor,
      LogKind.udhaar,
      'billed ${account.name} ${rs(thisMonth)} for ${qty(litres)} L '
      '(${monthShort(monthId)})'
      '${previousBalance > 0 ? ', plus ${rs(previousBalance)} carried over' : ''}',
      refType: 'bill',
      refId: billId,
    );

    final snap = await Db.bills.doc(billId).get();
    return Bill.fromDoc(snap);
  }

  /// Raises bills for every khaata customer who can be billed, closed ones
  /// included. Returns how many bills were raised.
  static Future<int> raiseAll(
    Actor actor, {
    required String monthId,
    required List<UdhaarAccount> accounts,
    required List<Delivery> monthDeliveries,
  }) async {
    var raised = 0;
    for (final account in accounts.where((a) => a.isBillable)) {
      final bill = await raise(
        actor,
        account: account,
        monthId: monthId,
        monthDeliveries: monthDeliveries,
      );
      if (bill != null) raised++;
    }
    return raised;
  }

  /// Raises whatever is due, without anyone asking.
  ///
  /// Cloud Functions would do this on a schedule, but they need a billing
  /// account the farm does not have yet — so the app does it instead, whenever
  /// a partner opens it. Two conditions, both deliberately conservative:
  ///
  /// * a month that has finished and still has unbilled milk in it, which is
  ///   the catch-up for nobody opening the app on the 30th; and
  /// * the current month, but only on its last day.
  ///
  /// Everything here is safe to run twice — the bill id is the customer and the
  /// month, and a billed day is stamped — so several phones doing this at once
  /// settle on one answer.
  static Future<int> raiseDue(
    Actor actor, {
    required List<UdhaarAccount> accounts,
    required List<Delivery> unbilled,
    DateTime? now,
  }) async {
    if (accounts.isEmpty) return 0;
    final due = dueNow(unbilled, now: now);
    if (due.isEmpty) return 0;

    var raised = 0;
    for (final entry in due.entries) {
      raised += await raiseAll(
        actor,
        monthId: entry.key,
        accounts: accounts,
        monthDeliveries: entry.value,
      );
    }
    return raised;
  }

  /// The unbilled milk that has fallen due, grouped by the month it belongs to.
  ///
  /// Kept apart from the writing so the rule — finished months always, the
  /// current month only on its last day — can be read and tested on its own.
  static Map<String, List<Delivery>> dueNow(
    List<Delivery> unbilled, {
    DateTime? now,
  }) {
    if (unbilled.isEmpty) return const {};

    final today = now ?? DateTime.now();
    final thisMonth = monthIdOf(today);
    final lastDay = DateTime(today.year, today.month + 1, 0).day == today.day;

    final due = <String, List<Delivery>>{};
    for (final d in unbilled) {
      final finished = d.monthId.compareTo(thisMonth) < 0;
      if (finished || (d.monthId == thisMonth && lastDay)) {
        due.putIfAbsent(d.monthId, () => []).add(d);
      }
    }
    return due;
  }

  /// Takes money against a bill — in full or in part.
  ///
  /// Books a receipt so the payment lands in the farm's cash, drops the
  /// customer's running balance, and records what is still owing.
  static Future<void> takePayment(
    Actor actor, {
    required Bill bill,
    required num amount,
    required PayVia payVia,
    required String handledBy,
  }) async {
    if (amount <= 0) return;
    final now = DateTime.now();
    final settles = amount >= bill.balance;

    await Db.bills.doc(bill.id).set({
      'paid': bill.paid + amount,
      if (settles) 'settledAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    await Db.udhaarAccounts.doc(bill.customerId).set({
      'balance': FieldValue.increment(-amount),
    }, SetOptions(merge: true));

    await TxnRepo.add(
      actor: actor,
      monthId: monthIdOf(now),
      type: TxnType.receipt,
      party: bill.customerName,
      customerId: bill.customerId,
      category: 'Khaata receipt',
      amount: amount,
      paid: true,
      note:
          'Khaata bill ${monthShort(bill.monthId)}'
          '${settles ? '' : ' (part payment)'}',
      payVia: payVia,
      handledBy: handledBy,
      date: now,
    );

    await Log.write(
      actor,
      LogKind.udhaar,
      'took ${rs(amount)} from ${bill.customerName} for '
      '${monthShort(bill.monthId)}'
      '${settles ? '' : ', ${rs(bill.balance - amount)} still owing'}',
      refType: 'bill',
      refId: bill.id,
    );
  }
}
