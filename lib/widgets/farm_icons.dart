import 'package:flutter/material.dart';

import '../util/svg_path.dart';

/// Phosphor Icons' cow, drawn as it was published.
///
/// Material has no cattle in it — the nearest thing is `Icons.pets`, a dog's
/// paw, which on a dairy farm's own app is simply wrong. Five attempts were
/// made at drawing one by hand and all five were rejected; the farm's
/// verdicts, in order, were a teddy bear, a devil, a rabbit and a cat. The
/// answer was to stop drawing and take a real one.
///
/// This is Phosphor Icons' `cow`, MIT licensed, which asks for nothing in
/// return — not a stock sheet with somebody's watermark across it. The
/// outline below is the published `d` string, unaltered, so the glyph is
/// the designer's and not an approximation of it.
///
/// Source: github.com/phosphor-icons/core, assets/regular/cow.svg (MIT).
const _cow =
    'M104,192a8,8,0,0,1-8,8H80a8,8,0,0,1,0-16H96A8,8,0,0,1,104,192Zm72-8H160'
    'a8,8,0,0,0,0,16h16a8,8,0,0,0,0-16Zm-76-48a12,12,0,1,0-12-12A12,12,0,0,0,'
    '100,136Zm56,0a12,12,0,1,0-12-12A12,12,0,0,0,156,136Zm88.39-13.88A16,16,'
    '0,0,1,232,128H200v32a40,40,0,0,1-24,72H80a40,40,0,0,1-24-72V128H24A16,16'
    ',0,0,1,8.31,109,56.13,56.13,0,0,1,63.22,64h1.64A55.83,55.83,0,0,1,48,24a'
    '8,8,0,0,1,16,0,40,40,0,0,0,40,40h48a40,40,0,0,0,40-40,8,8,0,0,1,16,0,55.'
    '83,55.83,0,0,1-16.86,40h1.64a56.13,56.13,0,0,1,54.91,45A15.82,15.82,0,0,'
    '1,244.39,122.12ZM72,152.8a40.57,40.57,0,0,1,8-.8h96a40.57,40.57,0,0,1,8,'
    '.8V104a24,24,0,0,0-24-24H96a24,24,0,0,0-24,24ZM56,112v-8a39.81,39.81,0,0'
    ',1,8-24h-.8A40.09,40.09,0,0,0,24,112Zm144,80a24,24,0,0,0-24-24H80a24,24,'
    '0,0,0,0,48h96A24,24,0,0,0,200,192Zm32-80a40.08,40.08,0,0,0-39.2-32H192a3'
    '9.81,39.81,0,0,1,8,24v8Z';

/// The published outline, parsed once. Every tile on every screen draws the
/// same object; parsing it per frame would be work for nothing.
final Path _cowPath = parseSvgPath(_cow);

class CattleIcon extends StatelessWidget {
  const CattleIcon({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _CowPainter(
        color: color ?? IconTheme.of(context).color ?? const Color(0xFF000000),
      ),
    ),
  );
}

class _CowPainter extends CustomPainter {
  const _CowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 256-point square, like the rest of the set.
    canvas.save();
    canvas.scale(size.width / 256, size.height / 256);
    canvas.drawPath(_cowPath, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CowPainter old) => old.color != color;
}
