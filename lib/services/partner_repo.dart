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

  static Future<String> create(
    Actor actor, {
    required String name,
    String userId = '',
    num invested = 0,
  }) async {
    final doc = await Db.partners.add({
      'userId': userId,
      'name': name,
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
