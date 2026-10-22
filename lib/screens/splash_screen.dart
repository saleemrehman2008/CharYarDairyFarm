import 'package:provider/provider.dart';
import '../state/session.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// What the farm looks at while the app finds its feet.
///
/// It used to be a 22-pixel spinner on an empty page, which reads as nothing
/// happening — and the wait felt twice as long as it was. The mark and the
/// farm's name say the right app opened and it is on its way.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => _build(context);

  Widget _build(BuildContext context) => Scaffold(
    backgroundColor: T.brandDeep,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The whole lockup, not the head. This is the first thing anybody
          // sees and there is a screen's worth of room for it; the head
          // alone is for the places that have none — a 36 point top bar, a
          // statement's corner.
          //
          // The farm's name used to be typed out underneath in the app's
          // own font. The drawing already says it, in its own lettering,
          // so it was the same words twice in two different hands.
          const FarmLogo(width: 268),
          const SizedBox(height: 34),
          SizedBox(
            width: 96,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(T.pill),
              child: LinearProgressIndicator(
                minHeight: 3,
                color: T.accent2,
                backgroundColor: Color(0x33FFFFFF),
              ),
            ),
          ),

          // Said only once it has taken longer than it should, and said as
          // what it is. A slow signal is not a reason to show somebody who
          // is already signed in a way out of his own app.
          if (context.watch<Session>().isSlow) ...[
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Signal dheema hy — intezar jari hy. Ap logged in hain, '
                'dobara login karne ki zaroorat nahi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xCCFFFFFF),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
