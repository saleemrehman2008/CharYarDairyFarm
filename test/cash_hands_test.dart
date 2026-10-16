import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';
import 'package:char_yar_dairy_farm/services/statement.dart';

/// Two things four friends with no accountant could not do with these books.
///
/// The first is to give up on money that is not coming. A shop pays a year of
/// milk bills and leaves a thousand rupees of the last one unpaid; everybody
/// knows it is gone. Left on the books the account says it is owed for ever,
/// and the next co-founder to read it goes and asks for it.
///
/// The second is to say whose hands the cash is in. The money comes in at the
/// gate to whoever is standing there, the feed is paid for out of whoever's
/// pocket is nearest, and one of them keeps the cash until everybody's
/// investment is paid in. Every entry has carried the handler's name from the
/// first day; it had never once been added up.

var _n = 0;

Txn _txn({
  required TxnType type,
  required String category,
  required num amount,
  String party = 'Urooj Dairy Shop',
  bool paid = true,
  num? paidSoFar,
  bool? paidOnCreate,
  String handledBy = '',
  String? settles,
  int day = 8,
}) => Txn(
  id: 't${_n++}',
  date: DateTime(2026, 10, day),
  monthId: '2026-10',
  type: type,
  party: party,
  category: category,
  amount: amount,
  paid: paid,
  paidSoFar: paidSoFar,
  paidOnCreate: paidOnCreate ?? paid,
  settlesTxnId: settles,
  handledBy: handledBy,
  note: '',
  createdBy: 'u1',
  createdAt: DateTime(2026, 10, day),
);

Books _books(List<Txn> ledger) => Books(
  monthId: '2026-10',
  openingCash: 0,
  capital: 0,
  monthTxns: ledger,
  unpaidTxns: ledger.where((t) => t.outstanding > 0).toList(),
);

MoneySummary _money(List<Txn> ledger) {
  final b = _books(ledger);
  return MoneySummary(
    capital: 0,
    assets: 0,
    runningCosts: b.costs,
    sales: b.sales,
    otherIncome: b.otherIncome,
    cash: b.cash,
    receivable: b.receivable,
    payable: b.payable,
  );
}

