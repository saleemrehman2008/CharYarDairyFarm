import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';

/// What happens to an entry that is booked in one period and settled in the
/// next — the case the farm hits every time a khaata customer pays late, and
/// the one place where a rupee could quietly be counted twice.
///
/// The rule the whole ledger rests on: **one entry, two dates.** The sale or
/// bill is written once, in the period it happened, and that is the only row
/// that ever touches the profit. The receipt or payment posted when the money
/// arrives is a cash row — it moves the balance and nothing else.

var _n = 0;

Txn _txn({
  required TxnType type,
  required num amount,
  bool paid = true,
  bool paidOnCreate = true,
  String? settles,
  String? category,
  String monthId = '2026-09',
}) => Txn(
  id: 'x${_n++}',
  date: DateTime(2026, 9, 10),
  monthId: monthId,
  type: type,
  party: 'Ahmed',
  category: category ?? type.categories.first,
  amount: amount,
  paid: paid,
  paidAt: paid ? DateTime(2026, 9, 10) : null,
  note: '',
  settlesTxnId: settles,
  paidOnCreate: paid && paidOnCreate,
  createdBy: 'u',
  createdAt: DateTime(2026, 9, 10),
);

Books _books(
  List<Txn> month, {
  List<Txn> unpaid = const [],
  num opening = 0,
  num capital = 0,
}) => Books(
  monthId: 'p',
  openingCash: opening,
  capital: capital,
  monthTxns: month,
  unpaidTxns: unpaid,
);

