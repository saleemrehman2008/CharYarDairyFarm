import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';

/// The all-time figures, and the three places they used to disagree with
/// themselves.
///
/// Four partners read the same farm on four phones. A period's own profit and
/// the all-time profit are the same claim about the same money, and if they
/// are worked out two different ways then sooner or later one of them is
/// wrong and nobody can say which. So the rule is one definition, read back
/// everywhere: profit is what was sold plus anything else that came in, less
/// what it cost to run the place.

var _n = 0;

Txn _txn({
  required TxnType type,
  required num amount,
  String category = 'Milk',
  bool paid = true,
  String? settles,
}) => Txn(
  id: 'l${_n++}',
  date: DateTime(2026, 9, 10),
  monthId: '2026-09',
  type: type,
  party: 'Somebody',
  category: category,
  amount: amount,
  paid: paid,
  paidOnCreate: paid,
  settlesTxnId: settles,
  note: '',
  createdBy: 'u',
  createdAt: DateTime(2026, 9, 10),
);

/// A period settled the way the app settles one: the figures are frozen off
/// the books as they stood.
FarmMonth _sealed(Books b) => FarmMonth(
  id: b.monthId,
  status: 'closed',
  openingCash: 0,
  sales: b.sales,
  otherIncome: b.otherIncome,
  purchases: b.purchases,
  expenses: b.expenses,
  assets: b.assetsBought,
  receivables: b.receivable,
  profit: b.profit,
);

Books _books(List<Txn> rows) => Books(
  monthId: '2026-09',
  openingCash: 0,
  capital: 100000,
  monthTxns: rows,
  unpaidTxns: rows.where((t) => !t.paid).toList(),
);

void main() {
  group('a closed period read back', () {
    test('its costs come back as what they were', () {
      final books = _books([
        _txn(type: TxnType.sale, amount: 50000),
        _txn(type: TxnType.expense, amount: 20000, category: 'Salaries'),
      ]);
      expect(books.costs, 20000);
      expect(_sealed(books).runningCosts, 20000);
    });

    test('a rent paid straight out is still in them', () {
      // This is the one that used to fall through. A payment tied to no bill
      // is money out of the farm, and adding up the stored purchases and
      // expenses does not see it — so the costs came back short by the rent
      // and the line stopped adding up to the profit printed beside it.
      final books = _books([
        _txn(type: TxnType.sale, amount: 50000),
        _txn(type: TxnType.payment, amount: 15000, category: 'Other payment'),
      ]);
      final sealed = _sealed(books);
      expect(books.costs, 15000);
      expect(sealed.runningCosts, 15000);
      expect(
        (sealed.sales ?? 0) + (sealed.otherIncome ?? 0) - sealed.runningCosts,
        sealed.profit,
        reason: 'the three figures on one line have to make each other',
      );
    });

    test('other income comes back too', () {
      final books = _books([
        _txn(type: TxnType.sale, amount: 50000),
        _txn(type: TxnType.receipt, amount: 4000, category: 'Other receipt'),
        _txn(type: TxnType.expense, amount: 20000, category: 'Salaries'),
      ]);
      final sealed = _sealed(books);
      expect(books.otherIncome, 4000);
      expect(books.profit, 34000);
      expect(sealed.runningCosts, 20000);
    });

    test('a period sealed before profit was stored still answers', () {
      final old = FarmMonth(
        id: '2026-08',
        status: 'closed',
        openingCash: 0,
        purchases: 30000,
        expenses: 10000,
        assets: 25000,
      );
      expect(old.runningCosts, 15000);
    });
  });

  group('all time', () {
    // One settled period and one still running, which is every farm that has
    // been going more than a month.
    final settled = _sealed(
      _books([
        _txn(type: TxnType.sale, amount: 80000),
        _txn(type: TxnType.receipt, amount: 5000, category: 'Other receipt'),
        _txn(type: TxnType.expense, amount: 30000, category: 'Salaries'),
      ]),
    );
    final open = _books([
      _txn(type: TxnType.sale, amount: 40000),
      _txn(type: TxnType.receipt, amount: 2000, category: 'Other receipt'),
      _txn(type: TxnType.expense, amount: 10000, category: 'Rent'),
    ]);

    // The same three sums the store does, kept here so the rule itself is
    // what is being tested and not the plumbing around it.
    final lifetimeSales = (settled.sales ?? 0) + open.sales;
    final lifetimeOther = (settled.otherIncome ?? 0) + open.otherIncome;
    final lifetimeCosts = settled.runningCosts + open.costs;
    final lifetimeProfit = lifetimeSales + lifetimeOther - lifetimeCosts;

    test('it is the periods added up, and nothing is lost between them', () {
      expect(lifetimeProfit, (settled.profit ?? 0) + open.profit);
    });

    test('other income is added, not taken off twice', () {
      // It used to be left out of the all-time profit while sitting inside
      // the costs that were read back — so seven thousand of scrap sold made
      // the farm look seven thousand worse off, twice over.
      expect(lifetimeOther, 7000);
      expect(lifetimeSales - lifetimeCosts, lifetimeProfit - 7000);
    });

    test('the running costs are the real ones', () {
      expect(lifetimeCosts, 40000);
    });
  });
}
