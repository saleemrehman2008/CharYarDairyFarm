import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';

/// Money the farm lends one of its own.
///
/// The whole of it turns on one thing: a loan is not a cost and a repayment
/// is not income. Book the loan as an expense — which is the obvious thing to
/// reach for, and was the first plan — and that month's profit drops by the
/// whole lakh, so all four co-founders lose their share of money that one of
/// them is going to give back. Book the repayment as a receipt and the profit
/// climbs by the same lakh a year later, and all four are handed a share of a
/// rupee the farm never earned. Between the two, money walks quietly from one
/// friend's account into another's for no reason anybody could name.
///
/// So it sits outside the profit entirely, the way a customer's advance does
/// — the same idea pointing the other way. An advance is money in the box
/// that is not the farm's; a loan is the farm's money that is not in the box.

var _n = 0;

Txn _txn({
  required TxnType type,
  required num amount,
  required String category,
  String party = 'Ghulam Ali',
}) => Txn(
  id: 'k${_n++}',
  date: DateTime(2026, 9, 12),
  monthId: '2026-09',
  type: type,
  party: party,
  category: category,
  amount: amount,
  paid: true,
  paidOnCreate: true,
  note: '',
  createdBy: 'u',
  createdAt: DateTime(2026, 9, 12),
);

Txn _lend(num amount) =>
    _txn(type: TxnType.payment, amount: amount, category: founderLoanCategory);

Txn _back(num amount) =>
    _txn(type: TxnType.receipt, amount: amount, category: loanRepaidCategory);

FounderLoan _loan({
  num amount = 100000,
  int months = 12,
  num repaid = 0,
  LoanState state = LoanState.given,
}) => FounderLoan(
  id: 'l1',
  partnerId: 'p1',
  name: 'Ghulam Ali',
  amount: amount,
  months: months,
  state: state,
  askedAt: DateTime(2026, 9, 1),
  givenAt: DateTime(2026, 9, 2),
  repaid: repaid,
);

