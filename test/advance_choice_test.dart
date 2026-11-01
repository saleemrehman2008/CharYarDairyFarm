import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';

/// How much of an advance comes off, and who decides.
///
/// The farm's answer is: whoever is paying him, that month, with the whole
/// of it offered and none of it forced. "Chahe is month hum zero hi kyun
/// na deduction karen to poora next month chala jaye" — so zero is a real
/// answer, every figure between is a real answer, and what is not taken
/// is not lost.
///
/// [advanceCarryTest] has the debt arithmetic. This is the choosing: what
/// a typed figure actually becomes, what it leaves behind, and the run of
/// months that follows from it.

var _n = 0;

Employee _man({num basic = 24000, num allowance = 0}) => Employee(
  id: 'e1',
  name: 'Gul Din',
  basic: basic,
  allowance: allowance,
  joinedOn: DateTime(2026, 1, 1),
  createdAt: DateTime(2026, 1, 1),
);

Txn _adv(num amount, {int month = 10, int day = 15}) => Txn(
  id: 'a${_n++}',
  date: DateTime(2026, month, day),
  monthId: '2026-${month.toString().padLeft(2, '0')}',
  type: TxnType.expense,
  party: 'Gul Din',
  category: salaryAdvanceCategory,
  amount: amount,
  paid: true,
  paidOnCreate: true,
  paidSoFar: amount,
  note: '',
  createdBy: 'u1',
  createdAt: DateTime(2026, month, day),
);

Txn _wage(num amount, {required int month, int day = 31, required num cut}) =>
    Txn(
      id: 'w${_n++}',
      date: DateTime(2026, month, day),
      monthId: '2026-${month.toString().padLeft(2, '0')}',
      type: TxnType.expense,
      party: 'Gul Din',
      category: salariesCategory,
      amount: amount,
      paid: true,
      paidOnCreate: true,
      paidSoFar: amount,
      note: '',
      createdBy: 'u1',
      createdAt: DateTime(2026, month, day),
      advanceCut: cut,
    );

DateTime _from(int month) => DateTime(2026, month, 1);
DateTime _to(int month) => DateTime(2026, month + 1, 0);

/// One payday, done the way the screen does it: work out what comes off,
/// then what is handed over, then write the entry.
({Txn wage, num took, num handed}) _payday(
  List<Txn> ledger,
  Employee who, {
  required int month,
  required num asked,
  int daysOff = 0,
}) {
  final wage = who.payForWindow(
    from: _from(month),
    to: _to(month),
    daysOff: daysOff,
  );
  final took = advanceComingOff(
    asked: asked,
    owed: advanceOwed(ledger, who: who.name),
    wage: wage,
  );
  final handed = wageToHand(
    who: who,
    from: _from(month),
    to: _to(month),
    daysOff: daysOff,
    drawn: took,
  );
  final entry = _wage(handed, month: month, cut: took);
  ledger.add(entry);
  return (wage: entry, took: took, handed: handed);
}

