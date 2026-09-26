import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'models/models.dart';
import 'screens/blocked_screen.dart';
import 'screens/cofounder/cofounder_root.dart';
import 'screens/customer/customer_root.dart';
import 'screens/login_screen.dart';
import 'screens/master/master_root.dart';
import 'screens/notice_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/staff/staff_root.dart';
import 'state/cart.dart';
import 'state/session.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android reads its configuration from google-services.json, so no generated
  // options file is needed. Run `flutterfire configure` when iOS is added.
  //
  // A failure here means the APK was built without a usable
  // google-services.json. Carry the error into the UI rather than dying on a
  // blank screen, so the message reaches whoever installed the build.
  Object? initError;
  try {
    await Firebase.initializeApp();

    // Keep what the phone has already seen. The farm's data changes slowly and
    // its signal does not: with the cache on, a screen draws from the last
    // snapshot straight away and the fresh figures slide in behind it, instead
    // of the app sitting on a spinner while it fetches what it already knew.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    initError = e;
  }

  paintSystemBars();

  runApp(CharYarApp(initError: initError));
}

/// Paint the status bar and the navigation bar to match the skin.
///
/// Android draws those two strips itself, outside anything Flutter controls,
/// so a black app with a white strip at the top looks like two apps stacked.
/// Called at start and again whenever the skin changes.
void paintSystemBars() {
  final bars = T.isDark ? Brightness.light : Brightness.dark;
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: bars,
      statusBarBrightness: T.isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: T.bg,
      systemNavigationBarIconBrightness: bars,
    ),
  );
}

class CharYarApp extends StatelessWidget {
  const CharYarApp({super.key, this.initError});

  final Object? initError;

  @override
  Widget build(BuildContext context) {
    if (initError != null) {
      return _skinned(
        NoticeScreen(
          title: 'Firebase did not start',
          body:
              'This build could not reach its Firebase project. It was '
              'probably built without a valid google-services.json.',
          detail: '$initError',
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Session()),
        ChangeNotifierProvider(create: (_) => Cart()),
      ],
      child: _skinned(const AuthGate()),
    );
  }

  /// The app, rebuilt from the top whenever the skin changes.
  ///
  /// [T] reads the skin on every access rather than holding a value, so the
  /// only thing needed to repaint the whole app is to build it again — no
  /// screen has to know a skin exists.
  Widget _skinned(Widget home) => ValueListenableBuilder<Skin>(
    valueListenable: skinNow,
    builder: (_, _, _) {
      paintSystemBars();
      return MaterialApp(
        title: 'Char Yar Dairy Farm',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: home,
      );
    },
  );
}

/// Picks the home screen from the signed-in user's role.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();

    if (session.loading) return const SplashScreen();
    if (!session.signedIn) return const LoginScreen();

    final user = session.user;
    // Signed in, but the profile never arrived. Say so instead of spinning.
    if (user == null) {
      return NoticeScreen(
        title: 'Could not load your account',
        body:
            'You are signed in, but the farm database did not answer. '
            'Check the connection and try again.',
        detail: session.error,
        primaryLabel: 'Try again',
        onPrimary: session.retry,
        secondaryLabel: 'Sign out',
        onSecondary: session.signOut,
      );
    }
    if (user.isBlocked) return const BlockedScreen();

    return switch (user.role) {
      Role.master => const MasterRoot(),
      Role.investor => const CofounderRoot(),
      Role.staff => const StaffRoot(),
      Role.customer => const CustomerRoot(),
    };
  }
}
