import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Cuts the farm's logo into the shapes the app needs.
///
/// One drawing arrives — a wide lockup on a transparent ground — and the app
/// shows it in three quite different places, each wanting something else:
///
///  * the whole lockup, on the splash and the sign-in page, where there is
///    room for it;
///  * a square mark at 38 points on a statement and in the top bar, where
///    the lockup would be a smudge and only the bull's head survives;
///  * the launcher icon, which Android wants in five sizes and which has to
///    read at the size of a fingernail.
///
/// The transparent ground is the other half of the job. The bull is silver
/// and drawn in black outline: on a pale page the silver vanishes, on a dark
/// one the outline does. So everything this writes carries its own deep navy
/// behind it — the same colour the app already puts behind the lockup — and
/// then it reads the same on every skin and on a sheet of paper.
///
/// Run: dart run tool/make_logo.dart <source image>
void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Give me the logo file.');
    exit(2);
  }
  final src = img.decodeImage(File(args.first).readAsBytesSync());
  if (src == null) {
    stderr.writeln('Could not read ${args.first}.');
    exit(2);
  }
  stdout.writeln('source ${src.width}x${src.height}');

  // The farm's deep navy, the same value the app uses behind the lockup.
  final navy = img.ColorRgb8(0x0B, 0x24, 0x38);

  // The drawing as it arrived, kept in the repo so the next recut needs
  // nothing but this file — not a hunt back through a chat for the
  // original.
  _write('assets/logo-source.png', src);

  final whole = _trim(src);
  stdout.writeln('lockup trimmed to ${whole.width}x${whole.height}');

  // ---- The lockup ----
  //
  // Kept transparent: the app draws it over its own navy card, and a baked
  // ground would show as a second rectangle inside the first.
  _write(
    'assets/logo.png',
    img.copyResize(whole, width: 900, interpolation: img.Interpolation.cubic),
  );

  // ---- The bull's head ----
  //
  // Taken as a fraction of the trimmed lockup rather than by pixel, so a
  // redrawn logo of another size still lands in the right place.
  //
  // The box stops short of the head on every side on purpose. Out to a
  // third of the width and the first blue of the splash comes with it, which
  // at this size is a stray mark nobody can read; down past the muzzle and
  // the ribbon that sweeps out from under the chin comes too, and reads as
  // a smear under the face. So: the head, and nothing that touches it.
  // There is no rectangle that holds the whole head and nothing else. The
  // horns reach out to the right as far as the C of CHAR reaches in under
  // the chin, so any box wide enough for the horn tips takes a blue sliver
  // of the C with it — and at this size a stray mark is all anybody sees.
  // So the C's corner is rubbed out of the copy first, and then the box can
  // be as wide as the horns need.
  final clean = whole.clone();
  _erase(
    clean,
    x0: (clean.width * 0.310).round(),
    y0: (clean.height * 0.400).round(),
    x1: (clean.width * 0.360).round(),
    y1: (clean.height * 0.640).round(),
  );
  final head = img.copyCrop(
    clean,
    x: 0,
    y: (clean.height * 0.055).round(),
    width: (clean.width * 0.350).round(),
    height: (clean.height * 0.560).round(),
  );
  final tight = _trim(head);
  stdout.writeln('head trimmed to ${tight.width}x${tight.height}');

  _write('assets/mark.png', _onNavy(tight, 192, navy));

  // ---- The launcher icon ----
  //
  // Android asks for five. Written from the same square so the icon on the
  // home screen and the mark in the app are one picture.
  const sizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  sizes.forEach((bucket, px) {
    _write(
      'android/app/src/main/res/mipmap-$bucket/ic_launcher.png',
      _onNavy(tight, px, navy),
    );
  });
}

/// Rubs a rectangle out of [im], leaving it fully transparent.
void _erase(
  img.Image im, {
  required int x0,
  required int y0,
  required int x1,
  required int y1,
}) {
  final clear = img.ColorRgba8(0, 0, 0, 0);
  for (var y = y0; y < y1 && y < im.height; y++) {
    for (var x = x0; x < x1 && x < im.width; x++) {
      im.setPixel(x, y, clear);
    }
  }
}

/// Drops the empty border round a drawing.
///
/// The logo arrives on a two-thousand-point square with most of it air. Left
/// alone, every size below is computed from the air rather than the drawing,
/// and the bull ends up a third of the size it should be.
img.Image _trim(img.Image src) {
  var top = src.height, left = src.width, right = -1, bottom = -1;
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      // Not "any alpha at all": a lossy re-encode leaves a haze of nearly
      // transparent pixels well outside the drawing, and trimming to those
      // trims to nothing.
      if (src.getPixel(x, y).a <= 12) continue;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
    }
  }
  if (right < left || bottom < top) return src;
  return img.copyCrop(
    src,
    x: left,
    y: top,
    width: right - left + 1,
    height: bottom - top + 1,
  );
}

/// A square of [ground] with [src] sat in the middle of it, [size] a side.
img.Image _onNavy(img.Image src, int size, img.Color ground) {
  final pad = (size * 0.10).round();
  final room = size - pad * 2;
  final scale = math.min(room / src.width, room / src.height);
  final fit = img.copyResize(
    src,
    width: math.max(1, (src.width * scale).round()),
    height: math.max(1, (src.height * scale).round()),
    interpolation: img.Interpolation.cubic,
  );
  final out = img.Image(width: size, height: size, numChannels: 4);
  img.fill(out, color: ground);
  return img.compositeImage(
    out,
    fit,
    dstX: (size - fit.width) ~/ 2,
    dstY: (size - fit.height) ~/ 2,
  );
}

void _write(String path, img.Image im) {
  final f = File(path)..createSync(recursive: true);
  f.writeAsBytesSync(img.encodePng(im));
  stdout.writeln('wrote $path  ${im.width}x${im.height}');
}
