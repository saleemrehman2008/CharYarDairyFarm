import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';

/// How the four of them split what the farm makes — version 2.
///
/// The rule they agreed, and the reasoning that has to survive contact with a
/// bad month:
///
///   · The share comes from what came out of a pocket and nothing else.
///     Profit kept in the farm never joins it, so nobody's share drifts while
///     they are saving up for another buffalo.
///   · The master sets one percentage for all four. That is not a shortcut —
///     it is what keeps the first rule honest. Everybody holds back the same
///     proportion, so nobody ends up with more of their money working in the
///     farm than their share of it reflects.
///   · A loss is split the way a profit is. A bad month that left four
///     accounts untouched would be a month the books had paid for out of
///     somebody's capital without saying whose.
///   · And if the losses run past what has been earned, the figure goes below
///     zero and stays visible. Asked directly, Saleem was plain: manfi
///     dikhao, chupana nahi hai.

Partner _p(String id, String name, num invested, {num held = 0}) => Partner(
  id: id,
  userId: 'u$id',
  name: name,
  invested: invested,
  profitHeld: held,
  withdrawn: 0,
  createdAt: DateTime(2026, 8, 1),
);

/// The four of them, with the money they have actually put in.
List<Partner> _four({num saleem = 1000000, num held = 0}) => [
  _p('p0', 'Ghulam Ali', 2000000, held: held),
  _p('p1', 'RAFIQUE AHMED', 1500000, held: held),
  _p('p2', 'Asif Soomro', 1500000, held: held),
  _p('p3', 'Saleem Rehman', saleem, held: held),
];

