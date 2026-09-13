// Recolours part of a picture, keeping the shading that is already drawn in.
//
//   dart run tool/recolour.dart <image> --box l,t,r,b --dark HEX --light HEX
//                               [--out file]
//
// The image tool the farm has cannot change a colour directly — it has to be
// coaxed there through settings, and comes back with whatever it feels like.
// This does it exactly: every pixel keeps how light or dark it was drawn and
// only which colour that lightness stands for changes, so metal still looks
// like metal and nothing goes flat.

import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'dart run tool/recolour.dart <image> --box l,t,r,b --dark HEX '
      '--light HEX [--out f]',
    );
    exit(2);
  }

  final src = img.decodeImage(File(args.first).readAsBytesSync());
  if (src == null) {
    stderr.writeln('Cannot read that.');
    exit(2);
  }

  final im = src.convert(numChannels: 4);
  final dark = _hex(_flag(args, '--dark') ?? '0B1C3A');
  final light = _hex(_flag(args, '--light') ?? '4C74B8');
  final out = _flag(args, '--out') ?? 'recoloured.png';

  final box = _flag(args, '--box');
  final (bx, by, bx2, by2) = box == null
      ? (0, 0, im.width, im.height)
      : _box(box, im);

  // The range of lightness actually present, so the new colours are stretched
  // across what is there rather than across a theoretical 0 to 255. Line art
  // that only ever runs from mid-grey to white would otherwise come out
  // uniformly pale.
  var lo = 255, hi = 0;
  for (var y = by; y < by2; y++) {
    for (var x = bx; x < bx2; x++) {
      final p = im.getPixel(x, y);
      if (p.a < 40) continue;
      final v = _luma(p);
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
  }
  if (hi <= lo) {
    stderr.writeln('Nothing to recolour in that box.');
    exit(2);
  }
  stdout.writeln('Lightness in the box runs $lo to $hi');

  var touched = 0;
  for (var y = by; y < by2; y++) {
    for (var x = bx; x < bx2; x++) {
      final p = im.getPixel(x, y);
      if (p.a < 8) continue;
      final t = ((_luma(p) - lo) / (hi - lo)).clamp(0.0, 1.0);
      im.setPixelRgba(
        x,
        y,
        (dark[0] + (light[0] - dark[0]) * t).round(),
        (dark[1] + (light[1] - dark[1]) * t).round(),
        (dark[2] + (light[2] - dark[2]) * t).round(),
        p.a.round(),
      );
      touched++;
    }
  }

  File(out).writeAsBytesSync(img.encodePng(im));
  stdout.writeln('Recoloured $touched pixels → $out');
}

String? _flag(List<String> args, String name) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

int _luma(img.Pixel p) => (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round();

List<int> _hex(String s) => [
  int.parse(s.substring(0, 2), radix: 16),
  int.parse(s.substring(2, 4), radix: 16),
  int.parse(s.substring(4, 6), radix: 16),
];

(int, int, int, int) _box(String spec, img.Image im) {
  final f = spec.split(',').map(double.parse).toList();
  return (
    (f[0] * im.width).round().clamp(0, im.width - 1),
    (f[1] * im.height).round().clamp(0, im.height - 1),
    (f[2] * im.width).round().clamp(1, im.width),
    (f[3] * im.height).round().clamp(1, im.height),
  );
}
