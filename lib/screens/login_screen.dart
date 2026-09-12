import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.signInWithGoogle();
      // The auth stream swaps this screen out; nothing else to do here.
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not sign in. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // A startup failure Session gave up on also belongs on this screen.
    final message = _error ?? context.watch<Session>().error;

    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/logo.png', width: 180),
                const SizedBox(height: 22),
                const Kicker('Fresh & natural · Quality milk'),
                const SizedBox(height: 10),
                const Text(
                  'Char Yar Dairy Farm',
                  textAlign: TextAlign.center,
                  style: T.title,
                ),
                const SizedBox(height: 12),
                Text(
                  'Order fresh milk and dairy, or sign in as a partner to run '
                  'the farm books.',
                  textAlign: TextAlign.center,
                  style: T.body.copyWith(color: T.n700),
                ),
                const SizedBox(height: 26),
                PrimaryButton(
                  label: 'Continue with Google',
                  busy: _busy,
                  onPressed: _signIn,
                ),
                const SizedBox(height: 12),
                Text(
                  'Customers can order straight away. Each order is confirmed '
                  'by the farm before it is prepared.',
                  textAlign: TextAlign.center,
                  style: T.meta,
                ),
                if (message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: T.meta.copyWith(color: T.alert),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
