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

  /// Master only. Corrects the name or the email on a capital record.
  ///
  /// The email is not decoration: a record carrying somebody's address is
  /// claimed by that person the first time they sign in, name, capital and
  /// all, instead of a second record starting up beside it. Typed wrong, the
  /// co-founder signs in and the app opens them a fresh empty record while
  /// their capital sits on the old one under nobody. Correcting it is how
  /// that is undone, so it has to be correctable.
  static Future<void> rename(
    Actor actor,
    Partner partner, {
    required String name,
    required String email,
  }) async {
    final to = name.trim();
    final mail = email.trim().toLowerCase();
    if (to.isEmpty) throw StateError('A record needs a name.');
    if (to == partner.name && mail == partner.email.trim().toLowerCase()) {
      return;
    }
    await Db.partners.doc(partner.id).update({'name': to, 'email': mail});
    await Log.write(
      actor,
      LogKind.investment,
      'changed the co-founder record "${partner.name}"'
      '${partner.email.isEmpty ? '' : ' (${partner.email})'} to "$to"'
      '${mail.isEmpty ? '' : ' ($mail)'}',
      refType: 'partner',
      refId: partner.id,
    );
  }

  /// Master only. Sets a partner's capital to a figure, rather than adding
  /// to it — for correcting one that went in wrong.
  ///
  /// This is not a small button. Capital is the sole basis of the share
  /// ratios, so moving one partner's figure moves all four partners' slices
  /// of every month closed from here on. There is no way to make that
  /// invisible and no attempt is made to: what it was and what it became
  /// both go in the log, under the name of whoever did it, where the other
  /// three can read it. A farm run by four friends can survive a figure
  /// being corrected; it cannot survive one being corrected quietly.
  ///
  /// Months already closed keep the slices they were closed with. Those were
  /// worked out on the day and written down, and this does not reach back
  /// into them.
  static Future<void> setInvested(
    Actor actor,
    Partner partner,
    num amount,
  ) async {
    if (amount < 0) {
      throw StateError('Capital cannot be less than nothing.');
    }
    final was = partner.invested;
    if (was == amount) return;
    await Db.partners.doc(partner.id).update({'invested': amount});
    await Log.write(
      actor,
      LogKind.investment,
      'changed ${partner.name} capital from ${rs(was)} to ${rs(amount)}',
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
  /// A record with money in it can go too, but only when [force] says so —
  /// which the screen only sets after naming every figure being lost. The
  /// master asked to be able to, and the honest answer is that this is their
  /// farm; the job here is to make sure nobody does it by accident and that
  /// nobody can do it unseen.
  static Future<void> remove(
    Actor actor,
    Partner partner, {
    bool force = false,
  }) async {
    if (!partner.isEmpty && !force) {
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
      partner.isEmpty
          ? 'removed the empty co-founder record for ${partner.name}'
                '${partner.email.isEmpty ? '' : ' (${partner.email})'}'
          // Every figure that went with it, written down. The record is gone
          // and this line is the only thing left that says what was in it.
          : 'removed the co-founder record for ${partner.name}'
                '${partner.email.isEmpty ? '' : ' (${partner.email})'} '
                'holding ${rs(partner.invested)} capital, '
                '${rs(partner.profitHeld)} profit kept in the farm and '
                '${rs(partner.withdrawn)} taken out',
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
