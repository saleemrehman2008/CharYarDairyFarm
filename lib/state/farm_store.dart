import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/accounting.dart';
import '../services/bill_clock.dart';
import '../services/bill_repo.dart';
import '../services/db.dart';
import '../services/log_service.dart';
import '../services/month_repo.dart';
import 'round_data.dart';

/// One subscription set for the whole farm side of the app.
///
/// Home, Accounts, Orders, Co-founders and Close month all read the same
/// figures, so they are gathered once here instead of each screen opening its
/// own listeners.
class FarmStore extends ChangeNotifier implements RoundData {
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
      Db.watchAssetTxns().listen((v) {
        _assetTxns = v;
        notifyListeners();
      }),
      Db.watchClosedMonths().listen((v) {
        _closedMonths = v;
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
      Db.watchBills().listen((v) {
        _bills = v;
        notifyListeners();
      }),
      Db.watchUnbilledDeliveries().listen((v) {
        _unbilled = v;
        _raiseDueBills();
        notifyListeners();
      }),
      if (isMaster)
        Db.watchUsers().listen((v) {
          _users = v;
          notifyListeners();
        }),
    ]);

    _clock.start();
  }

  final bool isMaster;
  final List<StreamSubscription<dynamic>> _subs = [];
  StreamSubscription<List<Txn>>? _monthTxnSub;
  StreamSubscription<List<Delivery>>? _deliverySub;

  /// The 11pm sweep, for anyone the round missed on the last day.
  late final BillClock _clock = BillClock(_raiseDueBills);

  FarmMonth? _month;
  List<Txn> _monthTxns = const [];
  List<Txn> _unpaidTxns = const [];
  List<Txn> _assetTxns = const [];
  List<FarmMonth> _closedMonths = const [];
  List<Partner> _partners = const [];
  List<Product> _products = const [];
  List<FarmOrder> _orders = const [];
  List<UdhaarAccount> _udhaar = const [];
  List<Bill> _bills = const [];
  List<Delivery> _deliveries = const [];
  List<Delivery> _unbilled = const [];
  bool _running = false;
  bool _again = false;
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

  /// Khaata customers who are approved and so on the daily round.
  @override
  List<UdhaarAccount> get khaataCustomers =>
      _udhaar.where((u) => u.isApproved).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  /// Everyone who can still be billed, closed khaatas included.
  List<UdhaarAccount> get billableKhaata =>
      _udhaar.where((u) => u.isBillable).toList();

  @override
  List<Bill> get bills => _bills;
  @override
  List<Bill> get unpaidBills => _bills.where((b) => !b.isSettled).toList();
  @override
  List<Delivery> get monthDeliveries => _deliveries;

  @override
  String get monthId => month.id;

  /// Months already closed, newest first — the ledger can be looked back at.
  List<FarmMonth> get closedMonths => _closedMonths;

  List<AppUser> get users => _users;
  FarmSettings get settings => _settings;

  Books get books => Books(
    monthId: month.id,
    openingCash: month.openingCash,
    capital: capitalIn,
    monthTxns: _monthTxns,
    unpaidTxns: _unpaidTxns,
  );

  Map<String, double> get ratios => ratiosOf(_partners);

  num get totalCapital => _partners.fold<num>(0, (a, p) => a + p.capital);

  /// Money the partners actually put in, which is cash the farm can spend.
  /// Reinvested profit is left out: it never left the farm in the first place.
  num get capitalIn => _partners.fold<num>(0, (a, p) => a + p.invested);

  /// Everything the farm owns — cattle and equipment, across every month.
  num get assetsOwned => _assetTxns.fold<num>(0, (a, t) => a + t.amount);

  /// All-time figures, read from the closed months plus the open one. Closed
  /// months keep their own totals, so this costs a dozen documents a year
  /// rather than re-reading the whole ledger every time the app opens.
  num get lifetimeSales =>
      _closedMonths.fold<num>(0, (a, m) => a + (m.sales ?? 0)) + books.sales;

  num get lifetimeRunningCosts =>
      _closedMonths.fold<num>(
        0,
        (a, m) => a + (m.purchases ?? 0) + (m.expenses ?? 0) - (m.assets ?? 0),
      ) +
      books.costs;

  /// The whole route the farm's money has taken, for the Home breakdown.
  MoneySummary get money => MoneySummary(
    capital: capitalIn,
    assets: assetsOwned,
    runningCosts: lifetimeRunningCosts,
    sales: lifetimeSales,
    cash: books.cash,
    receivable: books.receivable,
    payable: books.payable,
  );

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

  /// Raises any bill that has fallen due.
  ///
  /// This is the month-end job a scheduled Cloud Function would do. It runs
  /// when the unbilled milk changes and again at 11 at night, only ever raises
  /// what is genuinely due, and is safe to repeat — so the worst a second phone
  /// can do is find there was nothing left to raise.
  Future<void> _raiseDueBills() async {
    if (_running) {
      // Something arrived mid-run; go round once more when this one is done.
      _again = true;
      return;
    }
    // Closed khaatas are included: someone taken off the round mid-month is
    // still owed for the milk they had.
    final billable = billableKhaata;
    if (_unbilled.isEmpty || billable.isEmpty) return;

    _running = true;
    try {
      await BillRepo.raiseDue(
        Actor(uid: 'auto', name: 'The app'),
        accounts: billable,
        unbilled: _unbilled,
      );
    } catch (_) {
      // Nothing is lost: the 11 o'clock run tries again, so does whoever opens
      // the app next, and the bills screen can always raise them by hand.
    } finally {
      _running = false;
    }

    if (_again) {
      _again = false;
      await _raiseDueBills();
    }
  }

  void _resubscribeMonthTxns(String monthId) {
    _monthTxnSub?.cancel();
    _monthTxnSub = Db.watchMonthTxns(monthId).listen((v) {
      _monthTxns = v;
      notifyListeners();
    });
    _deliverySub?.cancel();
    _deliverySub = Db.watchMonthDeliveries(monthId).listen((v) {
      _deliveries = v;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _monthTxnSub?.cancel();
    _deliverySub?.cancel();
    _clock.dispose();
    super.dispose();
  }
}
