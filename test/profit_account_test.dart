import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/statement.dart';

/// A co-founder's profit account, on paper.
///
/// The third of the documents the farm prints, and the one the four of them
/// will read hardest. Their own money is not on it: what somebody put in out
/// of their pocket is a fixed figure that moves only when they put in more,
/// and mixing the two was the thing version 2 was asked to stop.
///
/// One figure has to come out right and the rest follows from it: what the
/// page closes at has to be what the farm is holding in their name. If those
/// two ever disagree, somebody is being told they own something they do not.

Partner _p(String id, String name, {num invested = 2000000, num held = 0}) =>
    Partner(
      id: id,
      userId: 'u$id',
      name: name,
      invested: invested,
      profitHeld: held,
      withdrawn: 0,
      createdAt: DateTime(2026, 8, 1),
    );

FarmMonth _closed({
  required String id,
  required int month,
  required List<MonthShare> shares,
  int percent = 0,
}) => FarmMonth(
  id: id,
  status: 'closed',
  openingCash: 0,
  closedAt: DateTime(2026, month, 28),
  sharedPercent: percent,
  shares: shares,
);

MonthShare _share(String partnerId, num amount, {num taken = 0}) => MonthShare(
  partnerId: partnerId,
  name: 'Ghulam Ali',
  ratio: 1 / 3,
  share: amount,
  taken: taken,
);

String _label(FarmMonth m) => m.id;

void main() {
  group('a year of keeping it all in', () {
    final periods = [
      _closed(id: '2026-09', month: 9, shares: [_share('p1', 148000)]),
      _closed(id: '2026-10', month: 10, shares: [_share('p1', 90000)]),
    ];
    final him = _p('p1', 'Ghulam Ali', held: 238000);
    final s = profitAccount(partner: him, periods: periods, label: _label);

    test('it opens at nothing — their own money is not on this page', () {
      expect(s.opening, 0);
    });

    test('each settled period is a line of its own', () {
      expect(s.lines.length, 2);
      expect(s.lines[0].credit, 148000);
      expect(s.lines[1].credit, 90000);
      expect(s.lines.every((l) => l.debit == 0), isTrue);
    });

    test('it closes at what the farm is holding in his name', () {
      expect(s.closing, him.profitHeld);
      expect(s.closing, 238000);
    });

    test('it calls itself what it is', () {
      expect(s.kind, StatementKind.capital);
      expect(s.kind.title, 'Profit account');
      expect(s.kind.footLabel, 'Kept in the farm');
    });
  });

  group('a period where some of it was handed over', () {
    final periods = [
      _closed(
        id: '2026-09',
        month: 9,
        percent: 50,
        shares: [_share('p1', 148000, taken: 74000)],
      ),
    ];
    final him = _p('p1', 'Ghulam Ali', held: 74000);
    final s = profitAccount(partner: him, periods: periods, label: _label);

    test('the slice and what was paid out are two lines, not one', () {
      expect(s.lines.length, 2);
      expect(s.lines[0].credit, 148000);
      expect(s.lines[1].debit, 74000);
    });

    test('it still closes at what is held', () {
      expect(s.closing, him.profitHeld);
    });

    test('the two columns and the balance agree', () {
      expect(s.credits - s.debits, s.closing - s.opening);
    });
  });

  group('a month that lost money', () {
    test('it is a debit, and the balance comes down', () {
      final periods = [
        _closed(id: '2026-09', month: 9, shares: [_share('p1', 148000)]),
        _closed(id: '2026-10', month: 10, shares: [_share('p1', -66667)]),
      ];
      final s = profitAccount(
        partner: _p('p1', 'Ghulam Ali', held: 81333),
        periods: periods,
        label: _label,
      );
      expect(s.lines[1].debit, 66667);
      expect(s.lines[1].detail, contains('Loss'));
      expect(s.closing, 81333);
    });

    test('nothing is ever handed out of one', () {
      final periods = [
        _closed(
          id: '2026-09',
          month: 9,
          percent: 100,
          shares: [_share('p1', -50000)],
        ),
      ];
      final s = profitAccount(
        partner: _p('p1', 'Ghulam Ali', held: -50000),
        periods: periods,
        label: _label,
      );
      expect(s.lines.single.debit, 50000);
      expect(s.lines.length, 1, reason: 'no payment line on a loss');
    });

    test('losses past what was earned take it below zero, and show it', () {
      // Saleem was asked what should happen here and was plain about it:
      // manfi dikhao, chupana nahi hai. A hole in what he put in is a thing
      // he would rather find out about on the page than a year later.
      final periods = [
        _closed(id: '2026-09', month: 9, shares: [_share('p1', 100000)]),
        _closed(id: '2026-10', month: 10, shares: [_share('p1', -266667)]),
      ];
      final s = profitAccount(
        partner: _p('p1', 'Ghulam Ali', held: -166667),
        periods: periods,
        label: _label,
      );
      expect(s.closing, -166667);
      expect(s.closing, lessThan(0));
    });
  });

  group('what is deliberately not on it', () {
    test('a period still waiting to be settled is absent', () {
      final sealed = FarmMonth(
        id: '2026-09b',
        status: 'sealed',
        openingCash: 0,
        shares: [_share('p1', 148000)],
      );
      final s = profitAccount(
        partner: _p('p1', 'Ghulam Ali'),
        periods: [sealed],
        label: _label,
      );
      expect(s.isEmpty, isTrue);
      expect(s.closing, 0);
    });

    test("another co-founder's slice stays on his own page", () {
      final periods = [
        _closed(
          id: '2026-09',
          month: 9,
          shares: [_share('p1', 148000), _share('p2', 74000)],
        ),
      ];
      final s = profitAccount(
        partner: _p('p2', 'Saleem Rehman', invested: 1000000, held: 74000),
        periods: periods,
        label: _label,
      );
      expect(s.lines.single.credit, 74000);
      expect(s.closing, 74000);
    });

    test('a co-founder with no slice in a period is not on it', () {
      final periods = [
        _closed(id: '2026-09', month: 9, shares: [_share('p1', 148000)]),
      ];
      final s = profitAccount(
        partner: _p('p9', 'Newcomer', invested: 500000),
        periods: periods,
        label: _label,
      );
      expect(s.isEmpty, isTrue);
      expect(s.closing, 0);
    });

    test('what they put in is not a line on it', () {
      final s = profitAccount(
        partner: _p('p1', 'Ghulam Ali', invested: 2000000),
        periods: const [],
        label: _label,
      );
      expect(s.lines, isEmpty);
      expect(s.closing, 0, reason: 'the two lakh is not profit');
    });
  });
}