void main() {
  group('a credit sale settled after the period closed', () {
    // September: 70 cash and 30 on credit. October: 50 cash, and Ahmed pays
    // the 30 he owed.
    final credit = _txn(type: TxnType.sale, amount: 30, paid: false);
    final sep = _books(
      [_txn(type: TxnType.sale, amount: 70), credit],
      unpaid: [credit],
    );
    final oct = _books([
      _txn(type: TxnType.sale, amount: 50, monthId: '2026-10'),
      _txn(
        type: TxnType.receipt,
        amount: 30,
        settles: credit.id,
        monthId: '2026-10',
      ),
    ], opening: sep.operatingCash);

    test('the sale is income in September and in no other period', () {
      expect(sep.sales, 100);
      expect(oct.sales, 50, reason: 'the receipt is cash, not a second sale');
    });

    test('the cash lands in October, when it actually arrived', () {
      expect(sep.operatingCash, 70, reason: 'the 30 had not come in yet');
      expect(oct.operatingCash, 150, reason: '70 carried + 50 sold + 30 paid');
    });

    test('it is shared once, and the two periods add up to the profit', () {
      final shared =
          sep.profitToShare(arIncluded: true) +
          oct.profitToShare(arIncluded: true);
      expect(shared, 150);
      expect(shared, sep.sales + oct.sales, reason: 'nothing lost, none twice');
    });

    test(
      'rolling it holds it back in September and pays it out in October',
      () {
        // Held back: only the 70 that was actually collected is shared.
        final first = sep.profitToShare(arIncluded: false);
        expect(first, 70);

        // And what was held back comes into the next period, or it would be
        // shared by nobody, ever.
        final second = oct.profitToShare(
          arIncluded: false,
          carriedReceivable: sep.receivable,
        );
        expect(second, 80);
        expect(first + second, 150);
      },
    );
  });

  group('a bill settled after the period closed', () {
    final bill = _txn(type: TxnType.purchase, amount: 20, paid: false);
    final sep = _books(
      [_txn(type: TxnType.sale, amount: 70), bill],
      unpaid: [bill],
    );
    final oct = _books([
      _txn(
        type: TxnType.payment,
        amount: 20,
        settles: bill.id,
        monthId: '2026-10',
      ),
    ], opening: sep.operatingCash);

    test('it is a cost in September and in no other period', () {
      expect(sep.costs, 20);
      expect(oct.costs, 0, reason: 'the payment settles it, it is not a cost');
    });

    test('the cash leaves in October, when it was actually handed over', () {
      expect(sep.operatingCash, 70);
      expect(oct.operatingCash, 50);
    });

    test('it is taken off the profit once', () {
      expect(sep.profit + oct.profit, 50);
    });
  });

  // Four co-founders put Rs 20,00,000 in between them, bought the herd and a
  // chiller out of it, ran the place for a month and sold the milk. The
  // breakdown on the home page has to add up at every point along that road —
  // before the first close, and after somebody takes their share out.
  group('where the money is, read down the waterfall', () {
    final cows = _txn(
      type: TxnType.purchase,
      amount: 1500000,
      category: 'Cattle purchase',
    );
    final chiller = _txn(
      type: TxnType.purchase,
      amount: 100000,
      category: 'Equipment',
    );
    final feed = _txn(
      type: TxnType.purchase,
      amount: 80000,
      category: 'Fodder / feed',
    );
    final feedOwed = _txn(
      type: TxnType.purchase,
      amount: 50000,
      category: 'Fodder / feed',
      paid: false,
    );
    final salaries = _txn(
      type: TxnType.expense,
      amount: 60000,
      category: 'Salaries',
    );
    final rent = _txn(type: TxnType.expense, amount: 40000, category: 'Rent');
    final milk = _txn(type: TxnType.sale, amount: 300000);
    final milkOwed = _txn(type: TxnType.sale, amount: 100000, paid: false);

    final ledger = [
      cows,
      chiller,
      feed,
      feedOwed,
      salaries,
      rent,
      milk,
      milkOwed,
    ];
    final owed = ledger.where((t) => !t.paid).toList();
    final books = _books(ledger, unpaid: owed, capital: 2000000);

    MoneySummary summaryOf(Books b, {num paidOut = 0}) => MoneySummary(
      capital: 2000000,
      assets: 1600000,
      runningCosts: 230000,
      sales: 400000,
      cash: b.cash,
      receivable: b.receivable,
      payable: b.payable,
      paidOut: paidOut,
    );

    test('what the founders put in is never profit', () {
      expect(books.assetsBought, 1600000, reason: 'the herd and the chiller');
      expect(books.costs, 230000, reason: 'feed, salaries and rent only');
      expect(books.profit, 170000);
      expect(books.profit, books.sales - books.costs);
    });

    test('it adds up before anybody has been paid', () {
      final m = summaryOf(books);
      expect(m.expected, 570000);
      expect(m.farmMoney, m.expected);
      expect(m.reconciles, isTrue);
    });

    test('it still adds up after a co-founder takes their share out', () {
      final paid = _txn(
        type: TxnType.payment,
        amount: 100000,
        category: profitShareCategory,
        monthId: '2026-10',
      );
      final after = Books(
        monthId: '2026-10',
        openingCash: books.operatingCash,
        capital: 2000000,
        monthTxns: [paid],
        unpaidTxns: owed,
      );
      expect(after.cash, 420000, reason: 'the money has left the farm');

      // Without the line for it the breakdown reads 100,000 high.
      expect(summaryOf(after).reconciles, isFalse);

      final m = summaryOf(after, paidOut: 100000);
      expect(m.expected, 470000);
      expect(m.farmMoney, 470000);
      expect(m.reconciles, isTrue);
    });
  });

  // The categories a person can pick from on the entry form, and the ones
  // the app posts itself. The difference matters: a row the app posts is
  // tied to the entry it settles, and the same row typed by hand is tied to
  // nothing — so the books read it as money earned all over again.
  group('what may be typed by hand', () {
    test('a collection is not offered as something to type', () {
      expect(
        TxnType.receipt.categories,
        isNot(contains(khaataReceiptCategory)),
        reason: 'money in against an entry is taken in from the ledger',
      );
      expect(TxnType.receipt.categories, contains(advanceCategory));
      expect(TxnType.receipt.categories, contains('Other receipt'));
    });

    test('and neither is anything else the app posts on its own', () {
      expect(TxnType.expense.categories, isNot(contains(writeOffCategory)));
      expect(TxnType.payment.categories, isNot(contains(profitShareCategory)));
    });

    test('which is what it would have cost to leave it there', () {
      // Kashif took 8,000 of milk on credit, so the farm has already earned
      // 8,000 and is owed 8,000.
      final sale = _txn(type: TxnType.sale, amount: 8000, paid: false);

      // The app's own way: a receipt tied to that sale. Cash comes in, the
      // sale is settled, and the profit does not move.
      final properly = _books(
        [
          sale,
          _txn(
            type: TxnType.receipt,
            amount: 8000,
            category: khaataReceiptCategory,
            settles: sale.id,
          ),
        ],
        unpaid: [sale],
      );
      expect(properly.profit, 8000);
      expect(properly.otherIncome, 0);

      // The same row typed by hand, tied to nothing: the books have no way
      // to know it is Kashif's milk money, so they count it as earned — and
      // the same 8,000 is in the profit twice.
      final byHand = _books(
        [
          sale,
          _txn(
            type: TxnType.receipt,
            amount: 8000,
            category: khaataReceiptCategory,
          ),
        ],
        unpaid: [sale],
      );
      expect(byHand.profit, 16000);
      expect(byHand.otherIncome, 8000);
    });
  });

  group('payments that are not settlements', () {
    test('rent paid straight out is a cost, not a free rupee', () {
      final p = _books([
        _txn(type: TxnType.payment, amount: 20, category: 'Other payment'),
      ]);
      expect(p.costs, 20);
      expect(p.operatingCash, -20);
    });

    test("a co-founder's profit share is money out but not a cost", () {
      final p = _books([
        _txn(type: TxnType.sale, amount: 100),
        _txn(type: TxnType.payment, amount: 40, category: profitShareCategory),
      ]);
      expect(
        p.profit,
        100,
        reason: 'paying the owners is not running the farm',
      );
      expect(p.costs, 0);
      expect(p.operatingCash, 60);
    });
  });
}
