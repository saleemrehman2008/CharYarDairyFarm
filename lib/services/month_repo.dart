import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../util/money.dart';
import 'accounting.dart';
import 'db.dart';
import 'log_service.dart';

class MonthRepo {
  MonthRepo._();

  /// The month the farm is currently booking into: the oldest month still
  /// marked open, or today's month if the farm has never closed one.
  static Stream<FarmMonth> watchOpen() =>
      Db.months.where('status', isEqualTo: 'open').snapshots().map((q) {
        if (q.docs.isEmpty) {
          return FarmMonth(
            id: monthIdOf(DateTime.now()),
            status: 'open',
            openingCash: 0,
          );
        }
        final months = q.docs.map(FarmMonth.fromDoc).toList()
          ..sort((a, b) => a.id.compareTo(b.id));
        return months.first;
      });

  /// Creates the month document the first time the farm books anything.
  static Future<void> ensureOpen(String monthId, {num openingCash = 0}) async {
    final ref = Db.months.doc(monthId);
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'status': 'open',
      'openingCash': openingCash,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Master only. Posts every partner's share, opens the next month with the
  /// cash that is actually left, and bills each udhaar customer for the month.
  ///
  /// Unpaid entries are not touched: they carry forward and stay in AR/AP until
  /// someone marks them paid.
  static Future<void> close({
    required Actor actor,
    required FarmMonth month,
    required Books books,
    required List<Partner> partners,
    required bool arIncluded,
    required Map<String, String> choices,
    required List<Txn> unpaidTxns,
  }) async {
    final profitToShare = books.profitToShare(arIncluded: arIncluded);
    final shares = shareOut(
      partners: partners,
      profitToShare: profitToShare,
      choices: choices,
    );

    final now = DateTime.now();
    final nextId = nextMonthId(month.id);
    final batch = Db.fs.batch();

    batch.update(Db.months.doc(month.id), {
      'status': 'closed',
      'closedAt': Timestamp.fromDate(now),
      'closedBy': actor.uid,
      'closedByName': actor.name,
      'arIncluded': arIncluded,
      'sales': books.sales,
      'purchases': books.purchases,
      'expenses': books.expenses,
      'receivables': books.receivable,
      'profit': books.profit,
      'profitShared': profitToShare,
      'shares': shares.map((e) => e.toMap()).toList(),
    });

    num withdrawnTotal = 0;
    for (final share in shares) {
      final ref = Db.partners.doc(share.partnerId);
      if (share.isReinvested) {
        batch.update(ref, {'reinvested': FieldValue.increment(share.share)});
      } else {
        batch.update(ref, {'withdrawn': FieldValue.increment(share.share)});
        withdrawnTotal += share.share;
        // A withdrawal is real money leaving the farm, so it is a payment row.
        batch.set(Db.transactions.doc(), {
          'date': Timestamp.fromDate(now),
          'monthId': month.id,
          'type': TxnType.payment.name,
          'party': share.name,
          'category': 'Other payment',
          'amount': share.share,
          'paid': true,
          'paidAt': Timestamp.fromDate(now),
          'note': 'Profit share – ${share.name} · ${monthShort(month.id)}',
          'createdBy': actor.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    // Next month opens with the cash actually in hand.
    batch.set(Db.months.doc(nextId), {
      'status': 'open',
      'openingCash': books.cash - withdrawnTotal,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
    await _billUdhaarCustomers(unpaidTxns);

    await Log.write(
      actor,
      LogKind.monthClose,
      'closed ${monthName(month.id)} and shared ${rs(profitToShare)} '
      '(${arIncluded ? 'AR counted' : 'AR rolled'})',
      refType: 'month',
      refId: month.id,
    );
  }

  /// An udhaar customer's balance is the sum of their sales still unpaid.
  static Future<void> _billUdhaarCustomers(List<Txn> unpaidTxns) async {
    final owed = <String, num>{};
    for (final t in unpaidTxns) {
      final id = t.customerId;
      if (t.isReceivable && id != null && id.isNotEmpty) {
        owed[id] = (owed[id] ?? 0) + t.amount;
      }
    }
    if (owed.isEmpty) return;

    final batch = Db.fs.batch();
    owed.forEach((uid, amount) {
      batch.set(Db.udhaarAccounts.doc(uid), {
        'balance': amount,
        'billedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    await batch.commit();
  }
}
