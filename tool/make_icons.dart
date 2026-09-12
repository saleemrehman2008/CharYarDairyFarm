// Turns the farm's logo picture into everything the app needs from it.
//
// The picture we have was exported with the checkerboard painted into it —
// it looks transparent on screen but every pixel is opaque, so dropped
// straight into the app it would carry a grey chessboard around the bull.
// This finds that backdrop, cuts it away for real, and writes out the pieces.
//
//   dart run tool/make_icons.dart <image> [--mark l,t,r,b] [--grip N] [--dry]
//
// It produces three things:
//
//   assets/logo.png       the whole lockup, transparent, for the login screen
//   assets/mark.png       the round splash on navy, for the top bar
//   mipmap-*/ic_launcher  the same mark at Android's five sizes
//
// A launcher icon is 48 points across on a phone and the top bar's is 36. The
// full lockup at that size is a smudge, which is why the small places get one
// mark rather than the whole thing.
//
// `--mark` says which part of the artwork the mark is, in fractions of the
// trimmed lockup: `--mark 0.44,0.0,0.72,0.52` is the box from 44% across and
// the very top to 72% across and 52% down.
//
// `--grip` is how close a pixel has to be to the backdrop to be cut away. The
// default is cautious. Shoot the logo against a colour nothing in it shares —
// magenta against cream, chrome and blue — and it can go far higher, which is
// what clears the shaded backdrop trapped inside an enclosed shape.

import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// The farm's navy, from the logo — the ground the mark sits on.
final _navy = img.ColorRgb8(0x0B, 0x24, 0x38);

/// Android's launcher sizes, by density folder.
const _launcher = {
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
};

/// Where the splash-and-cans roundel sits in the artwork we have. The
/// defaults below are the ones that came out right for it — shot against a
/// flat magenta, which nothing in the logo shares, so the cut can be hard.
const _defaultMark = '0.47,0.0,1.0,0.47';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('dart run tool/make_icons.dart <image> [--mark l,t,r,b]');
    exit(2);
  }

  final source = File(args.first);
  if (!source.existsSync()) {
    stderr.writeln('No such file: ${source.path}');
    exit(2);
  }

  final dry = args.contains('--dry');
  final markSpec = _flag(args, '--mark') ?? _defaultMark;
  final grip = int.tryParse(_flag(args, '--grip') ?? '') ?? 90;
  final spread = int.tryParse(_flag(args, '--spread') ?? '') ?? 145;

  var photo = img.decodeImage(source.readAsBytesSync());
  if (photo == null) {
    stderr.writeln('That file is not a picture I can read.');
    exit(2);
  }
  stdout.writeln('Read ${photo.width}x${photo.height}');

  photo = photo.convert(numChannels: 4);
  final cut = _stripBackdrop(photo, grip: grip, spread: spread);
  stdout.writeln('Backdrop removed: ${cut.$2} pixels');

  final lockup = _trimClear(cut.$1);
  stdout.writeln('Artwork is ${lockup.width}x${lockup.height}');

  // ---- the whole lockup ----
  final logo = img.copyResize(
    lockup,
    width: 900,
    interpolation: img.Interpolation.cubic,
  );

  // ---- one mark, for the small places ----
  final box = _boxFrom(markSpec, lockup);
  final mark = _trimClear(
    img.copyCrop(lockup, x: box.$1, y: box.$2, width: box.$3, height: box.$4),
  );
  stdout.writeln('Mark is ${mark.width}x${mark.height}');

  if (dry) {
    stdout.writeln('Dry run — nothing written.');
    return;
  }

  Directory('assets').createSync(recursive: true);
  File('assets/logo.png').writeAsBytesSync(img.encodePng(logo));
  stdout.writeln('Wrote assets/logo.png (${logo.width}x${logo.height})');

  File('assets/mark.png').writeAsBytesSync(img.encodePng(_onNavy(mark, 512)));
  stdout.writeln('Wrote assets/mark.png (512px)');

  for (final entry in _launcher.entries) {
    final path = 'android/app/src/main/res/${entry.key}/ic_launcher.png';
    File(path).writeAsBytesSync(img.encodePng(_onNavy(mark, entry.value)));
    stdout.writeln('Wrote $path (${entry.value}px)');
  }
}

String? _flag(List<String> args, String name) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

