import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';

/// Money in the farm and no hand in running it.
///
/// He has put capital in and takes his share of the profit like the rest of
/// them, and he wants to be able to look: what came in this month, what went
/// out, what the cattle are doing, where his own account stands. He enters
/// nothing, corrects nothing and approves nothing — the master and whoever
/// keeps the cash do all of it in his name.
///
/// Reading everything and writing nothing is not a courtesy here, it is the
/// point. The books are open to the people whose money is in them, and a man
/// who cannot change a figure can never be suspected of having changed one.
void main() {
  group('a silent investor', () {
    test('reads the books like the rest of them', () {
      expect(Role.silent.seesTheBooks, isTrue);
      expect(Role.master.seesTheBooks, isTrue);
      expect(Role.investor.seesTheBooks, isTrue);
    });

    test('and writes nothing at all', () {
      expect(Role.silent.readOnly, isTrue);
      expect(Role.master.readOnly, isFalse);
      expect(Role.investor.readOnly, isFalse);
    });

    test('is not a partner, which is what every write asks', () {
      // The rules ask isPartner() on every write there is. This is the same
      // question in Dart, and he fails it.
      expect(Role.silent.isPartner, isFalse);
    });

    test('does not go out on the round either', () {
      expect(Role.silent.canDeliver, isFalse);
    });

    test('is read back from the user record by that name', () {
      expect(Role.parse('silent'), Role.silent);
    });

    test('and anything unknown is still only a customer', () {
      // The safe end of the scale. A typo in a role must never open a book.
      expect(Role.parse('silnet'), Role.customer);
      expect(Role.parse(''), Role.customer);
      expect(Role.parse(null), Role.customer);
    });

    test('has a name the master can read on the grant screen', () {
      expect(Role.silent.label, 'Silent investor');
      expect(Role.silent.what, 'Looks at everything. Changes nothing.');
    });

    test('nobody else reads the books without being one of them', () {
      // Delivery staff take money at the door and see none of the books;
      // a customer sees their own khaata and nothing else.
      expect(Role.staff.seesTheBooks, isFalse);
      expect(Role.customer.seesTheBooks, isFalse);
    });

    test('and nobody else is read-only by accident', () {
      // Staff write plenty — the round, the money at the door. Read-only is
      // one role and one role only.
      for (final r in Role.values) {
        expect(r.readOnly, r == Role.silent, reason: r.name);
      }
    });
  });
}
