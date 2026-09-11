import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../models/models.dart';
import 'auth_service.dart';
import 'db.dart';
import 'log_service.dart';

class UserRepo {
  UserRepo._();

  /// Called right after a Google sign-in. A brand new account lands as a
  /// pending customer; an existing one only refreshes its profile fields so a
  /// role the master set by hand is never overwritten.
  static Future<void> ensureDoc(fb.User user) async {
    final ref = Db.users.doc(user.uid);
    final snap = await ref.get();
    final name = (user.displayName ?? '').trim().isEmpty
        ? (user.email ?? 'New user').split('@').first
        : user.displayName!.trim();

    if (!snap.exists) {
      await ref.set({
        'name': name,
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'role': 'customer',
        'status': 'pending',
        'fcmTokens': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });
      await Log.write(
        Actor(uid: user.uid, name: name),
        LogKind.user,
        'signed up and is waiting for approval',
        refType: 'user',
        refId: user.uid,
      );
      return;
    }

    await ref.set({
      'name': name,
      'email': user.email ?? '',
      'photoUrl': user.photoURL ?? '',
    }, SetOptions(merge: true));

    await Log.write(
      Actor(uid: user.uid, name: name),
      LogKind.login,
      'signed in',
      refType: 'user',
      refId: user.uid,
    );
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
    if (role == Role.investor && user.partnerId == null) {
      final partner = await Db.partners.add({
        'userId': user.uid,
        'name': user.name,
        'invested': 0,
        'reinvested': 0,
        'withdrawn': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await Db.users.doc(user.uid).update({'partnerId': partner.id});
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
