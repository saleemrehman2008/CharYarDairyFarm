import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/theme/tokens.dart';

/// Three skins, one set of tokens.
///
/// Every colour in the app comes out of [T], and [T] answers differently
/// depending on which skin is on. That makes one whole class of mistake
/// possible that could not happen before: a pairing that reads on paper and
/// vanishes on black. Nobody is going to open every screen on all three
/// skins by hand, so the pairings are checked here instead.

/// How far apart two colours are, by the WCAG reckoning. 4.5 is the usual
/// bar for ordinary writing, 3 for large writing and for furniture.
double _ratio(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  final hi = x > y ? x : y;
  final lo = x > y ? y : x;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  tearDown(() => skinNow.value = Skin.dark);

  test('the app opens dark, which is what the farm asked for', () {
    expect(skinNow.value, Skin.dark);
    expect(T.isDark, isTrue);
  });

  test('an unknown name falls back to dark rather than to nothing', () {
    expect(Skin.byName(null), Skin.dark);
    expect(Skin.byName('sepia'), Skin.dark);
    expect(Skin.byName('light'), Skin.light);
    expect(Skin.byName('medium'), Skin.medium);
  });

  for (final skin in Skin.values) {
    group('the ${skin.label.toLowerCase()} skin', () {
      setUp(() => skinNow.value = skin);

      test('writing can be read on the page', () {
        expect(_ratio(T.text, T.bg), greaterThan(7));
        expect(_ratio(T.text, T.surface), greaterThan(7));
        expect(_ratio(T.text, T.raised), greaterThan(6));
      });

      test('the quiet writing is quiet, not invisible', () {
        // Notes and dates are set in n700 and n600 on a card. They are
        // meant to recede; they are not meant to disappear.
        expect(_ratio(T.n700, T.surface), greaterThan(4.5));
        expect(_ratio(T.n600, T.surface), greaterThan(3.5));
      });

      test(
        'ink picked for a block is legible on every block it is used on',
        () {
          // Chips, filled day squares, badges and the FAB all ask [T.inkOn]
          // for their writing. If it answers badly for any of these, some
          // control somewhere on this skin is blank.
          final blocks = {
            'accent': T.accent,
            'accent300': T.accent300,
            'accent500': T.accent500,
            'accent700': T.accent700,
            'accent900': T.accent900,
            'fill': T.fill,
            'pending': T.pending,
            'done': T.done,
            'moneyOut': T.moneyOut,
            'n300': T.n300,
          };
          blocks.forEach((name, c) {
            expect(
              _ratio(T.inkOn(c), c),
              greaterThan(4.5),
              reason: 'writing on $name',
            );
          });
        },
      );

      test('a filled chip can be read', () {
        // The pairing that broke first: the accent ramp flips between the
        // skins, so white ink on a chip is legible on one and blank on
        // another. [T.onFill] is the answer and this is what checks it.
        expect(_ratio(T.onFill, T.fill), greaterThan(4.5));
      });

      test('money keeps its colours apart from the page', () {
        for (final pair in [
          (T.moneyIn, T.moneyInWash),
          (T.moneyOut, T.moneyOutWash),
          (T.moneyGet, T.moneyGetWash),
          (T.moneyDue, T.moneyDueWash),
        ]) {
          expect(
            _ratio(pair.$1, T.surface),
            greaterThan(3),
            reason: 'a figure on a card',
          );
          expect(
            _ratio(pair.$1, pair.$2),
            greaterThan(3),
            reason: 'a figure on its own wash',
          );
        }
      });

      test('and the four of them are told apart from each other', () {
        final money = [T.moneyIn, T.moneyOut, T.moneyGet, T.moneyDue];
        for (var i = 0; i < money.length; i++) {
          for (var j = i + 1; j < money.length; j++) {
            expect(
              money[i].toARGB32() == money[j].toARGB32(),
              isFalse,
              reason: 'two states of money drawn the same colour',
            );
          }
        }
      });

      test('the accent ramp runs one way, palest against the page first', () {
        final ramp = [
          T.accent100,
          T.accent200,
          T.accent300,
          T.accent400,
          T.accent500,
          T.accent600,
          T.accent700,
          T.accent800,
          T.accent900,
        ];
        for (var i = 1; i < ramp.length; i++) {
          final near = _ratio(ramp[i - 1], T.bg);
          final far = _ratio(ramp[i], T.bg);
          expect(
            far,
            greaterThanOrEqualTo(near),
            reason: 'step $i sits closer to the page than step ${i - 1}',
          );
        }
      });

      test('the neutral ramp does too', () {
        final ramp = [
          T.n100,
          T.n200,
          T.n300,
          T.n400,
          T.n500,
          T.n600,
          T.n700,
          T.n800,
          T.n900,
        ];
        for (var i = 1; i < ramp.length; i++) {
          expect(
            _ratio(ramp[i], T.bg),
            greaterThanOrEqualTo(_ratio(ramp[i - 1], T.bg)),
          );
        }
      });

      test('a button has a lip darker than its face', () {
        final face = T.fill;
        expect(
          T.lipOf(face).computeLuminance(),
          lessThan(face.computeLuminance()),
        );
      });

      test('the headline wash is dark enough to write on in white', () {
        for (final stop in [
          T.brandDeep,
          ...[T.heroWash.colors.last],
        ]) {
          expect(
            _ratio(const Color(0xFFFFFFFF), stop),
            greaterThan(4.5),
            reason: 'white on the hero',
          );
        }
      });

      test('the palest washes are visible against a card', () {
        // accent100 and accent200 are used as a tint behind a banner, a
        // chosen row, the pill under the open tab. On the dark skins they
        // were first written darker than the card they sit on, which made
        // every one of those markings vanish.
        for (final wash in [T.accent100, T.accent200]) {
          expect(
            _ratio(wash, T.surface),
            greaterThan(1.12),
            reason: 'a tint nobody can see is not a tint',
          );
          expect(
            _ratio(T.text, wash),
            greaterThan(6),
            reason: 'and writing still has to read on it',
          );
        }
      });

      test('writing on the headline wash reads', () {
        // The wash is deep on all three skins, so its ink does not follow
        // the ramp — it is fixed, and this is what says so.
        for (final stop in T.heroWash.colors) {
          expect(_ratio(T.onHero, stop), greaterThan(4.5));
          expect(_ratio(T.onHeroQuiet, stop), greaterThan(3));
        }
      });

      test('a card is distinguishable from the page behind it', () {
        expect(
          T.surface.toARGB32() == T.bg.toARGB32(),
          isFalse,
          reason: 'a card that is the same colour as the page is not a card',
        );
      });
    });
  }

  group('ink chosen for whatever it lands on', () {
    test('goes light on a dark block', () {
      expect(
        T.inkOn(const Color(0xFF0B2438)).computeLuminance(),
        greaterThan(0.5),
      );
    });

    test('and dark on a pale one', () {
      expect(
        T.inkOn(const Color(0xFFC7E6F9)).computeLuminance(),
        lessThan(0.5),
      );
    });

    test('which is the whole point — the same token, two skins', () {
      skinNow.value = Skin.light;
      final onPaper = T.inkOn(T.accent700);
      skinNow.value = Skin.dark;
      final onBlack = T.inkOn(T.accent700);
      // accent700 is a deep navy on paper and a pale sky on black, so the
      // ink has to come out the other way round.
      expect(onPaper.computeLuminance(), greaterThan(0.5));
      expect(onBlack.computeLuminance(), lessThan(0.5));
    });
  });

  group('a statement is paper whatever skin the sender is wearing', () {
    test('it comes out light in the middle of a dark app', () {
      skinNow.value = Skin.dark;
      final page = T.bg;
      final sheet = T.onPaper(() => T.bg);
      expect(sheet.computeLuminance(), greaterThan(0.8));
      expect(page.computeLuminance(), lessThan(0.1));
    });

    test('and the ink on it is dark', () {
      skinNow.value = Skin.dark;
      expect(T.onPaper(() => T.text).computeLuminance(), lessThan(0.1));
    });

    test('the skin is put back afterwards', () {
      skinNow.value = Skin.dark;
      T.onPaper(() => T.bg);
      expect(T.isDark, isTrue);
    });

    test('even if the thing being drawn throws', () {
      skinNow.value = Skin.dark;
      expect(
        () => T.onPaper<void>(() => throw StateError('bad statement')),
        throwsStateError,
      );
      expect(T.isDark, isTrue, reason: 'a failed export left the app white');
    });
  });
}
