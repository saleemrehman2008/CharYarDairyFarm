import 'dart:ui';

/// Turns an SVG `d` string into a [Path].
///
/// The farm's cattle glyph is a published icon, and the honest way to use a
/// published icon is to keep its own outline rather than trace something
/// near it by hand — five hand-drawn attempts at a buffalo were rejected in
/// turn, the kindest verdict being that it looked like a teddy bear.
///
/// A drawing package would do this, but it would also add a megabyte and a
/// half to an APK the farm has already asked twice to make smaller. This is
/// the whole of what is needed: the commands an icon actually uses, and
/// arcs, which Flutter happens to take in the same endpoint form SVG writes
/// them in.
Path parseSvgPath(String d) {
  final path = Path();
  final t = _Scan(d);

  var at = Offset.zero; // current point
  var start = Offset.zero; // where the current subpath began
  Offset? lastCubic; // second control point of the last C/S
  Offset? lastQuad; // control point of the last Q/T
  var cmd = '';

  Offset abs(double x, double y, bool rel) =>
      rel ? Offset(at.dx + x, at.dy + y) : Offset(x, y);

  while (true) {
    t.space();
    if (t.done) break;

    // A command may be left out when it repeats — "L 1,2 3,4" is two lines.
    if (t.isCommand) {
      cmd = t.take();
    } else if (cmd.isEmpty) {
      break;
    } else if (cmd == 'M') {
      cmd = 'L';
    } else if (cmd == 'm') {
      cmd = 'l';
    }

    final rel = cmd.toLowerCase() == cmd;
    switch (cmd.toLowerCase()) {
      case 'm':
        at = abs(t.num(), t.num(), rel);
        path.moveTo(at.dx, at.dy);
        start = at;
        lastCubic = lastQuad = null;
      case 'l':
        at = abs(t.num(), t.num(), rel);
        path.lineTo(at.dx, at.dy);
        lastCubic = lastQuad = null;
      case 'h':
        final x = t.num();
        at = Offset(rel ? at.dx + x : x, at.dy);
        path.lineTo(at.dx, at.dy);
        lastCubic = lastQuad = null;
      case 'v':
        final y = t.num();
        at = Offset(at.dx, rel ? at.dy + y : y);
        path.lineTo(at.dx, at.dy);
        lastCubic = lastQuad = null;
      case 'c':
        final c1 = abs(t.num(), t.num(), rel);
        final c2 = abs(t.num(), t.num(), rel);
        at = abs(t.num(), t.num(), rel);
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, at.dx, at.dy);
        lastCubic = c2;
        lastQuad = null;
      case 's':
        // The first control point mirrors the last one, which is what makes
        // a run of S commands smooth.
        final c1 = lastCubic == null
            ? at
            : Offset(2 * at.dx - lastCubic.dx, 2 * at.dy - lastCubic.dy);
        final c2 = abs(t.num(), t.num(), rel);
        at = abs(t.num(), t.num(), rel);
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, at.dx, at.dy);
        lastCubic = c2;
        lastQuad = null;
      case 'q':
        final c = abs(t.num(), t.num(), rel);
        at = abs(t.num(), t.num(), rel);
        path.quadraticBezierTo(c.dx, c.dy, at.dx, at.dy);
        lastQuad = c;
        lastCubic = null;
      case 't':
        final c = lastQuad == null
            ? at
            : Offset(2 * at.dx - lastQuad.dx, 2 * at.dy - lastQuad.dy);
        at = abs(t.num(), t.num(), rel);
        path.quadraticBezierTo(c.dx, c.dy, at.dx, at.dy);
        lastQuad = c;
        lastCubic = null;
      case 'a':
        final rx = t.num();
        final ry = t.num();
        final turn = t.num();
        final bigArc = t.flag();
        final sweep = t.flag();
        at = abs(t.num(), t.num(), rel);
        path.arcToPoint(
          at,
          radius: Radius.elliptical(rx.abs(), ry.abs()),
          rotation: turn,
          largeArc: bigArc,
          clockwise: sweep,
        );
        lastCubic = lastQuad = null;
      case 'z':
        path.close();
        at = start;
        lastCubic = lastQuad = null;
      default:
        // An unknown letter means the string is not what we think it is.
        // Stop rather than draw something wrong.
        return path;
    }
  }
  return path;
}

/// Reads numbers and letters out of a `d` string.
///
/// SVG path data is written as tightly as it will go: separators are
/// optional, a minus sign doubles as one, and the two flags of an arc are
/// single digits that may be stuck to the number after them.
class _Scan {
  _Scan(this.s);

  final String s;
  int i = 0;

  bool get done => i >= s.length;

  void space() {
    while (i < s.length &&
        (s[i] == ' ' ||
            s[i] == ',' ||
            s[i] == '\n' ||
            s[i] == '\r' ||
            s[i] == '\t')) {
      i++;
    }
  }

  bool get isCommand {
    if (done) return false;
    final c = s.codeUnitAt(i);
    return (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
  }

  String take() => s[i++];

  /// One flag of an arc: a bare 0 or 1, with nothing between it and the
  /// next number.
  bool flag() {
    space();
    final c = s[i++];
    return c == '1';
  }

  double num() {
    space();
    final from = i;
    if (i < s.length && (s[i] == '-' || s[i] == '+')) i++;
    while (i < s.length && _isDigit(s[i])) {
      i++;
    }
    if (i < s.length && s[i] == '.') {
      i++;
      while (i < s.length && _isDigit(s[i])) {
        i++;
      }
    }
    if (i < s.length && (s[i] == 'e' || s[i] == 'E')) {
      i++;
      if (i < s.length && (s[i] == '-' || s[i] == '+')) i++;
      while (i < s.length && _isDigit(s[i])) {
        i++;
      }
    }
    return double.tryParse(s.substring(from, i)) ?? 0;
  }

  static bool _isDigit(String c) {
    final u = c.codeUnitAt(0);
    return u >= 48 && u <= 57;
  }
}
