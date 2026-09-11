import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// A full-screen dead end with a way out — used when the app cannot carry on
/// but a blank spinner would tell the user nothing.
class NoticeScreen extends StatelessWidget {
  const NoticeScreen({
    super.key,
    required this.title,
    required this.body,
    this.detail,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String body;

  /// The underlying error, shown small — worth having when someone sends a
  /// screenshot to ask what went wrong.
  final String? detail;

  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: T.bg,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/logo.png', width: 120),
              const SizedBox(height: 20),
              Text(title, style: T.screenTitle, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: T.body.copyWith(color: T.n700),
              ),
              if (detail != null) ...[
                const SizedBox(height: 14),
                RegCard(
                  padding: const EdgeInsets.all(10),
                  child: Text(detail!, style: T.meta),
                ),
              ],
              if (primaryLabel != null) ...[
                const SizedBox(height: 22),
                PrimaryButton(label: primaryLabel!, onPressed: onPrimary),
              ],
              if (secondaryLabel != null) ...[
                const SizedBox(height: 10),
                GhostButton(label: secondaryLabel!, onPressed: onSecondary),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
