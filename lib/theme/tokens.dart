import 'package:flutter/material.dart';

/// Which of the three skins the app is wearing.
///
/// The farm asked for a choice, and the choice is kept small on purpose:
/// three, not a colour wheel. [dark] is what the app opens in — a round is
/// walked at four in the morning and again after dark, and a white screen at
/// that hour is a torch in the face.
enum Skin {
  dark('Dark'),
  medium('Medium dark'),
  light('Light');

  const Skin(this.label);
  final String label;

  static Skin byName(String? s) =>
      Skin.values.firstWhere((v) => v.name == s, orElse: () => Skin.dark);
}

/// The skin in force. Change it and the whole app repaints — [T] reads this
/// on every access, and the app is wrapped in a listener at the root.
final skinNow = ValueNotifier<Skin>(Skin.dark);

/// One skin's worth of colour. Nothing here is chosen twice: every page in
/// the app reaches these through [T], so a skin is complete the moment this
/// is filled in.
class _Pal {
  const _Pal({
    required this.dark,
    required this.bg,
    required this.surface,
    required this.raised,
    required this.text,
    required this.accent,
    required this.accent2,
    required this.divider,
    required this.acc,
    required this.neu,
    required this.done,
    required this.doneWash,
    required this.pending,
    required this.pendingWash,
    required this.alert,
    required this.moneyOut,
    required this.moneyOutWash,
    required this.moneyGet,
    required this.moneyGetWash,
    required this.moneyDue,
    required this.moneyDueWash,
    required this.shadowTint,
    required this.hero,
    required this.fill,
    required this.onFill,
    required this.hi,
    required this.lo,
  });

  /// Whether this skin is a dark one. Drives the status bar and anything
  /// else that has to know which way round the page is.
  final bool dark;

  final Color bg;

  /// A card on the page.
  final Color surface;

  /// A card on top of a card, or the face of a button.
  final Color raised;

  final Color text;
  final Color accent;
  final Color accent2;
  final Color divider;

  /// Accent ramp, nine steps. Index 0 is the faintest wash against the page
  /// and index 8 is the loudest — which means it inverts on a dark skin, and
  /// that is the point: "deeper" always means "further along", whatever the
  /// page is made of.
  final List<Color> acc;

  /// Neutral ramp, nine steps, same rule: 0 sits with the page, 8 sits with
  /// the ink.
  final List<Color> neu;

  final Color done;
  final Color doneWash;
  final Color pending;
  final Color pendingWash;
  final Color alert;
  final Color moneyOut;
  final Color moneyOutWash;
  final Color moneyGet;
  final Color moneyGetWash;
  final Color moneyDue;
  final Color moneyDueWash;

  /// What a shadow is made of on this skin.
  final Color shadowTint;

  /// Three stops behind a headline figure: deep, the farm's blue, then a
  /// violet at the far corner.
  final List<Color> hero;

  /// A block of colour meant to carry writing on top of it — the chosen
  /// chip, a filled button. On a pale page that is a deep blue under white
  /// ink; on a black page it is a bright blue under dark ink, because white
  /// on a mid blue is the one pairing that cannot be read either way.
  final Color fill;
  final Color onFill;

  /// The lit top edge and the dark bottom edge of a raised button — what
  /// makes it read as a thing you could press rather than a painted square.
  final Color hi;
  final Color lo;
}

