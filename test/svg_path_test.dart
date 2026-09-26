import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/util/svg_path.dart';

/// The cattle glyph is a published outline read out of a string at startup.
///
/// A parser that gets a command wrong does not throw — it draws a slightly
/// wrong animal, or an empty square, and nobody notices until the farm says
/// the icon looks like a teddy bear again. So the shape is measured here.

void main() {
  group('reading a path out of an SVG string', () {
    test('a square comes out square', () {
      final p = parseSvgPath('M0,0 L10,0 L10,10 L0,10 Z');
      expect(p.getBounds(), const Rect.fromLTRB(0, 0, 10, 10));
    });

    test('lower case means "from where you are"', () {
      // Same square, written as moves rather than positions.
      final p = parseSvgPath('M2,3 l10,0 l0,10 l-10,0 z');
      expect(p.getBounds(), const Rect.fromLTRB(2, 3, 12, 13));
    });

    test('H and V move along one axis only', () {
      final p = parseSvgPath('M0,0 H20 V5 H0 Z');
      expect(p.getBounds(), const Rect.fromLTRB(0, 0, 20, 5));
    });

    test('a repeated command may leave its letter out', () {
      // "L 10,0 10,10" is two lines, not one line and a stray pair.
      final one = parseSvgPath('M0,0 L10,0 L10,10 Z');
      final two = parseSvgPath('M0,0 L10,0 10,10 Z');
      expect(two.getBounds(), one.getBounds());
    });

    test('a move after a move is treated as a line, as the spec says', () {
      final p = parseSvgPath('M0,0 4,9');
      expect(p.getBounds(), const Rect.fromLTRB(0, 0, 4, 9));
    });

    test('a minus sign separates numbers with no comma between them', () {
      final p = parseSvgPath('M0,0L-5-7Z');
      expect(p.getBounds(), const Rect.fromLTRB(-5, -7, 0, 0));
    });

    test('an arc reaches the point it was told to reach', () {
      // Half a circle of radius 8, from one side to the other.
      final p = parseSvgPath('M0,0 a8,8 0 0 1 16,0');
      final b = p.getBounds();
      expect(b.left, closeTo(0, 0.01));
      expect(b.right, closeTo(16, 0.01));
      // Sweep flag 1 goes the positive-angle way, which on a screen — where
      // y counts downward — is over the top. Get this backwards and every
      // rounded corner of the glyph bulges outward instead of in.
      expect(b.top, closeTo(-8, 0.01));
      expect(b.bottom, closeTo(0, 0.01));
    });

    test('and the other way round with the flag cleared', () {
      final b = parseSvgPath('M0,0 a8,8 0 0 0 16,0').getBounds();
      expect(b.top, closeTo(0, 0.01));
      expect(b.bottom, closeTo(8, 0.01));
    });

    test('the two flags of an arc are read as single digits', () {
      // "0,0,1" is three flags' worth of characters and one number; a
      // parser that reads them as ordinary numbers swallows the endpoint.
      final p = parseSvgPath('M0,0a8,8,0,0,1,16,0');
      expect(p.getBounds().right, closeTo(16, 0.01));
    });

    test('curves are followed, not cut across', () {
      // A cubic that bulges well past the straight line between its ends.
      final p = parseSvgPath('M0,0 C0,-40 20,-40 20,0');
      expect(p.getBounds().top, lessThan(-20));
    });

    test('nonsense stops rather than drawing something wrong', () {
      final p = parseSvgPath('M0,0 L5,5 X9,9');
      expect(p.getBounds(), const Rect.fromLTRB(0, 0, 5, 5));
    });

    test('an empty string is an empty path, not a crash', () {
      expect(parseSvgPath('').getBounds(), Rect.zero);
    });
  });

  group('the cattle glyph itself', () {
    // The exact string the app ships, so this fails if it is ever mangled
    // by a reformat or a stray edit.
    const cow =
        'M104,192a8,8,0,0,1-8,8H80a8,8,0,0,1,0-16H96A8,8,0,0,1,104,192Zm72-8H'
        '160a8,8,0,0,0,0,16h16a8,8,0,0,0,0-16Zm-76-48a12,12,0,1,0-12-12A12,12,'
        '0,0,0,100,136Zm56,0a12,12,0,1,0-12-12A12,12,0,0,0,156,136Zm88.39-13.8'
        '8A16,16,0,0,1,232,128H200v32a40,40,0,0,1-24,72H80a40,40,0,0,1-24-72V1'
        '28H24A16,16,0,0,1,8.31,109,56.13,56.13,0,0,1,63.22,64h1.64A55.83,55.8'
        '3,0,0,1,48,24a8,8,0,0,1,16,0,40,40,0,0,0,40,40h48a40,40,0,0,0,40-40,8'
        ',8,0,0,1,16,0,55.83,55.83,0,0,1-16.86,40h1.64a56.13,56.13,0,0,1,54.91'
        ',45A15.82,15.82,0,0,1,244.39,122.12ZM72,152.8a40.57,40.57,0,0,1,8-.8h'
        '96a40.57,40.57,0,0,1,8,.8V104a24,24,0,0,0-24-24H96a24,24,0,0,0-24,24Z'
        'M56,112v-8a39.81,39.81,0,0,1,8-24h-.8A40.09,40.09,0,0,0,24,112Zm144,8'
        '0a24,24,0,0,0-24-24H80a24,24,0,0,0,0,48h96A24,24,0,0,0,200,192Zm32-80'
        'a40.08,40.08,0,0,0-39.2-32H192a39.81,39.81,0,0,1,8,24v8Z';

    test('fills its 256-point square without spilling out of it', () {
      final b = parseSvgPath(cow).getBounds();
      expect(b.left, greaterThanOrEqualTo(0));
      expect(b.top, greaterThanOrEqualTo(0));
      expect(b.right, lessThanOrEqualTo(256));
      expect(b.bottom, lessThanOrEqualTo(256));
      // And it is the whole animal, not a fragment left behind by a command
      // the parser gave up on.
      expect(b.width, greaterThan(200));
      expect(b.height, greaterThan(200));
    });

    test('an animal, not an empty box', () {
      // The eyes are solid dots at (100,124) and (156,124) — a path that
      // came out empty, or half-read, misses them. The middle of the face
      // is deliberately not tested: this is an outline, so the face is a
      // hole, and a "filled" one would mean the winding came out wrong.
      final p = parseSvgPath(cow);
      expect(p.contains(const Offset(100, 124)), isTrue, reason: 'left eye');
      expect(p.contains(const Offset(156, 124)), isTrue, reason: 'right eye');
      expect(p.contains(const Offset(128, 112)), isFalse, reason: 'forehead');
      expect(p.contains(const Offset(300, 300)), isFalse);
    });
  });
}
