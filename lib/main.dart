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
import 'screens/splash_screen.dart';
import 'state/cart.dart';
import 'state/session.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android reads its configuration from google-services.json, so no generated
  // options file is needed. Run `flutterfire configure` when iOS is added.
  await Firebase.initializeApp();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: T.bg,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const CharYarApp());
}

class CharYarApp extends StatelessWidget {
  const CharYarApp({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
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

/// Picks the home screen from the signed-in user's role.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();

    if (session.loading) return const SplashScreen();
    if (!session.signedIn) return const LoginScreen();

    final user = session.user;
    if (user == null) return const SplashScreen();
    if (user.isBlocked) return const BlockedScreen();

    return switch (user.role) {
      Role.master => const MasterRoot(),
      Role.investor => const CofounderRoot(),
      Role.customer => const CustomerRoot(),
    };
  }
}
