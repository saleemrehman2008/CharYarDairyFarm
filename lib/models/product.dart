import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers.dart';

class Product {
  Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.photoUrl,
    required this.photo,
    required this.active,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final String unit;
  final num price;

  /// A Storage link, from before pictures moved into the record itself.
  final String photoUrl;

  /// The picture, base64, on the product itself. One size: the shop tile is
  /// the only place a product is ever shown.
  final String photo;

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
      photo: s(m['photo']),
      active: m['active'] == null ? true : b(m['active']),
      sortOrder: i(m['sortOrder']),
    );
  }

  static const units = ['L', 'kg', 'pc', 'dozen'];
}
