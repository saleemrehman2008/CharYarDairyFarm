import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show SetOptions;
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
      // One listener for every period, rather than one for closed and another
      // for sealed. A sealed period used to fall between the two, which is how
      // a whole month's figures went missing from the all-time totals.
      Db.watchPeriods().listen((v) {
        _periods = v;
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
        _followFeatures(v.features);
        notifyListeners();
      }),
      if (isMaster)
        Db.watchUsers().listen((v) {
          _users = v;
          _publishFounders();
          notifyListeners();
        }),
    ]);

    _clock.start();
  }

  final bool isMaster;
  final List<StreamSubscription<dynamic>> _subs = [];
  StreamSubscription<List<Txn>>? _monthTxnSub;
  StreamSubscription<List<Delivery>>? _deliverySub;

  /// Listeners for the parts of the farm that can be switched off, kept by
  /// name so they can be started and stopped as the master changes his mind.
  ///
  /// The app used to open all fifteen of these the moment it launched, whether
  /// the farm was using them or not, and then wait on every one before it drew
  /// anything. A farm with orders and khaata switched off now opens about half
  /// as many, and reaches its first screen in about half the time.
  final Map<String, StreamSubscription<dynamic>> _optional = {};

  /// Starts and stops the optional listeners to match what is switched on.
  void _followFeatures(Features f) {
    _watch(
      'orders',
      f.orders,
      () => Db.watchOrders().listen((v) {
        _orders = v;
        notifyListeners();
      }),
    );

    _watch(
      'khaata',
      f.khaata,
      () => Db.watchUdhaarAccounts().listen((v) {
        _udhaar = v;
        notifyListeners();
      }),
    );
    _watch(
      'bills',
      f.khaata,
      () => Db.watchBills().listen((v) {
        _bills = v;
        notifyListeners();
      }),
    );
    _watch(
      'unbilled',
      f.khaata,
      () => Db.watchUnbilledDeliveries().listen((v) {
        _unbilled = v;
        _raiseDueBills();
        notifyListeners();
      }),
    );

    _watch(
      'cattle',
      f.cattle,
      () => Db.watchAnimals().listen((v) {
        _animals = v;
        notifyListeners();
      }),
    );

    _watch(
      'riders',
      f.rider,
      () => Db.watchOpenRiderDays().listen((v) {
        _riderDays = v;
        notifyListeners();
      }),
    );

    // Nothing switched off should leave a stale figure behind on a badge.
    if (!f.orders) _orders = const [];
    if (!f.khaata) {
      _udhaar = const [];
      _bills = const [];
      _unbilled = const [];
    }
    if (!f.cattle) _animals = const [];
    if (!f.rider) _riderDays = const [];
  }

  void _watch(
    String key,
    bool wanted,
    StreamSubscription<dynamic> Function() open,
  ) {
    final running = _optional.containsKey(key);
    if (wanted == running) return;
    if (wanted) {
      _optional[key] = open();
    } else {
      _optional.remove(key)?.cancel();
    }
  }

  /// The 11pm sweep, for anyone the round missed on the last day.
  late final BillClock _clock = BillClock(_raiseDueBills);

  FarmMonth? _month;
  List<Txn> _monthTxns = const [];
  List<Txn> _unpaidTxns = const [];
  List<Txn> _assetTxns = const [];

  /// Every period, newest first.
  List<FarmMonth> _periods = const [];
  List<Partner> _partners = const [];
  List<Product> _products = const [];
  List<FarmOrder> _orders = const [];
  List<UdhaarAccount> _udhaar = const [];
  List<Bill> _bills = const [];
  List<Delivery> _deliveries = const [];
  List<Delivery> _unbilled = const [];
  List<Animal> _animals = const [];
  List<RiderDay> _riderDays = const [];
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

  // ---- The cattle register ----

  /// Every animal ever registered, including the ones that have left.
  List<Animal> get animals => _animals;

  List<Animal> get herd => _animals.where((a) => a.status.isHere).toList();

  /// Animals that could be a mother: females still on the farm.
  List<Animal> get dams =>
      herd.where((a) => a.sex == Sex.female && a.species.milks).toList();

  /// A vaccination or check that has come round, soonest first. This is the
  /// whole reason for writing the next date down.
  List<Animal> get dueChecks =>
      herd.where((a) => a.dueSoon()).toList()
        ..sort((a, b) => a.nextDueOn!.compareTo(b.nextDueOn!));

  /// What the herd is giving a day, by the last reading of each animal.
  num get herdLitresPerDay =>
      herd.fold<num>(0, (a, x) => a + (x.isMilking ? x.dailyLitres : 0));

  int get milkingCount => herd.where((a) => a.isMilking).length;

  Animal? animalById(String? id) {
    if (id == null) return null;
    for (final a in _animals) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  List<Bill> get bills => _bills;
  @override
  List<Bill> get unpaidBills => _bills.where((b) => !b.isSettled).toList();
  @override
  List<Delivery> get monthDeliveries => _deliveries;

  @override
  String get monthId => month.id;

  /// Months already closed, newest first — the ledger can be looked back at.
  /// Periods that have been settled — closed, or sealed and waiting. Newest
  /// first.
  ///
  /// Both count towards the farm's all-time figures: a sealed period's trading
  /// happened, whatever is still being decided about the profit.
  List<FarmMonth> get settledPeriods =>
      _periods.where((m) => m.isFrozen).toList();

  List<FarmMonth> get closedMonths =>
      _periods.where((m) => m.isClosed).toList();

  /// Every period including the open one, newest first.
  List<FarmMonth> get periods => _periods;

  /// The period waiting on the co-founders: frozen figures, decisions coming
  /// in. Null when there is none, which is most of the time.
  FarmMonth? get sealedPeriod {
    for (final m in _periods) {
      if (m.isSealed) return m;
    }
    return null;
  }

  List<AppUser> get users => _users;
  FarmSettings get settings => _settings;

  /// Which parts of the farm the master has switched on.
  Features get features => _settings.features;

  Books get books => Books(
    monthId: month.id,
    openingCash: month.openingCash,
    capital: capitalIn,
    monthTxns: _monthTxns,
    unpaidTxns: _unpaidTxns,
    withRider: cashWithRiders,
  );

  // ---- Out with the riders ----

  /// Every rider day still open or waiting to be taken in.
  List<RiderDay> get riderDays => _riderDays;

  /// Handovers a founder has been asked to take in.
  List<RiderDay> get handoversWaiting =>
      _riderDays.where((d) => d.isWaiting).toList();

  /// Riders out on the road right now with something on them.
  List<RiderDay> get ridersOut =>
      _riderDays.where((d) => d.isOpen && !d.isEmpty).toList();

  /// Cash taken at doors that no founder has taken in yet.
  num get cashWithRiders => _riderDays.fold<num>(
    0,
    (a, d) => a + (d.cashInHand > 0 ? d.cashInHand : 0),
  );

  /// Milk out with the riders and not yet accounted for.
  num get milkWithRiders => _riderDays
      .where((d) => d.isOpen)
      .fold<num>(
        0,
        (a, d) => a + (d.milkUnaccounted > 0 ? d.milkUnaccounted : 0),
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
      settledPeriods.fold<num>(0, (a, m) => a + (m.sales ?? 0)) + books.sales;

  num get lifetimeRunningCosts =>
      settledPeriods.fold<num>(
        0,
        (a, m) => a + (m.purchases ?? 0) + (m.expenses ?? 0) - (m.assets ?? 0),
      ) +
      books.costs;

  /// What the farm has made since the day it started.
  num get lifetimeProfit => lifetimeSales - lifetimeRunningCosts;

  /// The whole route the farm's money has taken, for the Home breakdown.
  MoneySummary get money => MoneySummary(
    capital: capitalIn,
    assets: assetsOwned,
    runningCosts: lifetimeRunningCosts,
    sales: lifetimeSales,
    cash: books.cash,
    receivable: books.receivable,
    payable: books.payable,
    withRider: cashWithRiders,
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

  @override
  List<FarmOrder> get roundOrders => _orders
      .where((o) => o.status.isOpen && o.isApproved && o.mode != 'pickup')
      .toList();

  @override
  List<FarmOrder> get allOpenOrders => openOrders;

  List<UdhaarAccount> get pendingUdhaar =>
      _udhaar.where((u) => u.status == UdhaarStatus.pending).toList();

  List<AppUser> get pendingUsers =>
      _users.where((u) => u.status == UserStatus.pending).toList();

  List<Txn> get payablesDue => _unpaidTxns.where((t) => t.isPayable).toList();

  List<Txn> get receivablesDue =>
      _unpaidTxns.where((t) => t.isReceivable).toList();

  int get approvalCount => pendingOrders.length + pendingUdhaar.length;

  /// Keeps the rider-readable list of co-founders in step with the real one.
  ///
  /// A rider's phone cannot read the users collection — it has no business
  /// knowing who else uses the app — but he does have to pick somebody to
  /// hand the day's cash to. So the master's app writes the names where
  /// everyone can see them, and rewrites them whenever they change.
  Future<void> _publishFounders() async {
    if (!isMaster) return;
    final live =
        _users
            .where((u) => u.role.isPartner && u.status != UserStatus.blocked)
            .map((u) => FarmPerson(uid: u.uid, name: u.name))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    if (live.isEmpty) return;

    final known = _settings.founders;
    final same =
        known.length == live.length &&
        List.generate(
          live.length,
          (i) => known[i].uid == live[i].uid && known[i].name == live[i].name,
        ).every((x) => x);
    if (same) return;

    try {
      await Db.farmSettings.set({
        'founders': [for (final p in live) p.toMap()],
      }, SetOptions(merge: true));
    } catch (_) {
      // A rider picking from a stale list is a small thing; failing the
      // master's home screen over it is not.
    }
  }

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
    for (final s in _optional.values) {
      s.cancel();
    }
    _optional.clear();
    _monthTxnSub?.cancel();
    _deliverySub?.cancel();
    _clock.dispose();
    super.dispose();
  }
}