void main() {
  group('a thousand rupees nobody is going to pay', () {
    /// Sold on credit, nearly all of it collected, and the rest given up on.
    List<Txn> ledger({bool givenUp = true}) => [
      _txn(
        type: TxnType.sale,
        category: milkCategory,
        amount: 38000,
        paid: givenUp,
        paidSoFar: givenUp ? 38000 : 37000,
        paidOnCreate: false,
        day: 1,
      ),
      _txn(
        type: TxnType.receipt,
        category: khaataReceiptCategory,
        amount: 37000,
        handledBy: 'Jalbani',
        settles: 't0',
        day: 20,
      ),
      if (givenUp)
        _txn(
          type: TxnType.expense,
          category: badDebtCategory,
          amount: 1000,
          settles: 't0',
          day: 25,
        ),
    ];

    test('before it is given up on, the shop owes it for ever', () {
      final before = ledger(givenUp: false);
      expect(partyOwing(before, 'Urooj Dairy Shop').owesUs, 1000);
      expect(_books(before).receivable, 1000);
    });

    test('given up on, his account comes to nothing', () {
      final after = ledger();
      expect(partyOwing(after, 'Urooj Dairy Shop').owesUs, 0);
      final page = buildStatement(rows: after, party: 'Urooj Dairy Shop');
      expect(page.closing, 0, reason: 'nothing is owed either way');
      // And the page says what happened to it, rather than the line simply
      // vanishing: sold, paid, given up on.
      expect(page.lines.length, 3);
    });

    test('the farm is poorer by it, in the period it was given up in', () {
      final b = _books(ledger());
      expect(b.sales, 38000, reason: 'the sale was still made');
      expect(b.costs, 1000, reason: 'and a thousand of it never arrived');
      expect(b.profit, 37000);
    });

    test('and not a rupee of cash moves on the day', () {
      // The money never came. A cost that took cash with it would have the
      // farm paying out a thousand rupees it never had.
      final withIt = _books(ledger()).cash;
      final without = _books(ledger(givenUp: false)).cash;
      expect(withIt, without);
      expect(withIt, 37000, reason: 'only what was actually collected');
    });

    test('the books still balance, which is the whole test', () {
      // One side loses a receivable, the other gains a cost. If those two
      // did not move together the balance check would open a gap of exactly
      // a thousand rupees and nobody would know which half was wrong.
      expect(_money(ledger(givenUp: false)).reconciles, isTrue);
      expect(_money(ledger()).reconciles, isTrue);
    });

    test('it is not cash out of anybody\'s hands either', () {
      // Nobody handed anything over, so nobody's holding may move.
      final hands = cashInHands(ledger());
      expect(hands.single.who, 'Jalbani');
      expect(hands.single.received, 37000);
      expect(hands.single.paid, 0);
    });
  });

  group('cash passing from one pair of hands to another', () {
    /// Jalbani takes the money at the gate and hands it to Rafeeq, who keeps
    /// the farm's cash. Not a rupee enters or leaves the farm.
    // The sale the money came from. Without it on the page the farm
    // would be holding cash that nothing accounts for, and no balance
    // check could pass — which is itself the point of the check.
    final sale = _txn(
      type: TxnType.sale,
      category: milkCategory,
      amount: 38000,
      paidSoFar: 38000,
      paidOnCreate: false,
      day: 1,
    );

    final collected = _txn(
      type: TxnType.receipt,
      category: khaataReceiptCategory,
      amount: 38000,
      handledBy: 'Jalbani',
      settles: 'x1',
      day: 20,
    );

    final handedOver = _txn(
      type: TxnType.payment,
      category: handoverOutCategory,
      amount: 38000,
      party: 'Rafeeq',
      handledBy: 'Jalbani',
      day: 20,
    );

    final takenIn = _txn(
      type: TxnType.receipt,
      category: handoverInCategory,
      amount: 38000,
      party: 'Jalbani',
      handledBy: 'Rafeeq',
      day: 20,
    );

    test('the farm has exactly as much before and after', () {
      expect(_books([sale, collected]).cash, 38000);
      expect(_books([sale, collected, handedOver, takenIn]).cash, 38000);
    });

    test('and has neither earned nor spent anything by it', () {
      final b = _books([collected, handedOver, takenIn]);
      expect(b.sales, 0);
      expect(b.otherIncome, 0, reason: 'taking it in is not income');
      expect(b.costs, 0, reason: 'handing it over is not a cost');
      expect(b.profit, 0);
    });

    test('what moves is who is answerable for it', () {
      final before = cashInHands([collected]);
      expect(before.single.who, 'Jalbani');
      expect(before.single.holding, 38000);

      final after = cashInHands([collected, handedOver, takenIn]);
      expect(after.map((h) => h.who), ['Rafeeq', 'Jalbani']);
      expect(after.first.holding, 38000);
      expect(after.last.holding, 0);
    });

    test('and the books still balance', () {
      expect(_money([sale, collected]).reconciles, isTrue);
      expect(_money([sale, collected, handedOver, takenIn]).reconciles, isTrue);
    });
  });

  group('who is holding what', () {
    test('a founder who pays out of his own pocket reads as owed', () {
      // The thing the farm could not work out. Jalbani buys feed with his
      // own money; the farm owes him for it, and this is where it says so.
      final hands = cashInHands([
        _txn(
          type: TxnType.purchase,
          category: 'Wanda / feed',
          amount: 12000,
          party: 'Feed store',
          handledBy: 'Jalbani',
        ),
      ]);
      expect(hands.single.outOfPocket, isTrue);
      expect(hands.single.holding, -12000);
      expect(hands.single.paid, 12000);
    });

    test('two spellings of one man are one man', () {
      final hands = cashInHands([
        _txn(
          type: TxnType.sale,
          category: milkCategory,
          amount: 5000,
          handledBy: 'Jalbani',
        ),
        _txn(
          type: TxnType.sale,
          category: milkCategory,
          amount: 3000,
          handledBy: 'jalbani ',
        ),
      ]);
      expect(hands.length, 1);
      expect(hands.single.received, 8000);
      // Written back as the farm writes him most often.
      expect(hands.single.who, 'Jalbani');
      expect(hands.single.rows, 2);
    });

    test('money that moved with no name on it is shown, not dropped', () {
      // A farm needs telling about this, not protecting from it.
      final hands = cashInHands([
        _txn(
          type: TxnType.sale,
          category: milkCategory,
          amount: 5000,
          handledBy: 'Rafeeq',
        ),
        _txn(type: TxnType.sale, category: milkCategory, amount: 2000),
      ], unnamed: 'Nobody named');
      expect(hands.map((h) => h.who), ['Rafeeq', 'Nobody named']);
      expect(hands.last.received, 2000);
    });

    test('a credit sale lands on whoever collected it, not whoever wrote '
        'it', () {
      final hands = cashInHands([
        _txn(
          type: TxnType.sale,
          category: milkCategory,
          amount: 38000,
          paid: false,
          paidOnCreate: false,
          handledBy: 'Saleem',
        ),
        _txn(
          type: TxnType.receipt,
          category: khaataReceiptCategory,
          amount: 38000,
          handledBy: 'Jalbani',
          settles: 'x',
          day: 20,
        ),
      ]);
      expect(hands.single.who, 'Jalbani');
      expect(hands.single.received, 38000);
    });
  });
}
