import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';
import 'package:char_yar_dairy_farm/services/statement.dart';

/// A wage advance is money lent, and the taking back of it is a row.
///
/// It used to be a cost on the day it went, and the wage it came off was
/// smaller by whatever it recovered. Two things were wrong with that. The
/// month an advance went out looked dearer than it was and the month it
/// came back looked cheaper — and months are what the four of them share
/// out, so a big advance quietly moved profit from one month to the next.
/// And the recovery was written nowhere anybody could see: a man paid his
/// last wage less sixteen thousand had nothing in the books saying where
/// the sixteen went. The farm asked for both.
///
/// So: the advance is a loan, the wage is the cost in its own month, and
/// the taking-back is its own line — income to nobody, because the farm
/// is collecting its own money and not earning any.

var _n = 0;

Txn _row({
  required TxnType type,
  required String category,
  required num amount,
  int month = 10,
  int day = 14,
  String who = 'Gul Din',
  num? advanceCut,
}) => Txn(
  id: 'w${_n++}',
  date: DateTime(2026, month, day),
  monthId: '2026-${month.toString().padLeft(2, '0')}',
  type: type,
  party: who,
  category: category,
  amount: amount,
  paid: true,
  paidOnCreate: true,
  paidSoFar: amount,
  note: '',
  createdBy: 'u1',
  createdAt: DateTime(2026, month, day),
  advanceCut: advanceCut,
);

/// Sixteen thousand handed over before the month was out.
Txn _advance(num amount, {int month = 10, int day = 14}) => _row(
  type: TxnType.payment,
  category: salaryAdvanceCategory,
  amount: amount,
  month: month,
  day: day,
);

/// The whole wage for the month, which is the cost.
Txn _wage(num amount, {int month = 10, int day = 31}) => _row(
  type: TxnType.expense,
  category: salariesCategory,
  amount: amount,
  month: month,
  day: day,
  advanceCut: 0,
);

/// What the wage took back off his advance.
Txn _back(num amount, {int month = 10, int day = 31}) => _row(
  type: TxnType.receipt,
  category: salaryAdvanceBackCategory,
  amount: amount,
  month: month,
  day: day,
);

Books _books(List<Txn> rows, {String month = '2026-10'}) => Books(
  monthId: month,
  openingCash: 0,
  capital: 0,
  monthTxns: rows.where((t) => t.monthId == month).toList(),
  unpaidTxns: rows.where((t) => !t.paid).toList(),
);

