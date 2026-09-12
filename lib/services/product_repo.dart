import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../util/money.dart';
import 'db.dart';
import 'log_service.dart';
import 'photo_store.dart';

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
      'photo': '',
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

  /// The shop picture, shrunk and kept on the product itself.
  ///
  /// Firebase Storage would be the obvious home, but switching it on needs a
  /// card on a billing account with no spending ceiling, and the farm would
  /// rather not. A shop tile is 220 points wide, so a small picture is all it
  /// was ever going to show. See [Photos].
  static Future<String> uploadPhoto(
    Actor actor,
    Product product,
    File file,
  ) async {
    final photo = await Photos.prepare(file);

    await Db.products.doc(product.id).update({
      'photo': photo.full,
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
    return photo.full;
  }
}
