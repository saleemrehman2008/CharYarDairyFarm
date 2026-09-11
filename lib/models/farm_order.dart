import 'package:cloud_firestore/cloud_firestore.dart';
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

class OrderItem {
  const OrderItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.price,
    required this.unit,
  });

  final String productId;
  final String name;
  final num qty;
  final num price;
  final String unit;

  num get total => qty * price;

  /// "4 L Fresh milk"
  String get line {
    final q = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
    return '$q $unit $name';
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'qty': qty,
    'price': price,
    'unit': unit,
  };
}

class FarmOrder {
  FarmOrder({
    required this.id,
    required this.number,
    required this.customerId,
    required this.customerName,
    required this.items,
    required this.total,
    required this.mode,
    required this.slot,
    required this.repeat,
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
  final List<OrderItem> items;
  final num total;
  final String mode; // delivery | pickup
  final String slot; // morning | evening
  final String repeat; // once | daily
  final PayMethod pay;
  final OrderStatus status;
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;
  final DateTime? deliveredAt;
  final DateTime createdAt;

  bool get isApproved => approvedAt != null;
  bool get isUdhaar => pay == PayMethod.udhaar;

  /// "4 L Fresh milk, 1 kg Yogurt · daily"
  String get itemsText {
    final parts = items.map((e) => e.line).join(', ');
    return repeat == 'daily' ? '$parts · daily' : parts;
  }

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
      );
    }).toList()..sort((a, b) => a.name.compareTo(b.name));

    return FarmOrder(
      id: doc.id,
      number: s(m['number']).isEmpty ? doc.id : s(m['number']),
      customerId: s(m['customerId']),
      customerName: s(m['customerName']),
      items: items,
      total: n(m['total']),
      mode: s(m['mode']).isEmpty ? 'delivery' : s(m['mode']),
      slot: s(m['slot']).isEmpty ? 'morning' : s(m['slot']),
      repeat: s(m['repeat']).isEmpty ? 'once' : s(m['repeat']),
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