const _light = _Pal(
  dark: false,
  bg: Color(0xFFF4F7F9),
  surface: Color(0xFFFFFFFF),
  raised: Color(0xFFE7EDF2),
  text: Color(0xFF16202B),
  accent: Color(0xFF2277AF),
  accent2: Color(0xFF4FC3F7),
  divider: Color(0x2916202B),
  acc: [
    Color(0xFFE9F3FA),
    Color(0xFFCFE6F5),
    Color(0xFFA6D2EE),
    Color(0xFF6FB6E2),
    Color(0xFF3D95CE),
    Color(0xFF2277AF),
    Color(0xFF175C8C),
    Color(0xFF0F3F63),
    Color(0xFF0B2438),
  ],
  neu: [
    Color(0xFFF5F7F9),
    Color(0xFFE6EAEE),
    Color(0xFFCFD6DD),
    Color(0xFFAEB8C2),
    Color(0xFF8B96A2),
    Color(0xFF6C7784),
    Color(0xFF515C68),
    Color(0xFF39424C),
    Color(0xFF212933),
  ],
  done: Color(0xFF0B7A45),
  doneWash: Color(0xFFE3F5EB),
  pending: Color(0xFF9C3B2C),
  pendingWash: Color(0xFFFBE9E5),
  alert: Color(0xFF8C2F20),
  moneyOut: Color(0xFFC62828),
  moneyOutWash: Color(0xFFFCE8E8),
  moneyGet: Color(0xFF4A82C2),
  moneyGetWash: Color(0xFFEAF1FA),
  moneyDue: Color(0xFFAD7C36),
  moneyDueWash: Color(0xFFFBF2E4),
  shadowTint: Color(0xFF0B2438),
  hero: [Color(0xFF0B2438), Color(0xFF1E6394), Color(0xFF5B49C9)],
  fill: Color(0xFF2277AF),
  onFill: Color(0xFFFFFFFF),
  hi: Color(0x99FFFFFF),
  lo: Color(0x1F0B2438),
);

const _medium = _Pal(
  dark: true,
  bg: Color(0xFF131C27),
  surface: Color(0xFF1C2836),
  raised: Color(0xFF243243),
  text: Color(0xFFE8EEF5),
  accent: Color(0xFF4FA8DC),
  accent2: Color(0xFF7FD8FF),
  divider: Color(0x24E8EEF5),
  acc: [
    Color(0xFF223245),
    Color(0xFF283C54),
    Color(0xFF2F4A66),
    Color(0xFF2E5D7F),
    Color(0xFF3A7CA6),
    Color(0xFF4FA8DC),
    Color(0xFF78C2EA),
    Color(0xFFA6D9F3),
    Color(0xFFD2ECFA),
  ],
  neu: [
    Color(0xFF151E29),
    Color(0xFF1E2A38),
    Color(0xFF283647),
    Color(0xFF344456),
    Color(0xFF64748B),
    Color(0xFF8E9CAD),
    Color(0xFFAAB7C6),
    Color(0xFFC9D3DE),
    Color(0xFFE6ECF3),
  ],
  done: Color(0xFF2FBF82),
  doneWash: Color(0xFF13312A),
  pending: Color(0xFFE58060),
  pendingWash: Color(0xFF33201A),
  alert: Color(0xFFF2705C),
  moneyOut: Color(0xFFF0736E),
  moneyOutWash: Color(0xFF321C1C),
  moneyGet: Color(0xFF6FA6E8),
  moneyGetWash: Color(0xFF1A2739),
  moneyDue: Color(0xFFD9AE5E),
  moneyDueWash: Color(0xFF302818),
  shadowTint: Color(0xFF000814),
  hero: [Color(0xFF10263F), Color(0xFF1F5E96), Color(0xFF5946CE)],
  fill: Color(0xFF4FA8DC),
  onFill: Color(0xFF0B1620),
  hi: Color(0x1FFFFFFF),
  lo: Color(0x66000000),
);

const _dark = _Pal(
  dark: true,
  bg: Color(0xFF04060A),
  surface: Color(0xFF0E141C),
  raised: Color(0xFF161F2A),
  text: Color(0xFFEEF3F8),
  accent: Color(0xFF3D95CE),
  accent2: Color(0xFF6FD3FF),
  divider: Color(0x26EEF3F8),
  acc: [
    Color(0xFF13202E),
    Color(0xFF18293B),
    Color(0xFF1E3A52),
    Color(0xFF1F4E6D),
    Color(0xFF2A6C95),
    Color(0xFF3D95CE),
    Color(0xFF62B3E4),
    Color(0xFF93CEF0),
    Color(0xFFC7E6F9),
  ],
  neu: [
    Color(0xFF0A0E14),
    Color(0xFF141A22),
    Color(0xFF1F2731),
    Color(0xFF2C3642),
    Color(0xFF5A6674),
    Color(0xFF8794A2),
    Color(0xFFA6B2BF),
    Color(0xFFC7D0DA),
    Color(0xFFE8EEF4),
  ],
  done: Color(0xFF34D399),
  doneWash: Color(0xFF0C2A20),
  pending: Color(0xFFF08A6A),
  pendingWash: Color(0xFF2E1712),
  alert: Color(0xFFFF6B5A),
  moneyOut: Color(0xFFFF6B6B),
  moneyOutWash: Color(0xFF2E1414),
  moneyGet: Color(0xFF7FB2F0),
  moneyGetWash: Color(0xFF101E30),
  moneyDue: Color(0xFFE0B45C),
  moneyDueWash: Color(0xFF2B2211),
  shadowTint: Color(0xFF000000),
  hero: [Color(0xFF0B1E3A), Color(0xFF1A4E86), Color(0xFF5B3FD6)],
  fill: Color(0xFF3D95CE),
  onFill: Color(0xFF04121C),
  hi: Color(0x1AFFFFFF),
  lo: Color(0x8C000000),
);

