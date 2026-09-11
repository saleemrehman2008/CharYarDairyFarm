import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';
import 'package:char_yar_dairy_farm/util/money.dart';

/// Helper so each case reads as the entry a farmer would type.
Txn entry({
  required TxnType type,
  required num amount,
  bool paid = true,
  String? customerId,
  String monthId = '2026-09',
}) => Txn(
  id: 'x${amount}_${type.name}_$paid',
  date: DateTime(2026, 9, 10),
  monthId: monthId,
  type: type,
  party: 'Someone',
  customerId: customerId,
  category: type.categories.first,
  amount: amount,
  paid: paid,
  note: '',
  createdBy: 'uid',
  createdAt: DateTime(2026, 9, 10),
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
      entry(type: TxnType.sale, amount: 20000, paid: false, customerId: 'c1'),
      entry(type: TxnType.purchase, amount: 12000),
      entry(type: TxnType.purchase, amount: 3000, paid: false),
      entry(type: TxnType.expense, amount: 5000),
      entry(type: TxnType.receipt, amount: 1000),
      entry(type: TxnType.payment, amount: 500),
    ];
    final unpaid = monthTxns.where((t) => !t.paid).toList();

    final books = Books(
      monthId: '2026-09',
      openingCash: 10000,
      monthTxns: monthTxns,
      unpaidTxns: unpaid,
    );

    test('profit counts unpaid entries too', () {
      expect(books.sales, 70000);
      expect(books.costs, 20000);
      expect(books.profit, 50000);
    });

    test('cash counts only what actually settled', () {
      // 10000 opening + 50000 paid sale + 1000 receipt
      //        − 12000 paid purchase − 5000 paid expense − 500 payment
      expect(books.cash, 43500);
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
