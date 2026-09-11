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
  } catch (e) {
    initError = e;
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: T.bg,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(CharYarApp(initError: initError));
}

class CharYarApp extends StatelessWidget {
  const CharYarApp({super.key, this.initError});

  final Object? initError;

  @override
  Widget build(BuildContext context) {
    if (initError != null) {
      return MaterialApp(
        title: 'Char Yar Dairy Farm',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: NoticeScreen(
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
      child: MaterialApp(
        title: 'Char Yar Dairy Farm',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const AuthGate(),
      ),
    );
  }
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
      Role.customer => const CustomerRoot(),
    };
  }
}
