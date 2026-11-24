// Where a man stands if he walks off the farm today.
//
// Nobody joins on the first. A gawala taken on on the 20th of October is
// owed to the 19th of November, and the farm pays him along the way as the
// days build up. When he says he is going, two figures decide everything
// and neither of them was anywhere in the app: what is left to hand him,
// or — if he has drawn ahead of his work — how many more days he has to
// stay before the two sides meet.

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';
import 'package:flutter_test/flutter_test.dart';

var _n = 0;

Employee _gawala({
  num basic = 24000,
  num allowance = 0,
  DateTime? joined,
  DateTime? left,
}) => Employee(
  id: 'g${_n++}',
  name: 'Rafique Gawala',
  basic: basic,
  allowance: allowance,
  joinedOn: joined ?? DateTime(2026, 10, 20),
  leftOn: left,
  createdAt: DateTime(2026, 10, 20),
);

Txn _wage(num amount, {int month = 11, int day = 10}) => Txn(
  id: 's${_n++}',
  date: DateTime(2026, month, day),
  monthId: '2026-${month.toString().padLeft(2, '0')}',
  type: TxnType.expense,
  party: 'Rafique Gawala',
  category: salariesCategory,
  amount: amount,
  paid: true,
  paidOnCreate: true,
  paidSoFar: amount,
  note: '',
  createdBy: 'u1',
  createdAt: DateTime(2026, month, day),
);

Txn _advance(num amount, {int month = 11, int day = 5}) => Txn(
  id: 'a${_n++}',
  date: DateTime(2026, month, day),
  monthId: '2026-${month.toString().padLeft(2, '0')}',
  type: TxnType.payment,
  party: 'Rafique Gawala',
  category: salaryAdvanceCategory,
  amount: amount,
  paid: true,
  paidOnCreate: true,
  paidSoFar: amount,
  note: '',
  createdBy: 'u1',
  createdAt: DateTime(2026, month, day),
);

/// A man's month runs from the day he started.
///
/// The farm settled this looking at its own gawala: taken on the 20th of
/// October, his month is up on the 19th of November. Measured against the
/// calendar that run is thirty-one separate days and pays thirty-one
/// thousand — which breaks the rule the farm had already settled, that a
/// whole month is a whole wage whether it holds 28 days or 31.
void _hisOwnMonth() {
  Employee man({int joined = 20, int month = 10, DateTime? left}) => Employee(
    id: 'c${_n++}',
    name: 'Rafique Gawala',
    basic: 24000,
    allowance: 6000,
    joinedOn: DateTime(2026, month, joined),
    leftOn: left,
    createdAt: DateTime(2026, month, joined),
  );

  group('a month of his own', () {
    test('20 October to 19 November is one whole month, not 31 days', () {
      // The heart of it. Thirty-one days of the calendar; one wage.
      expect(man().earnedTo(DateTime(2026, 11, 19)), 30000);
    });

    test('and a day short of it is counted a day at a time', () {
      // Thirty days from the 20th of October to the 18th of November.
      expect(man().earnedTo(DateTime(2026, 11, 18)), 30000);
      // Twenty-nine days, which is 29,000 and not a whole wage.
      expect(man().earnedTo(DateTime(2026, 11, 17)), 29000);
    });

    test('two whole months and five days over', () {
      // 20 Oct–19 Nov, 20 Nov–19 Dec, then 20–24 December.
      expect(man().earnedTo(DateTime(2026, 12, 24)), 65000);
    });

    test('and the farm\'s own question: he leaves on the 25th', () {
      // Two whole months of his, and six days.
      expect(man().earnedTo(DateTime(2026, 12, 25)), 66000);
    });
  });

  group('a man taken on the first', () {
    test('keeps the calendar month, and nothing about him changes', () {
      final first = man(joined: 1, month: 11);
      expect(first.earnedTo(DateTime(2026, 11, 30)), 30000);
      expect(first.earnedTo(DateTime(2026, 12, 31)), 60000);
    });

    test('and February pays him a whole wage like any other month', () {
      final first = Employee(
        id: 'f1',
        name: 'Gul Din',
        basic: 30000,
        joinedOn: DateTime(2026, 2, 1),
        createdAt: DateTime(2026, 2, 1),
      );
      expect(first.earnedTo(DateTime(2026, 2, 28)), 30000);
    });
  });

  group('the awkward days of the month', () {
    test('a man taken on the 31st begins his next on the 28th', () {
      // There is no 31st of February to begin it on.
      final late = Employee(
        id: 'l1',
        name: 'Chhotu',
        basic: 30000,
        joinedOn: DateTime(2026, 1, 31),
        createdAt: DateTime(2026, 1, 31),
      );
      // 31 January to 27 February is one month of his.
      expect(late.earnedTo(DateTime(2026, 2, 27)), 30000);
    });
  });

  group('the run his wage for a month covers', () {
    test('is named by the month it ends in', () {
      final c = man().cycleEndingIn(DateTime(2026, 11, 15));
      expect(c.from, DateTime(2026, 10, 20));
      expect(c.to, DateTime(2026, 11, 19));
    });

    test('and for a man taken on the first it is the calendar month', () {
      final c = man(joined: 1, month: 11).cycleEndingIn(DateTime(2026, 11, 9));
      expect(c.from, DateTime(2026, 11, 1));
      expect(c.to, DateTime(2026, 11, 30));
    });
  });

  group('a man who has gone', () {
    test('earns nothing past his last day', () {
      final gone = man(left: DateTime(2026, 11, 5));
      expect(
        gone.earnedTo(DateTime(2026, 12, 31)),
        gone.earnedTo(DateTime(2026, 11, 5)),
      );
      // 20 October to 5 November is seventeen days, short of a month.
      expect(gone.earnedTo(DateTime(2026, 12, 31)), 17000);
    });
  });
}

