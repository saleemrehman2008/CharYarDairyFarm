import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// What the daily round and the bills screens need, whoever is holding the
/// phone.
///
/// A partner's [FarmStore] and a delivery person's [StaffStore] both satisfy
/// this, so the two screens are written once and neither has to know which
/// store it is looking at — or what else that store can see.
abstract class RoundData extends ChangeNotifier {
  String get monthId;
  List<UdhaarAccount> get khaataCustomers;
  List<Delivery> get monthDeliveries;
  List<Bill> get bills;
  List<Bill> get unpaidBills;

  /// Shop orders the round has to take out: approved, not yet finished, and
  /// going to a door rather than being collected from the farm.
  List<FarmOrder> get roundOrders;

  /// Every order the farm has on its books that is still to go out, approved
  /// or not. The round shows only the approved ones, but it uses this to say
  /// why the others are missing instead of showing an empty screen.
  List<FarmOrder> get allOpenOrders;
}

/// The same filtering for either store. An extension rather than a method on
/// the interface, because both stores `implement` it and would each have to
/// carry their own copy of a rule that is the same for both.
extension RoundOrders on RoundData {
  /// The orders still to go out on one day, in one slot. A week's order turns
  /// up on each of its days until that day is marked delivered.
  List<FarmOrder> ordersOn(String dayKey, String slot) => roundOrders
      .where((o) => o.dueOn(dayKey) && !o.deliveredOn(dayKey))
      .where((o) => (o.slot == 'evening') == (slot == 'evening'))
      .toList();

  /// Orders for today that a co-founder has not approved yet, so the round
  /// cannot show them. A rider staring at an empty list deserves to know.
  List<FarmOrder> awaitingApprovalOn(String dayKey) => allOpenOrders
      .where((o) => !o.isApproved && o.dueOn(dayKey) && !o.deliveredOn(dayKey))
      .toList();

  /// Everyone on today's round who has not been marked yet.
  int get roundLeft {
    final key = Delivery.dayKey(DateTime.now());
    final done = monthDeliveries
        .where((d) => Delivery.dayKey(d.date) == key)
        .map((d) => d.customerId)
        .toSet();
    return khaataCustomers.where((c) => !done.contains(c.uid)).length;
  }

  /// Approved orders for days still to come.
  List<FarmOrder> laterThan(String dayKey) => roundOrders
      .where((o) => o.daysLeft.any((d) => d.compareTo(dayKey) > 0))
      .toList();
}
