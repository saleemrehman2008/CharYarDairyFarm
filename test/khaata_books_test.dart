import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';

/// Khaata milk, and the books it was never in.
///
/// Two ways milk goes out on credit, and they kept two different sets of
/// books. An order booked a sale the day it was delivered, so the ledger
/// knew about it. The daily round booked nothing at all: a delivery
/// record, a monthly bill, a running balance on the customer — and the
/// farm's own accounts were never told a thing.
///
/// Then a payment against a bill posted one receipt tied to nothing. For
/// the round that receipt was the only record of the money, so it had to
/// read as income. For an order it read as income a second time, on top of
/// the sale — the farm earned the same rupees twice — and the sale stayed
/// unpaid for ever besides, so the farm went on being owed money it had
/// already been handed.
///
/// These are the sums that say which is which.

var _n = 0;

Txn _sale(num amount, {bool paid = false, num paidSoFar = 0, int day = 10}) =>
    Txn(
      id: 's${_n++}',
      date: DateTime(2026, 10, day),
      monthId: '2026-10',
      type: TxnType.sale,
      party: 'Babar Dairy',
      customerId: 'cust1',
      category: milkCategory,
      amount: amount,
      paid: paid,
      paidOnCreate: false,
      paidSoFar: paidSoFar,
      note: '',
      createdBy: 'u1',
      createdAt: DateTime(2026, 10, day),
    );

Txn _receipt(num amount, {String? settles, int day = 31}) => Txn(
  id: 'r${_n++}',
  date: DateTime(2026, 10, day),
  monthId: '2026-10',
  type: TxnType.receipt,
  party: 'Babar Dairy',
  customerId: 'cust1',
  category: khaataReceiptCategory,
  amount: amount,
  paid: true,
  paidOnCreate: true,
  paidSoFar: amount,
  note: '',
  createdBy: 'u1',
  createdAt: DateTime(2026, 10, day),
  settlesTxnId: settles,
);

Books _books(List<Txn> rows) => Books(
  monthId: '2026-10',
  openingCash: 0,
  capital: 0,
  monthTxns: rows,
  unpaidTxns: rows.where((t) => !t.paid).toList(),
);

void main() {
  group('a receipt tied to what it settles', () {
    test('a loose receipt is income of its own', () {
      // Which is right when nothing else on the books says the money was
      // earned — the daily round used to book no sale at all.
      final books = _books([_receipt(2000)]);
      expect(books.otherIncome, 2000);
      expect(books.sales, 0);
      expect(books.profit, 2000);
    });

    test('and a tied one is not', () {
      // The sale said the farm earned it. The receipt only says it was
      // handed over.
      final sale = _sale(2000, paid: true, paidSoFar: 2000);
      final books = _books([sale, _receipt(2000, settles: sale.id)]);
      expect(books.sales, 2000);
      expect(books.otherIncome, 0);
      expect(books.profit, 2000);
    });

    test('the bug: a sale and a loose receipt earn it twice', () {
      // What a khaata order plus a bill payment used to do. This is the
      // shape of the thing, kept here so it cannot come back unnoticed.
      final books = _books([_sale(2000), _receipt(2000)]);
      expect(books.sales, 2000);
      expect(books.otherIncome, 2000);
      expect(books.profit, 4000, reason: 'earned once, counted twice');
    });
  });

  group('what the farm is owed', () {
    test('an unpaid sale is a receivable', () {
      expect(_books([_sale(2000)]).receivable, 2000);
    });

    test('a loose receipt clears nothing', () {
      // The other half of the same bug: the sale was never marked off, so
      // the farm chased money it had already taken.
      final books = _books([_sale(2000), _receipt(2000)]);
      expect(books.receivable, 2000, reason: 'paid, and still owed');
    });

    test('a settled sale is owed no longer', () {
      final sale = _sale(2000, paid: true, paidSoFar: 2000);
      final books = _books([sale, _receipt(2000, settles: sale.id)]);
      expect(books.receivable, 0);
    });

    test('and half of one is half owed', () {
      final sale = _sale(2000, paidSoFar: 800);
      final books = _books([sale, _receipt(800, settles: sale.id)]);
      expect(books.receivable, 1200);
      expect(books.otherIncome, 0);
    });
  });

  group('a month of round milk, from the bill to the money', () {
    test('billing it puts it on the books, and paying it clears it', () {
      // The round delivers 20 days at 500. The bill books one sale,
      // unpaid; the payment settles that sale rather than landing loose.
      final billed = _sale(10000);
      var books = _books([billed]);
      expect(books.sales, 10000);
      expect(books.receivable, 10000);
      expect(books.otherIncome, 0);

      final settled = _sale(10000, paid: true, paidSoFar: 10000);
      books = _books([settled, _receipt(10000, settles: settled.id)]);
      expect(books.sales, 10000);
      expect(books.otherIncome, 0);
      expect(books.profit, 10000, reason: 'earned once');
      expect(books.receivable, 0);
    });

    test('and paying part of it leaves the rest owed, earning nothing new', () {
      final part = _sale(10000, paidSoFar: 4000);
      final books = _books([part, _receipt(4000, settles: part.id)]);
      expect(books.profit, 10000);
      expect(books.receivable, 6000);
    });

    test('paying more than the ledger holds comes in as its own receipt', () {
      // Milk billed before any of this has no entry to land on, so the
      // leftover is still recorded — as income, because nothing else on
      // the books says the farm earned it.
      final old = _sale(3000, paid: true, paidSoFar: 3000);
      final books = _books([
        old,
        _receipt(3000, settles: old.id),
        _receipt(2000),
      ]);
      expect(books.sales, 3000);
      expect(books.otherIncome, 2000);
      expect(books.profit, 5000);
      expect(books.receivable, 0);
    });
  });

  group('the two halves of the balance still meet', () {
    test('a settled khaata month reconciles', () {
      final sale = _sale(10000, paid: true, paidSoFar: 10000);
      final books = _books([sale, _receipt(10000, settles: sale.id)]);
      final money = MoneySummary(
        cash: books.cash,
        capital: 0,
        assets: books.assetsBought,
        runningCosts: books.costs,
        sales: books.sales,
        otherIncome: books.otherIncome,
        receivable: books.receivable,
        payable: books.payable,
      );
      expect(money.reconciles, isTrue);
    });

    test('and so does one still owing', () {
      final books = _books([_sale(10000)]);
      final money = MoneySummary(
        cash: books.cash,
        capital: 0,
        assets: books.assetsBought,
        runningCosts: books.costs,
        sales: books.sales,
        otherIncome: books.otherIncome,
        receivable: books.receivable,
        payable: books.payable,
      );
      expect(money.reconciles, isTrue);
    });
  });
}
