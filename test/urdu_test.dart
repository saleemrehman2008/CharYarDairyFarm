// The third language: Urdu in its own script, running right to left.
//
// Two of these matter more than the rest. The first is that `ur` still
// means Roman Urdu — it has meant that since the first build, and every
// account that chose it must go on reading what it chose. The second is
// that the Urdu table answers every phrase the screens ask for: a man
// reading this language cannot read the English fallback at all, so a
// missing line is a hole in his page rather than a rough patch in it.

import 'dart:io';

import 'package:char_yar_dairy_farm/i18n/roman_urdu.dart';
import 'package:char_yar_dairy_farm/i18n/samjhao.dart';
import 'package:char_yar_dairy_farm/i18n/urdu.dart';
import 'package:char_yar_dairy_farm/i18n/words.dart';
import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Anything in the Arabic script, which is what Urdu is written in.
final _urduLetter = RegExp(r'[؀-ۿ]');

/// A letter of the English alphabet.
final _latinLetter = RegExp(r'[A-Za-z]');

void main() {
  group('three languages, and the old two unchanged', () {
    test('a stored name picks the language it has always picked', () {
      expect(Lang.parse('en'), Lang.en);
      expect(Lang.parse('ur'), Lang.ur);
      expect(Lang.parse('urdu'), Lang.urdu);
    });

    test('anything else is English, as it was', () {
      expect(Lang.parse(null), Lang.en);
      expect(Lang.parse(''), Lang.en);
      expect(Lang.parse('punjabi'), Lang.en);
      expect(Lang.parse(7), Lang.en);
    });

    test('ur still means Roman Urdu, not the script', () {
      // The id was written onto real accounts long before the script
      // existed. If it ever moved, every one of them would open into a page
      // they did not choose.
      expect(Lang.parse('ur').label, 'Roman Urdu');
      expect(const L(Lang.ur).t('Cash in hand'), 'Farm ke paas cash');
      expect(const L(Lang.ur).t('Cash in hand'), isNot(contains('نقد')));
    });

    test('each language reads out of its own table', () {
      const cash = 'Cash in hand';
      expect(const L(Lang.en).t(cash), cash);
      expect(const L(Lang.ur).t(cash), romanUrdu[cash]);
      expect(const L(Lang.urdu).t(cash), urduScript[cash]);
      expect(urduScript[cash], contains('نقد'));
    });

    test('only the script language turns the page round', () {
      expect(const L(Lang.en).rtl, isFalse);
      expect(const L(Lang.ur).rtl, isFalse);
      expect(const L(Lang.urdu).rtl, isTrue);
    });

    test('a phrase with nothing behind it falls back to the English', () {
      const nonsense = 'Pack the buffalo into the lorry';
      for (final lang in Lang.values) {
        expect(L(lang).t(nonsense), nonsense);
      }
    });

    test('the fill-ins work in the script too', () {
      final said = const L(Lang.urdu).t2('%s unpaid', 'Rs 4,200');
      expect(said, contains('Rs 4,200'));
      expect(said, isNot(contains('%s')));
      expect(said, matches(_urduLetter));
    });
  });

  group('the Urdu table', () {
    test('answers every phrase the Roman Urdu table answers', () {
      // Both are keyed on the same English. One ahead of the other means a
      // screen that reads in one language and not the other.
      final missing = romanUrdu.keys
          .where((k) => !urduScript.containsKey(k))
          .toList();
      expect(missing, isEmpty, reason: 'no Urdu for: ${missing.take(5)}');
    });

    test('and asks for nothing the screens do not', () {
      final extra = urduScript.keys
          .where((k) => !romanUrdu.containsKey(k))
          .toList();
      expect(extra, isEmpty, reason: 'nothing asks for: ${extra.take(5)}');
    });

    test('every line of it is actually in Urdu script', () {
      // The point of this table is a page with no Latin on it. A line left
      // in English here reads as a blank to the one reader it is for.
      final notUrdu = <String>[];
      for (final entry in urduScript.entries) {
        if (!_urduLetter.hasMatch(entry.value)) notUrdu.add(entry.key);
      }
      expect(notUrdu, isEmpty, reason: 'still in English: ${notUrdu.take(5)}');
    });

    test('and carries no English words inside the sentences', () {
      // Figures, Rs, L, the @ sign and the %s fill-ins are allowed — they
      // are read the same in both scripts and the farm reads its own
      // numerals. Words are not.
      final latin = <String>[];
      for (final entry in urduScript.entries) {
        final stripped = entry.value
            .replaceAll('%s', '')
            .replaceAll(RegExp(r'\bRs\b'), '')
            .replaceAll(RegExp(r'\bL\b'), '')
            // The Sheet's own tab names are what a reader will see written
            // on the Sheet itself, so they stay spelled as they are there.
            .replaceAll(
              RegExp(
                r'\b(Summary|Entries|Periods|Co-founders|Khaata|'
                r'Deliveries|Cattle|Add)\b',
              ),
              '',
            );
        if (_latinLetter.hasMatch(stripped)) latin.add(entry.key);
      }
      expect(latin, isEmpty, reason: 'English left in: ${latin.take(5)}');
    });

    test('draws no arrows, which point the wrong way on a reversed page', () {
      // An arrow is drawn left to right and carries its meaning in that
      // direction. On a page running the other way it ends up pointing
      // back at where the money came from, so "A gave it to B" reads as
      // "B gave it to A" — on a screen about who is holding whose money.
      // The Urdu lines say it in words instead.
      final arrows = urduScript.entries
          .where((e) => e.value.contains('→') || e.value.contains('←'))
          .map((e) => e.key)
          .toList();
      expect(arrows, isEmpty, reason: 'arrow in: ${arrows.take(5)}');
    });

    test('keeps every fill-in the English has, in the same number', () {
      final wrong = <String>[];
      for (final entry in urduScript.entries) {
        final wanted = '%s'.allMatches(entry.key).length;
        final got = '%s'.allMatches(entry.value).length;
        if (wanted != got) wrong.add(entry.key);
      }
      expect(wrong, isEmpty, reason: 'fill-ins do not match: ${wrong.take(5)}');
    });
  });

  group('the explanations behind a word', () {
    test('say the same things in both languages', () {
      expect(samjhaoUrdu.keys.toSet(), samjhao.keys.toSet());
    });

    test('and the script one is in the script', () {
      for (final said in samjhaoUrdu.values) {
        expect(said, matches(_urduLetter));
      }
    });

    test('a reader is handed the table for his own language', () {
      expect(samjhaoFor(Lang.en), same(samjhao));
      expect(samjhaoFor(Lang.ur), same(samjhao));
      expect(samjhaoFor(Lang.urdu), same(samjhaoUrdu));
    });
  });

  group('the font the script is drawn in', () {
    test('is on the phone, not borrowed from it', () {
      // Barlow has no Arabic glyphs at all. Without this file bundled, an
      // Urdu page falls through to whatever the handset happens to carry,
      // and on a cheap Android that is sometimes nothing but empty boxes.
      for (final weight in ['Regular', 'Medium', 'SemiBold']) {
        final face = File('assets/fonts/NotoNaskhArabic-$weight.ttf');
        expect(face.existsSync(), isTrue, reason: '$weight is missing');
        expect(face.lengthSync(), greaterThan(100000));
      }
    });

    test('and is named behind every style in the token file', () {
      final tokens = File('lib/theme/tokens.dart').readAsStringSync();
      final named = 'fontFamily: font'.allMatches(tokens).length;
      final backed = 'fontFamilyFallback: urduFaces'.allMatches(tokens).length;
      expect(named, greaterThan(10));
      expect(backed, named, reason: 'a style with no Urdu behind it');
    });

    test('and is declared in the pubspec under the name the styles use', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('family: NotoNaskhArabic'));
      for (final weight in ['Regular', 'Medium', 'SemiBold']) {
        expect(pubspec, contains('NotoNaskhArabic-$weight.ttf'));
      }
    });
  });
}
