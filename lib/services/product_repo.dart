import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/models.dart';
import '../util/money.dart';
import 'db.dart';
import 'log_service.dart';

class ProductRepo {
  ProductRepo._();

  static Future<String> add(
    Actor actor, {
    required String name,
    required num price,
    required String unit,
    int sortOrder = 99,
  }) async {
    final doc = await Db.products.add({
      'name': name,
      'unit': unit,
      'price': price,
      'photoUrl': '',
      'active': true,
      'sortOrder': sortOrder,
      'updatedBy': actor.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await Log.write(
      actor,
      LogKind.products,
      'added "$name" at ${rs(price)} / $unit',
      refType: 'product',
      refId: doc.id,
    );
    return doc.id;
  }

  static Future<void> setPrice(Actor actor, Product product, num price) async {
    if (price == product.price) return;
    await Db.products.doc(product.id).update({
      'price': price,
      'updatedBy': actor.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await Log.write(
      actor,
      LogKind.products,
      'changed "${product.name}" rate ${rs(product.price)} to ${rs(price)}',
      refType: 'product',
      refId: product.id,
    );

    // The udhaar limit suggestion quotes the milk rate, so keep a copy handy.
    if (product.name.toLowerCase().contains('milk')) {
      await Db.farmSettings.set({
        'milkPriceCache': price,
      }, SetOptions(merge: true));
    }
  }

  /// Removing hides the item from the shop but keeps past orders readable.
  static Future<void> remove(Actor actor, Product product) async {
    await Db.products.doc(product.id).update({
      'active': false,
      'updatedBy': actor.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await Log.write(
      actor,
      LogKind.products,
      'removed "${product.name}" from the shop',
      refType: 'product',
      refId: product.id,
    );
  }

  static Future<String> uploadPhoto(
    Actor actor,
    Product product,
    File file,
  ) async {
    final ext = file.path.split('.').last.toLowerCase();
    final ref = FirebaseStorage.instance.ref(
      'products/${product.id}.${ext.isEmpty ? 'jpg' : ext}',
    );
    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    await Db.products.doc(product.id).update({
      'photoUrl': url,
      'updatedBy': actor.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await Log.write(
      actor,
      LogKind.products,
      'updated the photo for "${product.name}"',
      refType: 'product',
      refId: product.id,
    );
    return url;
  }
}
