import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';

/// An advance is a debt, and a debt does not expire.
///
/// It used to come off the wage of the month it was drawn in, all of it,
/// with nothing said. Sixteen thousand against a twenty-four thousand wage
/// handed a man eight thousand to live on for a month he had not agreed to
/// live on eight thousand. And an advance bigger than the wage was worse
/// than unfair: the next month's window did not reach back to it, so the
/// part that could not be recovered fell quietly off the books in the
/// farm's favour, against a man who had already spent it.
///
/// So the wage says what it took — and what it did not take is still owed
/// and still findable. These are the sums behind that: what is left after
/// each wage, what an old entry is assumed to have taken, and the one case
/// the farm actually has in front of it.

var _n = 0;

Txn _adv(num amount, {int day = 15, String who = 'Gul Din', DateTime? gone}) =>
    Txn(
      id: 'a${_n++}',
      date: DateTime(2026, 10, day),
      monthId: '2026-10',
      type: TxnType.expense,
      party: who,
      category: salaryAdvanceCategory,
      amount: amount,
      paid: true,
      paidOnCreate: true,
      paidSoFar: amount,
      note: '',
      createdBy: 'u1',
      createdAt: DateTime(2026, 10, day),
      deletedAt: gone,
    );

Txn _wage(
  num amount, {
  required int month,
  int day = 31,
  num? cut,
  String who = 'Gul Din',
  DateTime? gone,
}) => Txn(
  id: 'w${_n++}',
  date: DateTime(2026, month, day),
  monthId: '2026-${month.toString().padLeft(2, '0')}',
  type: TxnType.expense,
  party: who,
  category: salariesCategory,
  amount: amount,
  paid: true,
  paidOnCreate: true,
  paidSoFar: amount,
  note: '',
  createdBy: 'u1',
  createdAt: DateTime(2026, month, day),
  advanceCut: cut,
  deletedAt: gone,
);

void main() {
  group('what is still owed', () {
    test('an advance with no wage against it is owed whole', () {
      expect(advanceOwed([_adv(16000)], who: 'Gul Din'), 16000);
    });

    test('a wage that took part of it leaves the rest owed', () {
      final led = [_adv(16000), _wage(16000, month: 10, cut: 8000)];
      expect(advanceOwed(led, who: 'Gul Din'), 8000);
    });

    test('and the next wage finds that rest, a month later', () {
      // The thing the old rule could not do at all: November's window
      // did not reach back to an advance drawn in October, so what was
      // left of it simply stopped existing.
      final led = [
        _adv(16000),
        _wage(16000, month: 10, cut: 8000),
        _wage(24000, month: 11, cut: 0),
      ];
      expect(advanceOwed(led, who: 'Gul Din'), 8000);
    });

    test('a wage that took all of it leaves nothing', () {
      final led = [_adv(16000), _wage(8000, month: 10, cut: 16000)];
      expect(advanceOwed(led, who: 'Gul Din'), 0);
    });

    test('and nothing owed never reads as money the other way', () {
      final led = [_adv(5000), _wage(19000, month: 10, cut: 9000)];
      expect(advanceOwed(led, who: 'Gul Din'), 0);
    });

    test('two advances and one part payment add up as one debt', () {
      final led = [
        _adv(10000, day: 8),
        _adv(6000, day: 20),
        _wage(21000, month: 10, cut: 3000),
      ];
      expect(advanceOwed(led, who: 'Gul Din'), 13000);
    });
  });

  group('whose debt it is', () {
    test('one man\'s advance is not another man\'s', () {
      final led = [_adv(16000), _adv(4000, who: 'Jalbani')];
      expect(advanceOwed(led, who: 'Gul Din'), 16000);
      expect(advanceOwed(led, who: 'Jalbani'), 4000);
    });

    test('and one spelling of a name is one man', () {
      final led = [_adv(16000, who: 'gul din')];
      expect(advanceOwed(led, who: 'Gul Din'), 16000);
    });
  });

  group('an entry taken off the books', () {
    test('a deleted advance is not owed', () {
      final led = [_adv(16000, gone: DateTime(2026, 10, 16))];
      expect(advanceOwed(led, who: 'Gul Din'), 0);
    });

    test('and a deleted wage gives the debt back', () {
      // Undoing the wage has to undo what it recovered, or the farm keeps
      // a deduction it has just taken off the books.
      final led = [
        _adv(16000),
        _wage(16000, month: 10, cut: 8000, gone: DateTime(2026, 11, 1)),
      ];
      expect(advanceOwed(led, who: 'Gul Din'), 16000);
    });

    test('and the wage being corrected is left out of its own sum', () {
      // Opening a saved wage to change it must show the debt as it stood
      // before that wage was written, not after.
      final wage = _wage(16000, month: 10, cut: 8000);
      final led = [_adv(16000), wage];
      expect(advanceOwed(led, who: 'Gul Din', ignoring: wage.id), 16000);
    });
  });

  group('wages written before any of this', () {
    test('an old wage is taken to have swallowed its own month', () {
      // No advanceCut on it at all. The old form deducted every advance
      // of the month it was paying for, so that is what it did.
      final led = [_adv(16000), _wage(8000, month: 10)];
      expect(advanceOwed(led, who: 'Gul Din'), 0);
    });

    test('and one paid in the first days of the next month too', () {
      // Paying on the 3rd of November is October's wage — the same guess
      // the form itself makes.
      final led = [_adv(16000), _wage(8000, month: 11, day: 3)];
      expect(advanceOwed(led, who: 'Gul Din'), 0);
    });

    test('but an old wage does not swallow a later advance', () {
      final led = [
        _wage(24000, month: 10, day: 20),
        _adv(16000, day: 25),
        _wage(24000, month: 11, day: 30, cut: 0),
      ];
      expect(advanceOwed(led, who: 'Gul Din'), 16000);
    });
  });

  group('the farm\'s own case', () {
    // Gul Din is on 24,000 and has drawn 16,000. Paying him in full would
    // leave him 8,000 for the month, which is not what was agreed — so
    // 6,000 comes off now and the rest waits.
    final man = Employee(
      id: 'e1',
      name: 'Gul Din',
      basic: 24000,
      joinedOn: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
    );
    final oct = DateTime(2026, 10, 1);
    final octEnd = DateTime(2026, 10, 31);

    test('taking part of it hands him the rest of his wage', () {
      expect(wageToHand(who: man, from: oct, to: octEnd, drawn: 6000), 18000);
    });

    test('and what was left stands against the next wage', () {
      final led = [_adv(16000), _wage(18000, month: 10, cut: 6000)];
      expect(advanceOwed(led, who: 'Gul Din'), 10000);
    });

    test('an advance larger than the wage is recovered across months', () {
      // 30,000 drawn against a 24,000 wage. The old rule handed him
      // nothing and lost the other 6,000; this one carries it.
      final led = <Txn>[_adv(30000)];
      expect(advanceOwed(led, who: 'Gul Din'), 30000);
      expect(wageToHand(who: man, from: oct, to: octEnd, drawn: 24000), 0);

      led.add(_wage(0, month: 10, cut: 24000));
      expect(advanceOwed(led, who: 'Gul Din'), 6000);
    });

    test('and taking none of it leaves the whole wage and the whole debt', () {
      final led = [_adv(16000), _wage(24000, month: 10, cut: 0)];
      expect(wageToHand(who: man, from: oct, to: octEnd), 24000);
      expect(advanceOwed(led, who: 'Gul Din'), 16000);
    });
  });
}