void main() {
  _hisOwnMonth();

  group('a man taken on partway through a month', () {
    // 20 October, so his month runs to the 19th of November.
    final man = _gawala();

    test('is owed for the days he was here, at the flat day', () {
      // Thirty days between 20 October and 18 November, and neither month
      // was worked right through — so both are counted a day at a time, at
      // a thirtieth of the wage each. A whole month would have paid the
      // whole wage whatever its length; a part of one does not.
      final s = settleUp(const [], man, upTo: DateTime(2026, 11, 18));
      expect(s.daysWorked, 30);
      expect(s.aDay, closeTo(800, 0.01));
      expect(s.earned, 30 * 800);
    });

    test('and both ends of the run count as worked', () {
      final s = settleUp(const [], man, upTo: DateTime(2026, 10, 20));
      expect(s.daysWorked, 1);
    });
  });

  group('when the farm still owes him', () {
    final man = _gawala();
    final s = settleUp([_wage(10000)], man, upTo: DateTime(2026, 11, 18));

    test('the net is what is left to hand over', () {
      expect(s.farmOwes, isTrue);
      expect(s.toPay, closeTo(s.earned - 10000, 1));
    });

    test('and there are no days left to work off', () {
      expect(s.daysToSquare, 0);
      expect(s.over, 0);
    });
  });

  group('when he has drawn ahead of his work', () {
    // The farm's own case: paid along the way, more than the days have
    // earned, and now he says he is going.
    final man = _gawala();
    final s = settleUp([_wage(30000)], man, upTo: DateTime(2026, 11, 18));

    test('nothing is owed to him', () {
      expect(s.heOwes, isTrue);
      expect(s.toPay, 0);
    });

    test('and the sheet says by how much', () {
      expect(s.over, closeTo(30000 - s.earned, 1));
    });

    test('and how many more days square it', () {
      // 24,000 over thirty is eight hundred a day, in every month.
      expect(s.aDay, closeTo(800, 0.01));
      expect(s.daysToSquare, (s.over / 800).ceil());
    });

    test('rounded up, because a part day squares nothing', () {
      // Told "four and a bit days", a man works four and still owes.
      expect(s.daysToSquare * s.aDay, greaterThanOrEqualTo(s.over));
    });

    test('and says the day it lands on', () {
      expect(
        s.squareOn,
        DateTime(2026, 11, 18).add(Duration(days: s.daysToSquare)),
      );
    });
  });

  group('an advance still standing', () {
    test('counts against him, because he has had the money', () {
      final man = _gawala();
      final plain = settleUp([_wage(10000)], man, upTo: DateTime(2026, 11, 18));
      final withAdvance = settleUp(
        [_wage(10000), _advance(5000)],
        man,
        upTo: DateTime(2026, 11, 18),
      );
      expect(withAdvance.advanceOwed, 5000);
      expect(withAdvance.net, closeTo(plain.net - 5000, 1));
    });
  });

  group('the allowance is part of what he earns', () {
    test('so a part month carries its share of it too', () {
      final withAllowance = _gawala(allowance: 6000);
      final s = settleUp(const [], withAllowance, upTo: DateTime(2026, 11, 18));
      final plain = settleUp(const [], _gawala(), upTo: DateTime(2026, 11, 18));
      expect(s.earned, greaterThan(plain.earned));
      expect(s.aDay, closeTo(30000 / 30, 0.01));
    });
  });

  group('a man who has already gone', () {
    test('is settled to his last day, not to today', () {
      final gone = _gawala(left: DateTime(2026, 11, 5));
      final s = settleUp(const [], gone, upTo: DateTime(2026, 11, 30));
      expect(s.upTo, DateTime(2026, 11, 5));
      // 20–31 October and 1–5 November is seventeen days.
      expect(s.daysWorked, 17);
    });
  });

  group('the day he started', () {
    test('asked before it, nothing is earned and nothing is owed', () {
      final man = _gawala();
      final s = settleUp(const [], man, upTo: DateTime(2026, 10, 1));
      expect(s.daysWorked, 0);
      expect(s.earned, 0);
    });
  });

  _theRealOne();

  group('square to the rupee', () {
    test('neither side owes the other', () {
      final man = _gawala();
      final earned = settleUp(
        const [],
        man,
        upTo: DateTime(2026, 11, 18),
      ).earned;
      final s = settleUp([_wage(earned)], man, upTo: DateTime(2026, 11, 18));
      expect(s.square, isTrue);
      expect(s.toPay, 0);
      expect(s.daysToSquare, 0);
    });
  });
}

