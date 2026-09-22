import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/statement.dart';

/// A co-founder's own account with the farm.
///
/// The third of the three statements, and the one four friends will check
/// hardest. It cannot be built from the ledger — what somebody put in out of
/// their own pocket never passed through it, because capital is not trading —
/// so it is built from what they have put in and what every settled period
/// handed them.
///
/// One figure has to come out right and everything else follows from it: what
/// the page closes at must be what they have in the farm, which is what they
/// put in plus every rupee of profit they have left in. If those two ever
/// disagree, somebody is being told they own something they do not.

Partner _p({
  required String id,
  required String name,
  required num invested,
  num reinvested = 0,
  num withdrawn = 0,
}) => Partner(
  id: id,
  userId: 'u$id',
  name: name,
  invested: invested,
  reinvested: reinvested,
  withdrawn: withdrawn,
  createdAt: DateTime(2026, 8, 1),
);

FarmMonth _closed({
  required String id,
  required int month,
  required List<MonthShare> shares,
}) => FarmMonth(
  id: id,
  status: 'closed',
  openingCash: 0,
  closedAt: DateTime(2026, month, 28),
  shares: shares,
);

MonthShare _share({
  required String partnerId,
  required num amount,
  num withdraw = 0,
}) => MonthShare(
  partnerId: partnerId,
  name: 'Ghulam Ali',
  ratio: 0.25,
  share: amount,
  choice: 'split',
  withdraw: withdraw,
  decidedAt: DateTime(2026, 9, 28),
);

String _label(FarmMonth m) => m.id;

void main() {
  group('a co-founder who has left everything in', () {
    // Two periods, nothing taken out, so both slices became investment.
    final periods = [
      _closed(
        id: '2026-09',
        month: 9,
        shares: [_share(partnerId: 'p1', amount: 148000)],
      ),
      _closed(
        id: '2026-10',
        month: 10,
        shares: [_share(partnerId: 'p1', amount: 90000)],
      ),
    ];
    final him = _p(
      id: 'p1',
      name: 'Ghulam Ali',
      invested: 2000000,
      reinvested: 238000,
    );
    final s = capitalAccount(partner: him, periods: periods, label: _label);

    test('it opens at what came out of his own pocket', () {
      expect(s.opening, 2000000);
    });

    test('each settled period is a line of its own', () {
      expect(s.lines.length, 2);
      expect(s.lines[0].credit, 148000);
      expect(s.lines[1].credit, 90000);
      expect(s.lines.every((l) => l.debit == 0), isTrue);
    });

    test('it closes at what he has in the farm', () {
      expect(s.closing, him.capital);
      expect(s.closing, 2238000);
    });
  });

  group('a co-founder who takes some of it out', () {
    final periods = [
      _closed(
        id: '2026-09',
        month: 9,
        shares: [_share(partnerId: 'p1', amount: 148000, withdraw: 100000)],
      ),
    ];
    final him = _p(
      id: 'p1',
      name: 'Ghulam Ali',
      invested: 2000000,
      reinvested: 48000,
      withdrawn: 100000,
    );
    final s = capitalAccount(partner: him, periods: periods, label: _label);

    test('the share and what he took are two lines, not one', () {
      expect(s.lines.length, 2);
      expect(s.lines[0].credit, 148000);
      expect(s.lines[1].debit, 100000);
    });

    test('it still closes at his stake', () {
      expect(s.closing, him.capital);
      expect(s.closing, 2048000);
    });

    test('the two columns and the balance agree', () {
      expect(s.credits - s.debits, s.closing - s.opening);
    });
  });

  group('what is deliberately not on it', () {
    test('a period still waiting on decisions is absent', () {
      // Sealed, shares worked out, nothing decided and nothing handed over.
      // Putting it here would promise somebody money the four of them have
      // not finished settling.
      final sealed = FarmMonth(
        id: '2026-09b',
        status: 'sealed',
        openingCash: 0,
        shares: [_share(partnerId: 'p1', amount: 148000)],
      );
      final s = capitalAccount(
        partner: _p(id: 'p1', name: 'Ghulam Ali', invested: 2000000),
        periods: [sealed],
        label: _label,
      );
      expect(s.isEmpty, isTrue);
      expect(s.closing, 2000000);
    });

    test("another co-founder's slice stays on his own page", () {
      final periods = [
        _closed(
          id: '2026-09',
          month: 9,
          shares: [
            _share(partnerId: 'p1', amount: 148000),
            _share(partnerId: 'p2', amount: 74000),
          ],
        ),
      ];
      final s = capitalAccount(
        partner: _p(id: 'p2', name: 'Saleem Rehman', invested: 1000000),
        periods: periods,
        label: _label,
      );
      expect(s.lines.single.credit, 74000);
      expect(s.closing, 1074000);
    });

    test('a co-founder with no share in a period is simply not on it', () {
      final periods = [
        _closed(
          id: '2026-09',
          month: 9,
          shares: [_share(partnerId: 'p1', amount: 148000)],
        ),
      ];
      final s = capitalAccount(
        partner: _p(id: 'p9', name: 'Newcomer', invested: 500000),
        periods: periods,
        label: _label,
      );
      expect(s.isEmpty, isTrue);
      expect(s.closing, 500000);
    });
  });

  test('the page says which of the three documents it is', () {
    final s = capitalAccount(
      partner: _p(id: 'p1', name: 'Ghulam Ali', invested: 2000000),
      periods: const [],
      label: _label,
    );
    expect(s.kind, StatementKind.capital);
    expect(s.kind.title, 'Capital account');
    expect(s.kind.footLabel, 'Their stake in the farm');
  });
}
