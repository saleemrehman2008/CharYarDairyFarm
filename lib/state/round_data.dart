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
}
