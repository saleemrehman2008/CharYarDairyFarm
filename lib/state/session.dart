import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/db.dart';
import '../services/log_service.dart';
import '../services/notif_service.dart';
import '../services/user_repo.dart';

/// Who is signed in and what the app is allowed to show them.
///
/// Listens to Firebase Auth and then to that user's own document, so a role or
/// status the master changes in Firestore lands on the phone without a restart.
class Session extends ChangeNotifier {
  Session() {
    _authSub = AuthService.authState().listen(_onAuth);
  }

  StreamSubscription<fb.User?>? _authSub;
  StreamSubscription<AppUser?>? _userSub;

  fb.User? _fbUser;
  AppUser? _user;
  bool _loading = true;
  bool _docMissing = false;

  fb.User? get fbUser => _fbUser;
  AppUser? get user => _user;
  bool get loading => _loading;
  bool get signedIn => _fbUser != null;

  /// True while the user document has not been created yet — the first moment
  /// after a brand new sign-in.
  bool get awaitingProfile => signedIn && _user == null && !_docMissing;

  Role get role => _user?.role ?? Role.customer;
  Actor get actor => Actor(
    uid: _fbUser?.uid ?? '',
    name: _user?.name ?? _fbUser?.displayName ?? 'Someone',
  );

  Future<void> _onAuth(fb.User? u) async {
    _fbUser = u;
    await _userSub?.cancel();
    _userSub = null;

    if (u == null) {
      _user = null;
      _loading = false;
      _docMissing = false;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();

    try {
      await UserRepo.ensureDoc(u);
    } catch (_) {
      // Offline first run: the document stream below will pick it up later.
    }

    _userSub = Db.watchUser(u.uid).listen((appUser) {
      _user = appUser;
      _docMissing = appUser == null;
      _loading = false;
      notifyListeners();

      if (appUser == null) return;
      // A blocked account is shown the door at the next refresh.
      if (appUser.isBlocked) {
        signOut();
      } else {
        Notifs.register(appUser);
      }
    });
  }

  Future<void> signOut() async {
    await Notifs.unregister();
    await AuthService.signOut();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}
