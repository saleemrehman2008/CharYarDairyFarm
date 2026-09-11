import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';
import 'package:char_yar_dairy_farm/util/money.dart';

/// Helper so each case reads as the entry a farmer would type.
var _seq = 0;

/// An entry paid as it was written — "Paid now" on the form.
Txn entry({
  required TxnType type,
  required num amount,
  bool paid = true,
  String? customerId,
  String? settlesTxnId,
  String monthId = '2026-09',
}) => Txn(
  id: 'txn${_seq++}',
  date: DateTime(2026, 9, 10),
  monthId: monthId,
  type: type,
  party: 'Someone',
  customerId: customerId,
  category: type.categories.first,
  amount: amount,
  paid: paid,
  paidAt: paid ? DateTime(2026, 9, 10) : null,
  note: '',
  settlesTxnId: settlesTxnId,
  paidOnCreate: paid,
  createdBy: 'uid',
  createdAt: DateTime(2026, 9, 10),
);

/// An entry booked on credit and settled later, which is how udhaar and
/// supplier bills behave. The cash moves on the settlement row, not here.
Txn creditEntry({
  required TxnType type,
  required num amount,
  required bool settled,
  String? customerId,
  String monthId = '2026-09',
}) => Txn(
  id: 'txn${_seq++}',
  date: DateTime(2026, 9, 10),
  monthId: monthId,
  type: type,
  party: 'Someone',
  customerId: customerId,
  category: type.categories.first,
  amount: amount,
  paid: settled,
  paidAt: settled ? DateTime(2026, 10, 5) : null,
  note: '',
  paidOnCreate: false,
  createdBy: 'uid',
  createdAt: DateTime(2026, 9, 10),
);

/// The receipt or payment "Mark paid" posts against [settles].
Txn settlement({
  required TxnType type,
  required num amount,
  required String settles,
  String monthId = '2026-09',
}) => Txn(
  id: 'txn${_seq++}',
  date: DateTime(2026, 10, 5),
  monthId: monthId,
  type: type,
  party: 'Someone',
  category: type.categories.first,
  amount: amount,
  paid: true,
  paidAt: DateTime(2026, 10, 5),
  note: 'Settles something',
  settlesTxnId: settles,
  paidOnCreate: true,
  createdBy: 'uid',
  createdAt: DateTime(2026, 10, 5),
);

