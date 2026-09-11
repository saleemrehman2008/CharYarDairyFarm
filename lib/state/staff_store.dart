import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/db.dart';
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
    ]);
  }

  final List<StreamSubscription<dynamic>> _subs = [];

  List<UdhaarAccount> _khaata = const [];
  List<Delivery> _deliveries = const [];
  List<FarmOrder> _orders = const [];
  List<Bill> _bills = const [];
  FarmSettings _settings = FarmSettings.fallback;

  @override
  String get monthId => monthIdOf(DateTime.now());
  FarmSettings get settings => _settings;

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

  /// Everyone on today's round who has not been marked yet.
  int get roundLeft {
    final key = Delivery.dayKey(DateTime.now());
    final done = _deliveries
        .where((d) => Delivery.dayKey(d.date) == key)
        .map((d) => d.customerId)
        .toSet();
    return khaataCustomers.where((c) => !done.contains(c.uid)).length;
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
