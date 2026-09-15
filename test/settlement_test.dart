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
