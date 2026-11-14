// The report page and the summary beside it have to say the same thing.
//
// The farm opened Report, read "Rs -18,188" on the period tab, switched to
// Summary and read "Rs -2,188" for the same stretch, and asked why. The
// 16,000 between them was an advance against a wage: money lent, which the
// summary had left out of the costs since the day the farm asked for the
// taking-back to have a row of its own, and which the period tab was still
// counting as spent.
//
// Both figures now come out of one rule. These are the two shapes that rule
// has to hold for — the advance as it was typed before the change, and as
// it is typed now.

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';
import 'package:flutter_test/flutter_test.dart';

var _n = 0;

Txn _row({
  required TxnType type,
  required String category,
  required num amount,
  String who = 'Gul Din',
  bool deleted = false,
}) => Txn(
  id: 'r${_n++}',
  date: DateTime(2026, 10, 14),
  monthId: '2026-10',
  type: type,
  party: who,
  category: category,
  amount: amount,
  paid: true,
  paidOnCreate: true,
  paidSoFar: amount,
  note: '',
  createdBy: 'u1',
  createdAt: DateTime(2026, 10, 14),
  deletedAt: deleted ? DateTime(2026, 10, 15) : null,
);

Txn _milkSold(num amount) =>
    _row(type: TxnType.sale, category: milkCategory, amount: amount);

Txn _feed(num amount) =>
    _row(type: TxnType.purchase, category: 'Fodder / feed', amount: amount);

Txn _buffalo(num amount) =>
    _row(type: TxnType.purchase, category: 'Cattle purchase', amount: amount);

/// An advance as it is typed today: a payment.
Txn _advanceNow(num amount) => _row(
  type: TxnType.payment,
  category: salaryAdvanceCategory,
  amount: amount,
);

/// An advance as it sits in the farm's books from before the change: an
/// expense carrying the same heading.
Txn _advanceOld(num amount) => _row(
  type: TxnType.expense,
  category: salaryAdvanceCategory,
  amount: amount,
);

/// The costs the summary works out, for the same rows.
num _summaryCosts(List<Txn> rows) => Books(
  monthId: '2026-10',
  openingCash: 0,
  capital: 0,
  monthTxns: rows.where((t) => !t.isDeleted).toList(),
  unpaidTxns: const [],
).costs;

void main() {
  group('an advance typed before the change, which is an expense', () {
    final rows = [_milkSold(296000), _feed(282188), _advanceOld(16000)];
    final sums = ReportTotals.of(rows);

    test('is in the gross, because that is how it was written', () {
      expect(sums.gross, 298188);
    });

    test('and is taken off again, because it is lent and not spent', () {
      expect(sums.advances, 16000);
      expect(sums.moneyOut, 282188);
    });

    test('so the page agrees with the summary to the rupee', () {
      expect(sums.moneyOut, _summaryCosts(rows));
    });

    test('and the net is what the farm actually made', () {
      expect(sums.net, 296000 - 282188);
    });
  });

  group('an advance typed today, which is a payment', () {
    final rows = [_milkSold(296000), _feed(282188), _advanceNow(16000)];
    final sums = ReportTotals.of(rows);

    test('never reaches the gross — it drops out with the settlements', () {
      expect(sums.gross, 282188);
    });

    test('so it is not taken off a second time', () {
      expect(sums.advances, 0);
      expect(sums.moneyOut, 282188);
    });

    test('and the two shapes of the same advance come to the same figure', () {
      final old = ReportTotals.of([
        _milkSold(296000),
        _feed(282188),
        _advanceOld(16000),
      ]);
      expect(sums.moneyOut, old.moneyOut);
      expect(sums.net, old.net);
    });

    test('and the page still agrees with the summary', () {
      expect(sums.moneyOut, _summaryCosts(rows));
    });
  });

  group('cattle, which the farm still owns', () {
    final rows = [_milkSold(100000), _feed(20000), _buffalo(250000)];
    final sums = ReportTotals.of(rows);

    test('are in the gross and then taken off, the same as before', () {
      expect(sums.gross, 270000);
      expect(sums.assets, 250000);
      expect(sums.moneyOut, 20000);
    });

    test('so a month of buying does not read as a month of losing', () {
      expect(sums.net, 80000);
    });
  });

  group('both at once, which is the farm as it stands', () {
    final rows = [
      _milkSold(296000),
      _feed(260000),
      _buffalo(100000),
      _advanceOld(16000),
    ];
    final sums = ReportTotals.of(rows);

    test('each comes off once and only once', () {
      expect(sums.gross, 376000);
      expect(sums.assets, 100000);
      expect(sums.advances, 16000);
      expect(sums.moneyOut, 260000);
    });

    test('and the summary says the same', () {
      expect(sums.moneyOut, _summaryCosts(rows));
    });
  });

  group('a row taken off the books', () {
    test('is in none of it, not even as something to take off', () {
      final rows = [
        _milkSold(100000),
        _feed(20000),
        _row(
          type: TxnType.expense,
          category: salaryAdvanceCategory,
          amount: 16000,
          deleted: true,
        ),
      ];
      final sums = ReportTotals.of(rows);
      expect(sums.gross, 20000);
      expect(sums.advances, 0);
      expect(sums.moneyOut, 20000);
      expect(sums.net, 80000);
    });
  });

  group('an advance standing is money owed to the farm', () {
    MoneySummary summary({num advanced = 0}) => MoneySummary(
      capital: 100000,
      assets: 0,
      runningCosts: 0,
      sales: 0,
      cash: 50000,
      receivable: 20000,
      payable: 5000,
      wagesAdvanced: advanced,
    );

    test('so what the farm is worth goes up by exactly it', () {
      final without = summary().farmMoney;
      final with16 = summary(advanced: 16000).farmMoney;
      expect(with16 - without, 16000);
    });

    test('and it stands on the same side as a loan out, not against it', () {
      // The farm's own money in somebody else's pocket. An advance in the
      // box would be the opposite — that is a security held, and it is
      // taken off, not added.
      expect(
        summary(advanced: 16000).farmMoney,
        greaterThan(summary().farmMoney),
      );
    });

    test('and it is never a cost, however it was typed', () {
      for (final advance in [_advanceOld(16000), _advanceNow(16000)]) {
        final rows = [_milkSold(100000), _feed(20000), advance];
        expect(ReportTotals.of(rows).moneyOut, 20000);
        expect(_summaryCosts(rows), 20000);
      }
    });
  });

  group('the rule about what the page counts at all', () {
    test('a receipt against a sale is the sale, not a second one', () {
      final settles = Txn(
        id: 's1',
        date: DateTime(2026, 10, 20),
        monthId: '2026-10',
        type: TxnType.receipt,
        party: 'Babar Dairy',
        category: 'Khaata receipt',
        amount: 5000,
        paid: true,
        paidOnCreate: true,
        paidSoFar: 5000,
        note: '',
        createdBy: 'u1',
        createdAt: DateTime(2026, 10, 20),
        settlesTxnId: 'r1',
      );
      expect(countedInReport(settles), isFalse);
    });

    test('but a receipt tied to nothing is the only record of that money', () {
      final loose = _row(
        type: TxnType.receipt,
        category: 'Other sale',
        amount: 5000,
        who: 'Scrap man',
      );
      expect(countedInReport(loose), isTrue);
      expect(ReportTotals.of([loose]).moneyIn, 5000);
    });
  });
}
