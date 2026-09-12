import 'package:flutter/material.dart';

/// Design tokens, taken from the farm's logo: the blue of the milk splash,
/// the near-navy behind it, and the steel of the bull.
///
/// Every colour, radius and type size lives in this one file so the whole app
/// shifts together. The pages stay light — a round is walked in daylight, and
/// a dark screen in the sun cannot be read.
abstract final class T {
  // ---- Colours ----
  static const bg = Color(0xFFF4F7F9);
  static const surface = Color(0xFFE7EDF2);
  static const text = Color(0xFF16202B);
  static const accent = Color(0xFF2277AF); // logo blue
  static const accent2 = Color(0xFF4FC3F7); // the bright splash
  static const divider = Color(0x2916202B);

  /// Accent ramp 100 -> 900, palest wash to near-navy.
  ///
  /// This is also the app's progress scale: the further something has come,
  /// the deeper the blue. See [stage].
  static const accent100 = Color(0xFFE9F3FA);
  static const accent200 = Color(0xFFCFE6F5);
  static const accent300 = Color(0xFFA6D2EE);
  static const accent400 = Color(0xFF6FB6E2);
  static const accent500 = Color(0xFF3D95CE);
  static const accent600 = Color(0xFF2277AF);
  static const accent700 = Color(0xFF175C8C);
  static const accent800 = Color(0xFF0F3F63);
  static const accent900 = Color(0xFF0B2438);

  // Neutral ramp 100 -> 900, cool steel rather than warm paper.
  static const n100 = Color(0xFFF5F7F9);
  static const n200 = Color(0xFFE6EAEE);
  static const n300 = Color(0xFFCFD6DD);
  static const n400 = Color(0xFFAEB8C2);
  static const n500 = Color(0xFF8B96A2);
  static const n600 = Color(0xFF6C7784);
  static const n700 = Color(0xFF515C68);
  static const n800 = Color(0xFF39424C);
  static const n900 = Color(0xFF212933);

  // ---- Meaning ----
  /// Done, and nothing left to do about it.
  static const done = Color(0xFF2E7D5B);
  static const doneWash = Color(0xFFE4F1EA);

  /// Still to do. Not an error — just not finished.
  static const pending = Color(0xFF9C3B2C);
  static const pendingWash = Color(0xFFFBE9E5);

  /// Something wrong that needs a person: an overdue check, a missing rate.
  static const alert = Color(0xFF8C2F20);

  /// How far along something is, in colour: the further it has come, the
  /// deeper the blue. One step of an order, one stage of anything.
  ///
  /// [step] runs from 1; anything at or past [steps] is the darkest.
  static Color stage(int step, {int steps = 4}) =>
      switch (step.clamp(0, steps)) {
        <= 0 => n300,
        1 => accent300,
        2 => accent500,
        3 => accent700,
        _ => accent900,
      };

  /// The wash behind a stage, for a card or a strip.
  static Color stageWash(int step, {int steps = 4}) =>
      switch (step.clamp(0, steps)) {
        <= 0 => n200,
        1 => accent100,
        2 => accent200,
        _ => accent300,
      };

  /// Ratio-bar / partner dot colours, in order.
  static const partnerColors = [accent700, accent500, accent300, accent800];

  // ---- Shape ----
  /// Square-ish corners: the design uses 0–4 px only.
  static const radius = 2.0;
  static const hairline = 1.0;

  static Border get hair => Border.all(color: divider, width: hairline);

  // ---- Spacing ----
  static const gap = 12.0;
  static const pad = 16.0;

  /// Minimum tap target on a real device.
  static const tap = 44.0;

  // ---- Type ----
  static const fontHead = 'BarlowCondensed';
  static const fontBody = 'Barlow';

  static const title = TextStyle(
    fontFamily: fontHead,
    fontWeight: FontWeight.w600,
    fontSize: 44,
    height: 1.02,
    color: text,
  );
  static const screenTitle = TextStyle(
    fontFamily: fontHead,
    fontWeight: FontWeight.w600,
    fontSize: 22,
    height: 1.1,
    color: text,
  );
  static const num36 = TextStyle(
    fontFamily: fontHead,
    fontWeight: FontWeight.w600,
    fontSize: 36,
    height: 1.05,
    color: text,
  );
  static const num30 = TextStyle(
    fontFamily: fontHead,
    fontWeight: FontWeight.w600,
    fontSize: 30,
    height: 1.05,
    color: text,
  );
  static const num28 = TextStyle(
    fontFamily: fontHead,
    fontWeight: FontWeight.w600,
    fontSize: 28,
    height: 1.05,
    color: text,
  );
  static const num26 = TextStyle(
    fontFamily: fontHead,
    fontWeight: FontWeight.w600,
    fontSize: 26,
    height: 1.05,
    color: text,
  );
  static const num22 = TextStyle(
    fontFamily: fontHead,
    fontWeight: FontWeight.w600,
    fontSize: 22,
    height: 1.05,
    color: text,
  );
  static const cardTitle = TextStyle(
    fontFamily: fontBody,
    fontWeight: FontWeight.w500,
    fontSize: 17,
    height: 1.25,
    color: text,
  );
  static const body = TextStyle(
    fontFamily: fontBody,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.4,
    color: text,
  );
  static const bodyMid = TextStyle(
    fontFamily: fontBody,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 1.4,
    color: text,
  );
  static const meta = TextStyle(
    fontFamily: fontBody,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 1.35,
    color: n700,
  );
  static const kicker = TextStyle(
    fontFamily: fontBody,
    fontWeight: FontWeight.w500,
    fontSize: 11,
    height: 1.3,
    letterSpacing: 0.12 * 11,
    color: n600,
  );
  static const tabLabel = TextStyle(
    fontFamily: fontBody,
    fontWeight: FontWeight.w500,
    fontSize: 11,
    height: 1.2,
  );
}
