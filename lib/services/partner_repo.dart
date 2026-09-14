import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../util/money.dart';
import 'db.dart';
import 'log_service.dart';

class PartnerRepo {
  PartnerRepo._();

  /// Master only. Raising a partner's capital re-weights every share ratio,
  /// which the app derives rather than stores.
  static Future<void> addInvestment(
    Actor actor,
    Partner partner,
    num amount,
  ) async {
    if (amount <= 0) return;
    await Db.partners.doc(partner.id).update({
      'invested': FieldValue.increment(amount),
    });
    await Log.write(
      actor,
      LogKind.investment,
      'added ${rs(amount)} investment for ${partner.name}',
      refType: 'partner',
      refId: partner.id,
    );
  }

  /// Master only. Removes a capital record that no money has ever passed
  /// through.
  ///
  /// For the duplicates: one person holding two accounts on the farm ends up
  /// with two records under the same name, and an older bug could leave a
  /// third. A record with nothing in it can go without anything being lost —
  /// no capital, no withdrawal, and no closed period's figures resting on it.
  /// A record with money in it is never deletable, whatever it is called.
  static Future<void> remove(Actor actor, Partner partner) async {
    if (!partner.isEmpty) {
      throw StateError(
        'That record holds money. Only an empty one can be removed.',
      );
    }
    await Db.partners.doc(partner.id).delete();

    // The user document points at this record so the rules can tell whose
    // share that person may decide about. Leave it pointing at nothing.
    if (partner.userId.isNotEmpty) {
      try {
        await Db.users.doc(partner.userId).set({
          'partnerId': FieldValue.delete(),
        }, SetOptions(merge: true));
      } catch (_) {
        // The record is gone either way; a stale pointer resolves to nothing.
      }
    }

    await Log.write(
      actor,
      LogKind.investment,
      'removed the empty co-founder record for ${partner.name}'
      '${partner.email.isEmpty ? '' : ' (${partner.email})'}',
      refType: 'partner',
      refId: partner.id,
    );
  }

  /// Master only. Opens a capital record for somebody who has not signed in
  /// yet.
  ///
  /// A co-founder can put money in months before they ever open the app, and
  /// the books have to be able to say so. Give the record their email and
  /// their own sign-in will claim it — name, share and capital all intact —
  /// instead of starting a second one beside it.
  static Future<String> create(
    Actor actor, {
    required String name,
    String email = '',
    String userId = '',
    num invested = 0,
  }) async {
    final doc = await Db.partners.add({
      'userId': userId,
      'name': name,
      'email': email.trim().toLowerCase(),
      'invested': invested,
      'reinvested': 0,
      'withdrawn': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await Log.write(
      actor,
      LogKind.investment,
      'added co-founder $name'
      '${invested > 0 ? ' with ${rs(invested)}' : ''}',
      refType: 'partner',
      refId: doc.id,
    );
    return doc.id;
  }
}
