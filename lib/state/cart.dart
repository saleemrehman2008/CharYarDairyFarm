import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// The customer's basket, held in memory until checkout.
///
/// Each item keeps its own delivery days. Milk is wanted every morning and a
/// kilo of ghee once a fortnight, so one set of days across the whole basket
/// would deliver whichever of them was wrong.
class Cart extends ChangeNotifier {
  final Map<String, num> _qty = {};
  final Map<String, Set<String>> _days = {};

  num qtyOf(String productId) => _qty[productId] ?? 0;
  bool get isEmpty => _qty.isEmpty;
  int get lineCount => _qty.length;

  /// The days this item is wanted on. A new item starts on today alone.
  Set<String> daysOf(String productId) =>
      _days[productId] ?? {dayKeyOf(DateTime.now())};

  void setDays(String productId, Set<String> days) {
    _days[productId] = days;
    notifyListeners();
  }

  void add(Product p, [num step = 1]) {
    _qty[p.id] = qtyOf(p.id) + step;
    _days.putIfAbsent(p.id, () => {dayKeyOf(DateTime.now())});
    notifyListeners();
  }

  void remove(Product p, [num step = 1]) {
    final next = qtyOf(p.id) - step;
    if (next <= 0) {
      _qty.remove(p.id);
      _days.remove(p.id);
    } else {
      _qty[p.id] = next;
    }
    notifyListeners();
  }

  void clear() {
    _qty.clear();
    _days.clear();
    notifyListeners();
  }

  /// Every day any item is wanted on — the days the round will see.
  Set<String> get allDays => {for (final id in _qty.keys) ...daysOf(id)};

  /// What one day's drop comes to: only the items wanted that day.
  num amountOn(String dayKey, List<Product> products) => products
      .where((p) => qtyOf(p.id) > 0 && daysOf(p.id).contains(dayKey))
      .fold<num>(0, (a, p) => a + qtyOf(p.id) * p.price);

  /// Lines priced at today's rates, each with its own days, in shop order.
  List<OrderItem> lines(List<Product> products) => products
      .where((p) => qtyOf(p.id) > 0)
      .map(
        (p) => OrderItem(
          productId: p.id,
          name: p.name,
          qty: qtyOf(p.id),
          price: p.price,
          unit: p.unit,
          dayKeys: daysOf(p.id).toList()..sort(),
        ),
      )
      .toList();

  /// The whole order: every item across every one of its own days.
  num total(List<Product> products) =>
      lines(products).fold<num>(0, (a, l) => a + l.total);
}
