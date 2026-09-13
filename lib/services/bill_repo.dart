import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../util/money.dart';
import 'db.dart';
import 'log_service.dart';
import 'month_repo.dart';
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

  /// Raises — or tops up — one customer's bill for one month.
  ///
  /// A month has exactly one bill. Raising it again never makes a second one:
  /// the id is the customer and the month, and milk delivered after the bill
  /// was first raised is added to that same statement. Only days not already
  /// stamped with a bill are counted, and the whole thing runs in one Firestore
  /// transaction, so two phones doing this at the same moment bill the milk
  /// once between them.
  ///
  /// Returns null when there was nothing left to bill.
  static Future<Bill?> raise(
    Actor actor, {
    required UdhaarAccount account,
    required String monthId,
    required List<Delivery> monthDeliveries,
  }) async {
    final candidates = monthDeliveries
        .where((d) => d.customerId == account.uid && !d.isBilled)
        .toList();

    final billRef = Db.bills.doc(Bill.idFor(account.uid, monthId));
    num litres = 0;
    num thisMonth = 0;
    num carried = 0;
    var topUp = false;

    final billed = await Db.fs.runTransaction<bool>((tx) async {
      final billSnap = await tx.get(billRef);
      final existing = billSnap.exists ? Bill.fromDoc(billSnap) : null;

      // Each day is read again inside the transaction: another phone may have
      // billed it since this list was taken, and then it is not ours to bill.
      final fresh = <Delivery>[];
      for (final d in candidates) {
        final snap = await tx.get(Db.deliveries.doc(d.id));
        if (!snap.exists) continue;
        final live = Delivery.fromDoc(snap);
        if (!live.isBilled) fresh.add(live);
      }

      // Nothing new. A bill with no milk in it is only worth raising when
      // something is owing and no statement has gone out for this month yet.
      if (fresh.isEmpty && (existing != null || account.balance <= 0)) {
        return false;
      }

      litres = fresh.fold<num>(0, (a, d) => a + d.litres);
      thisMonth = fresh.fold<num>(0, (a, d) => a + d.amount);
      topUp = existing != null;
      // What was owing before this month's statement opened. On a top-up the
      // figure already on the bill is the right one — by now the account
      // balance has this month's earlier milk in it.
      carried = existing?.previousBalance ?? account.balance;

      tx.set(billRef, {
        'customerId': account.uid,
        'customerName': account.name,
        'monthId': monthId,
        'litres': (existing?.litres ?? 0) + litres,
        'thisMonth': (existing?.thisMonth ?? 0) + thisMonth,
        'previousBalance': carried,
        if (existing == null) 'paid': 0,
        if (existing == null) 'createdAt': FieldValue.serverTimestamp(),
        'billedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // The account owes what it owed, plus the milk now on the statement.
      if (thisMonth > 0) {
        tx.set(Db.udhaarAccounts.doc(account.uid), {
          'balance': FieldValue.increment(thisMonth),
        }, SetOptions(merge: true));
      }

      // Stamp the days so nothing is ever billed twice.
      for (final d in fresh) {
        tx.set(Db.deliveries.doc(d.id), {
          'billId': billRef.id,
          'billed': true,
        }, SetOptions(merge: true));
      }
      return true;
    });

    if (!billed) return null;

    await Log.write(
      actor,
      LogKind.udhaar,
      topUp
          ? 'added ${rs(thisMonth)} to ${account.name}\'s '
                '${monthShort(monthId)} bill (${qty(litres)} L)'
          : 'billed ${account.name} ${rs(thisMonth)} for ${qty(litres)} L '
                '(${monthShort(monthId)})'
                '${carried > 0 ? ', plus ${rs(carried)} carried over' : ''}',
      refType: 'bill',
      refId: billRef.id,
    );

    final snap = await billRef.get();
    return Bill.fromDoc(snap);
  }

  /// Raises one customer's bill when the caller is not already holding the
  /// month's round sheet — which is the case the moment a delivery is marked.
  static Future<Bill?> raiseForCustomer(
    Actor actor, {
    required UdhaarAccount account,
    required String monthId,
  }) async {
    final q = await Db.deliveries
        .where('customerId', isEqualTo: account.uid)
        .where('monthId', isEqualTo: monthId)
        .where('billed', isEqualTo: false)
        .get();

    return raise(
      actor,
      account: account,
      monthId: monthId,
      monthDeliveries: q.docs.map(Delivery.fromDoc).toList(),
    );
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
  /// A Cloud Function does this at 11 at night once the farm is on a billing
  /// plan. Until then the app does it, whenever a partner or the delivery man
  /// has it open. Two conditions, both deliberately conservative:
  ///
  /// * a month that has finished and still has unbilled milk in it, which is
  ///   the catch-up for nobody opening the app on the 30th; and
  /// * the current month, but only on its last day.
  ///
  /// Everything here is safe to run twice — one bill per customer per month,
  /// and a billed day is stamped — so several phones doing this at once settle
  /// on one answer.
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
    final lastDay = isLastDayOfMonth(today);

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
      monthId: MonthRepo.bookingId,
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
