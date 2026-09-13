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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: T.accent900,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FarmLogo(width: 132, mark: true),
          const SizedBox(height: 20),
          Text(
            'CHAR YAR',
            style: T.screenTitle.copyWith(
              color: Colors.white,
              letterSpacing: 6,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'DAIRY FARM',
            style: T.meta.copyWith(color: T.accent300, letterSpacing: 4),
          ),
          const SizedBox(height: 34),
          SizedBox(
            width: 96,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(T.pill),
              child: const LinearProgressIndicator(
                minHeight: 3,
                color: T.accent2,
                backgroundColor: Color(0x33FFFFFF),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