void main() {
  group('an advance is not a cost', () {
    test('handing one over costs the farm nothing', () {
      // It is owed back. The farm has not spent it.
      final books = _books([_advance(16000)]);
      expect(books.costs, 0);
      expect(books.profit, 0);
    });

    test('but the cash goes', () {
      expect(_advance(16000).type, TxnType.payment);
      expect(movedCashOut(_advance(16000)), isTrue);
    });

    test('and it is not a running cost whichever way it was written', () {
      // The farm has rows from when these were saved as an expense.
      final old = _row(
        type: TxnType.expense,
        category: salaryAdvanceCategory,
        amount: 16000,
      );
      expect(old.isWageAdvance, isTrue);
      expect(old.isRunningCost, isFalse);
      expect(_books([old]).costs, 0);
    });
  });

  group('taking it back is not income', () {
    test('the row is money in, and nothing earned', () {
      final books = _books([_back(16000)]);
      expect(books.otherIncome, 0);
      expect(books.profit, 0);
    });

    test('but the cash comes', () {
      expect(movedCashIn(_back(16000)), isTrue);
    });

    test('and it never reads as a loose receipt', () {
      expect(_back(16000).isLooseReceipt, isFalse);
    });
  });

  group("Gul Din's last wage", () {
    // 24,000 for October. He drew 16,000 on the 14th and the whole of it
    // comes off, so 8,000 goes in his hand.
    final led = [_advance(16000), _wage(24000), _back(16000)];

    test('the cost is the wage, in the wage\'s own month', () {
      expect(_books(led).costs, 24000);
    });

    test('the cash that left is the wage, no more and no less', () {
      final out = led.where(movedCashOut).fold<num>(0, (a, t) => a + t.amount);
      final back = led.where(movedCashIn).fold<num>(0, (a, t) => a + t.amount);
      expect(out - back, 24000);
    });

    test('what he was handed is the wage less what came back', () {
      final wage = led.firstWhere((t) => t.category == salariesCategory);
      final took = led
          .where((t) => t.isWageAdvanceBack)
          .fold<num>(0, (a, t) => a + t.amount);
      expect(wage.amount - took, 8000);
    });

    test('and he owes nothing after it', () {
      expect(advanceOwed(led, who: 'Gul Din'), 0);
    });

    test('the books still balance', () {
      final b = _books(led);
      final money = MoneySummary(
        cash: b.cash,
        capital: 0,
        assets: b.assetsBought,
        runningCosts: b.costs,
        sales: b.sales,
        otherIncome: b.otherIncome,
        receivable: b.receivable,
        payable: b.payable,
      );
      expect(money.reconciles, isTrue);
    });
  });

  group('the month it used to move', () {
    // The advance in October, the wage in November. Under the old rule
    // October carried a 16,000 cost that was not October's.
    final led = [
      _advance(16000, month: 10),
      _wage(24000, month: 11),
      _back(16000, month: 11),
    ];

    test('October costs nothing', () {
      expect(_books(led, month: '2026-10').costs, 0);
    });

    test('November carries the whole wage', () {
      expect(_books(led, month: '2026-11').costs, 24000);
    });

    test('and across both months the farm is out by one wage', () {
      final out = led.where(movedCashOut).fold<num>(0, (a, t) => a + t.amount);
      final back = led.where(movedCashIn).fold<num>(0, (a, t) => a + t.amount);
      expect(out - back, 24000);
    });
  });

  group('part of it, and the rest next month', () {
    test('six thousand off a sixteen thousand advance', () {
      final led = [_advance(16000), _wage(24000), _back(6000)];
      expect(advanceOwed(led, who: 'Gul Din'), 10000);
      expect(_books(led).costs, 24000);
    });

    test('and the ten thousand comes off the next wage', () {
      final led = [
        _advance(16000, month: 10),
        _wage(24000, month: 10),
        _back(6000, month: 10),
        _wage(24000, month: 11),
        _back(10000, month: 11),
      ];
      expect(advanceOwed(led, who: 'Gul Din'), 0);
      expect(_books(led, month: '2026-11').costs, 24000);
    });
  });

  group('when it is not coming back', () {
    final gone = _row(
      type: TxnType.expense,
      category: advanceGivenUpCategory,
      amount: 16000,
      month: 11,
      day: 5,
    );

    test('it closes what he owes', () {
      final led = [_advance(16000), gone];
      expect(advanceOwed(led, who: 'Gul Din'), 0);
    });

    test('the farm takes it as a loss', () {
      expect(gone.isAdvanceGivenUpOn, isTrue);
      expect(gone.isRunningCost, isTrue);
      expect(_books([gone], month: '2026-11').costs, 16000);
    });

    test('and no rupee moves, because it moved with the advance', () {
      expect(gone.movedNoCash, isTrue);
      expect(movedCashOut(gone), isFalse);
    });

    test('part of it may be given up on and the rest left standing', () {
      final led = [
        _advance(16000),
        _row(
          type: TxnType.expense,
          category: advanceGivenUpCategory,
          amount: 10000,
          month: 11,
          day: 5,
        ),
      ];
      expect(advanceOwed(led, who: 'Gul Din'), 6000);
    });

    test('and one man\'s loss is not another\'s', () {
      final led = [
        _advance(16000),
        _advance(5000, day: 15).copyAs('Jalbani'),
        gone,
      ];
      expect(advanceOwed(led, who: 'Gul Din'), 0);
      expect(advanceOwed(led, who: 'Jalbani'), 5000);
    });
  });

  group('wages written before any of this', () {
    test('one that says what it recovered is still believed', () {
      // No taking-back row: the wage says it on itself.
      final led = [
        _advance(16000),
        _row(
          type: TxnType.expense,
          category: salariesCategory,
          amount: 8000,
          day: 31,
          advanceCut: 16000,
        ),
      ];
      expect(advanceOwed(led, who: 'Gul Din'), 0);
    });

    test('and is never counted twice against a row that says it too', () {
      // A wage saved since carries a zero, so the row does the saying.
      final led = [_advance(16000), _wage(24000), _back(16000)];
      final wage = led.firstWhere((t) => t.category == salariesCategory);
      expect(wage.advanceCut, 0);
      expect(advanceOwed(led, who: 'Gul Din'), 0);
    });
  });

  group('his own statement', () {
    // Gul Din: 16,000 drawn on the 14th, a 24,000 wage on the 31st with
    // 6,000 taken back off it. Ten thousand is still on him.
    final led = [_advance(16000), _wage(24000), _back(6000)];

    test('every line of his is on it', () {
      final paper = buildStatement(rows: led, party: 'Gul Din');
      expect(paper.lines, hasLength(3));
    });

    test('and it closes at what he still owes', () {
      // It closed at nothing. Everything on a wage settles the day it is
      // written, so each row netted to zero and the page said he and the
      // farm were square — while he had ten thousand of theirs.
      final paper = buildStatement(rows: led, party: 'Gul Din');
      expect(paper.closing, 10000);
    });

    test('which is the figure the wage list shows', () {
      final paper = buildStatement(rows: led, party: 'Gul Din');
      expect(paper.closing, advanceOwed(led, who: 'Gul Din'));
    });

    test('a man with no advance closes at nothing', () {
      final clean = [_wage(24000)];
      expect(buildStatement(rows: clean, party: 'Gul Din').closing, 0);
      expect(advanceOwed(clean, who: 'Gul Din'), 0);
    });

    test('and one who has worked it all off closes at nothing too', () {
      final done = [_advance(16000), _wage(24000), _back(16000)];
      expect(buildStatement(rows: done, party: 'Gul Din').closing, 0);
      expect(advanceOwed(done, who: 'Gul Din'), 0);
    });

    test('giving up on it closes his page as well', () {
      final gone = [
        _advance(16000),
        _row(
          type: TxnType.expense,
          category: advanceGivenUpCategory,
          amount: 16000,
          month: 11,
          day: 5,
        ),
      ];
      expect(buildStatement(rows: gone, party: 'Gul Din').closing, 0);
      expect(advanceOwed(gone, who: 'Gul Din'), 0);
    });

    test('the two sides agree however the months fall', () {
      // The one that has to hold whatever happens: what his page closes
      // at is what the wage list says he owes.
      for (final led in [
        <Txn>[_advance(16000)],
        <Txn>[_advance(16000), _back(4000)],
        <Txn>[_advance(16000), _wage(24000), _back(6000)],
        <Txn>[_advance(16000), _advance(5000, day: 20), _back(9000)],
        <Txn>[
          _advance(16000),
          _wage(24000, month: 11),
          _back(16000, month: 11),
        ],
      ]) {
        expect(
          buildStatement(rows: led, party: 'Gul Din').closing,
          advanceOwed(led, who: 'Gul Din'),
        );
      }
    });
  });
}

extension on Txn {
  /// The same row against another man.
  Txn copyAs(String who) => Txn(
    id: id,
    date: date,
    monthId: monthId,
    type: type,
    party: who,
    category: category,
    amount: amount,
    paid: paid,
    paidOnCreate: paidOnCreate,
    paidSoFar: paidSoFar,
    note: note,
    createdBy: createdBy,
    createdAt: createdAt,
    advanceCut: advanceCut,
  );
}
