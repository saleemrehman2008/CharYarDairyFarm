import 'package:cloud_firestore/cloud_firestore.dart';

import '../util/money.dart';
import 'helpers.dart';

enum OrderStatus {
  newOrder,
  preparing,
  out,
  delivered,
  cancelled;

  static OrderStatus parse(Object? v) => switch (s(v)) {
    'preparing' => OrderStatus.preparing,
    'out' => OrderStatus.out,
    'delivered' => OrderStatus.delivered,
    'cancelled' => OrderStatus.cancelled,
    _ => OrderStatus.newOrder,
  };

  String get key => switch (this) {
    OrderStatus.newOrder => 'new',
    OrderStatus.preparing => 'preparing',
    OrderStatus.out => 'out',
    OrderStatus.delivered => 'delivered',
    OrderStatus.cancelled => 'cancelled',
  };

  String get label => switch (this) {
    OrderStatus.newOrder => 'New',
    OrderStatus.preparing => 'Preparing',
    OrderStatus.out => 'Out for delivery',
    OrderStatus.delivered => 'Delivered',
    OrderStatus.cancelled => 'Cancelled',
  };

  /// Position on the 4-segment progress bar; a cancelled order fills none.
  int get step => switch (this) {
    OrderStatus.newOrder => 1,
    OrderStatus.preparing => 2,
    OrderStatus.out => 3,
    OrderStatus.delivered => 4,
    OrderStatus.cancelled => 0,
  };

  OrderStatus? get next => switch (this) {
    OrderStatus.newOrder => OrderStatus.preparing,
    OrderStatus.preparing => OrderStatus.out,
    OrderStatus.out => OrderStatus.delivered,
    _ => null,
  };

  /// Copy for the button that advances the order one step.
  String? get advanceLabel => switch (next) {
    OrderStatus.preparing => 'Mark preparing',
    OrderStatus.out => 'Mark out for delivery',
    OrderStatus.delivered => 'Mark delivered',
    _ => null,
  };

  bool get isOpen =>
      this != OrderStatus.delivered && this != OrderStatus.cancelled;
}

enum PayMethod {
  cod,
  bank,
  jazzcash,
  udhaar;

  static PayMethod parse(Object? v) => switch (s(v)) {
    'bank' => PayMethod.bank,
    'jazzcash' => PayMethod.jazzcash,
    'udhaar' => PayMethod.udhaar,
    _ => PayMethod.cod,
  };

  String get label => switch (this) {
    PayMethod.cod => 'Cash on delivery',
    PayMethod.bank => 'Bank transfer',
    PayMethod.jazzcash => 'JazzCash / EasyPaisa',
    PayMethod.udhaar => 'Monthly khaata',
  };

  String get short => switch (this) {
    PayMethod.cod => 'Cash on delivery',
    PayMethod.bank => 'Bank transfer',
    PayMethod.jazzcash => 'JazzCash / EasyPaisa',
    PayMethod.udhaar => 'Khaata',
  };
}

/// One line of an order, with the days it is to be delivered on.
///
/// Each item carries its own days, because they do not go out together: milk
/// comes every morning and a kilo of ghee comes once. Ordering both and
/// putting one set of days on the order would send four kilos of ghee.
class OrderItem {
  const OrderItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.price,
    required this.unit,
    this.dayKeys = const [],
  });

  final String productId;
  final String name;
  final num qty;
  final num price;
  final String unit;

  /// The days this item goes out on, `YYYY-MM-DD`, in order.
  final List<String> dayKeys;

  /// One delivery of this line.
  num get each => qty * price;

  /// Every delivery of it, across all its days.
  num get total => each * (dayKeys.isEmpty ? 1 : dayKeys.length);

  bool dueOn(String dayKey) => dayKeys.isEmpty || dayKeys.contains(dayKey);

  /// "4 L Fresh milk"
  String get line {
    final q = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
    return '$q $unit $name';
  }

  /// "4 L Fresh milk · 7 days"
  String get lineWithDays =>
      dayKeys.length > 1 ? '$line · ${dayKeys.length} days' : line;

  Map<String, dynamic> toMap() => {
    'name': name,
    'qty': qty,
    'price': price,
    'unit': unit,
    'dayKeys': dayKeys,
  };
}

class FarmOrder {
  FarmOrder({
    required this.id,
    required this.number,
    required this.customerId,
    required this.customerName,
    required this.address,
    required this.mobile,
    required this.items,
    required this.total,
    required this.mode,
    required this.slot,
    required this.repeat,
    required this.dayKeys,
    required this.doneDays,
    required this.pay,
    required this.status,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    this.deliveredAt,
    required this.createdAt,
  });

  final String id;
  final String number;
  final String customerId;
  final String customerName;

  /// Where it goes and who to ring — carried on the order so the person doing
  /// the round has it in front of them, and so a later move does not rewrite
  /// where an old order actually went.
  final String address;
  final String mobile;

  final List<OrderItem> items;
  final num total;
  final String mode; // delivery | pickup
  final String slot; // morning | evening
  final String repeat; // once | daily

  /// The days this order is to be delivered on, `YYYY-MM-DD`, in order.
  ///
  /// A customer ordering milk for the coming week places one order with seven
  /// days on it. Each day is delivered and paid for on its own, so the round
  /// shows the order on every one of those days and the money lands the day
  /// the milk actually goes out.
  final List<String> dayKeys;

