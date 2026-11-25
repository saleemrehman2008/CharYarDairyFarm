// Ten days at a time.
//
// The farm sells milk to a dairy every morning, so one name holds thirty
// entries a month and the column of days answers nothing. What the two of
// them settle on is the ten days — the 1st to the 10th, the 11th to the
// 20th, and the 21st to the end of the month — so each stretch has to
// carry its own total, and the three have to come to what the name comes
// to.

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';
import 'package:flutter_test/flutter_test.dart';

var _n = 0;

Txn _sale(
  int day, {
  num amount = 1000,
  int month = 11,
  int year = 2026,
  String who = 'Amir Dairy',
  String? takeId,
}) {
  final on = DateTime(year, month, day);
  return Txn(
    id: 'd${_n++}',
    date: on,
    monthId: '$year-${month.toString().padLeft(2, '0')}',
    type: TxnType.sale,
    party: who,
    category: 'Milk',
    amount: amount,
    paid: true,
    paidOnCreate: true,
    paidSoFar: amount,
    note: '',
    createdBy: 'u1',
    createdAt: on,
    takeId: takeId,
  );
}

/// A month of daily sales, newest first — the order the page reads them in.
List<Txn> _aMonth({int month = 11, int days = 30, num amount = 1000}) => [
  for (var d = days; d >= 1; d--) _sale(d, month: month, amount: amount),
];

num _total(Stretch s) => s.rows.fold<num>(0, (a, t) => a + t.amount);

void main() {
  group('a month of milk, read ten days at a time', () {
    final stretches = tenDayStretches(_aMonth());

    test('comes out as three stretches', () {
      expect(stretches.length, 3);
    });

    test('newest first, matching the list it came from', () {
      // The page reads newest first, so the 21st to the 30th is at the top.
      expect(stretches.map((s) => s.from.day).toList(), [21, 11, 1]);
      expect(stretches.map((s) => s.part).toList(), [2, 1, 0]);
    });

    test('the first is the 1st to the 10th, and holds ten days', () {
      final first = stretches.last;
      expect(first.from, DateTime(2026, 11, 1));
      expect(first.to, DateTime(2026, 11, 10));
      expect(first.rows.length, 10);
      expect(_total(first), 10000);
    });

    test('the second is the 11th to the 20th', () {
      final second = stretches[1];
      expect(second.from, DateTime(2026, 11, 11));
      expect(second.to, DateTime(2026, 11, 20));
      expect(second.rows.length, 10);
      expect(_total(second), 10000);
    });

    test('and the third runs to the last day of the month', () {
      final third = stretches.first;
      expect(third.from, DateTime(2026, 11, 21));
      expect(third.to, DateTime(2026, 11, 30));
      expect(third.rows.length, 10);
      expect(_total(third), 10000);
    });

    test('and nothing is lost between them', () {
      // The three heads add up to what the name's own line says. If they
      // ever did not, the page would be arguing with itself about money.
      expect(stretches.fold<num>(0, (a, s) => a + _total(s)), 30000);
      expect(stretches.fold<int>(0, (a, s) => a + s.rows.length), 30);
    });

    test('and each stretch keeps its days newest first', () {
      expect(stretches.first.rows.map((t) => t.date.day).toList(), [
        30,
        29,
        28,
        27,
        26,
        25,
        24,
        23,
        22,
        21,
      ]);
    });
  });

  group('the last stretch takes whatever the month leaves it', () {
    test('eleven days in a 31-day month', () {
      final s = tenDayStretches(_aMonth(month: 12, days: 31));
      expect(s.first.to, DateTime(2026, 12, 31));
      expect(s.first.rows.length, 11);
    });

    test('eight in February', () {
      final s = tenDayStretches(_aMonth(month: 2, days: 28));
      expect(s.first.to, DateTime(2026, 2, 28));
      expect(s.first.rows.length, 8);
    });

    test('nine in a leap February', () {
      final s = tenDayStretches([
        for (var d = 29; d >= 1; d--) _sale(d, month: 2, year: 2028),
      ]);
      expect(s.first.to, DateTime(2028, 2, 29));
      expect(s.first.rows.length, 9);
    });
  });

  group('an empty stretch is not a stretch', () {
    test('two days of trade give the two stretches they fell in', () {
      final s = tenDayStretches([_sale(25), _sale(4)]);
      expect(s.length, 2);
      expect(s.map((x) => x.part).toList(), [2, 0]);
    });

    test('and one day gives one', () {
      expect(tenDayStretches([_sale(14)]).length, 1);
    });

    test('and nothing at all gives nothing', () {
      expect(tenDayStretches(const []), isEmpty);
    });
  });

  group('the boundaries', () {
    test('the 10th is in the first stretch, the 11th in the second', () {
      final s = tenDayStretches([_sale(11), _sale(10)]);
      expect(s.last.rows.single.date.day, 10);
      expect(s.first.rows.single.date.day, 11);
    });

    test('the 20th is in the second, the 21st in the third', () {
      final s = tenDayStretches([_sale(21), _sale(20)]);
      expect(s.last.part, 1);
      expect(s.first.part, 2);
    });
  });

  group('two months', () {
    test('keep their stretches apart, newest month first', () {
      final s = tenDayStretches([_sale(5, month: 11), _sale(25, month: 10)]);
      expect(s.length, 2);
      expect(s.first.from, DateTime(2026, 11, 1));
      expect(s.last.from, DateTime(2026, 10, 21));
    });

    test('and the same ten days of different months never merge', () {
      final s = tenDayStretches([_sale(3, month: 11), _sale(3, month: 10)]);
      expect(s.length, 2);
      expect(s.every((x) => x.rows.length == 1), isTrue);
    });
  });

  group('one handful of money stays whole', () {
    // A payment that settled days on both sides of a boundary reaches the
    // page as slices. If the slices were split between two stretches, each
    // stretch would count the whole payment and the heads would add up to
    // more than the name owes.
    final take = [
      _sale(22, takeId: 't1', amount: 4000),
      _sale(19, takeId: 't1', amount: 3000),
      _sale(8, takeId: 't1', amount: 2000),
    ];

    test('every slice goes where the first one went', () {
      final s = tenDayStretches(take);
      expect(s.length, 1);
      expect(s.single.part, 2);
      expect(s.single.rows.length, 3);
    });

    test('and two separate payments are still two things', () {
      final s = tenDayStretches([
        _sale(22, takeId: 't1'),
        _sale(8, takeId: 't2'),
      ]);
      expect(s.length, 2);
    });

    test('while the days around it fall where their own dates say', () {
      final s = tenDayStretches([_sale(25), ...take, _sale(3)]);
      // The take's three slices sit in the 21st–30th with the 25th; only
      // the 3rd is in the first stretch.
      expect(s.length, 2);
      expect(s.first.rows.length, 4);
      expect(s.last.rows.single.date.day, 3);
    });
  });
}
