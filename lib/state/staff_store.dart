import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/bill_clock.dart';
import '../services/bill_repo.dart';
import '../services/db.dart';
import '../services/log_service.dart';
import 'round_data.dart';

/// What a delivery person needs, and nothing else.
///
/// Deliberately kept apart from [FarmStore]: staff never read the ledger, the
/// partners' capital or the profit, so this store never asks Firestore for
/// them. Their phone could not show the farm's books even if a screen tried.
class StaffStore extends ChangeNotifier implements RoundData {
  StaffStore() {
    final monthId = monthIdOf(DateTime.now());
    _subs.addAll(<StreamSubscription<dynamic>>[
      Db.watchUdhaarAccounts().listen((v) {
        _khaata = v;
        notifyListeners();
      }),
      Db.watchMonthDeliveries(monthId).listen((v) {
        _deliveries = v;
        notifyListeners();
      }),
      Db.watchOrders().listen((v) {
        _orders = v;
        notifyListeners();
      }),
      Db.watchBills().listen((v) {
        _bills = v;
        notifyListeners();
      }),
      Db.watchSettings().listen((v) {
        _settings = v;
        notifyListeners();
      }),
      Db.watchUnbilledDeliveries().listen((v) {
        _unbilled = v;
        notifyListeners();
      }),
    ]);

    _clock.start();
  }

  final List<StreamSubscription<dynamic>> _subs = [];

  /// The delivery man is usually the last one awake with the app open, so his
  /// phone takes the 11pm sweep too. Billing is safe to run from anywhere.
  late final BillClock _clock = BillClock(_raiseDueBills);
  bool _running = false;

  List<UdhaarAccount> _khaata = const [];
  List<Delivery> _deliveries = const [];
  List<Delivery> _unbilled = const [];
  List<FarmOrder> _orders = const [];
  List<Bill> _bills = const [];
  FarmSettings _settings = FarmSettings.fallback;

  @override
  String get monthId => monthIdOf(DateTime.now());
  FarmSettings get settings => _settings;

  /// Who the day's cash can be handed to.
  List<FarmPerson> get founders => _settings.founders;

  /// The shop rate, which is what a spot sale goes out at.
  num get milkRate => _settings.milkPriceCache;

  /// Approved khaata customers, in the order the round is walked.
  @override
  List<UdhaarAccount> get khaataCustomers =>
      _khaata.where((u) => u.isApproved).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  @override
  List<Delivery> get monthDeliveries => _deliveries;
  @override
  List<Bill> get bills => _bills;
  @override
  List<Bill> get unpaidBills => _bills.where((b) => !b.isSettled).toList();

  /// Orders still to be prepared or taken out — the ones a delivery round
  /// actually has to do something about.
  List<FarmOrder> get openOrders =>
      _orders.where((o) => o.status.isOpen && o.isApproved).toList();

  @override
  List<FarmOrder> get roundOrders =>
      openOrders.where((o) => o.mode != 'pickup').toList();

  @override
  List<FarmOrder> get allOpenOrders =>
      _orders.where((o) => o.status.isOpen).toList();

  /// Everything the rider's phone has, finished or not — what the three
  /// filters on his Orders tab pick from.
  List<FarmOrder> get allOpenOrdersAndDone => _orders;

  /// The 11 o'clock sweep: whoever was missed on the last day of the month
  /// still gets billed tonight. Idempotent, so it does not matter that a
  /// partner's phone may be doing the same thing at the same moment.
  Future<void> _raiseDueBills() async {
    if (_running || _unbilled.isEmpty) return;
    final billable = _khaata.where((u) => u.isBillable).toList();
    if (billable.isEmpty) return;

    _running = true;
    try {
      await BillRepo.raiseDue(
        Actor(uid: 'auto', name: 'The app'),
        accounts: billable,
        unbilled: _unbilled,
      );
    } catch (_) {
      // A partner's phone, or tomorrow's catch-up, will get it.
    } finally {
      _running = false;
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _clock.dispose();
    super.dispose();
  }
}
