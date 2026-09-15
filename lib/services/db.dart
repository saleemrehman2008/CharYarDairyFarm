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

  /// Khaata accounts. The collection keeps its original `udhaar_accounts` name
  /// so no data has to be migrated; everything the farm reads says "khaata".
  static Col get udhaarAccounts => fs.collection('udhaar_accounts');
  static Col get deliveries => fs.collection('deliveries');
  static Col get bills => fs.collection('bills');

  /// The cattle register and each animal's history.
  static Col get animals => fs.collection('animals');
  static Col get animalEvents => fs.collection('animal_events');

  /// Full-size pictures, one document each, kept apart from the records so a
  /// list of animals never has to carry them.
  static Col get animalPhotos => fs.collection('animal_photos');

  /// One document per rider per day: milk out, milk delivered, cash held.
  static Col get riderDays => fs.collection('rider_days');

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

  /// The shop catalogue, in shop order.
  ///
  /// Both the sorting and the active-only filter happen in Dart. A farm has a
  /// handful of products, so it costs nothing — and an ordered query would
  /// drop any product saved without the field it orders on, which would take
  /// an item out of the shop altogether.
  static Stream<List<Product>> watchProducts({bool onlyActive = false}) =>
      products.snapshots().map((s) {
        final all = s.docs.map(Product.fromDoc);
        return (onlyActive ? all.where((p) => p.active) : all).toList()
          ..sort((a, b) {
            final byOrder = a.sortOrder.compareTo(b.sortOrder);
            return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
          });
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

  /// Every period the farm has had — open, sealed and closed — newest first.
  ///
  /// The whole ledger is read as one list, so the app needs to know where each
  /// period began and ended in order to draw the line between them.
  static Stream<List<FarmMonth>> watchPeriods() => months.snapshots().map(
    (q) =>
        q.docs.map(FarmMonth.fromDoc).toList()
          ..sort((a, b) => b.id.compareTo(a.id)),
  );

  /// The whole ledger, newest first.
  ///
  /// Not one period at a time: a farm's books are read as a running account,
  /// and chopping them at each settling-up hid every entry of the period that
  /// had just been closed. Where one period ends and the next begins is drawn
  /// as a line through the list instead.
  ///
  /// Capped, because this grows for as long as the farm does. Five hundred
  /// entries is well over a year for a farm this size; past that the oldest
  /// are reached through the Sheet or the export.
  static Stream<List<Txn>> watchLedger({int limit = 500}) => transactions
      .orderBy('date', descending: true)
      .limit(limit)
      .snapshots()
      .map((q) => q.docs.map(Txn.fromDoc).where((t) => !t.isDeleted).toList());

  /// The ledger from a date onwards, for a report that spans more than one
  /// period. Pass null for the lot.
  ///
  /// Filtered on the entry's own date rather than on the period it was booked
  /// into, because the reader is asking about a stretch of time, not about the
  /// farm's settling-up arrangements.
  static Stream<List<Txn>> watchTxnsSince(DateTime? from) {
    final q = from == null
        ? transactions
        : transactions.where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(from),
          );
    return q.snapshots().map(
      (s) =>
          s.docs.map(Txn.fromDoc).where((t) => !t.isDeleted).toList()
            ..sort((a, b) => b.date.compareTo(a.date)),
    );
  }

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
  /// Everything the farm owns, across every month, and everything it has
  /// stopped owning — a handful of rows, since cattle and equipment are
  /// bought rarely and leave more rarely still.
  ///
  /// Both in one stream because they answer one question. An animal bought
  /// and then sold is not something the farm owns, and a card that says what
  /// the farm owns has to be reading both halves or it will keep counting a
  /// buffalo that is no longer in the shed.
  static Stream<List<Txn>> watchAssetTxns() => transactions
      .where('category', whereIn: [...assetCategories, writeOffCategory])
      .snapshots()
      .map(
        (q) => q.docs
            .map(Txn.fromDoc)
            .where((t) => !t.isDeleted && (t.isCapitalAsset || t.isWriteOff))
            .toList(),
      );

  /// Every profit share the farm has actually handed over, across every
  /// period — four rows a close, so this is cheap to keep open.
  ///
  /// Read from the payment rows rather than from what each period decided,
  /// because these rows are what moved the cash. A card that says where the
  /// money went has to be reading the same thing the balance read, or the two
  /// drift apart and neither can be trusted.
  static Stream<List<Txn>> watchProfitShareTxns() => transactions
      .where('category', isEqualTo: profitShareCategory)
      .snapshots()
      .map(
        (q) => q.docs
            .map(Txn.fromDoc)
            .where((t) => !t.isDeleted && t.type == TxnType.payment)
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

  /// The whole cattle register. Sorted in Dart — an ordered query would drop
  /// any animal saved without the field it orders on.
  static Stream<List<Animal>> watchAnimals() => animals.snapshots().map(
    (q) => q.docs.map(Animal.fromDoc).toList()..sort(Animal.byTag),
  );

  /// The full-size picture, read only when it is actually being looked at.
  static Future<String> animalPhoto(String photoId) async {
    try {
      final snap = await animalPhotos.doc(photoId).get();
      return s((snap.data() ?? const {})['data']);
    } catch (_) {
      return '';
    }
  }

  /// One animal's history, newest first.
  static Stream<List<AnimalEvent>> watchAnimalEvents(String animalId) =>
      animalEvents
          .where('animalId', isEqualTo: animalId)
          .snapshots()
          .map(
            (q) =>
                q.docs.map(AnimalEvent.fromDoc).toList()
                  ..sort((a, b) => b.date.compareTo(a.date)),
          );

  /// One rider's day, watched by the rider's own phone.
  static Stream<RiderDay?> watchRiderDay(String riderId, String dayKey) =>
      riderDays
          .doc(RiderDay.idFor(riderId, dayKey))
          .snapshots()
          .map((d) => d.exists ? RiderDay.fromDoc(d) : null);

  /// Every rider day that is not closed yet — what the founders are waiting
  /// to take in, and what is still out on the road.
  static Stream<List<RiderDay>> watchOpenRiderDays() => riderDays
      .where('status', whereIn: ['open', 'handedOver'])
      .snapshots()
      .map(
        (q) =>
            q.docs.map(RiderDay.fromDoc).toList()
              ..sort((a, b) => b.dayKey.compareTo(a.dayKey)),
      );

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

  /// The period whose figures are frozen and out with the co-founders.
  ///
  /// There is at most one — the app will not seal a second until the first is
  /// closed — but the query returns a list so a farm that somehow has two can
  /// still see both rather than silently showing one.
  static Stream<List<FarmMonth>> watchSealedMonths() => months
      .where('status', isEqualTo: 'sealed')
      .snapshots()
      .map(
        (q) =>
            q.docs.map(FarmMonth.fromDoc).toList()
              ..sort((a, b) => a.id.compareTo(b.id)),
      );

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