/// Cuts away whatever the artwork was sitting on.
///
/// Two passes, because a chessboard shows through the holes in a drawing as
/// well as around it. Flooding in from the edges alone leaves patches inside
/// the bull's face and inside the letters, where the outside cannot reach.
///
/// So first every pixel that is almost exactly a backdrop colour goes,
/// wherever it is — that clears the flat squares, enclosed or not, and is
/// tight enough that the bull's own greys are nowhere near it. Then a flood
/// spreads out from what was removed with a looser tolerance, which picks up
/// the seams between squares and the blend around each edge.
///
/// Returns the cut image and how many pixels went.
(img.Image, int) _stripBackdrop(
  img.Image src, {
  int grip = 14,
  int spread = 42,
}) {
  final out = img.Image.from(src);
  final w = src.width, h = src.height;

  // What the backdrop is: the colours sitting along the border.
  final samples = <List<int>>[];
  for (var x = 0; x < w; x += 4) {
    samples.add(_rgb(src, x, 0));
    samples.add(_rgb(src, x, h - 1));
  }
  for (var y = 0; y < h; y += 4) {
    samples.add(_rgb(src, 0, y));
    samples.add(_rgb(src, w - 1, y));
  }
  final backdrop = _cluster(samples);
  stdout.writeln(
    'Backdrop colours: ${backdrop.map((c) => 'rgb(${c[0]},${c[1]},${c[2]})').join(', ')}',
  );

  /// How far a pixel is from the nearest backdrop colour.
  int distance(int x, int y) {
    final p = _rgb(src, x, y);
    var best = 1 << 20;
    for (final c in backdrop) {
      final d = (p[0] - c[0]).abs() + (p[1] - c[1]).abs() + (p[2] - c[2]).abs();
      if (d < best) best = d;
    }
    return best;
  }

  // The chessboard is two flat greys, but the seam between two squares is a
  // blend of the two, so the tolerance has to be wide enough to swallow the
  // grid lines as well. It can afford to be: the flood only ever walks in
  // from the outside, so however wide it is set it cannot wander into the
  // middle of the artwork.
  // How close a pixel has to be to count as backdrop.
  //
  // A grey chessboard sits near the artwork's own greys and has to be cut
  // narrowly, at the default. A magenta key sits nowhere near cream, chrome
  // or blue, so it can be cut hard — and needs to be, because a 3D render
  // shades its own background inside an enclosed ring and those pixels are
  // no longer quite the colour they started as.
  final exact = grip;
  const edge = 130; // part backdrop, part artwork

  final seen = List<bool>.filled(w * h, false);
  final queue = Queue<int>();

  void push(int x, int y, int tolerance) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    final i = y * w + x;
    if (seen[i]) return;
    if (distance(x, y) > tolerance) return;
    seen[i] = true;
    queue.add(i);
  }

  // Pass one: the flat squares, wherever they are.
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      push(x, y, exact);
    }
  }

  // Pass two: spread out from those into the seams and the blended rim.
  var cut = 0;
  while (queue.isNotEmpty) {
    final i = queue.removeFirst();
    final x = i % w, y = i ~/ w;
    out.setPixelRgba(x, y, 0, 0, 0, 0);
    cut++;
    push(x - 1, y, spread);
    push(x + 1, y, spread);
    push(x, y - 1, spread);
    push(x, y + 1, spread);
  }

  // The rim: pixels the flood stopped at are part backdrop, part artwork, and
  // left alone they draw a grey outline round everything. Their alpha is
  // pulled down by however much backdrop is in them.
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (seen[y * w + x]) continue;
      if (!_touchesClear(seen, x, y, w, h)) continue;
      final d = distance(x, y);
      if (d >= edge) continue;
      final p = out.getPixel(x, y);
      out.setPixelRgba(
        x,
        y,
        p.r.round(),
        p.g.round(),
        p.b.round(),
        (255 * (d / edge)).round(),
      );
    }
  }

  // The fringe: a pixel of artwork sitting right on the boundary is
  // literally a mixture of artwork and backdrop, so it keeps a trace of the
  // backdrop's colour — the hairline of magenta around everything that gives
  // a bad cutout away. Rubbing those pixels out would eat into the shape, so
  // instead each one takes its colour from the artwork just inside it and
  // keeps its own alpha. The edge stays exactly where it was; only its colour
  // is corrected.
  //
  // Two rings deep, because a render's edge is soft and one pixel is rarely
  // the whole of it.
  var rim = <int>[];
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (seen[y * w + x]) continue;
      if (_touchesClear(seen, x, y, w, h)) rim.add(y * w + x);
    }
  }

  final isRim = List<bool>.filled(w * h, false);
  for (final i in rim) {
    isRim[i] = true;
  }
  // A second ring in from the first.
  final rim2 = <int>[];
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      if (seen[i] || isRim[i]) continue;
      for (var dy = -1; dy <= 1 && !isRim[i]; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          if (isRim[ny * w + nx]) {
            rim2.add(i);
            dy = 2;
            break;
          }
        }
      }
    }
  }
  for (final i in rim2) {
    isRim[i] = true;
  }
  rim = [...rim, ...rim2];

  // Each rim pixel takes the average of the solid artwork near it.
  final fixed = <int, List<int>>{};
  for (final i in rim) {
    final x = i % w, y = i ~/ w;
    var r = 0, g = 0, b = 0, n = 0;
    for (var dy = -3; dy <= 3; dy++) {
      for (var dx = -3; dx <= 3; dx++) {
        final nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        final j = ny * w + nx;
        if (seen[j] || isRim[j]) continue; // only solid artwork donates
        final q = _rgb(src, nx, ny);
        r += q[0];
        g += q[1];
        b += q[2];
        n++;
      }
    }
    if (n > 0) fixed[i] = [r ~/ n, g ~/ n, b ~/ n];
  }

  for (final entry in fixed.entries) {
    final x = entry.key % w, y = entry.key ~/ w;
    final c = entry.value;
    out.setPixelRgba(x, y, c[0], c[1], c[2], out.getPixel(x, y).a.round());
  }

  return (out, cut);
}

