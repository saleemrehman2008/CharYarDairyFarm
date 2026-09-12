import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/db.dart';

/// What a customer is allowed to see: the shop, their own orders and their own
/// udhaar account. Kept separate from [FarmStore] so no customer device ever
/// asks Firestore for the farm's ledger.
class CustomerStore extends ChangeNotifier {
  CustomerStore({required this.uid}) {
    _subs.addAll(<StreamSubscription<dynamic>>[
      Db.watchProducts(onlyActive: true).listen((v) {
        _products = v;
        notifyListeners();
      }),
      Db.watchCustomerOrders(uid).listen((v) {
        _orders = v;
        notifyListeners();
      }),
      Db.watchUdhaar(uid).listen((v) {
        _udhaar = v;
        notifyListeners();
      }),
      Db.watchCustomerBills(uid).listen((v) {
        _bills = v;
        notifyListeners();
      }),
      Db.watchCustomerDeliveries(uid, monthIdOf(DateTime.now())).listen((v) {
        _deliveries = v;
        notifyListeners();
      }),
      Db.watchSettings().listen((v) {
        _settings = v;
        notifyListeners();
      }),
    ]);
  }

  final String uid;
  final List<StreamSubscription<dynamic>> _subs = [];

  List<Product> _products = const [];
  List<FarmOrder> _orders = const [];
  UdhaarAccount? _udhaar;
  List<Bill> _bills = const [];
  List<Delivery> _deliveries = const [];
  FarmSettings _settings = FarmSettings.fallback;

  List<Product> get products => _products;
  List<FarmOrder> get orders => _orders;
  UdhaarAccount? get udhaar => _udhaar;

  /// This month's milk, newest first, and every bill raised so far.
  List<Delivery> get deliveries => _deliveries;
  List<Bill> get bills => _bills;
  List<Bill> get unpaidBills => _bills.where((b) => !b.isSettled).toList();

  /// The bill waiting to be paid, newest first. This is what the customer is
  /// told about the moment the farm raises it — on their phone if push is on,
  /// and in the app either way.
  Bill? get billDue => unpaidBills.isEmpty ? null : unpaidBills.first;

  num get owedOnBills =>
      unpaidBills.fold<num>(0, (a, b) => a + (b.balance > 0 ? b.balance : 0));

  num get litresThisMonth => _deliveries.fold<num>(0, (a, d) => a + d.litres);
  num get amountThisMonth => _deliveries.fold<num>(0, (a, d) => a + d.amount);
  FarmSettings get settings => _settings;

  UdhaarStatus get udhaarStatus => _udhaar?.status ?? UdhaarStatus.none;
  bool get udhaarApproved => _udhaar?.isApproved ?? false;

  num get milkRate {
    for (final p in _products) {
      if (p.name.toLowerCase().contains('milk')) return p.price;
    }
    return _settings.milkPriceCache;
  }

  int get openOrderCount => _orders.where((o) => o.status.isOpen).length;

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