// ---------------------------------------------------------------------------
// Gawalo Rafiq Jatt, as the books actually stand on 24 November 2026.
//
// The farm's own case, put in as a test so the figure on the screen can be
// checked against a figure nobody can quietly change. Taken on 20 October;
// 24,000 a month with 6,000 for the milk on top. One advance of 16,000 on
// 21 October, still standing. Wages of 24,000, 5,000 and 1,000 handed over
// on the 12th, 19th and 22nd of November.
void _theRealOne() {
  group('Gawalo Rafiq Jatt on 24 November', () {
    final man = Employee(
      id: 'rafiq',
      name: 'Gawalo Rafiq Jatt',
      basic: 24000,
      allowance: 6000,
      allowanceFor: 'milk',
      joinedOn: DateTime(2026, 10, 20),
      createdAt: DateTime(2026, 10, 20),
    );

    final ledger = [
      Txn(
        id: 'adv',
        date: DateTime(2026, 10, 21),
        monthId: '2026-10',
        type: TxnType.payment,
        party: 'Gawalo Rafiq Jatt',
        category: salaryAdvanceCategory,
        amount: 16000,
        paid: true,
        paidOnCreate: true,
        paidSoFar: 16000,
        note: '',
        createdBy: 'u1',
        createdAt: DateTime(2026, 10, 21),
      ),
      for (final (day, amount) in [(12, 24000), (19, 5000), (22, 1000)])
        Txn(
          id: 'w$day',
          date: DateTime(2026, 11, day),
          monthId: '2026-11',
          type: TxnType.expense,
          party: 'Gawalo Rafiq Jatt',
          category: salariesCategory,
          amount: amount,
          paid: true,
          paidOnCreate: true,
          paidSoFar: amount,
          note: '',
          createdBy: 'u1',
          createdAt: DateTime(2026, 11, day),
        ),
    ];

    final s = settleUp(ledger, man, upTo: DateTime(2026, 11, 24));

    test('he has worked 36 days', () {
      // 20–31 October is twelve, 1–24 November is twenty-four.
      expect(s.daysWorked, 36);
    });

    test('and earned Rs 35,000 — one month of his, and five days', () {
      // His month runs 20 October to 19 November, which is thirty-one
      // days of the calendar and one whole month of his: 30,000. Then
      // five days of the next, at a thousand each.
      expect(s.aDay, closeTo(1000, 0.01));
      expect(s.earned, 35000);
    });

    test('against Rs 30,000 of wages and Rs 16,000 still owed on advance', () {
      expect(s.paid, 30000);
      expect(s.advanceOwed, 16000);
    });

    test('so he has had Rs 11,000 more than he has worked for', () {
      // 30,000 of wages and 16,000 still owed on the advance is 46,000 in
      // his hands against 35,000 worked for.
      expect(s.heOwes, isTrue);
      expect(s.toPay, 0);
      expect(s.over, 11000);
    });

    test('and 11 more days would square it, on 5 December', () {
      expect(s.aDay, closeTo(1000, 0.01));
      expect(s.daysToSquare, 11);
      expect(s.squareOn, DateTime(2026, 12, 5));
    });
  });
}
