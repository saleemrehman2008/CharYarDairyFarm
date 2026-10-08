import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Cuts the farm's logo into the shapes the app needs.
///
/// One drawing arrives and the app shows it in three places: whole on the
/// splash and the sign-in page and at the head of a statement; small in the
/// top bar, where there is room for about thirty-six points of it; and as
/// the launcher icon, which Android wants in five sizes.
///
/// The farm's crest is a round emblem, so all three are the same picture at
/// different sizes — there is nothing to crop out. The lockup before it was
/// wide with the bull at one end, and the small shapes had to be cut from
/// the head alone, which is why this file used to be full of boxes and
/// fractions and still took three goes to stop clipping the muzzle. A round
/// mark is simply easier to be.
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

  // The crest's own dark, so an icon reads as the crest on a tile of its
  // own colour rather than the crest on somebody else's. The farm's navy
  // was right behind the silver lockup that came before and is wrong here:
  // this emblem is brown and gold.
  final ground = img.ColorRgb8(0x17, 0x12, 0x0E);

  // The drawing as it arrived, kept in the repo so the next recut needs
  // nothing but this file.
  _write('assets/logo-source.png', src);

  final crest = _trim(src);
  stdout.writeln('crest trimmed to ${crest.width}x${crest.height}');

  // ---- The crest, whole ----
  //
  // Transparent: the app puts it on whatever the page under it is.
  _write(
    'assets/logo.png',
    img.copyResize(crest, width: 900, interpolation: img.Interpolation.cubic),
  );

  // ---- The small mark, and the launcher ----
  //
  // Both on a ground, for the same reason: a transparent icon with dark
  // edges disappears into a dark wallpaper, and the one place the farm
  // cannot choose the background is somebody's home screen.
  // The small mark is the whole crest, the same as the launcher. It was
  // cut down to the bull alone for a while, on the grounds that at
  // thirty-six points the ring and the lettering go to a smudge — which
  // they do. The farm looked at the two side by side and chose the whole
  // crest anyway: one mark everywhere beats a sharper one that is a
  // different picture.
  _write('assets/mark.png', _onGround(crest, 192, ground));

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
      _onGround(crest, px, ground),
    );
  });
}

/// Drops the empty border round a drawing.
///
/// The logo arrives on a two-thousand-point square with air around it. Left
/// alone, every size below is worked out from the air rather than the
/// drawing, and the crest ends up smaller than it should be.
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
///
/// Barely any padding: a round crest already carries its own margin in the
/// ring, and adding more only makes it smaller on the home screen, where it
/// is competing with every other icon to be recognised.
img.Image _onGround(img.Image src, int size, img.Color ground) {
  final pad = (size * 0.03).round();
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
