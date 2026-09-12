// Cuts a piece out of a picture and blows it up, so an edge can actually be
// looked at instead of guessed about.
//
//   dart run tool/zoom.dart <image> <l,t,r,b> [--on navy|white|checks]
//
// The box is in fractions of the image. The backing matters: a cut looks
// clean against one colour and filthy against another, and the app shows the
// logo on navy while a printer would put it on white.

import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('dart run tool/zoom.dart <image> <l,t,r,b> [--on navy]');
    exit(2);
  }

  final src = img.decodeImage(File(args.first).readAsBytesSync());
  if (src == null) {
    stderr.writeln('Cannot read that.');
    exit(2);
  }

  final f = args[1].split(',').map(double.parse).toList();
  final x = (f[0] * src.width).round();
  final y = (f[1] * src.height).round();
  final w = ((f[2] - f[0]) * src.width).round().clamp(1, src.width - x);
  final h = ((f[3] - f[1]) * src.height).round().clamp(1, src.height - y);

  final on = args.contains('--on') ? args[args.indexOf('--on') + 1] : 'navy';
  final piece = img.copyCrop(src, x: x, y: y, width: w, height: h);
  final big = img.copyResize(
    piece,
    width: (w * 4).clamp(1, 1400),
    interpolation: img.Interpolation.nearest,
  );

  final canvas = img.Image(width: big.width, height: big.height);
  switch (on) {
    case 'white':
      canvas.clear(img.ColorRgb8(255, 255, 255));
    case 'checks':
      for (var yy = 0; yy < canvas.height; yy++) {
        for (var xx = 0; xx < canvas.width; xx++) {
          final light = ((xx ~/ 16) + (yy ~/ 16)).isEven;
          final v = light ? 220 : 180;
          canvas.setPixelRgb(xx, yy, v, v, v);
        }
      }
    default:
      canvas.clear(img.ColorRgb8(0x0B, 0x24, 0x38));
  }
  img.compositeImage(canvas, big);

  File('zoom.png').writeAsBytesSync(img.encodePng(canvas));
  stdout.writeln('Wrote zoom.png (${canvas.width}x${canvas.height}) on $on');
}
