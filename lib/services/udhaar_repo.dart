import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../util/money.dart';
import 'db.dart';
import 'log_service.dart';

class UdhaarRepo {
  UdhaarRepo._();

  /// Customer asks for a monthly-credit account. The suggested limit is
  /// litres x milk rate x 30 x 1.2; the master can edit it on approval.
  static Future<void> request(
    Actor actor, {
    required String name,
    required String address,
    required String mobile,
    required String slot,
    required num litresPerDay,
    required num milkRate,
  }) async {
    await Db.udhaarAccounts.doc(actor.uid).set({
      'name': name,
      'address': address,
      'mobile': mobile,
      'slot': slot,
      'litresPerDay': litresPerDay,
      // Starts at the shop rate; the master can give a regular a better one.
      'rate': milkRate,
      'limit': UdhaarAccount.suggestLimit(litresPerDay, milkRate),
      'balance': 0,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await Log.write(
      actor,
      LogKind.udhaar,
      'opened a khaata for $litresPerDay L/day',
      refType: 'udhaar',
      refId: actor.uid,
    );
  }

  static Future<void> approve(
    Actor actor,
    UdhaarAccount account, {
    num? limit,
    num? rate,
  }) async {
    await Db.udhaarAccounts.doc(account.uid).update({
      'status': 'approved',
      'limit': ?limit,
      'rate': ?rate,
      'approvedBy': actor.uid,
      'approvedByName': actor.name,
      'approvedAt': FieldValue.serverTimestamp(),
    });
    await Log.write(
      actor,
      LogKind.udhaar,
      'approved udhaar for ${account.name} '
      '(limit ${rs(limit ?? account.limit)})',
      refType: 'udhaar',
      refId: account.uid,
    );
  }

  static Future<void> reject(Actor actor, UdhaarAccount account) async {
    await Db.udhaarAccounts.doc(account.uid).update({
      'status': 'rejected',
      'approvedBy': actor.uid,
      'approvedByName': actor.name,
      'approvedAt': FieldValue.serverTimestamp(),
    });
    await Log.write(
      actor,
      LogKind.udhaar,
      'did not approve udhaar for ${account.name}',
      refType: 'udhaar',
      refId: account.uid,
    );
  }

  /// Master only. The rate and the limit are the two terms of a khaata, so
  /// they are changed together.
  static Future<void> setTerms(
    Actor actor,
    UdhaarAccount account, {
    required num limit,
    num? rate,
  }) async {
    await Db.udhaarAccounts.doc(account.uid).update({
      'limit': limit,
      'rate': ?rate,
    });
    await Log.write(
      actor,
      LogKind.udhaar,
      'set ${account.name}\'s khaata to ${rs(limit)} limit'
      '${rate == null ? '' : ' at ${rs(rate)} / L'}',
      refType: 'udhaar',
      refId: account.uid,
    );
  }
}
