import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers.dart';

class Product {
  Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.photoUrl,
    required this.active,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final String unit;
  final num price;
  final String photoUrl;
  final bool active;
  final int sortOrder;

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return Product(
      id: doc.id,
      name: s(m['name']),
      unit: s(m['unit']).isEmpty ? 'L' : s(m['unit']),
      price: n(m['price']),
      photoUrl: s(m['photoUrl']),
      active: m['active'] == null ? true : b(m['active']),
      sortOrder: i(m['sortOrder']),
    );
  }

  static const units = ['L', 'kg', 'pc', 'dozen'];
}