/// What a skin looks like, without wearing it.
///
/// The settings page shows all three side by side, each painted in its own
/// colours, so the choice explains itself the way the language cards do —
/// you recognise the one you want instead of reading about it.
extension SkinLook on Skin {
  _Pal get _pal => switch (this) {
    Skin.light => _light,
    Skin.medium => _medium,
    Skin.dark => _dark,
  };

  Color get sampleBg => _pal.bg;
  Color get sampleCard => _pal.surface;
  Color get sampleInk => _pal.text;
  Color get sampleMuted => _pal.neu[5];
  Color get sampleAccent => _pal.accent;
  Color get sampleGood => _pal.done;
  bool get sampleDark => _pal.dark;
}

/// Design tokens, taken from the farm's logo: the blue of the milk splash,
/// the near-navy behind it, and the steel of the bull.
///
/// Every colour, radius and type size lives in this one file so the whole app
/// shifts together — including between the three skins. Nothing outside this
/// file writes a colour of its own.
abstract final class T {
  static Skin? _forced;

  static _Pal get _p => switch (_forced ?? skinNow.value) {
    Skin.light => _light,
    Skin.medium => _medium,
    Skin.dark => _dark,
  };

  /// Build something as a printed document rather than a screen.
  ///
  /// A statement leaves the phone — it is shared to a customer, who reads it
  /// on their own phone and may hold it up at the gate. It is paper, so it
  /// is white with dark ink whichever skin the person who sent it was
  /// wearing. Everything inside [build] must be laid out in the same pass,
  /// which is why the statement's parts are functions and not widgets: a
  /// widget's own build runs later, after this has been put back.
  static R onPaper<R>(R Function() build) {
    final was = _forced;
    _forced = Skin.light;
    try {
      return build();
    } finally {
      _forced = was;
    }
  }

  /// True when the page is dark under the ink.
  static bool get isDark => _p.dark;

  // ---- Colours ----
  static Color get bg => _p.bg;
  static Color get surface => _p.surface;

  /// A card on top of a card, or the face of a button.
  static Color get raised => _p.raised;
  static Color get text => _p.text;
  static Color get accent => _p.accent;
  static Color get accent2 => _p.accent2;
  static Color get divider => _p.divider;

  /// The lit top edge of a raised button, and the shade under its lip.
  static Color get lit => _p.hi;
  static Color get shade => _p.lo;

  /// A block of colour with writing on it — a chosen chip, a filled button.
  /// Always use the pair: [onFill] is the only ink that reads on [fill].
  static Color get fill => _p.fill;
  static Color get onFill => _p.onFill;

  /// The farm's deep navy, the same on all three skins. For the splash and
  /// anything else that is the farm's own colour rather than the page's.
  static Color get brandDeep => _p.hero[0];

  /// Writing on top of the headline wash, and the quieter second line of it.
  ///
  /// These do not follow the ramp and do not change with the skin, because
  /// the wash does not either — it is deep on all three. The label on the
  /// hero used to be [accent200], which is pale on paper and very nearly
  /// black once the ramp flipped, so on the dark skin the word above the
  /// farm's cash balance disappeared entirely.
  static const onHero = Color(0xFFFFFFFF);
  static const onHeroQuiet = Color(0xFFBBD5EC);

  /// The lip under a raised button's face — the same colour, driven into
  /// the dark. A button is one colour with a shadow under it on most apps;
  /// here the lip is part of the button, so it looks like a key you press
  /// rather than a sticker on the page.
  static Color lipOf(Color c) => Color.lerp(c, const Color(0xFF000000), 0.42)!;

