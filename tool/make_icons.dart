// Turns a photograph of the farm's logo into the app's logo and launcher
// icons.
//
// The logo the farm has is a mockup — the artwork rendered on a dark wall,
// with the wall's texture, a shadow and a highlight baked in. There is no
// clean original. So rather than ask for one that does not exist, this reads
// the photograph, finds the artwork inside it, drops the wall, and writes out
// what Android needs.
//
//   dart run tool/make_icons.dart <image> [--icon-crop l,t,r,b] [--dry]
//
// The crop is given as fractions of the image, so it reads the same whatever
// size the photograph is: `--icon-crop 0.42,0.12,0.78,0.52` means the box
// from 42% across and 12% down to 78% across and 52% down.
//
// Everything here is deliberately plain: no background-removal library, no
// service, nothing to keep working. The wall is dark and the artwork is
// bright, and that one fact is enough to separate them.

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// The app's own navy, from the logo — the ground every icon sits on.
final _navy = img.ColorRgb8(0x0B, 0x24, 0x38);

/// Android's launcher sizes, by density folder.
const _launcher = {
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
};

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Give it the picture: dart run tool/make_icons.dart <file>');
    exit(2);
  }

  final source = File(args.first);
  if (!source.existsSync()) {
    stderr.writeln('No such file: ${source.path}');
    exit(2);
  }

  final dry = args.contains('--dry');
  final cropArg = _flag(args, '--icon-crop');

  final photo = img.decodeImage(source.readAsBytesSync());
  if (photo == null) {
    stderr.writeln('That file is not a picture I can read.');
    exit(2);
  }
  stdout.writeln('Read ${photo.width}x${photo.height} from ${source.path}');

  // ---- the whole lockup, for inside the app ----
  final lockup = _trimDark(photo);
  stdout.writeln('Artwork found at ${lockup.width}x${lockup.height}');

  final appLogo = _fit(lockup, 512);
  if (!dry) {
    Directory('assets').createSync(recursive: true);
    File('assets/logo.png').writeAsBytesSync(img.encodePng(appLogo));
    stdout.writeln('Wrote assets/logo.png (${appLogo.width}x${appLogo.height})');
  }

  // ---- one mark, for the launcher ----
  //
  // A launcher icon is 48 points across on a phone. The whole lockup at that
  // size is a smudge, so the icon is one part of it — by default the middle,
  // or whatever box is given.
  final markBox = cropArg == null
      ? _centreSquare(lockup)
      : _boxFrom(cropArg, lockup);
  final mark = img.copyCrop(
    lockup,
    x: markBox.$1,
    y: markBox.$2,
    width: markBox.$3,
    height: markBox.$4,
  );

  for (final entry in _launcher.entries) {
    final icon = _square(mark, entry.value);
    final path = 'android/app/src/main/res/${entry.key}/ic_launcher.png';
    if (!dry) {
      File(path).writeAsBytesSync(img.encodePng(icon));
    }
    stdout.writeln('${dry ? 'Would write' : 'Wrote'} $path (${entry.value}px)');
  }

  if (!dry) {
    File('assets/icon.png').writeAsBytesSync(
      img.encodePng(_square(mark, 512)),
    );
    stdout.writeln('Wrote assets/icon.png (512px)');
  }
}

String? _flag(List<String> args, String name) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

/// Cuts the dark wall away from the edges.
///
/// The wall is near black and the artwork is not, so walking in from each
/// side until a row or column stops being dark finds the artwork without
/// anybody having to measure anything.
img.Image _trimDark(img.Image src, {int threshold = 46}) {
  bool darkRow(int y) {
    for (var x = 0; x < src.width; x++) {
      if (_luma(src, x, y) > threshold) return false;
    }
    return true;
  }

  bool darkCol(int x) {
    for (var y = 0; y < src.height; y++) {
      if (_luma(src, x, y) > threshold) return false;
    }
    return true;
  }

  var top = 0, bottom = src.height - 1, left = 0, right = src.width - 1;
  while (top < bottom && darkRow(top)) {
    top++;
  }
  while (bottom > top && darkRow(bottom)) {
    bottom--;
  }
  while (left < right && darkCol(left)) {
    left++;
  }
  while (right > left && darkCol(right)) {
    right--;
  }

  // A little air around it, so nothing is shaved off the artwork itself.
  const pad = 8;
  left = math.max(0, left - pad);
  top = math.max(0, top - pad);
  right = math.min(src.width - 1, right + pad);
  bottom = math.min(src.height - 1, bottom + pad);

  return img.copyCrop(
    src,
    x: left,
    y: top,
    width: right - left + 1,
    height: bottom - top + 1,
  );
}

int _luma(img.Image im, int x, int y) {
  final p = im.getPixel(x, y);
  return (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round();
}

/// The middle square of an image — a fair guess at where the mark is when
/// nobody has said otherwise.
(int, int, int, int) _centreSquare(img.Image im) {
  final side = math.min(im.width, im.height);
  return (((im.width - side) / 2).round(), ((im.height - side) / 2).round(),
      side, side);
}

(int, int, int, int) _boxFrom(String spec, img.Image im) {
  final parts = spec.split(',').map(double.parse).toList();
  if (parts.length != 4) {
    stderr.writeln('--icon-crop wants four numbers: left,top,right,bottom');
    exit(2);
  }
  final l = (parts[0] * im.width).round();
  final t = (parts[1] * im.height).round();
  final r = (parts[2] * im.width).round();
  final b = (parts[3] * im.height).round();
  return (l, t, math.max(1, r - l), math.max(1, b - t));
}

/// Scales to fit a box, keeping the shape, on the farm's navy.
img.Image _fit(img.Image src, int side) {
  final scaled = src.width >= src.height
      ? img.copyResize(src, width: side, interpolation: img.Interpolation.cubic)
      : img.copyResize(src, height: side, interpolation: img.Interpolation.cubic);
  return scaled;
}

/// A square icon: the mark scaled to fill, centred, on navy.
img.Image _square(img.Image src, int side) {
  final canvas = img.Image(width: side, height: side)
    ..clear(_navy);

  final scale = side / math.max(src.width, src.height);
  final w = (src.width * scale).round();
  final h = (src.height * scale).round();
  final scaled = img.copyResize(
    src,
    width: w,
    height: h,
    interpolation: img.Interpolation.cubic,
  );

  img.compositeImage(
    canvas,
    scaled,
    dstX: ((side - w) / 2).round(),
    dstY: ((side - h) / 2).round(),
  );
  return canvas;
}
