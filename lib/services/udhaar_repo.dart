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
    num? rate,
    num? litresPerDay,
  }) async {
    await Db.udhaarAccounts.doc(account.uid).update({
      'status': 'approved',
      'rate': ?rate,
      'litresPerDay': ?litresPerDay,
      'approvedBy': actor.uid,
      'approvedByName': actor.name,
      'approvedAt': FieldValue.serverTimestamp(),
    });
    await Log.write(
      actor,
      LogKind.udhaar,
      'approved a khaata for ${account.name} '
      'at ${rs(rate ?? account.rate)} / L',
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

  /// Takes someone off the round mid-month, after billing them for what they
  /// have already had.
  ///
  /// The account is closed rather than deleted: whatever is still owing stays
  /// on it, and their bills and days remain readable. Reopening is just an
  /// approval away.
  static Future<void> close(Actor actor, UdhaarAccount account) async {
    await Db.udhaarAccounts.doc(account.uid).update({'status': 'closed'});
    await Log.write(
      actor,
      LogKind.udhaar,
      'closed ${account.name}\'s khaata'
      '${account.balance > 0 ? ' with ${rs(account.balance)} still owing' : ''}',
      refType: 'udhaar',
      refId: account.uid,
    );
  }

  /// Puts a closed khaata back on the round.
  static Future<void> reopen(Actor actor, UdhaarAccount account) async {
    await Db.udhaarAccounts.doc(account.uid).update({'status': 'approved'});
    await Log.write(
      actor,
      LogKind.udhaar,
      'reopened ${account.name}\'s khaata',
      refType: 'udhaar',
      refId: account.uid,
    );
  }

  /// Master only. The rate and the daily litres are the two terms of a
  /// khaata: what the milk costs, and how much of it goes out each day.
  static Future<void> setTerms(
    Actor actor,
    UdhaarAccount account, {
    required num rate,
    required num litresPerDay,
  }) async {
    await Db.udhaarAccounts.doc(account.uid).update({
      'rate': rate,
      'litresPerDay': litresPerDay,
    });
    await Log.write(
      actor,
      LogKind.udhaar,
      'set ${account.name}\'s khaata to ${qty(litresPerDay)} L/day '
      'at ${rs(rate)} / L',
      refType: 'udhaar',
      refId: account.uid,
    );
  }
}