void main() {
  group('the share comes from pockets alone', () {
    test('it is what each of them put in, over the whole', () {
      final r = ratiosOf(_four());
      expect(r['p0'], closeTo(1 / 3, 0.0001));
      expect(r['p1'], closeTo(0.25, 0.0001));
      expect(r['p2'], closeTo(0.25, 0.0001));
      expect(r['p3'], closeTo(1 / 6, 0.0001));
    });

    test('profit kept in the farm does not move it', () {
      // Version 1's whole difficulty. Four lakh held each, and not a
      // percentage point moves — which is the point of the change.
      final before = ratiosOf(_four());
      final after = ratiosOf(_four(held: 400000));
      for (final id in before.keys) {
        expect(after[id], closeTo(before[id]!, 0.000001));
      }
    });

    test('even when they hold different amounts', () {
      // It cannot happen while one percentage is set for all four, but the
      // ratio must not depend on that being true.
      final odd = [
        _p('p0', 'Ghulam Ali', 2000000, held: 900000),
        _p('p1', 'RAFIQUE AHMED', 1500000),
        _p('p2', 'Asif Soomro', 1500000, held: 40000),
        _p('p3', 'Saleem Rehman', 1000000),
      ];
      expect(ratiosOf(odd)['p0'], closeTo(1 / 3, 0.0001));
    });

    test('it moves the moment somebody puts more money in', () {
      // Saleem adds five lakh: from a sixth to just over a fifth, and the
      // other three give up the difference between them.
      final after = ratiosOf(_four(saleem: 1500000));
      expect(after['p3'], closeTo(1500000 / 6500000, 0.0001));
      expect(after['p0'], closeTo(2000000 / 6500000, 0.0001));
      expect(after.values.fold<double>(0, (a, b) => a + b), closeTo(1, 1e-9));
    });

    test('a farm where nobody has put anything in splits it evenly', () {
      final r = ratiosOf([_p('a', 'A', 0), _p('b', 'B', 0)]);
      expect(r['a'], 0.5);
      expect(r['b'], 0.5);
    });
  });

  group('cutting up a month', () {
    test('the slices add up to the profit, to the rupee', () {
      final shares = shareOut(partners: _four(), profit: 444000);
      expect(shares.fold<num>(0, (a, s) => a + s.share), 444000);
      expect(shares.firstWhere((s) => s.partnerId == 'p0').share, 148000);
      expect(shares.firstWhere((s) => s.partnerId == 'p3').share, 74000);
    });

    test('an odd rupee is not lost', () {
      final shares = shareOut(partners: _four(), profit: 100);
      expect(shares.fold<num>(0, (a, s) => a + s.share), 100);
    });

    test('a loss is cut up the same way, and comes back negative', () {
      final shares = shareOut(partners: _four(), profit: -200000);
      expect(shares.fold<num>(0, (a, s) => a + s.share), -200000);
      expect(shares.firstWhere((s) => s.partnerId == 'p0').share, -66667);
      expect(shares.firstWhere((s) => s.partnerId == 'p3').share, -33333);
      expect(shares.every((s) => s.isLoss), isTrue);
    });

    test('a month that made nothing gives everybody nothing', () {
      final shares = shareOut(partners: _four(), profit: 0);
      expect(shares.every((s) => s.share == 0), isTrue);
    });

    test('a farm with no co-founders yet does not fall over', () {
      expect(shareOut(partners: const [], profit: 444000), isEmpty);
    });
  });

  group('the percentage the master sets', () {
    final shares = shareOut(partners: _four(), profit: 444000);

    test('nothing out means nothing out, and it all stays in', () {
      final handed = handOut(shares, 0);
      expect(handed.every((s) => s.taken == 0), isTrue);
      expect(handed.fold<num>(0, (a, s) => a + s.held), 444000);
    });

    test('half out is half out, each of them', () {
      final handed = handOut(shares, 50);
      expect(handed.firstWhere((s) => s.partnerId == 'p0').taken, 74000);
      expect(handed.firstWhere((s) => s.partnerId == 'p0').held, 74000);
      expect(handed.firstWhere((s) => s.partnerId == 'p3').taken, 37000);
    });

    test('all of it out leaves nothing in', () {
      final handed = handOut(shares, 100);
      expect(handed.fold<num>(0, (a, s) => a + s.taken), 444000);
      expect(handed.every((s) => s.held == 0), isTrue);
    });

    test('what goes out and what stays in always make the slice', () {
      for (final pct in [0, 17, 33, 50, 99, 100]) {
        for (final s in handOut(shares, pct)) {
          expect(s.taken + s.held, s.share, reason: 'at $pct%');
        }
      }
    });

    test('a loss hands out nothing, whatever the percentage says', () {
      final bad = shareOut(partners: _four(), profit: -200000);
      final handed = handOut(bad, 100);
      expect(handed.every((s) => s.taken == 0), isTrue);
      // The whole loss lands in the profit accounts, where it belongs.
      expect(handed.fold<num>(0, (a, s) => a + s.held), -200000);
    });

    test('a percentage outside its senses is brought back inside', () {
      expect(handOut(shares, 300).fold<num>(0, (a, s) => a + s.taken), 444000);
      expect(handOut(shares, -50).fold<num>(0, (a, s) => a + s.taken), 0);
    });
  });

  group('a year of keeping it all in', () {
    test("nobody's share of the farm has moved by the end of it", () {
      // Twelve months at nothing out. Their profit accounts fill up; the
      // ratio they are worked out from does not budge, which is the whole
      // reason the four of them asked for this.
      var four = _four();
      final before = ratiosOf(four);

      for (var month = 0; month < 12; month++) {
        final handed = handOut(shareOut(partners: four, profit: 444000), 0);
        four = [
          for (final p in four)
            _p(
              p.id,
              p.name,
              p.invested,
              held:
                  p.profitHeld +
                  handed.firstWhere((s) => s.partnerId == p.id).held,
            ),
        ];
      }

      final after = ratiosOf(four);
      for (final id in before.keys) {
        expect(after[id], closeTo(before[id]!, 1e-9));
      }
      expect(four.firstWhere((p) => p.id == 'p0').profitHeld, 148000 * 12);
      expect(
        four.fold<num>(0, (a, p) => a + p.profitHeld),
        444000 * 12,
        reason: 'every rupee the farm made is in somebody s name',
      );
    });

    test('what they own is their own money plus what they have kept', () {
      final him = _p('p0', 'Ghulam Ali', 2000000, held: 1776000);
      expect(him.inTheFarm, 3776000);
      expect(ratiosOf([him])['p0'], 1.0, reason: 'the ratio ignores the rest');
    });
  });

  group('a bad month, and a run of them', () {
    test('the loss comes off what they have kept', () {
      final held = 500000;
      final bad = handOut(shareOut(partners: _four(), profit: -200000), 100);
      final after = held + bad.first.held;
      expect(bad.first.held, -66667);
      expect(after, 433333);
    });

    test('losses past what was earned go below zero, and stay there', () {
      // Eight lakh lost against three lakh earned. Ghulam Ali's third of the
      // difference is a real hole in what he put in, and the figure says so
      // rather than sitting at nothing and waiting to surprise him.
      var held = 0;
      for (final profit in [300000, -800000]) {
        final handed = handOut(shareOut(partners: _four(), profit: profit), 0);
        held += handed.firstWhere((s) => s.partnerId == 'p0').held.toInt();
      }
      expect(held, lessThan(0));
      expect(held, 100000 - 266667);
    });

    test('a loss month never hands anybody cash', () {
      final handed = handOut(shareOut(partners: _four(), profit: -1), 100);
      expect(handed.every((s) => s.taken == 0), isTrue);
    });
  });
}