void main() {
  group('a loan is not a cost', () {
    test('lending does not touch the profit', () {
      final rows = [
        _txn(type: TxnType.sale, amount: 600000, category: 'Milk'),
        _txn(type: TxnType.expense, amount: 60000, category: 'Salaries'),
        _lend(100000),
      ];
      final books = Books(
        monthId: '2026-09',
        openingCash: 0,
        capital: 6000000,
        monthTxns: rows,
        unpaidTxns: const [],
      );
      expect(books.profit, 540000, reason: 'the lakh is not a cost');
      expect(books.costs, 60000);
      expect(books.loosePayments, 0, reason: 'it is not a loose payment');
    });

    test('without that rule all four would lose a share of it', () {
      // What the books would say if the loan went in as an ordinary payment.
      // Ghulam Ali's third of the difference is 33,333 — taken off him for
      // money he himself is going to repay.
      final asCost = Books(
        monthId: '2026-09',
        openingCash: 0,
        capital: 6000000,
        monthTxns: [
          _txn(type: TxnType.sale, amount: 600000, category: 'Milk'),
          _txn(
            type: TxnType.payment,
            amount: 100000,
            category: 'Other payment',
          ),
        ],
        unpaidTxns: const [],
      );
      expect(asCost.profit, 500000);

      final proper = Books(
        monthId: '2026-09',
        openingCash: 0,
        capital: 6000000,
        monthTxns: [
          _txn(type: TxnType.sale, amount: 600000, category: 'Milk'),
          _lend(100000),
        ],
        unpaidTxns: const [],
      );
      expect(proper.profit - asCost.profit, 100000);
    });

    test('paying it back is not income', () {
      final books = Books(
        monthId: '2026-09',
        openingCash: 0,
        capital: 6000000,
        monthTxns: [
          _txn(type: TxnType.sale, amount: 600000, category: 'Milk'),
          _back(8333),
        ],
        unpaidTxns: const [],
      );
      expect(books.otherIncome, 0, reason: 'the farm earned nothing here');
      expect(books.profit, 600000);
    });

    test('but both move the cash, because they are cash', () {
      final lent = Books(
        monthId: '2026-09',
        openingCash: 0,
        capital: 6000000,
        monthTxns: [_lend(100000)],
        unpaidTxns: const [],
      );
      expect(lent.cash, 5900000);

      final backAgain = Books(
        monthId: '2026-09',
        openingCash: 0,
        capital: 6000000,
        monthTxns: [_lend(100000), _back(100000)],
        unpaidTxns: const [],
      );
      expect(backAgain.cash, 6000000);
    });
  });

  group('the books still balance', () {
    test('what is lent out is counted as the farm s, not lost', () {
      final books = Books(
        monthId: '2026-09',
        openingCash: 0,
        capital: 6000000,
        monthTxns: [
          _txn(type: TxnType.sale, amount: 600000, category: 'Milk'),
          _lend(100000),
        ],
        unpaidTxns: const [],
      );
      final money = MoneySummary(
        capital: 6000000,
        assets: 0,
        runningCosts: books.costs,
        sales: books.sales,
        cash: books.cash,
        receivable: books.receivable,
        payable: books.payable,
        loansOut: 100000,
      );
      expect(money.reconciles, isTrue);
      expect(money.expected, money.farmMoney);
    });

    test('and leaving it out is exactly what breaks them', () {
      final books = Books(
        monthId: '2026-09',
        openingCash: 0,
        capital: 6000000,
        monthTxns: [
          _txn(type: TxnType.sale, amount: 600000, category: 'Milk'),
          _lend(100000),
        ],
        unpaidTxns: const [],
      );
      final blind = MoneySummary(
        capital: 6000000,
        assets: 0,
        runningCosts: books.costs,
        sales: books.sales,
        cash: books.cash,
        receivable: books.receivable,
        payable: books.payable,
      );
      expect(blind.reconciles, isFalse);
      expect(blind.expected - blind.farmMoney, 100000);
    });
  });

  group('the instalments', () {
    test('a lakh over a year is eight thousand and a bit a month', () {
      expect(_loan().instalment, 8333);
    });

    test('what is left comes down as it is paid', () {
      expect(_loan(repaid: 8333).left, 91667);
      expect(_loan(repaid: 100000).left, 0);
      expect(_loan(repaid: 100000).isCleared, isTrue);
    });

    test('it never goes below nothing, however much comes back', () {
      expect(_loan(repaid: 150000).left, 0);
    });

    test('a loan over no months at all is due in one', () {
      expect(_loan(months: 0).instalment, 100000);
    });

    test('how far along it is, for the bar', () {
      expect(_loan(repaid: 50000).done, closeTo(0.5, 1e-9));
      expect(_loan(repaid: 0).done, 0);
      expect(_loan(repaid: 999999).done, 1);
    });
  });

  group('the last instalment', () {
    // A lakh over twelve months is 8,333 a month, and twelve of those is
    // 99,996 — so the last month is not a month, it is whatever is left. The
    // figure offered has to be that, and nothing bigger than it can be taken:
    // past the end of a loan the farm is owed a negative amount, which is not
    // a thing, and the extra would sit in the cash with nothing behind it.
    num offered(FounderLoan loan) =>
        loan.instalment < loan.left ? loan.instalment : loan.left;

    test('is whatever is left, not a whole month', () {
      final nearlyDone = _loan(repaid: 95000);
      expect(nearlyDone.left, 5000);
      expect(nearlyDone.instalment, 8333);
      expect(offered(nearlyDone), 5000);
    });

    test('an ordinary month is still a whole month', () {
      expect(offered(_loan(repaid: 8333)), 8333);
    });

    test('a loan already paid off offers nothing', () {
      expect(offered(_loan(repaid: 100000)), 0);
      expect(_loan(repaid: 100000).isCleared, isTrue);
    });

    test('what is left never goes past the end', () {
      for (final paid in [0, 8333, 50000, 99999, 100000, 120000]) {
        final loan = _loan(repaid: paid);
        expect(loan.left, greaterThanOrEqualTo(0));
        expect(offered(loan), lessThanOrEqualTo(loan.left));
      }
    });
  });

  group('a loan that has been paid off says so', () {
    // The stored word records what the master did — handed it over — and
    // nothing goes back to rewrite it when the last instalment lands. An
    // instalment somebody enters themselves pays a loan off just as truly as
    // one a close took, so whether it is finished has to be read off the
    // ledger rather than off that word. Read the word alone and a loan that
    // is fully paid goes on calling itself running, which is what the farm
    // was looking at.
    test('even while the record still says it was handed over', () {
      final done = _loan(repaid: 100000);
      expect(done.state, LoanState.given);
      expect(done.standing, LoanState.cleared);
      expect(done.standing.isOpen, isFalse);
    });

    test('one still being paid is still running', () {
      expect(_loan(repaid: 50000).standing, LoanState.given);
    });

    test('overpaid is still paid off, not something stranger', () {
      final over = _loan(repaid: 100499);
      expect(over.standing, LoanState.cleared);
      expect(over.left, 0);
      expect(over.done, 1);
    });

    test('asking and being turned down are left alone', () {
      expect(_loan(state: LoanState.asked).standing, LoanState.asked);
      expect(_loan(state: LoanState.refused).standing, LoanState.refused);
    });
  });

  group('where a loan stands', () {
    test('only one that has been handed over is running', () {
      expect(_loan(state: LoanState.asked).state.isOpen, isFalse);
      expect(_loan(state: LoanState.given).state.isOpen, isTrue);
      expect(_loan(state: LoanState.cleared).state.isOpen, isFalse);
      expect(_loan(state: LoanState.refused).state.isOpen, isFalse);
    });

    test('an old record still reads', () {
      expect(LoanState.parse('given'), LoanState.given);
      expect(LoanState.parse('nonsense'), LoanState.asked);
    });
  });
}