  /// The days already delivered.
  final List<String> doneDays;
  final PayMethod pay;
  final OrderStatus status;
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;
  final DateTime? deliveredAt;
  final DateTime createdAt;

  bool get isApproved => approvedAt != null;
  bool get isUdhaar => pay == PayMethod.udhaar;

  /// The items going out on one day. Milk every morning, ghee on the one
  /// day it was asked for.
  List<OrderItem> itemsOn(String dayKey) =>
      items.where((i) => i.dueOn(dayKey)).toList();

  /// What that day's delivery comes to — which is what the customer pays on
  /// the day, and what the books take when it is marked delivered.
  num amountOn(String dayKey) {
    final due = itemsOn(dayKey);
    if (due.isEmpty) return 0;
    // An order from before items carried days: the whole thing is one drop.
    if (items.every((i) => i.dayKeys.isEmpty)) {
      return dayKeys.isEmpty ? total : total / dayKeys.length;
    }
    return due.fold<num>(0, (a, i) => a + i.each);
  }

  /// What the person delivering has to come back with. A khaata order is
  /// billed at month end, so nothing is taken at the door.
  num toCollectOn(String dayKey) => isUdhaar ? 0 : amountOn(dayKey);

  bool get isMultiDay => dayKeys.length > 1;

  /// Days still to go out, in order.
  List<String> get daysLeft =>
      dayKeys.where((d) => !doneDays.contains(d)).toList();

  bool deliveredOn(String dayKey) => doneDays.contains(dayKey);
  bool dueOn(String dayKey) => dayKeys.contains(dayKey);

  /// Whether the whole order has gone out.
  bool get allDaysDone => daysLeft.isEmpty && dayKeys.isNotEmpty;

  /// "day 3 of 7", for the round and the receipt line.
  String dayLabel(String dayKey) {
    final i = dayKeys.indexOf(dayKey);
    if (!isMultiDay || i < 0) return '';
    return 'day ${i + 1} of ${dayKeys.length}';
  }

  /// "13–19 Sep" or "13 Sep, 15 Sep, 18 Sep" — how the days read at a glance.
  String get daysText {
    if (dayKeys.isEmpty) return '';
    final dates = dayKeys.map(dayFromKey).nonNulls.toList();
    if (dates.isEmpty) return '';
    if (dates.length == 1) return fmtDate(dates.first);

    // A run of consecutive days reads as a span; anything else is listed.
    final consecutive = List.generate(
      dates.length,
      (i) => i == 0 || dates[i].difference(dates[i - 1]).inDays == 1,
    ).every((x) => x);

    if (consecutive) {
      return '${fmtDate(dates.first)} – ${fmtDate(dates.last)} '
          '(${dates.length} days)';
    }
    return dates.map(fmtDate).join(', ');
  }

  /// "4 L Fresh milk · 7 days, 1 kg Ghee" — each line with its own count,
  /// because they do not all go out the same number of times.
  String get itemsText =>
      items.map((e) => isMultiDay ? e.lineWithDays : e.line).join(', ');

  /// The same for one day's drop: just what is going out that morning.
  String itemsTextOn(String dayKey) =>
      itemsOn(dayKey).map((e) => e.line).join(', ');

  String get modeLabel => mode == 'pickup' ? 'Farm pickup' : 'Home delivery';
  String get slotLabel => slot == 'evening' ? 'Evening 5–8' : 'Morning 6–9';

  factory FarmOrder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    final raw = (m['items'] as Map<String, dynamic>?) ?? const {};
    final items = raw.entries.map((e) {
      final v = (e.value as Map?)?.cast<String, dynamic>() ?? const {};
      return OrderItem(
        productId: e.key,
        name: s(v['name']),
        qty: n(v['qty']),
        price: n(v['price']),
        unit: s(v['unit']),
        dayKeys: strings(v['dayKeys']),
      );
    }).toList()..sort((a, b) => a.name.compareTo(b.name));

    return FarmOrder(
      id: doc.id,
      number: s(m['number']).isEmpty ? doc.id : s(m['number']),
      customerId: s(m['customerId']),
      customerName: s(m['customerName']),
      address: s(m['address']),
      mobile: s(m['mobile']),
      items: items,
      total: n(m['total']),
      mode: s(m['mode']).isEmpty ? 'delivery' : s(m['mode']),
      slot: s(m['slot']).isEmpty ? 'morning' : s(m['slot']),
      repeat: s(m['repeat']).isEmpty ? 'once' : s(m['repeat']),
      // Orders placed before days were a thing are a single delivery, on the
      // day they were ordered.
      dayKeys: strings(m['dayKeys']).isEmpty
          ? [dayKeyOf(dtOr(m['createdAt']))]
          : strings(m['dayKeys']),
      doneDays: strings(m['doneDays']),
      pay: PayMethod.parse(m['pay']),
      status: OrderStatus.parse(m['status']),
      approvedBy: m['approvedBy'] == null ? null : s(m['approvedBy']),
      approvedByName: m['approvedByName'] == null
          ? null
          : s(m['approvedByName']),
      approvedAt: dt(m['approvedAt']),
      deliveredAt: dt(m['deliveredAt']),
      createdAt: dtOr(m['createdAt']),
    );
  }
}