bool _touchesClear(List<bool> seen, int x, int y, int w, int h) {
  for (var dy = -1; dy <= 1; dy++) {
    for (var dx = -1; dx <= 1; dx++) {
      final nx = x + dx, ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
      if (seen[ny * w + nx]) return true;
    }
  }
  return false;
}

List<int> _rgb(img.Image im, int x, int y) {
  final p = im.getPixel(x, y);
  return [p.r.round(), p.g.round(), p.b.round()];
}

/// The handful of colours a set of samples actually holds.
///
/// A chessboard is two greys; a flat backdrop is one colour. Either way this
/// gathers them without being told which it is looking at.
List<List<int>> _cluster(List<List<int>> samples, {int tolerance = 24}) {
  final centres = <List<int>>[];
  final counts = <int>[];

  for (final s in samples) {
    var found = false;
    for (var i = 0; i < centres.length; i++) {
      final c = centres[i];
      final d = (s[0] - c[0]).abs() + (s[1] - c[1]).abs() + (s[2] - c[2]).abs();
      if (d <= tolerance) {
        counts[i]++;
        found = true;
        break;
      }
    }
    if (!found) {
      centres.add(s);
      counts.add(1);
    }
  }

  // Only the ones that turn up often enough to be a backdrop.
  final keep = <List<int>>[];
  for (var i = 0; i < centres.length; i++) {
    if (counts[i] >= samples.length * 0.05) keep.add(centres[i]);
  }
  return keep.isEmpty ? [centres.first] : keep;
}

/// Trims fully transparent edges.
img.Image _trimClear(img.Image src) {
  bool clearRow(int y) {
    for (var x = 0; x < src.width; x++) {
      if (src.getPixel(x, y).a > 8) return false;
    }
    return true;
  }

  bool clearCol(int x) {
    for (var y = 0; y < src.height; y++) {
      if (src.getPixel(x, y).a > 8) return false;
    }
    return true;
  }

  var top = 0, bottom = src.height - 1, left = 0, right = src.width - 1;
  while (top < bottom && clearRow(top)) {
    top++;
  }
  while (bottom > top && clearRow(bottom)) {
    bottom--;
  }
  while (left < right && clearCol(left)) {
    left++;
  }
  while (right > left && clearCol(right)) {
    right--;
  }

  return img.copyCrop(
    src,
    x: left,
    y: top,
    width: right - left + 1,
    height: bottom - top + 1,
  );
}

(int, int, int, int) _boxFrom(String spec, img.Image im) {
  final parts = spec.split(',').map(double.parse).toList();
  if (parts.length != 4) {
    stderr.writeln('--mark wants four numbers: left,top,right,bottom');
    exit(2);
  }
  final l = (parts[0] * im.width).round().clamp(0, im.width - 1);
  final t = (parts[1] * im.height).round().clamp(0, im.height - 1);
  final r = (parts[2] * im.width).round().clamp(1, im.width);
  final b = (parts[3] * im.height).round().clamp(1, im.height);
  return (l, t, math.max(1, r - l), math.max(1, b - t));
}

/// The mark on the farm's navy, square, with a little air around it.
img.Image _onNavy(img.Image src, int side) {
  final canvas = img.Image(width: side, height: side)..clear(_navy);

  final inner = (side * 0.78).round();
  final scale = inner / math.max(src.width, src.height);
  final w = (src.width * scale).round();
  final h = (src.height * scale).round();

  img.compositeImage(
    canvas,
    img.copyResize(
      src,
      width: w,
      height: h,
      interpolation: img.Interpolation.cubic,
    ),
    dstX: ((side - w) / 2).round(),
    dstY: ((side - h) / 2).round(),
  );
  return canvas;
}
