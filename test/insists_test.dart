import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';

/// What an entry has to say before it can be saved, and who decides.
///
/// A question the app answers for somebody is a question nobody reads.
/// "Paid now" sat there already picked, so an entry that was really on
/// credit went in as cash whenever nobody looked at the toggle — and the one
/// person who would look is the one who already knew.
///
/// Which of them matter is the master's call rather than the app's, so they
/// live in his settings. The important half is what happens when the record
/// says nothing at all: a farm running on a settings document written before
/// any of this existed must not quietly find its books loosened.
void main() {
  group('what an entry must say', () {
    test('a record that says nothing insists on all of them', () {
      // Silence is not permission. Every farm already running keeps the
      // stricter behaviour until somebody deliberately turns one off.
      expect(Insists.read(null).on, MustSay.values.toSet());
      expect(Insists.read('nonsense').on, MustSay.values.toSet());
      expect(
        Insists.read(const <String, dynamic>{}).on,
        MustSay.values.toSet(),
      );
    });

    test('only an explicit no turns one off', () {
      final some = Insists.read(const {'askPaid': false});
      expect(some.paid, isFalse);
      expect(some.shift, isTrue);
      expect(some.handler, isTrue);
    });

    test('an explicit yes is a yes', () {
      final all = Insists.read(const {
        'askPaid': true,
        'askShift': true,
        'askHandler': true,
      });
      expect(all.on, MustSay.values.toSet());
    });

    test('anything other than false is a yes', () {
      // A half-written record, a string where a bool belongs, a null left by
      // a merge. None of those is somebody saying no.
      for (final v in [true, null, 0, 1, 'false', '']) {
        expect(
          Insists.read({'askPaid': v}).paid,
          isTrue,
          reason: 'askPaid: $v',
        );
      }
    });

    test('all three can be turned off, and then none is insisted on', () {
      final none = Insists.read(const {
        'askPaid': false,
        'askShift': false,
        'askHandler': false,
      });
      expect(none.on, isEmpty);
      expect(none.paid, isFalse);
      expect(none.shift, isFalse);
      expect(none.handler, isFalse);
    });

    test('each one has a name the master can read on the switch', () {
      for (final m in MustSay.values) {
        expect(m.label, isNotEmpty);
        expect(m.id, isNotEmpty);
      }
      expect(MustSay.paid.label, 'Paid now, or on the account');
    });

    test('the ids are the ones written to the settings record', () {
      // Renaming one of these silently turns that question off on every
      // farm already running, because the old key stops being read.
      expect(MustSay.shift.id, 'askShift');
      expect(MustSay.paid.id, 'askPaid');
      expect(MustSay.handler.id, 'askHandler');
    });

    test('and a farm with no settings record at all insists too', () {
      // The shipped default, which is what a brand new farm runs on.
      expect(Insists.all.on, MustSay.values.toSet());
    });
  });
}
