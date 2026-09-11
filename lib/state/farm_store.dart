import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/accounting.dart';
import '../services/db.dart';
import '../services/month_repo.dart';

/// One subscription set for the whole farm side of the app.
///
/// Home, Accounts, Orders, Co-founders and Close month all read the same
/// figures, so they are gathered once here instead of each screen opening its
/// own listeners.
class FarmStore extends ChangeNotifier {
  FarmStore({required this.isMaster}) {
    _subs.addAll(<StreamSubscription<dynamic>>[
      MonthRepo.watchOpen().listen((m) {
        final first = _month == null;
        _month = m;
        _resubscribeMonthTxns(m.id);
        if (first) MonthRepo.ensureOpen(m.id);
        notifyListeners();
      }),
      Db.watchUnpaidTxns().listen((v) {
        _unpaidTxns = v;
        notifyListeners();
      }),
      Db.watchPartners().listen((v) {
        _partners = v;
        notifyListeners();
      }),
      Db.watchProducts().listen((v) {
        _products = v;
        notifyListeners();
      }),
      Db.watchSettings().listen((v) {
        _settings = v;
        notifyListeners();
      }),
      Db.watchOrders().listen((v) {
        _orders = v;
        notifyListeners();
      }),
      Db.watchUdhaarAccounts().listen((v) {
        _udhaar = v;
        notifyListeners();
      }),
      if (isMaster)
        Db.watchUsers().listen((v) {
          _users = v;
          notifyListeners();
        }),
    ]);
  }

  final bool isMaster;
  final List<StreamSubscription<dynamic>> _subs = [];
  StreamSubscription<List<Txn>>? _monthTxnSub;

  FarmMonth? _month;
  List<Txn> _monthTxns = const [];
  List<Txn> _unpaidTxns = const [];
  List<Partner> _partners = const [];
  List<Product> _products = const [];
  List<FarmOrder> _orders = const [];
  List<UdhaarAccount> _udhaar = const [];
  List<AppUser> _users = const [];
  FarmSettings _settings = FarmSettings.fallback;

  FarmMonth get month =>
      _month ??
      FarmMonth(id: monthIdOf(DateTime.now()), status: 'open', openingCash: 0);

  bool get ready => _month != null;

  List<Txn> get monthTxns => _monthTxns;
  List<Txn> get unpaidTxns => _unpaidTxns;
  List<Partner> get partners => _partners;

  /// Shop order, active items only.
  List<Product> get shopProducts => _products.where((p) => p.active).toList();
  List<Product> get allProducts => _products;
  List<FarmOrder> get orders => _orders;
  List<UdhaarAccount> get udhaarAccounts => _udhaar;
  List<AppUser> get users => _users;
  FarmSettings get settings => _settings;

  Books get books => Books(
    monthId: month.id,
    openingCash: month.openingCash,
    monthTxns: _monthTxns,
    unpaidTxns: _unpaidTxns,
  );

  Map<String, double> get ratios => ratiosOf(_partners);

  num get totalCapital => _partners.fold<num>(0, (a, p) => a + p.capital);

  Partner? partnerFor(String uid) {
    for (final p in _partners) {
      if (p.userId == uid) return p;
    }
    return null;
  }

  /// Milk rate quoted on the udhaar estimate; falls back to the cached value.
  num get milkRate {
    for (final p in shopProducts) {
      if (p.name.toLowerCase().contains('milk')) return p.price;
    }
    return _settings.milkPriceCache;
  }

  // ---- Things needing attention ----

  List<FarmOrder> get pendingOrders => _orders
      .where((o) => o.status == OrderStatus.newOrder && !o.isApproved)
      .toList();

  List<FarmOrder> get openOrders =>
      _orders.where((o) => o.status.isOpen).toList();

  List<UdhaarAccount> get pendingUdhaar =>
      _udhaar.where((u) => u.status == UdhaarStatus.pending).toList();

  List<AppUser> get pendingUsers =>
      _users.where((u) => u.status == UserStatus.pending).toList();

  List<Txn> get payablesDue => _unpaidTxns.where((t) => t.isPayable).toList();

  List<Txn> get receivablesDue =>
      _unpaidTxns.where((t) => t.isReceivable).toList();

  int get approvalCount => pendingOrders.length + pendingUdhaar.length;

  void _resubscribeMonthTxns(String monthId) {
    _monthTxnSub?.cancel();
    _monthTxnSub = Db.watchMonthTxns(monthId).listen((v) {
      _monthTxns = v;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _monthTxnSub?.cancel();
    super.dispose();
  }
}
