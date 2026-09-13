// Draws a line round the outside of part of a picture, and only the outside.
//
//   dart run tool/outline.dart <image> --box l,t,r,b --width N [--out file]
//
// Asking an image tool for "an outline around the bull" gets an outline
// around every line of the bull, inner detail and all, which turns silver
// line art into navy line art. What was wanted is the silhouette: the shape
// you would get tracing round the outside of the whole head with one unbroken
// line, leaving every line inside it alone.
//
// That is a shape question, not a drawing question, and the alpha channel
// already answers it. Flood the empty space in from the edges: whatever it
// reaches is outside, and whatever it cannot reach is a gap enclosed by the
// artwork. Grow the artwork by a few pixels, keep only the growth that landed
// outside, and paint that. The gaps between the inner lines are never outside,
// so they are never painted.

import 'dart:collection';
import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'dart run tool/outline.dart <image> --box l,t,r,b --width N [--out f]',
    );
    exit(2);
  }

  final src = img.decodeImage(File(args.first).readAsBytesSync());
  if (src == null) {
    stderr.writeln('Cannot read that.');
    exit(2);
  }

  final image = src.convert(numChannels: 4);
  final width = int.tryParse(_flag(args, '--width') ?? '') ?? 6;
  final out = _flag(args, '--out') ?? 'outlined.png';
  final colour = _colour(_flag(args, '--colour') ?? '1B2A5B');

  // Which part of the picture to work on. Everything outside the box is left
  // exactly as it was.
  final box = _flag(args, '--box');
  final b = box == null ? (0, 0, image.width, image.height) : _box(box, image);

  final painted = _outline(image, b, width, colour);
  File(out).writeAsBytesSync(img.encodePng(image));
  stdout.writeln('Outlined $painted pixels, $width wide → $out');
}

String? _flag(List<String> args, String name) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

img.ColorRgb8 _colour(String hex) => img.ColorRgb8(
  int.parse(hex.substring(0, 2), radix: 16),
  int.parse(hex.substring(2, 4), radix: 16),
  int.parse(hex.substring(4, 6), radix: 16),
);

(int, int, int, int) _box(String spec, img.Image im) {
  final f = spec.split(',').map(double.parse).toList();
  final l = (f[0] * im.width).round().clamp(0, im.width - 1);
  final t = (f[1] * im.height).round().clamp(0, im.height - 1);
  final r = (f[2] * im.width).round().clamp(1, im.width);
  final btm = (f[3] * im.height).round().clamp(1, im.height);
  return (l, t, r, btm);
}

/// Paints a band of [colour] round the outside of whatever is opaque inside
/// [box], and nowhere else. Returns how many pixels were painted.
int _outline(img.Image im, (int, int, int, int) box, int width, img.Color c) {
  final (bx, by, bx2, by2) = box;
  final w = bx2 - bx, h = by2 - by;
  if (w <= 0 || h <= 0) return 0;

  bool solid(int x, int y) => im.getPixel(bx + x, by + y).a > 40;

  // Where the emptiness outside the artwork reaches. Anything it cannot get
  // to is a hole the artwork encloses — the space between the bull's own
  // lines — and must be left alone.
  final outside = List<bool>.filled(w * h, false);
  final queue = Queue<int>();

  void push(int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    final i = y * w + x;
    if (outside[i] || solid(x, y)) return;
    outside[i] = true;
    queue.add(i);
  }

  for (var x = 0; x < w; x++) {
    push(x, 0);
    push(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    push(0, y);
    push(w - 1, y);
  }
  while (queue.isNotEmpty) {
    final i = queue.removeFirst();
    final x = i % w, y = i ~/ w;
    push(x - 1, y);
    push(x + 1, y);
    push(x, y - 1);
    push(x, y + 1);
  }

  // Grow the artwork outwards, and keep only what landed in the outside.
  final band = <int>[];
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      if (!outside[i]) continue;
      if (solid(x, y)) continue;

      var near = false;
      for (var dy = -width; dy <= width && !near; dy++) {
        for (var dx = -width; dx <= width; dx++) {
          if (dx * dx + dy * dy > width * width) continue;
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          if (solid(nx, ny)) {
            near = true;
            break;
          }
        }
      }
      if (near) band.add(i);
    }
  }

  for (final i in band) {
    final x = bx + i % w, y = by + i ~/ w;
    im.setPixelRgba(x, y, c.r.round(), c.g.round(), c.b.round(), 255);
  }
  return band.length;
}
