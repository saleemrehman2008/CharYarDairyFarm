import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/screens/master/animal_screen.dart';

/// Following a cow to her calf and back again should not build a pile.
///
/// The register cross-links both ways: a mother's page lists her calves and
/// a calf's page names his mother. Follow those links and you are walking a
/// circle, and a circle where every step is a new page is how the farm ended
/// up pressing Back five times to reach its home screen — through pages it
/// had already read, one of them the same cow twice.
///
/// So a page already open underneath is returned to. These are the sums that
/// decide how far back that is: [stepsBackTo] counts this page and everything
/// standing between it and the one being asked for.
void main() {
  group('how far back a link goes', () {
    test('a cow not open below is somewhere new', () {
      expect(stepsBackTo('calf-2', const ['cow-1']), 0);
      expect(stepsBackTo('cow-1', const []), 0);
    });

    test('the page straight underneath is one step', () {
      // Cow → her calf. From the calf, tapping his mother is one Back.
      expect(stepsBackTo('cow-1', const ['cow-1']), 1);
    });

    test('and a page further down is as many steps as it is deep', () {
      // Cow → calf → the calf's mother, who is that same cow. Two pages
      // come off, not a third one added.
      expect(stepsBackTo('cow-1', const ['cow-1', 'calf-2']), 2);
      expect(stepsBackTo('calf-2', const ['cow-1', 'calf-2']), 1);
    });

    test('a long walk still lands on the first time it was opened', () {
      // Four pages deep and the link points at the floor of it.
      const trail = ['cow-1', 'calf-2', 'cow-3', 'calf-4'];
      expect(stepsBackTo('cow-1', trail), 4);
      expect(stepsBackTo('calf-4', trail), 1);
    });

    test('a cow that appears twice goes back to the first of them', () {
      // It cannot happen while the trail is only ever added to by pages
      // that were not already in it — and if it ever does, the answer is
      // the one furthest down, because every page above it is coming off.
      expect(stepsBackTo('cow-1', const ['cow-1', 'calf-2', 'cow-1']), 3);
    });
  });
}
