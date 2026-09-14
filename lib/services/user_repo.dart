import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../models/models.dart';
import '../util/phone.dart';
import 'auth_service.dart';
import 'db.dart';
import 'log_service.dart';

class UserRepo {
  UserRepo._();

  /// Called right after a Google sign-in.
  ///
  /// A brand new account comes in as an active customer: it can shop, order and
  /// ask for udhaar straight away. Nothing is given away by that — an order
  /// still waits for a co-founder to approve it, and so does an udhaar account
  /// — and making people wait to see a price list only loses the farm sales.
  /// The master can still block anyone.
  ///
  /// The exceptions are the emails the master set aside on `settings/farm` —
  /// `autoCofounderEmails` and `staffEmails` — which take that role on their
  /// own sign-in. An existing account otherwise only refreshes its profile
  /// fields, so a role the master set by hand is never overwritten.
  static Future<void> ensureDoc(fb.User user) async {
    final ref = Db.users.doc(user.uid);
    final snap = await ref.get();
    final name = (user.displayName ?? '').trim().isEmpty
        ? (user.email ?? 'New user').split('@').first
        : user.displayName!.trim();
    final actor = Actor(uid: user.uid, name: name);
    final listed = await _listedRole(user.email);

    if (!snap.exists) {
      await ref.set({
        'name': name,
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'role': (listed ?? Role.customer).name,
        'status': 'active',
        'fcmTokens': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (listed == Role.investor) {
        await _ensurePartner(actor, email: user.email ?? '');
      }
      await Log.write(
        actor,
        LogKind.user,
        switch (listed) {
          Role.investor => 'joined as a co-founder',
          Role.staff => 'joined as delivery staff',
          _ => 'signed up as a customer',
        },
        refType: 'user',
        refId: user.uid,
      );
      return;
    }

    // Someone on a list who already signed in as a customer is moved across on
    // their next sign-in. A blocked account stays blocked, and the master's own
    // role is never touched.
    final data = snap.data() ?? const {};
    final role = s(data['role']);
    final status = s(data['status']);
    final upgrade =
        listed != null &&
        role != 'master' &&
        status != 'blocked' &&
        !(role == listed.name && status == 'active');

    // Anyone left waiting from before customers were let straight in is
    // activated on their next sign-in.
    final activate = !upgrade && role == 'customer' && status == 'pending';

    await ref.set({
      'name': name,
      'email': user.email ?? '',
      'photoUrl': user.photoURL ?? '',
      if (upgrade) 'role': listed.name,
      if (upgrade || activate) 'status': 'active',
    }, SetOptions(merge: true));

    if (upgrade) {
      await Log.write(
        actor,
        LogKind.user,
        listed == Role.staff
            ? 'joined as delivery staff'
            : 'joined as a co-founder',
        refType: 'user',
        refId: user.uid,
      );
    }

    // Anyone on the farm side holds capital — the master is a co-founder too,
    // so they need a partner record or they would be left out of the ratios.
    final finalRole = upgrade ? listed.name : role;
    if (finalRole == 'master' || finalRole == 'investor') {
      await _ensurePartner(actor, email: user.email ?? '');
    }

    await Log.write(
      actor,
      LogKind.login,
      'signed in',
      refType: 'user',
      refId: user.uid,
    );
  }

  /// The role the master set aside for this email, if any.
  ///
  /// The lists live on `settings/farm`, which only the partners can write, so a
  /// person's own sign-in can take the role without anyone having to be at a
  /// console when they do. Everyone else arrives as a customer.
  static Future<Role?> _listedRole(String? email) async {
    final address = (email ?? '').trim().toLowerCase();
    if (address.isEmpty) return null;
    try {
      final data = (await Db.farmSettings.get()).data() ?? const {};

      bool listedIn(String field) => ((data[field] as List?) ?? const [])
          .map((e) => s(e).trim().toLowerCase())
          .contains(address);

      if (listedIn('autoCofounderEmails')) return Role.investor;
      if (listedIn('staffEmails')) return Role.staff;
      return null;
    } catch (_) {
      // No settings document yet, or offline — treat as not listed.
      return null;
    }
  }

  /// Gives this account its capital record, and never a second one.
  ///
  /// The record is filed under the account's own id. That is the whole
  /// safeguard: signing in twice, or on two phones at once, or with the
  /// cached copy of the partners list out of date, all land on the same
  /// document. The old way looked the record up by a query first and created
  /// one when the query came back empty — and a query that came back empty
  /// for any reason at all quietly made a duplicate.
  ///
  /// Written with merge, so an existing record keeps every figure in it and
  /// only gains what is missing.
  static Future<void> _ensurePartner(Actor actor, {String email = ''}) async {
    var id = actor.uid;
    try {
      // A record already claimed by this account — including one made under
      // the old scheme, which has a random id. Keep using it rather than
      // opening a second one beside it.
      final mine = await Db.partners
          .where('userId', isEqualTo: actor.uid)
          .limit(1)
          .get();

      // Failing that, a record the master opened for this person before they
      // ever signed in, waiting under their email. Claim it, so the capital
      // they already put in stays theirs instead of a second record starting
      // at zero beside it.
      var claiming = false;
      if (mine.docs.isEmpty && email.isNotEmpty) {
        final waiting = await Db.partners
            .where('email', isEqualTo: email.trim().toLowerCase())
            .limit(5)
            .get();
        for (final doc in waiting.docs) {
          if (s(doc.data()['userId']).isEmpty) {
            id = doc.id;
            claiming = true;
            break;
          }
        }
      }

      final fresh = mine.docs.isEmpty && !claiming;
      if (mine.docs.isNotEmpty) id = mine.docs.first.id;

      await Db.partners.doc(id).set({
        'userId': actor.uid,
        'name': actor.name,
        // Lower case, because this is what a record waiting for its owner is
        // matched on and Google does not promise the case it hands back.
        if (email.isNotEmpty) 'email': email.trim().toLowerCase(),
        if (fresh) ...{
          'invested': 0,
          'reinvested': 0,
          'withdrawn': 0,
          'createdAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (_) {
      // The master can still add the partner by hand from Co-founders.
    }

    // Kept out of the try above on purpose. The rules read this pointer to
    // tell whose share this person may decide about, so it matters more than
    // the refresh does — and it must still be written on the day the refresh
    // is refused.
    try {
      await Db.users.doc(actor.uid).set({
        'partnerId': id,
      }, SetOptions(merge: true));
    } catch (_) {
      // Offline. The next sign-in writes it.
    }
  }

  /// Remembers where a customer wants milk delivered, so the next order does
  /// not ask again.
  static Future<void> saveDeliveryDetails(
    String uid, {
    required String address,
    required String mobile,
  }) async {
    await Db.users.doc(uid).set({
      'address': address.trim(),
      'mobile': Phone.normalise(mobile),
    }, SetOptions(merge: true));
  }

  /// The language this person reads the app in. Theirs alone — no other
  /// account changes with it, and it is not an approval of any kind, so
  /// anybody may set their own.
  static Future<void> setLang(String uid, Lang lang) async {
    await Db.users.doc(uid).set({'lang': lang.id}, SetOptions(merge: true));
  }

  static Future<void> saveFcmToken(String uid, String token) async {
    try {
      await Db.users.doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
    } catch (_) {
      // A missing token just means this device will not get pushes.
    }
  }

  static Future<void> setRole(Actor actor, AppUser user, Role role) async {
    if (user.role == role) return;
    await Db.users.doc(user.uid).update({'role': role.name});
    await Log.write(
      actor,
      LogKind.user,
      'made ${user.name} a ${role.label.toLowerCase()}',
      refType: 'user',
      refId: user.uid,
    );

    // A new co-founder needs a partner record to hold their capital.
    if (role == Role.investor) {
      await _ensurePartner(Actor(uid: user.uid, name: user.name));
    }
  }

  static Future<void> approve(Actor actor, AppUser user) async {
    await Db.users.doc(user.uid).update({'status': 'active'});
    await Log.write(
      actor,
      LogKind.user,
      'approved ${user.name}',
      refType: 'user',
      refId: user.uid,
    );
  }

  static Future<void> setBlocked(
    Actor actor,
    AppUser user, {
    required bool blocked,
  }) async {
    await Db.users.doc(user.uid).update({
      'status': blocked ? 'blocked' : 'active',
    });
    await Log.write(
      actor,
      LogKind.user,
      '${blocked ? 'blocked' : 'unblocked'} ${user.name}',
      refType: 'user',
      refId: user.uid,
    );
  }

  /// Google accounts have no app password, so "Reset" sends the account-recovery
  /// mail Firebase offers for that address.
  static Future<void> sendReset(Actor actor, AppUser user) async {
    await AuthService.sendPasswordReset(user.email);
    await Log.write(
      actor,
      LogKind.user,
      'sent a sign-in reset link to ${user.email}',
      refType: 'user',
      refId: user.uid,
    );
  }
}
