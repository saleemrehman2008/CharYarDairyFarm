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
  static Col get udhaarAccounts => fs.collection('udhaar_accounts');
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

  static Stream<List<Product>> watchProducts({bool onlyActive = false}) {
    Query<Map<String, dynamic>> q = products.orderBy('sortOrder');
    if (onlyActive) q = q.where('active', isEqualTo: true);
    return q.snapshots().map((s) => s.docs.map(Product.fromDoc).toList());
  }

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