  /// The face of a raised button: the colour, lit slightly across the top.
  static LinearGradient faceOf(Color c) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color.lerp(c, const Color(0xFFFFFFFF), 0.16)!, c],
  );

  /// The blue-to-violet the farm chose for anything that is the one thing
  /// on the screen to press.
  static LinearGradient get cta => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [_p.hero[1], _p.hero[2]],
  );

  /// Writing that can be read on top of [c], whatever [c] turns out to be.
  ///
  /// The accent ramp flips between the skins — the same token that is a deep
  /// navy on paper is a pale sky on black — so a chip that hard-codes white
  /// ink is legible on one skin and blank on another. Ask instead.
  /// Whichever of the two reads better, measured rather than guessed. A
  /// first cut of this split at "is it lighter than halfway", which put
  /// white ink on the mid blues where it is the worse of the two by a long
  /// way — the crossover is nearer a fifth of the way up, not halfway.
  static Color inkOn(Color c) {
    const dark = Color(0xFF08131C);
    const light = Color(0xFFFFFFFF);
    final l = c.computeLuminance();
    final onLight = 1.05 / (l + 0.05);
    final onDark = (l + 0.05) / (dark.computeLuminance() + 0.05);
    return onLight >= onDark ? light : dark;
  }

  /// Accent ramp 100 -> 900, faintest wash to loudest.
  ///
  /// This is also the app's progress scale: the further something has come,
  /// the deeper the blue. See [stage].
  static Color get accent100 => _p.acc[0];
  static Color get accent200 => _p.acc[1];
  static Color get accent300 => _p.acc[2];
  static Color get accent400 => _p.acc[3];
  static Color get accent500 => _p.acc[4];
  static Color get accent600 => _p.acc[5];
  static Color get accent700 => _p.acc[6];
  static Color get accent800 => _p.acc[7];
  static Color get accent900 => _p.acc[8];

  // Neutral ramp 100 -> 900, cool steel rather than warm paper.
  static Color get n100 => _p.neu[0];
  static Color get n200 => _p.neu[1];
  static Color get n300 => _p.neu[2];
  static Color get n400 => _p.neu[3];
  static Color get n500 => _p.neu[4];
  static Color get n600 => _p.neu[5];
  static Color get n700 => _p.neu[6];
  static Color get n800 => _p.neu[7];
  static Color get n900 => _p.neu[8];

  // ---- Meaning ----
  /// Done, and nothing left to do about it.
  static Color get done => _p.done;
  static Color get doneWash => _p.doneWash;

  /// Still to do. Not an error — just not finished.
  static Color get pending => _p.pending;
  static Color get pendingWash => _p.pendingWash;

  /// Something wrong that needs a person: an overdue check, a missing rate.
  static Color get alert => _p.alert;

  // ---- Money ----
  /// Money is read in two grades, and the farm asked for the difference to be
  /// visible from across the room: what has actually moved is deep and bold,
  /// what is still only promised is pale and light.
  ///
  /// Deep: the rupee changed hands. Pale: it has not, yet.
  static Color get moneyIn => _p.done; // received
  static Color get moneyInWash => _p.doneWash;
  static Color get moneyOut => _p.moneyOut; // paid out
  static Color get moneyOutWash => _p.moneyOutWash;
  static Color get moneyGet => _p.moneyGet; // receivable — still to come
  static Color get moneyGetWash => _p.moneyGetWash;
  static Color get moneyDue => _p.moneyDue; // payable — still to go
  static Color get moneyDueWash => _p.moneyDueWash;

  /// The colour a figure should be written in.
  ///
  /// [settled] is whether the money has moved. A sale that is paid is deep
  /// green; the same sale unpaid is pale blue, because the farm does not have
  /// it yet.
  static Color money({required bool incoming, required bool settled}) =>
      incoming
      ? (settled ? moneyIn : moneyGet)
      : (settled ? moneyOut : moneyDue);

  static Color moneyWash({required bool incoming, required bool settled}) =>
      incoming
      ? (settled ? moneyInWash : moneyGetWash)
      : (settled ? moneyOutWash : moneyDueWash);

  /// Weight goes with the grade: settled money is stated, unsettled is noted.
  static FontWeight moneyWeight(bool settled) =>
      settled ? FontWeight.w600 : FontWeight.w500;

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
  static List<Color> get partnerColors => [
    accent700,
    accent500,
    accent300,
    accent800,
  ];

  // ---- Shape ----
  /// Rounded, and lifted off the page rather than ruled off it.
  ///
  /// The first cut of this app drew everything as hairline boxes with square
  /// corners, which read as one flat grey sheet — the farm's word for it was
  /// "pheeka". Cards now round and cast a shadow, so a tap target looks like
  /// an object you could pick up.
  static const radius = 16.0;
  static const radiusSm = 12.0;
  static const radiusXs = 9.0;
  static const pill = 999.0;
  static const hairline = 1.0;

  static Border get hair => Border.all(color: divider, width: hairline);

  static BorderRadius get round => BorderRadius.circular(radius);
  static BorderRadius get roundSm => BorderRadius.circular(radiusSm);

  /// A card at rest: a hairline of contact plus a soft spread, so it lifts
  /// without the muddy grey halo a single big blur leaves on a pale page.
  static List<BoxShadow> get shadow => [
    BoxShadow(
      color: _p.shadowTint.withValues(alpha: _p.dark ? 0.45 : 0.06),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: _p.shadowTint.withValues(alpha: _p.dark ? 0.55 : 0.08),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  /// The one thing on the screen that matters most.
  static List<BoxShadow> get shadowLift => [
    BoxShadow(
      color: _p.shadowTint.withValues(alpha: _p.dark ? 0.50 : 0.10),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: _p.shadowTint.withValues(alpha: _p.dark ? 0.70 : 0.17),
      blurRadius: 40,
      offset: const Offset(0, 18),
    ),
  ];

  /// The navy-to-blue-to-violet wash behind a headline figure.
  static LinearGradient get heroWash => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: _p.hero,
    stops: const [0, 0.55, 1],
  );

  /// The same wash in any hue, for a filtered page that has taken a colour.
  static LinearGradient washOf(Color c) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color.lerp(c, const Color(0xFF04101A), 0.62)!, c],
  );

  // ---- Spacing ----
  static const gap = 12.0;
  static const pad = 16.0;

  /// Minimum tap target on a real device.
  static const tap = 44.0;

  // ---- Type ----
  static const fontHead = 'BarlowCondensed';
  static const fontBody = 'Barlow';

  static TextStyle get title => TextStyle(
    fontFamily: fontHead,
    fontWeight: FontWeight.w600,
    fontSize: 44,
    height: 1.02,
    color: text,
  );
  static TextStyle get screenTitle => TextStyle(
    fontFamily: fontHead,
    fontWeight: FontWeight.w600,
    fontSize: 22,
    height: 1.1,
    color: text,
  );
  static TextStyle get num36 => TextStyle(
    fontFamily: fontHead,
    fontWeight: FontWeight.w600,
    fontSize: 36,
    height: 1.05,
    color: text,
  );
  static TextStyle get num30 => TextStyle(
    fontFamily: fontHead,
    fontWeight: FontWeight.w600,
    fontSize: 30,
    height: 1.05,
    color: text,
  );
  static TextStyle get num28 => TextStyle(
    fontFamily: fontHead,
    fontWeight: FontWeight.w600,
    fontSize: 28,
    height: 1.05,
    color: text,
  );
  static TextStyle get num26 => TextStyle(
    fontFamily: fontHead,
    fontWeight: FontWeight.w600,
    fontSize: 26,
    height: 1.05,
    color: text,
  );
  static TextStyle get num22 => TextStyle(
    fontFamily: fontHead,
    fontWeight: FontWeight.w600,
    fontSize: 22,
    height: 1.05,
    color: text,
  );
  static TextStyle get cardTitle => TextStyle(
    fontFamily: fontBody,
    fontWeight: FontWeight.w500,
    fontSize: 17,
    height: 1.25,
    color: text,
  );
  static TextStyle get body => TextStyle(
    fontFamily: fontBody,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.4,
    color: text,
  );
  static TextStyle get bodyMid => TextStyle(
    fontFamily: fontBody,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 1.4,
    color: text,
  );
  static TextStyle get meta => TextStyle(
    fontFamily: fontBody,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 1.35,
    color: n700,
  );
  static TextStyle get kicker => TextStyle(
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
