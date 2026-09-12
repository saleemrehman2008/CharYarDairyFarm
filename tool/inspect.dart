// Tells you what is actually in a picture: its size, whether it has a real
// alpha channel, and what the corners look like.
//
// Worth having, because a checkerboard on screen can be genuine transparency
// or a checkerboard somebody's viewer painted in before it was saved, and the
// two are handled completely differently.
//
//   dart run tool/inspect.dart <image>

import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('dart run tool/inspect.dart <image>');
    exit(2);
  }

  final im = img.decodeImage(File(args.first).readAsBytesSync());
  if (im == null) {
    stderr.writeln('Cannot read that.');
    exit(2);
  }

  stdout.writeln('${im.width} x ${im.height}, ${im.numChannels} channels');

  var clear = 0;
  var opaque = 0;
  for (var y = 0; y < im.height; y += 3) {
    for (var x = 0; x < im.width; x += 3) {
      im.getPixel(x, y).a < 16 ? clear++ : opaque++;
    }
  }
  final total = clear + opaque;
  stdout.writeln(
    'transparent: ${(clear / total * 100).toStringAsFixed(1)}%  '
    'opaque: ${(opaque / total * 100).toStringAsFixed(1)}%',
  );

  void corner(String name, int x, int y) {
    final p = im.getPixel(x, y);
    stdout.writeln(
      '$name  rgba(${p.r.round()}, ${p.g.round()}, ${p.b.round()}, '
      '${p.a.round()})',
    );
  }

  corner('top-left    ', 2, 2);
  corner('top-right   ', im.width - 3, 2);
  corner('bottom-left ', 2, im.height - 3);
  corner('bottom-right', im.width - 3, im.height - 3);
  corner('centre      ', im.width ~/ 2, im.height ~/ 2);
}
