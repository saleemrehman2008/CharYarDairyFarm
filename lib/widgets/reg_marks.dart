import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The "+" registration marks that sit at the corners of cards and primary
/// buttons — the print-press detail the brand is built on.
class RegMarks extends StatelessWidget {
  const RegMarks({
    super.key,
    required this.child,
    this.color = T.divider,
    this.arm = 4,
    this.inset = 5,
  });

  final Widget child;
  final Color color;

  /// Half-length of each stroke.
  final double arm;

  /// Distance from the corner to the centre of the mark.
  final double inset;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      child,
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _RegPainter(color: color, arm: arm, inset: inset),
          ),
        ),
      ),
    ],
  );
}

class _RegPainter extends CustomPainter {
  const _RegPainter({
    required this.color,
    required this.arm,
    required this.inset,
  });

  final Color color;
  final double arm;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1
      ..isAntiAlias = false;

    for (final c in [
      Offset(inset, inset),
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      Offset(size.width - inset, size.height - inset),
    ]) {
      canvas.drawLine(c.translate(-arm, 0), c.translate(arm, 0), p);
      canvas.drawLine(c.translate(0, -arm), c.translate(0, arm), p);
    }
  }

  @override
  bool shouldRepaint(covariant _RegPainter old) =>
      old.color != color || old.arm != arm || old.inset != inset;
}
