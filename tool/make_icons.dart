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
const _defaultMark = '0.48,0.0,0.95,0.46';

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

  // A picture that already has its background off needs nothing doing to it,
  // and doing something anyway would be worse than useless: with no backdrop
  // to sample, the border reads as black, and everything dark in the artwork
  // starts looking like something to cut away.
  final img.Image cleaned;
  if (_alreadyClear(photo)) {
    stdout.writeln('Already transparent — nothing to cut.');
    cleaned = photo;
  } else {
    final cut = _stripBackdrop(photo, grip: grip, spread: spread);
    stdout.writeln('Backdrop removed: ${cut.$2} pixels');
    cleaned = cut.$1;
  }

  final lockup = _trimClear(cleaned);
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

/// Whether the picture arrived with its background already taken off.
///
/// Judged at the border, because that is where a backdrop always is: if every
/// edge is see-through, somebody has done this already.
bool _alreadyClear(img.Image im) {
  var clear = 0, total = 0;
  for (var x = 0; x < im.width; x += 2) {
    for (final y in [0, im.height - 1]) {
      if (im.getPixel(x, y).a < 16) clear++;
      total++;
    }
  }
  for (var y = 0; y < im.height; y += 2) {
    for (final x in [0, im.width - 1]) {
      if (im.getPixel(x, y).a < 16) clear++;
      total++;
    }
  }
  return total > 0 && clear / total > 0.97;
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

  // Is the backdrop a colour, or a grey?
  //
  // It decides how a pixel is judged, and the difference matters. A grey
  // chessboard can only be told apart by how close a pixel is to it, and
  // close is all one can ask, because the bull is grey too. A magenta key can
  // be told apart by what colour it *is* — and that is a far better question,
  // because a shaded magenta in the shadow of a milk can is still magenta,
  // while chrome in shadow is still grey. Measuring distance confuses those
  // two; asking the hue does not.
  final key = _average(backdrop);
  final keyHue = _hue(key);
  final keySat = _saturation(key);
  final keyed = keySat > 0.25;

  stdout.writeln(
    keyed
        ? 'Backdrop is a colour key at hue ${keyHue.round()}°'
        : 'Backdrop is neutral — judging by distance',
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

  /// Whether this pixel is the backdrop's own colour, however light or dark
  /// the render has made it.
  bool isKey(int x, int y) {
    final p = _rgb(src, x, y);
    final sat = _saturation(p);
    if (sat < keySat * 0.30) return false;
    var d = (_hue(p) - keyHue).abs();
    if (d > 180) d = 360 - d;
    return d < 28;
  }

  /// The one test everything below uses.
  bool isBackdrop(int x, int y, int tolerance) =>
      keyed ? isKey(x, y) : distance(x, y) <= tolerance;

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
    if (!isBackdrop(x, y, tolerance)) return;
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

  // Softening the rim by how much backdrop is in it only makes sense when
  // the backdrop was a grey the artwork half shares. Against a colour key a
  // pixel either is that colour or is not, and thinning the edge there just
  // gnaws at the shape.
  if (!keyed) {
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

  // Last: wring the key's colour out of anything that kept a trace of it.
  //
  // The pass above hands a boundary pixel the colour of the artwork inside
  // it, which works where there is an inside. On a line one pixel wide there
  // is none — the whole stroke is boundary — so the bull's outline came out
  // wearing a pink thread down one side. Rather than hunt for a donor that
  // does not exist, that pixel simply has the pink taken out of it: the hue
  // is drained to grey and the brightness left exactly where it was.
  //
  // Safe because nothing in this artwork is anywhere near the key's hue. The
  // milk is warm cream, the chrome has no hue at all, the lettering is blue.
  // Only what the backdrop touched is wearing magenta, so only that changes.
  if (keyed) {
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (seen[y * w + x]) continue;
        final px = out.getPixel(x, y);
        if (px.a < 8) continue;

        final c = [px.r.round(), px.g.round(), px.b.round()];
        final sat = _saturation(c);
        if (sat < 0.06) continue;

        var d = (_hue(c) - keyHue).abs();
        if (d > 180) d = 360 - d;
        if (d > 42) continue;

        // Fully the key's hue, fully drained; further off, less so.
        final pull = 1 - (d / 42);
        final grey = (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]);
        out.setPixelRgba(
          x,
          y,
          (c[0] + (grey - c[0]) * pull).round(),
          (c[1] + (grey - c[1]) * pull).round(),
          (c[2] + (grey - c[2]) * pull).round(),
          px.a.round(),
        );
      }
    }
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

/// The middle of a set of colours.
List<int> _average(List<List<int>> colours) {
  var r = 0, g = 0, b = 0;
  for (final c in colours) {
    r += c[0];
    g += c[1];
    b += c[2];
  }
  final n = colours.length;
  return [r ~/ n, g ~/ n, b ~/ n];
}

/// Which colour this is, on the wheel, 0–360.
double _hue(List<int> c) {
  final r = c[0] / 255, g = c[1] / 255, b = c[2] / 255;
  final max = [r, g, b].reduce((a, x) => a > x ? a : x);
  final min = [r, g, b].reduce((a, x) => a < x ? a : x);
  final d = max - min;
  if (d == 0) return 0;
  double h;
  if (max == r) {
    h = ((g - b) / d) % 6;
  } else if (max == g) {
    h = (b - r) / d + 2;
  } else {
    h = (r - g) / d + 4;
  }
  h *= 60;
  return h < 0 ? h + 360 : h;
}

/// How much colour there is in it, 0–1. Grey is zero however light or dark.
double _saturation(List<int> c) {
  final max = [c[0], c[1], c[2]].reduce((a, x) => a > x ? a : x);
  final min = [c[0], c[1], c[2]].reduce((a, x) => a < x ? a : x);
  return max == 0 ? 0 : (max - min) / max;
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
