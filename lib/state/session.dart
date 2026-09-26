import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/db.dart';
import '../services/log_service.dart';
import '../services/month_repo.dart';
import '../services/notif_service.dart';
import '../services/user_repo.dart';
import '../theme/tokens.dart';

/// Who is signed in and what the app is allowed to show them.
///
/// Listens to Firebase Auth and then to that user's own document, so a role or
/// status the master changes in Firestore lands on the phone without a restart.
///
/// Every wait here is bounded. On a farm with patchy mobile data a stream that
/// never arrives would otherwise leave the app spinning on its splash screen
/// with nothing to tell the user, so a watchdog always ends the wait and says
/// what went wrong.
class Session extends ChangeNotifier {
  Session() {
    _startWatchdog();
    _authSub = AuthService.authState().listen(
      _onAuth,
      onError: (Object e) => _giveUp('Sign-in service did not respond. $e'),
    );
  }

  /// How long to wait before showing something instead of a spinner.
  static const _patience = Duration(seconds: 12);

  StreamSubscription<fb.User?>? _authSub;
  StreamSubscription<AppUser?>? _userSub;
  StreamSubscription<FarmSettings>? _settingsSub;
  Timer? _watchdog;

  fb.User? _fbUser;
  AppUser? _user;
  FarmSettings? _settings;
  bool _loading = true;
  bool _docMissing = false;
  String? _error;

  fb.User? get fbUser => _fbUser;
  AppUser? get user => _user;
  bool get loading => _loading;
  bool get signedIn => _fbUser != null;

  /// Set when a wait timed out or a stream failed; shown to the user.
  String? get error => _error;

  /// Signed in, but the profile document never arrived — usually Firestore
  /// rules not deployed yet, or no connection on first run.
  bool get profileUnavailable => signedIn && _user == null && !_loading;

  /// True while the user document has not been created yet — the first moment
  /// after a brand new sign-in.
  bool get awaitingProfile => signedIn && _user == null && !_docMissing;

  /// The farm's own settings, read once for the whole app.
  ///
  /// Every role needs these — a customer to know whether the shop is running,
  /// a rider to know who he can hand cash to — so they are held here rather
  /// than in the partners' store, which the other roles never build.
  FarmSettings get settings => _settings ?? FarmSettings.fallback;

  /// Which parts of the farm are switched on. Master only decides these;
  /// everybody else lives with the answer.
  Features get features => settings.features;

  /// True until the settings have been read once. A tab that would otherwise
  /// appear and then vanish waits on this.
  bool get settingsLoading => _settings == null;

  Lang get lang => _user?.lang ?? Lang.en;

  /// The skin this person chose. Dark until the profile says otherwise.
  Skin get skin => _user?.skin ?? Skin.dark;

  Role get role => _user?.role ?? Role.customer;
  Actor get actor => Actor(
    uid: _fbUser?.uid ?? '',
    name: _user?.name ?? _fbUser?.displayName ?? 'Someone',
  );

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(_patience, () {
      if (!_loading) return;
      _giveUp(
        signedIn
            ? 'Could not load your profile. Check the connection, or ask the '
                  'master whether the database rules have been published.'
            : 'Could not reach Firebase. Check the connection and try again.',
      );
    });
  }

  void _settle() {
    _watchdog?.cancel();
    _watchdog = null;
    _loading = false;
  }

  void _giveUp(String message) {
    _settle();
    _error = message;
    notifyListeners();
  }

  Future<void> _onAuth(fb.User? u) async {
    _fbUser = u;
    await _userSub?.cancel();
    _userSub = null;

    await _settingsSub?.cancel();
    _settingsSub = null;

    if (u == null) {
      _user = null;
      _settings = null;
      _docMissing = false;
      _error = null;
      _settle();
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    _startWatchdog();
    notifyListeners();

    try {
      await UserRepo.ensureDoc(u);
    } catch (_) {
      // Offline first run: the document stream below will pick it up later.
    }

    // Settings never hold up sign-in: a farm whose settings cannot be read
    // still has an app, it just runs on what it last knew.
    _settingsSub = Db.watchSettings().listen((v) {
      _settings = v;
      notifyListeners();
    }, onError: (Object _) {});

    _userSub = Db.watchUser(u.uid).listen(
      (appUser) {
        _user = appUser;
        _docMissing = appUser == null;
        _error = null;
        // The skin lives outside the widget tree, because the whole tree is
        // built from it. Set it here, where the profile lands, so it is
        // right on the first frame after sign-in and on every other phone
        // this person picks up.
        if (appUser != null) skinNow.value = appUser.skin;
        _settle();
        notifyListeners();

        if (appUser == null) return;
        // A blocked account is shown the door at the next refresh.
        if (appUser.isBlocked) {
          signOut();
        } else {
          Notifs.register(appUser);
          // Anyone who writes to the ledger needs to know which period is
          // open, so an entry made after a seal lands in the new one rather
          // than in figures the co-founders are already deciding about.
          if (appUser.role.canDeliver) MonthRepo.trackBooking();
        }
      },
      onError: (Object e) =>
          _giveUp('Could not read your profile from the database. $e'),
    );
  }

  /// Backs all the way out to the login screen after a failure.
  Future<void> retry() async {
    _error = null;
    _loading = true;
    _startWatchdog();
    notifyListeners();
    await _onAuth(AuthService.currentUser);
  }

  Future<void> signOut() async {
    await Notifs.unregister();
    await MonthRepo.stopTracking();
    await AuthService.signOut();
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _authSub?.cancel();
    _userSub?.cancel();
    _settingsSub?.cancel();
    super.dispose();
  }
}
