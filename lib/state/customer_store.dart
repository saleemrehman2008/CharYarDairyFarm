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
  FarmSettings _settings = FarmSettings.fallback;

  List<Product> get products => _products;
  List<FarmOrder> get orders => _orders;
  UdhaarAccount? get udhaar => _udhaar;
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

  /// An udhaar order is refused if it would push the balance past the limit.
  bool udhaarFits(num orderTotal) {
    final u = _udhaar;
    if (u == null || !u.isApproved) return false;
    return u.balance + orderTotal <= u.limit;
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
