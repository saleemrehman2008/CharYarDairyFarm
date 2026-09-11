import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google sign-in, kept behind one call so the login screen stays dumb.
///
/// The native Credential Manager flow is tried first. On Android it needs the
/// OAuth web client id, which the `google-services` Gradle plugin writes into
/// `default_web_client_id` from `google-services.json` — so no id is passed
/// here. If that resource is missing (Google sign-in not enabled in the
/// Firebase console yet) we fall back to Firebase's own browser flow, which
/// needs no client id at all.
class AuthService {
  AuthService._();

  static final _auth = FirebaseAuth.instance;
  static bool _initialised = false;

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> authState() => _auth.authStateChanges();

  /// Passed in from `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` when the
  /// generated resource is not usable; normally left empty.
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  static Future<void> _ensureInit() async {
    if (_initialised) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
    );
    _initialised = true;
  }

  /// Returns null when the user backed out of the Google sheet.
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      await _ensureInit();
      final google = GoogleSignIn.instance;
      if (!google.supportsAuthenticate()) return _browserFallback();

      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        // No id token means the web client id never reached the app.
        return _browserFallback();
      }
      return _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      return _browserFallback();
    }
  }

  static Future<UserCredential?> _browserFallback() async {
    try {
      return await _auth.signInWithProvider(GoogleAuthProvider());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'web-context-canceled' || e.code == 'canceled') return null;
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      if (_initialised) await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Signing out of Firebase is what matters; ignore plugin noise.
    }
    await _auth.signOut();
  }

  /// Used by the master's "Reset" button on the Users screen.
  static Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);
}
