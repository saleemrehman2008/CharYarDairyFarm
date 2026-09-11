import 'package:flutter/material.dart';

/// Design tokens taken from the handoff README (derived from the farm logo).
/// Keep every colour, radius and type size in this one place so the whole app
/// shifts together if the brand is ever retuned.
abstract final class T {
  // ---- Colours ----
  static const bg = Color(0xFFF6F2EC);
  static const surface = Color(0xFFECE5DB);
  static const text = Color(0xFF221B15);
  static const accent = Color(0xFF9A6A3F); // bronze
  static const accent2 = Color(0xFFB98A4D); // gold
  static const divider = Color(0x29221B15); // rgba(34,27,21,.16)

  // Accent ramp 100 -> 900
  static const accent100 = Color(0xFFF9F1E6);
  static const accent200 = Color(0xFFF0DFC8);
  static const accent300 = Color(0xFFE2C5A0);
  static const accent400 = Color(0xFFCBA475);
  static const accent500 = Color(0xFFAD8351);
  static const accent600 = Color(0xFF8F683C);
  static const accent700 = Color(0xFF6E4F2C);
  static const accent800 = Color(0xFF4D371E);
  static const accent900 = Color(0xFF2F2214);

  // Neutral ramp 100 -> 900
  static const n100 = Color(0xFFF8F5F1);
  static const n200 = Color(0xFFEBE6DF);
  static const n300 = Color(0xFFD8D1C8);
  static const n400 = Color(0xFFBAB2A8);
  static const n500 = Color(0xFF9A9187);
  static const n600 = Color(0xFF7A7168);
  static const n700 = Color(0xFF5C554D);
  static const n800 = Color(0xFF413B35);
  static const n900 = Color(0xFF2A2521);

  /// Ratio-bar / partner dot colours, in order.
  static const partnerColors = [accent700, accent500, accent400, accent300];

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
