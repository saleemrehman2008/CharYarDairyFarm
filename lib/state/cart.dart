import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// The customer's basket, held in memory until checkout.
class Cart extends ChangeNotifier {
  final Map<String, num> _qty = {};

  num qtyOf(String productId) => _qty[productId] ?? 0;
  bool get isEmpty => _qty.isEmpty;
  int get lineCount => _qty.length;

  void add(Product p, [num step = 1]) {
    _qty[p.id] = qtyOf(p.id) + step;
    notifyListeners();
  }

  void remove(Product p, [num step = 1]) {
    final next = qtyOf(p.id) - step;
    if (next <= 0) {
      _qty.remove(p.id);
    } else {
      _qty[p.id] = next;
    }
    notifyListeners();
  }

  void clear() {
    _qty.clear();
    notifyListeners();
  }

  /// Lines priced at today's rates, in shop order.
  List<OrderItem> lines(List<Product> products) => products
      .where((p) => qtyOf(p.id) > 0)
      .map(
        (p) => OrderItem(
          productId: p.id,
          name: p.name,
          qty: qtyOf(p.id),
          price: p.price,
          unit: p.unit,
        ),
      )
      .toList();

  num total(List<Product> products) =>
      lines(products).fold<num>(0, (a, l) => a + l.total);
}
