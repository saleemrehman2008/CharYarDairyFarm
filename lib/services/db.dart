import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

typedef Snap = DocumentSnapshot<Map<String, dynamic>>;
typedef QSnap = QuerySnapshot<Map<String, dynamic>>;
typedef Col = CollectionReference<Map<String, dynamic>>;

/// Every Firestore path the app touches, plus the read streams the screens
/// listen to. Writes live in [FarmRepo] so this file stays a map of the data.
class Db {
  Db._();

  static FirebaseFirestore get fs => FirebaseFirestore.instance;

  static Col get users => fs.collection('users');
  static Col get partners => fs.collection('partners');
  static Col get products => fs.collection('products');
  static Col get transactions => fs.collection('transactions');
  static Col get orders => fs.collection('orders');
  static Col get subscriptions => fs.collection('subscriptions');

  /// Khaata accounts. The collection keeps its original `udhaar_accounts` name
  /// so no data has to be migrated; everything the farm reads says "khaata".
  static Col get udhaarAccounts => fs.collection('udhaar_accounts');
  static Col get deliveries => fs.collection('deliveries');
  static Col get bills => fs.collection('bills');
  static Col get months => fs.collection('months');
  static Col get logs => fs.collection('logs');
  static DocumentReference<Map<String, dynamic>> get farmSettings =>
      fs.collection('settings').doc('farm');

  // ---- Reads ----

  static Stream<AppUser?> watchUser(String uid) => users
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? AppUser.fromDoc(d) : null);

  static Stream<List<AppUser>> watchUsers() => users
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((q) => q.docs.map(AppUser.fromDoc).toList());

  static Stream<List<AppUser>> watchPendingUsers() => users
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((q) => q.docs.map(AppUser.fromDoc).toList());

  static Stream<FarmSettings> watchSettings() =>
      farmSettings.snapshots().map(FarmSettings.fromDoc);

  static Stream<List<Partner>> watchPartners() => partners
      .orderBy('createdAt')
      .snapshots()
      .map((q) => q.docs.map(Partner.fromDoc).toList());

  /// Active-only filtering happens in Dart rather than in the query: a farm
  /// has a handful of products, and this way the app needs no composite index,
  /// which is one less thing to get wrong when setting the project up.
  static Stream<List<Product>> watchProducts({bool onlyActive = false}) =>
      products.orderBy('sortOrder').snapshots().map((s) {
        final all = s.docs.map(Product.fromDoc);
        return (onlyActive ? all.where((p) => p.active) : all).toList();
      });

  /// Transactions for one farm month, newest first. Soft-deleted rows are
  /// filtered in Dart so a missing composite index can never hide the ledger.
  static Stream<List<Txn>> watchMonthTxns(String monthId) => transactions
      .where('monthId', isEqualTo: monthId)
      .snapshots()
      .map(
        (q) =>
            q.docs.map(Txn.fromDoc).where((t) => !t.isDeleted).toList()
              ..sort((a, b) => b.date.compareTo(a.date)),
      );

  /// Every unsettled entry, whatever month it was booked in — these carry
  /// forward across a month close.
  static Stream<List<Txn>> watchUnpaidTxns() => transactions
      .where('paid', isEqualTo: false)
      .snapshots()
      .map(
        (q) =>
            q.docs.map(Txn.fromDoc).where((t) => !t.isDeleted).toList()
              ..sort((a, b) => b.date.compareTo(a.date)),
      );

  /// Everything the farm owns, across every month — a handful of rows, since
  /// cattle and equipment are bought rarely.
  static Stream<List<Txn>> watchAssetTxns() => transactions
      .where('category', whereIn: assetCategories.toList())
      .snapshots()
      .map(
        (q) => q.docs
            .map(Txn.fromDoc)
            .where((t) => !t.isDeleted && t.isCapitalAsset)
            .toList(),
      );

  static Stream<List<FarmOrder>> watchOrders() => orders
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((q) => q.docs.map(FarmOrder.fromDoc).toList());

  static Stream<List<FarmOrder>> watchCustomerOrders(String uid) => orders
      .where('customerId', isEqualTo: uid)
      .snapshots()
      .map(
        (q) =>
            q.docs.map(FarmOrder.fromDoc).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  static Stream<UdhaarAccount?> watchUdhaar(String uid) => udhaarAccounts
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? UdhaarAccount.fromDoc(d) : null);

  static Stream<List<UdhaarAccount>> watchUdhaarAccounts() =>
      udhaarAccounts.snapshots().map(
        (q) =>
            q.docs.map(UdhaarAccount.fromDoc).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  static Stream<List<UdhaarAccount>> watchPendingUdhaar() => udhaarAccounts
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((q) => q.docs.map(UdhaarAccount.fromDoc).toList());

  /// Every delivery in one farm month — the round sheet and the bills both
  /// read from this.
  static Stream<List<Delivery>> watchMonthDeliveries(String monthId) =>
      deliveries
          .where('monthId', isEqualTo: monthId)
          .snapshots()
          .map(
            (q) =>
                q.docs.map(Delivery.fromDoc).toList()
                  ..sort((a, b) => b.date.compareTo(a.date)),
          );

  static Stream<List<Delivery>> watchCustomerDeliveries(
    String uid,
    String monthId,
  ) => deliveries
      .where('customerId', isEqualTo: uid)
      .where('monthId', isEqualTo: monthId)
      .snapshots()
      .map(
        (q) =>
            q.docs.map(Delivery.fromDoc).toList()
              ..sort((a, b) => b.date.compareTo(a.date)),
      );

  /// Days of milk not yet on a bill — what the month-end run works from.
  static Stream<List<Delivery>> watchUnbilledDeliveries() => deliveries
      .where('billed', isEqualTo: false)
      .snapshots()
      .map((q) => q.docs.map(Delivery.fromDoc).toList());

  /// Bills that still have something owing, newest first.
  static Stream<List<Bill>> watchBills() => bills
      .orderBy('createdAt', descending: true)
      .limit(300)
      .snapshots()
      .map((q) => q.docs.map(Bill.fromDoc).toList());

  static Stream<List<Bill>> watchCustomerBills(String uid) => bills
      .where('customerId', isEqualTo: uid)
      .snapshots()
      .map(
        (q) =>
            q.docs.map(Bill.fromDoc).toList()
              ..sort((a, b) => b.monthId.compareTo(a.monthId)),
      );

  static Stream<FarmMonth?> watchMonth(String id) => months
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? FarmMonth.fromDoc(d) : null);

  static Stream<List<FarmMonth>> watchClosedMonths() => months
      .where('status', isEqualTo: 'closed')
      .snapshots()
      .map(
        (q) =>
            q.docs.map(FarmMonth.fromDoc).toList()
              ..sort((a, b) => b.id.compareTo(a.id)),
      );

  static Stream<List<LogEntry>> watchLogs({int limit = 100}) => logs
      .orderBy('at', descending: true)
      .limit(limit)
      .snapshots()
      .map((q) => q.docs.map(LogEntry.fromDoc).toList());
}
