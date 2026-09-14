import 'package:flutter/material.dart';

/// A buffalo's head, drawn rather than borrowed.
///
/// Material has no cattle in it. The nearest thing is `Icons.pets`, which is a
/// dog's paw — on a dairy farm's own app, next to the word for its animals,
/// that is simply wrong. So this is drawn: the wide forehead, the ears under
/// the horns, and the horns sweeping out and up, which is what tells a buffalo
/// from a cow at the size of a fingernail.
///
/// Stroked at the same weight as the outlined Material icons it sits beside,
/// and scaled from a 24-point square like them, so it does not look like a
/// guest among them.
class CattleIcon extends StatelessWidget {
  const CattleIcon({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _CattlePainter(
        color: color ?? IconTheme.of(context).color ?? const Color(0xFF000000),
      ),
    ),
  );
}

class _CattlePainter extends CustomPainter {
  const _CattlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final dot = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    Offset p(double x, double y) => Offset(x * k, y * k);

    // The head: a broad forehead narrowing to the muzzle.
    canvas.drawPath(
      Path()
        ..moveTo(7.0 * k, 10.2 * k)
        ..cubicTo(6.9 * k, 14.8 * k, 8.6 * k, 18.2 * k, 12 * k, 18.2 * k)
        ..cubicTo(15.4 * k, 18.2 * k, 17.1 * k, 14.8 * k, 17.0 * k, 10.2 * k)
        ..cubicTo(17.0 * k, 8.2 * k, 14.9 * k, 7.3 * k, 12 * k, 7.3 * k)
        ..cubicTo(9.1 * k, 7.3 * k, 7.0 * k, 8.2 * k, 7.0 * k, 10.2 * k)
        ..close(),
      line,
    );

    // Ears: leaf shapes out to the sides, clear of the horns. Keeping the two
    // apart is what stops the whole thing reading as a goat.
    canvas.drawPath(
      Path()
        ..moveTo(7.0 * k, 11.0 * k)
        ..quadraticBezierTo(3.9 * k, 10.7 * k, 2.5 * k, 12.4 * k)
        ..quadraticBezierTo(4.2 * k, 14.1 * k, 6.9 * k, 13.0 * k)
        ..close(),
      line,
    );
    canvas.drawPath(
      Path()
        ..moveTo(17.0 * k, 11.0 * k)
        ..quadraticBezierTo(20.1 * k, 10.7 * k, 21.5 * k, 12.4 * k)
        ..quadraticBezierTo(19.8 * k, 14.1 * k, 17.1 * k, 13.0 * k)
        ..close(),
      line,
    );

    // Horns: one clean sweep out and up from the top of the head. No curl —
    // a curled tip reads as a ram at this size.
    canvas.drawPath(
      Path()
        ..moveTo(8.6 * k, 7.8 * k)
        ..quadraticBezierTo(5.4 * k, 5.0 * k, 2.8 * k, 6.2 * k),
      line,
    );
    canvas.drawPath(
      Path()
        ..moveTo(15.4 * k, 7.8 * k)
        ..quadraticBezierTo(18.6 * k, 5.0 * k, 21.2 * k, 6.2 * k),
      line,
    );

    // Eyes and nostrils. Round dots rather than drawn shapes, because at
    // twenty points anything more becomes a smudge.
    canvas.drawCircle(p(10.1, 11.9), 0.9 * k, dot);
    canvas.drawCircle(p(13.9, 11.9), 0.9 * k, dot);
    canvas.drawCircle(p(11.1, 15.7), 0.62 * k, dot);
    canvas.drawCircle(p(12.9, 15.7), 0.62 * k, dot);
  }

  @override
  bool shouldRepaint(_CattlePainter old) => old.color != color;
}
