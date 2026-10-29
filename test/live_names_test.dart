import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';

/// A name written down twice can be two things at once.
///
/// The register copies a mother's tag onto her calf the day he is written
/// down, and copies the calf's tag onto the birth line on her page. Both
/// copies were only ever rewritten when the link between the two animals
/// changed — so renaming an animal, or giving her a new tag, which the farm
/// does now that the numbers are its own to type, left the other's page
/// printing what she used to be called.
///
/// The farm found it the way these are always found: one buffalo under two
/// names, in the one register it goes to to settle which animal is which.
///
/// The rule is the same both ways and it is the rule everywhere else in
/// these books — read the figure off the record that owns it. The stored
/// copy stays, and is the answer only for an animal no longer in the
/// register at all: she was somebody, and "Out of nobody" is worse than an
/// old name.

Animal _a({
  required String id,
  required String tag,
  String name = '',
  String? motherId,
  String? motherTag,
}) => Animal(
  id: id,
  tag: tag,
  name: name,
  species: Species.buffalo,
  sex: Sex.female,
  status: AnimalStatus.onFarm,
  photoUrl: '',
  thumb: '',
  dailyLitres: 0,
  motherId: motherId,
  motherTag: motherTag,
  createdAt: DateTime(2026, 10, 1),
);

/// The two lookups, written the way FarmStore writes them.
String? _motherNameOf(Animal calf, List<Animal> herd) {
  final live = herd.where((a) => a.id == calf.motherId).firstOrNull;
  return live?.label ?? calf.motherTag;
}

String? _calfNameOf(String? calfId, String? calfTag, List<Animal> herd) {
  if (calfId == null) return calfTag;
  return herd.where((a) => a.id == calfId).firstOrNull?.label ?? calfTag;
}

void main() {
  group('a calf names his mother off her own record', () {
    test('renaming her changes what his page says', () {
      final calf = _a(
        id: 'c1',
        tag: '24-07',
        motherId: 'm1',
        motherTag: '21-02',
      );
      // She was 21-02 the day he was registered and is 21-02 Kaali now.
      final herd = [_a(id: 'm1', tag: '21-02', name: 'Kaali'), calf];

      expect(_motherNameOf(calf, herd), '21-02 Kaali');
      expect(calf.motherTag, '21-02', reason: 'the copy is left alone');
    });

    test('and so does giving her a new tag', () {
      final calf = _a(
        id: 'c1',
        tag: '24-07',
        motherId: 'm1',
        motherTag: '21-02',
      );
      final herd = [_a(id: 'm1', tag: 'B-14'), calf];

      expect(_motherNameOf(calf, herd), 'B-14');
    });

    test('a mother no longer in the register keeps her old name', () {
      // Sold two years ago and off the list. The copy is all there is, and
      // it is better than saying he came out of nobody.
      final calf = _a(
        id: 'c1',
        tag: '24-07',
        motherId: 'm1',
        motherTag: '21-02',
      );
      expect(_motherNameOf(calf, [calf]), '21-02');
    });

    test('a calf out of nobody says nothing either way', () {
      expect(_motherNameOf(_a(id: 'c1', tag: '24-07'), const []), isNull);
    });
  });

  group('and her page names the calf off his', () {
    test('renaming him changes the birth line on her page', () {
      // Her page said "Calf 24-07" long after he had become 24-07 Noori.
      final herd = [_a(id: 'c1', tag: '24-07', name: 'Noori')];
      expect(_calfNameOf('c1', '24-07', herd), '24-07 Noori');
    });

    test('a calf gone from the register keeps the name he was born under', () {
      expect(_calfNameOf('c1', '24-07', const []), '24-07');
    });

    test('an event about no calf at all names none', () {
      expect(_calfNameOf(null, null, const []), isNull);
    });
  });
}