Partner partner(String id, {num invested = 0, num reinvested = 0}) => Partner(
  id: id,
  userId: 'u$id',
  name: 'Partner $id',
  invested: invested,
  reinvested: reinvested,
  withdrawn: 0,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  group('money formatting', () {
    test('groups the Pakistani way', () {
      expect(groupPk(0), '0');
      expect(groupPk(999), '999');
      expect(groupPk(1000), '1,000');
      expect(groupPk(99999), '99,999');
      expect(groupPk(123456), '1,23,456');
      expect(groupPk(12345678), '1,23,45,678');
      expect(rs(123456), 'Rs 1,23,456');
    });

    test('keeps the sign outside the rupees', () {
      expect(groupPk(-123456), '-1,23,456');
      expect(signedRs(5000, incoming: true), '+ Rs 5,000');
      expect(signedRs(5000, incoming: false), '− Rs 5,000');
    });

    test('rolls the month id over a year boundary', () {
      expect(nextMonthId('2026-09'), '2026-10');
      expect(nextMonthId('2026-12'), '2027-01');
    });
  });

  group('Books', () {
    final monthTxns = [
      entry(type: TxnType.sale, amount: 50000),
      creditEntry(
        type: TxnType.sale,
        amount: 20000,
        settled: false,
        customerId: 'c1',
      ),
      entry(type: TxnType.purchase, amount: 12000),
      creditEntry(type: TxnType.purchase, amount: 3000, settled: false),
      entry(type: TxnType.expense, amount: 5000),
      entry(type: TxnType.receipt, amount: 1000),
      entry(type: TxnType.payment, amount: 500),
    ];
    final unpaid = monthTxns.where((t) => !t.paid).toList();

    final books = Books(
      monthId: '2026-09',
      openingCash: 10000,
      capital: 400000,
      monthTxns: monthTxns,
      unpaidTxns: unpaid,
    );

    test('profit counts unpaid entries too', () {
      expect(books.sales, 70000);
      expect(books.costs, 20000);
      expect(books.profit, 50000);
    });

    test('capital the partners put in is money the farm can spend', () {
      // 400000 capital + 10000 opening + 50000 paid sale + 1000 receipt
      //        − 12000 paid purchase − 5000 paid expense − 500 payment
      expect(books.cash, 443500);
      // The same figure without the partners' capital is what carries forward.
      expect(books.operatingCash, 43500);
    });

    test('profit is not touched by capital', () {
      expect(books.profit, 50000);
    });

    test('receivables and payables split by entry type', () {
      expect(books.receivable, 20000);
      expect(books.payable, 3000);
    });

    test('rolling receivables takes them out of the shareable profit', () {
      expect(books.profitToShare(arIncluded: true), 50000);
      expect(books.profitToShare(arIncluded: false), 30000);
    });

    test('an empty month is all zeroes, not a crash', () {
      final empty = Books.empty('2026-10');
      expect(empty.profit, 0);
      expect(empty.cash, 0);
      expect(empty.profitBar, 0);
    });
  });

  group('credit does not move the balance until it is settled', () {
    Books booksOf(List<Txn> txns, {num opening = 0, num capital = 0}) => Books(
      monthId: '2026-09',
      openingCash: opening,
      capital: capital,
      monthTxns: txns,
      unpaidTxns: txns.where((t) => !t.paid).toList(),
    );

    test('an unpaid bill sits in payables and leaves cash alone', () {
      final books = booksOf([
        creditEntry(type: TxnType.expense, amount: 15000, settled: false),
      ], capital: 100000);
      expect(books.payable, 15000);
      expect(books.cash, 100000);
      // It still counts against profit — the farm owes it either way.
      expect(books.profit, -15000);
    });

    test('an unpaid sale sits in receivables and leaves cash alone', () {
      final books = booksOf([
        creditEntry(type: TxnType.sale, amount: 7200, settled: false),
      ], capital: 100000);
      expect(books.receivable, 7200);
      expect(books.cash, 100000);
    });

    test('marking it paid moves the cash exactly once', () {
      final bill = creditEntry(
        type: TxnType.purchase,
        amount: 400000,
        settled: true,
      );
      final books = booksOf([
        bill,
        settlement(type: TxnType.payment, amount: 400000, settles: bill.id),
      ], capital: 2200000);
      // Not 1,400,000, which is what counting both rows would give.
      expect(books.cash, 1800000);
      expect(books.payable, 0);
    });

    test('settling last month carries the cash into this month', () {
      // The sale was booked and closed in September; the money arrives in
      // October, so only the settlement row is in this month's ledger.
      final books = booksOf([
        settlement(
          type: TxnType.receipt,
          amount: 10000,
          settles: 'septemberSale',
          monthId: '2026-10',
        ),
      ], opening: 5000);
      expect(books.cash, 15000);
    });
  });

  group('share ratios', () {
    test('follow capital including reinvested profit', () {
      final partners = [
        partner('a', invested: 300000),
        partner('b', invested: 100000, reinvested: 100000),
      ];
      final ratios = ratiosOf(partners);
      expect(ratios['a'], closeTo(0.6, 1e-9));
      expect(ratios['b'], closeTo(0.4, 1e-9));
    });

    test('split evenly before anyone has put money in', () {
      final ratios = ratiosOf([partner('a'), partner('b'), partner('c')]);
      expect(ratios['a'], closeTo(1 / 3, 1e-9));
    });

    test('shareOut rounds to whole rupees and honours each choice', () {
      final partners = [
        partner('a', invested: 60000),
        partner('b', invested: 40000),
      ];
      final shares = shareOut(
        partners: partners,
        profitToShare: 50001,
        choices: {'a': 'reinvest'},
      );
      expect(shares.map((s) => s.share).toList(), [30001, 20000]);
      expect(shares.first.isReinvested, isTrue);
      // Anyone not given a choice defaults to taking the cash.
      expect(shares.last.choice, 'withdraw');
    });

    test('every rupee is handed out, even when it will not divide', () {
      final partners = [partner('a', invested: 1), partner('b', invested: 1)];
      final shares = shareOut(
        partners: partners,
        profitToShare: 101,
        choices: const {},
      );
      expect(shares.fold<num>(0, (a, s) => a + s.share), 101);
    });

    test('three equal partners still add up', () {
      final partners = [
        partner('a', invested: 1),
        partner('b', invested: 1),
        partner('c', invested: 1),
      ];
      final shares = shareOut(
        partners: partners,
        profitToShare: 100,
        choices: const {},
      );
      expect(shares.fold<num>(0, (a, s) => a + s.share), 100);
    });
  });

  group('udhaar limit', () {
    test('is litres x rate x 30 x 1.2, rounded up to a thousand', () {
      // 5 * 200 * 30 * 1.2 = 36000
      expect(UdhaarAccount.suggestLimit(5, 200), 36000);
      // 4 * 210 * 30 * 1.2 = 30240 -> 31000
      expect(UdhaarAccount.suggestLimit(4, 210), 31000);
    });
  });

  group('order status', () {
    test('advances one step at a time and then stops', () {
      expect(OrderStatus.newOrder.next, OrderStatus.preparing);
      expect(OrderStatus.preparing.next, OrderStatus.out);
      expect(OrderStatus.out.next, OrderStatus.delivered);
      expect(OrderStatus.delivered.next, isNull);
      expect(OrderStatus.delivered.advanceLabel, isNull);
    });

    test('open means not delivered and not cancelled', () {
      expect(OrderStatus.out.isOpen, isTrue);
      expect(OrderStatus.delivered.isOpen, isFalse);
      expect(OrderStatus.cancelled.isOpen, isFalse);
      expect(OrderStatus.cancelled.step, 0);
    });
  });
}
