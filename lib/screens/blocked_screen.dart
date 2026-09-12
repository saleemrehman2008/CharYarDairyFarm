import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// Shown for the moment between a master blocking an account and the app
/// signing that device out.
class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: T.bg,
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FarmLogo(width: 150),
              const SizedBox(height: 20),
              const Text('Account blocked', style: T.screenTitle),
              const SizedBox(height: 8),
              Text(
                'This account cannot use the app right now. Please contact the '
                'farm master.',
                textAlign: TextAlign.center,
                style: T.body.copyWith(color: T.n700),
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                label: 'Sign out',
                onPressed: context.read<Session>().signOut,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