void main() {
  group('what a typed figure becomes', () {
    test('nothing typed takes nothing', () {
      expect(advanceComingOff(asked: 0, owed: 16000, wage: 24000), 0);
    });

    test('and a figure between is taken as it stands', () {
      expect(advanceComingOff(asked: 6000, owed: 16000, wage: 24000), 6000);
    });

    test('the whole of what he owes is taken when the wage can carry it', () {
      expect(advanceComingOff(asked: 16000, owed: 16000, wage: 24000), 16000);
    });

    test('more than he owes is held to what he owes', () {
      // Fifty thousand typed against a sixteen thousand advance would
      // have the farm recover money it never advanced, and under-pay a
      // man by the difference.
      expect(advanceComingOff(asked: 50000, owed: 16000, wage: 24000), 16000);
    });

    test('more than the wage can carry is held to the wage', () {
      // Thirty thousand owed against a twenty-four thousand wage. The
      // wage stops at nothing owing; the other six thousand waits.
      expect(advanceComingOff(asked: 30000, owed: 30000, wage: 24000), 24000);
    });

    test('a minus figure is not a payment to him', () {
      expect(advanceComingOff(asked: -5000, owed: 16000, wage: 24000), 0);
    });

    test('nothing owed takes nothing however much is typed', () {
      expect(advanceComingOff(asked: 9000, owed: 0, wage: 24000), 0);
    });

    test('and no wage to take it out of takes nothing', () {
      // A man on the list who worked no days of this window.
      expect(advanceComingOff(asked: 9000, owed: 16000, wage: 0), 0);
    });
  });

  group('zero this month, the whole of it next', () {
    test('taking nothing hands him his whole wage', () {
      final man = _man();
      final led = <Txn>[_adv(16000)];
      final oct = _payday(led, man, month: 10, asked: 0);

      expect(oct.took, 0);
      expect(oct.handed, 24000);
      expect(advanceOwed(led, who: 'Gul Din'), 16000);
    });

    test('and the next month is offered the whole of it', () {
      final man = _man();
      final led = <Txn>[_adv(16000)];
      _payday(led, man, month: 10, asked: 0);

      // What November's card would put in the box.
      final offered = advanceComingOff(
        asked: advanceOwed(led, who: 'Gul Din'),
        owed: advanceOwed(led, who: 'Gul Din'),
        wage: man.payForWindow(from: _from(11), to: _to(11)),
      );
      expect(offered, 16000);

      final nov = _payday(led, man, month: 11, asked: offered);
      expect(nov.took, 16000);
      expect(nov.handed, 8000);
      expect(advanceOwed(led, who: 'Gul Din'), 0);
    });

    test('and three months of taking nothing still owes the same', () {
      final man = _man();
      final led = <Txn>[_adv(16000)];
      for (final m in [10, 11, 12]) {
        final day = _payday(led, man, month: m, asked: 0);
        expect(day.handed, 24000);
      }
      expect(advanceOwed(led, who: 'Gul Din'), 16000);
    });
  });

  group('a little at a time', () {
    test('six thousand a month clears sixteen in three', () {
      final man = _man();
      final led = <Txn>[_adv(16000)];

      final oct = _payday(led, man, month: 10, asked: 6000);
      expect(oct.handed, 18000);
      expect(advanceOwed(led, who: 'Gul Din'), 10000);

      final nov = _payday(led, man, month: 11, asked: 6000);
      expect(nov.handed, 18000);
      expect(advanceOwed(led, who: 'Gul Din'), 4000);

      // The last one is smaller than the rest, and asking for six
      // thousand must not take six thousand.
      final dec = _payday(led, man, month: 12, asked: 6000);
      expect(dec.took, 4000);
      expect(dec.handed, 20000);
      expect(advanceOwed(led, who: 'Gul Din'), 0);
    });

    test('and a month in the middle may take nothing at all', () {
      final man = _man();
      final led = <Txn>[_adv(16000)];

      _payday(led, man, month: 10, asked: 6000);
      final nov = _payday(led, man, month: 11, asked: 0);
      expect(nov.handed, 24000);
      expect(advanceOwed(led, who: 'Gul Din'), 10000);

      _payday(led, man, month: 12, asked: 10000);
      expect(advanceOwed(led, who: 'Gul Din'), 0);
    });

    test('nothing is lost across the whole run', () {
      // Every rupee advanced is either recovered or still owed, which is
      // the one thing that has to hold however the months are played.
      final man = _man();
      final led = <Txn>[_adv(16000)];
      var took = 0 as num;
      for (final (m, asked) in [(10, 3000), (11, 0), (12, 9000)]) {
        took += _payday(led, man, month: m, asked: asked).took;
      }
      expect(took + advanceOwed(led, who: 'Gul Din'), 16000);
      expect(took, 12000);
    });
  });

  group('an advance bigger than the wage', () {
    test('thirty thousand against a twenty-four thousand month', () {
      // The case the old rule could not do at all: it took what it could
      // and the rest fell off the books in the farm's favour.
      final man = _man();
      final led = <Txn>[_adv(30000)];

      final oct = _payday(led, man, month: 10, asked: 30000);
      expect(oct.took, 24000);
      expect(oct.handed, 0);
      expect(advanceOwed(led, who: 'Gul Din'), 6000);

      final nov = _payday(led, man, month: 11, asked: 6000);
      expect(nov.handed, 18000);
      expect(advanceOwed(led, who: 'Gul Din'), 0);
    });

    test('and he may be left something to live on instead', () {
      final man = _man();
      final led = <Txn>[_adv(30000)];
      final oct = _payday(led, man, month: 10, asked: 10000);
      expect(oct.handed, 14000);
      expect(advanceOwed(led, who: 'Gul Din'), 20000);
    });
  });

  group('days off and part months', () {
    test('the deduction is held to the smaller wage, not the whole one', () {
      // Three days off a 31-day October takes the wage to 21,678. An
      // advance of 24,000 cannot all come off that.
      final man = _man();
      final led = <Txn>[_adv(24000)];
      final oct = _payday(led, man, month: 10, asked: 24000, daysOff: 3);

      expect(oct.handed, 0);
      expect(
        oct.took,
        man.payForWindow(from: _from(10), to: _to(10), daysOff: 3),
      );
      expect(advanceOwed(led, who: 'Gul Din'), 24000 - oct.took);
      expect(advanceOwed(led, who: 'Gul Din'), greaterThan(0));
    });

    test('and a man who worked no days of the month takes nothing off', () {
      final gone = Employee(
        id: 'e2',
        name: 'Gul Din',
        basic: 24000,
        joinedOn: DateTime(2026, 1, 1),
        leftOn: DateTime(2026, 9, 30),
        createdAt: DateTime(2026, 1, 1),
      );
      final led = <Txn>[_adv(16000)];
      final oct = _payday(led, gone, month: 10, asked: 16000);

      expect(oct.took, 0);
      expect(oct.handed, 0);
      expect(advanceOwed(led, who: 'Gul Din'), 16000);
    });
  });

  group('two payments in one month', () {
    test('the second can take what the first left', () {
      // A wage already on the books used to stop this, because the
      // deduction was worked out afresh from the month's advances every
      // time and a second entry would have taken it twice. It is written
      // on the entry now, so a second part-payment is safe.
      final man = _man();
      final led = <Txn>[_adv(16000)];

      _payday(led, man, month: 10, asked: 4000);
      expect(advanceOwed(led, who: 'Gul Din'), 12000);

      final rest = advanceComingOff(
        asked: 12000,
        owed: advanceOwed(led, who: 'Gul Din'),
        wage: man.payForWindow(from: _from(10), to: _to(10)),
      );
      expect(rest, 12000);
    });

    test('and never more than was advanced, however many entries', () {
      final man = _man();
      final led = <Txn>[_adv(16000)];
      _payday(led, man, month: 10, asked: 16000);
      _payday(led, man, month: 10, asked: 16000);
      expect(advanceOwed(led, who: 'Gul Din'), 0);
    });
  });

  group('an advance drawn after the wage was paid', () {
    test('stands against the next one', () {
      final man = _man();
      final led = <Txn>[];
      _payday(led, man, month: 10, asked: 0);
      led.add(_adv(5000, month: 11, day: 4));

      expect(advanceOwed(led, who: 'Gul Din'), 5000);
      final nov = _payday(led, man, month: 11, asked: 5000);
      expect(nov.handed, 19000);
    });
  });

  group('the figure on the card is the figure in the books', () {
    test('what the card shows coming off is what the entry records', () {
      // The sum used to be done in three places against three slightly
      // different wages. They agree by construction now, and this is the
      // test that says so.
      final man = _man(basic: 20000, allowance: 2000);
      final led = <Txn>[_adv(9000)];
      for (final asked in <num>[0, 1, 4500, 9000, 100000, -3]) {
        final wage = man.payForWindow(from: _from(10), to: _to(10));
        final owed = advanceOwed(led, who: 'Gul Din');
        final shown = advanceComingOff(asked: asked, owed: owed, wage: wage);
        final handed = wageToHand(
          who: man,
          from: _from(10),
          to: _to(10),
          drawn: shown,
        );
        expect(handed, wage - shown);
        expect(shown + (owed - shown), owed);
      }
    });
  });
}
