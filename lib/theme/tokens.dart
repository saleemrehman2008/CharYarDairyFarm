import 'package:flutter/material.dart';

/// Which of the three skins the app is wearing.
///
/// The farm asked for a choice, and the choice is kept small on purpose:
/// three, not a colour wheel. [dark] is what the app opens in — a round is
/// walked at four in the morning and again after dark, and a white screen at
/// that hour is a torch in the face.
///
/// [wallet] took the place of a second dark skin after the farm was shown
/// its own home screen beside a payments app and asked for that one. A
/// middling dark was the least useful of the three: whoever wanted dark
/// wanted the darkest, and whoever did not wanted white. A name nobody has
/// chosen for a year falls back to [dark], which is what anybody on the old
/// middle skin will open into — the nearest thing to what they had.
enum Skin {
  dark('Dark'),
  glow('Glow'),
  ember('Ember'),
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

/// The wallet skin: the farm's books in the shape of a payments app.
///
/// Asked for by name after a side-by-side with Easypaisa and JazzCash, and
/// built the way those are built: a white ground, one band of green across
/// the top, and the figures in black on white cards. Nothing about the
/// books changes — every page is the same page, every figure the same
/// figure. Only the paint is different.
///
/// Green rather than the farm's blue, because the green is what makes the
/// app read as a wallet at a glance, and because the farm already has a
/// blue skin: two blues would have been one choice wearing two coats.
/// Money in and money out keep their own green and red, a shade apart from
/// the accent so a receipt never reads as a brand colour.
/// The ember skin: black, with one orange burning on it.
///
/// The third reference he sent, and the opposite half of the same idea as
/// [_glow] — a page that is simply black, and one hot colour carrying every
/// button, every lit tab and every heading. Where the glow skin tints its
/// black green, this one tints it the other way: the neutrals here are warm
/// greys, so the orange sits on them rather than fighting them.
///
/// The money colours take more care here than on any other skin. Orange is
/// close to red and close to amber, and this app writes money out in a red
/// and money owed in an amber — so on a page whose chrome is orange, those
/// two would read as the brand rather than as figures. Money out is pulled
/// round to a crimson and money owed to a clear yellow-gold, far enough
/// from the accent that a figure is never mistaken for a button.
const _ember = _Pal(
  dark: true,
  bg: Color(0xFF0A0908),
  surface: Color(0xFF151311),
  raised: Color(0xFF1E1A17),
  text: Color(0xFFF2EEEA),
  accent: Color(0xFFFF6A1A),
  accent2: Color(0xFFFF9A5C),
  divider: Color(0x24F2EEEA),
  acc: [
    Color(0xFF2A1E14),
    Color(0xFF32200F),
    Color(0xFF452810),
    Color(0xFF653511),
    Color(0xFFA14914),
    Color(0xFFFF6A1A),
    Color(0xFFFF8F4F),
    Color(0xFFFFB587),
    Color(0xFFFFDCC4),
  ],
  neu: [
    Color(0xFF0D0B0A),
    Color(0xFF171412),
    Color(0xFF221E1B),
    Color(0xFF2F2A26),
    Color(0xFF6A615A),
    Color(0xFF948A82),
    Color(0xFFB3A99F),
    Color(0xFFD3C9C0),
    Color(0xFFF0EAE4),
  ],
  done: Color(0xFF3DDC84),
  doneWash: Color(0xFF0D2A1B),
  pending: Color(0xFFFFB07A),
  pendingWash: Color(0xFF2E1C10),
  alert: Color(0xFFFF5A4D),
  moneyOut: Color(0xFFFF4D6D),
  moneyOutWash: Color(0xFF2E1219),
  moneyGet: Color(0xFF5BA8FF),
  moneyGetWash: Color(0xFF0E1E33),
  moneyDue: Color(0xFFF5C542),
  moneyDueWash: Color(0xFF2C2410),
  shadowTint: Color(0xFF000000),
  hero: [Color(0xFF140A04), Color(0xFF4A1C06), Color(0xFF7A2F08)],
  fill: Color(0xFFFF6A1A),
  onFill: Color(0xFF140A04),
  hi: Color(0x1FFFFFFF),
  lo: Color(0x66000000),
);

/// The glow skin: near-black with a green in it, and one vivid green on top.
///
/// Asked for from two references he sent — a payments app and a smart-home
/// app, both black with a single bright green doing all the work. The two
/// agreed on everything that matters: a ground so dark it is almost black
/// but tinted green rather than blue, cards barely lifted off it, and one
/// saturated green carrying every button, every active tab and every figure
/// that means money came in.
///
/// It is not the wallet skin in the dark. The wallet green is the deep
/// green of a bank's letterhead; this one is a lit sign at night, and the
/// whole point of it is that the green glows against black. That only works
/// if nothing else on the page competes: the neutrals here are green-grey,
/// not blue-grey, so the accent is the only saturated thing in sight.
const _glow = _Pal(
  dark: true,
  bg: Color(0xFF070B09),
  surface: Color(0xFF101614),
  raised: Color(0xFF18211D),
  text: Color(0xFFE8F3EC),
  accent: Color(0xFF2EE07A),
  accent2: Color(0xFF7BFFB0),
  divider: Color(0x24E8F3EC),
  acc: [
    Color(0xFF10261A),
    Color(0xFF133020),
    Color(0xFF16422A),
    Color(0xFF1A5D38),
    Color(0xFF209650),
    Color(0xFF2EE07A),
    Color(0xFF5EE99A),
    Color(0xFF92F2BD),
    Color(0xFFC8FADF),
  ],
  neu: [
    Color(0xFF0A100D),
    Color(0xFF121A16),
    Color(0xFF1B241F),
    Color(0xFF27332C),
    Color(0xFF566A5F),
    Color(0xFF80948A),
    Color(0xFFA0B2A8),
    Color(0xFFC4D4CA),
    Color(0xFFE6F2EB),
  ],
  done: Color(0xFF35E07D),
  doneWash: Color(0xFF0D2A1C),
  pending: Color(0xFFFFA06A),
  pendingWash: Color(0xFF2E1B12),
  alert: Color(0xFFFF6B6B),
  moneyOut: Color(0xFFFF6B7A),
  moneyOutWash: Color(0xFF2E1418),
  moneyGet: Color(0xFF5BC8FF),
  moneyGetWash: Color(0xFF0F2434),
  moneyDue: Color(0xFFFFC24D),
  moneyDueWash: Color(0xFF2E2413),
  shadowTint: Color(0xFF000000),
  hero: [Color(0xFF04140C), Color(0xFF0A3B22), Color(0xFF12603A)],
  fill: Color(0xFF2EE07A),
  onFill: Color(0xFF04140C),
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
    Skin.glow => _glow,
    Skin.ember => _ember,
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
    Skin.glow => _glow,
    Skin.ember => _ember,
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

  /// The light a coloured thing throws onto the page behind it.
  ///
  /// The farm asked for the app to glow, from two references that were both
  /// black with one hot colour on them. A glow is light, so it only reads
  /// where there is dark for it to fall on: the same shadow under a green
  /// chip on a white page is a dirty smudge. So it is strong on the dark
  /// skins and almost nothing on the pale ones — one call site, four
  /// answers, and no screen has to know which skin it is wearing.
  ///
  /// [strong] is for the few things that are meant to be the brightest on
  /// the page: the tab you are on, the button that does the thing.
  static List<BoxShadow> glowOf(Color c, {bool strong = false}) => [
    BoxShadow(
      color: c.withValues(
        alpha: isDark ? (strong ? 0.42 : 0.26) : (strong ? 0.20 : 0.11),
      ),
      blurRadius: strong ? 18 : 11,
      spreadRadius: strong ? 0 : -1,
    ),
  ];

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

  /// Urdu as it is written.
  ///
  /// Barlow has no Arabic-script glyphs at all, so without this every Urdu
  /// word falls through to whatever face the phone happens to carry — which
  /// on a cheap Android is sometimes nothing, and the screen fills with empty
  /// boxes. Naming the face behind every style settles it on the app's own
  /// terms: Latin text never reaches the fallback, Urdu text always does.
  ///
  /// Naskh rather than Nastaliq on purpose. Nastaliq is the handwriting Urdu
  /// is set in on a poster, and it slopes — it needs close to twice the line
  /// height to sit without clipping. This app is a book of accounts: twenty
  /// rows to a page, a figure on the right of each. Naskh reads cleanly at
  /// twelve point in a row that tight, and the ledger stays a ledger.
  static const fontUrdu = 'NotoNaskhArabic';
  static const urduFaces = <String>[fontUrdu];

  static TextStyle get title => TextStyle(
    fontFamily: fontHead,
    fontFamilyFallback: urduFaces,
    fontWeight: FontWeight.w600,
    fontSize: 44,
    height: 1.02,
    color: text,
  );
  static TextStyle get screenTitle => TextStyle(
    fontFamily: fontHead,
    fontFamilyFallback: urduFaces,
    fontWeight: FontWeight.w600,
    fontSize: 22,
    height: 1.1,
    color: text,
  );
  static TextStyle get num36 => TextStyle(
    fontFamily: fontHead,
    fontFamilyFallback: urduFaces,
    fontWeight: FontWeight.w600,
    fontSize: 36,
    height: 1.05,
    color: text,
  );
  static TextStyle get num30 => TextStyle(
    fontFamily: fontHead,
    fontFamilyFallback: urduFaces,
    fontWeight: FontWeight.w600,
    fontSize: 30,
    height: 1.05,
    color: text,
  );
  static TextStyle get num28 => TextStyle(
    fontFamily: fontHead,
    fontFamilyFallback: urduFaces,
    fontWeight: FontWeight.w600,
    fontSize: 28,
    height: 1.05,
    color: text,
  );
  static TextStyle get num26 => TextStyle(
    fontFamily: fontHead,
    fontFamilyFallback: urduFaces,
    fontWeight: FontWeight.w600,
    fontSize: 26,
    height: 1.05,
    color: text,
  );
  static TextStyle get num22 => TextStyle(
    fontFamily: fontHead,
    fontFamilyFallback: urduFaces,
    fontWeight: FontWeight.w600,
    fontSize: 22,
    height: 1.05,
    color: text,
  );
  static TextStyle get cardTitle => TextStyle(
    fontFamily: fontBody,
    fontFamilyFallback: urduFaces,
    fontWeight: FontWeight.w500,
    fontSize: 17,
    height: 1.25,
    color: text,
  );
  static TextStyle get body => TextStyle(
    fontFamily: fontBody,
    fontFamilyFallback: urduFaces,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.4,
    color: text,
  );
  static TextStyle get bodyMid => TextStyle(
    fontFamily: fontBody,
    fontFamilyFallback: urduFaces,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 1.4,
    color: text,
  );
  static TextStyle get meta => TextStyle(
    fontFamily: fontBody,
    fontFamilyFallback: urduFaces,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 1.35,
    color: n700,
  );
  static TextStyle get kicker => TextStyle(
    fontFamily: fontBody,
    fontFamilyFallback: urduFaces,
    fontWeight: FontWeight.w500,
    fontSize: 11,
    height: 1.3,
    letterSpacing: 0.12 * 11,
    color: n600,
  );
  static const tabLabel = TextStyle(
    fontFamily: fontBody,
    fontFamilyFallback: urduFaces,
    fontWeight: FontWeight.w500,
    fontSize: 11,
    height: 1.2,
  );
}
