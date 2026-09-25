import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';

/// A milch buffalo and the calf that came with her.
///
/// She is never sold on her own. One price buys the pair, and both animals go
/// on the register — the calf is the farm's, and one day she will be milking
/// or sold.
///
/// The whole of the money side is one rule: the price sits on the mother and
/// the calf costs nothing. Put it on both and the farm has five lakh of
/// buffalo it never bought; split it between them and somebody has to decide
/// what a calf is worth, which is a guess dressed up as a figure. Leaving it
/// whole on the mother is the only version that is simply true — what was
/// paid is what is on the books.
///
/// It comes right over the two of them however they are sold. The day the
/// mother goes, the whole price comes off; whatever the calf then fetches is
/// all earnings. Over the pair the farm is out exactly what it paid and in
/// exactly what it got, which is the figure that has to be right.

var _n = 0;

Txn _txn({
  required TxnType type,
  required num amount,
  required String party,
  required String category,
  int day = 1,
}) => Txn(
  id: 'c${_n++}',
  date: DateTime(2026, 9, day),
  monthId: '2026-09',
  type: type,
  party: party,
  category: category,
  amount: amount,
  paid: true,
  paidOnCreate: true,
  note: '',
  createdBy: 'u',
  createdAt: DateTime(2026, 9, day),
);

Books _books(List<Txn> rows) => Books(
  monthId: '2026-09',
  openingCash: 0,
  capital: 6000000,
  monthTxns: rows,
  unpaidTxns: const [],
);

/// Bought as a pair for five lakh: one purchase, on the mother.
List<Txn> _bought() => [
  _txn(
    type: TxnType.purchase,
    amount: 500000,
    party: 'B-01 Kaali',
    category: 'Cattle purchase',
  ),
];

void main() {
  group('bought as a pair', () {
    test('one price is booked, not two', () {
      final books = _books(_bought());
      expect(books.assetsBought, 500000);
      expect(books.purchases, 500000);
    });

    test('and it is not a cost — the farm owns them', () {
      final books = _books(_bought());
      expect(books.costs, 0);
      expect(books.profit, 0);
    });

    test('the cash is down by what was actually handed over', () {
      expect(_books(_bought()).cash, 6000000 - 500000);
    });
  });

  group('and sold, one at a time', () {
    // The mother goes first for four lakh — less than the pair cost, so that
    // month reads as a loss. Then the calf goes for two, and all of it is
    // earnings because nothing was ever spent on her.
    final rows = [
      ..._bought(),
      _txn(
        type: TxnType.sale,
        amount: 400000,
        party: 'Cattle buyer',
        category: 'Cattle sale',
        day: 10,
      ),
      _txn(
        type: TxnType.expense,
        amount: 500000,
        party: 'B-01 Kaali',
        category: writeOffCategory,
        day: 10,
      ),
      _txn(
        type: TxnType.sale,
        amount: 200000,
        party: 'Cattle buyer',
        category: 'Cattle sale',
        day: 20,
      ),
    ];

    test('the mother comes off at the whole price', () {
      final off = rows.where((t) => t.isWriteOff);
      expect(off.single.amount, 500000);
    });

    test('the calf comes off at nothing, because she cost nothing', () {
      // There is no write-off for her, and that is the point — not an
      // oversight. She was never bought.
      expect(rows.where((t) => t.isWriteOff).length, 1);
    });

    test('over the pair the farm made what it actually made', () {
      // Six lakh in, five lakh of buffalo gone: a lakh, and nothing else.
      final books = _books(rows);
      expect(books.sales, 600000);
      expect(books.profit, 100000);
    });

    test('and the books balance with nothing owned any more', () {
      final books = _books(rows);
      final owned = rows.fold<num>(
        0,
        (a, t) =>
            t.isCapitalAsset ? a + t.amount : (t.isWriteOff ? a - t.amount : a),
      );
      expect(owned, 0, reason: 'both animals have left the farm');

      final money = MoneySummary(
        capital: 6000000,
        assets: owned,
        runningCosts: books.costs,
        sales: books.sales,
        cash: books.cash,
        receivable: books.receivable,
        payable: books.payable,
      );
      expect(money.reconciles, isTrue);
    });

    test('the cash is the price out and both sales in', () {
      expect(_books(rows).cash, 6000000 - 500000 + 600000);
    });
  });

  group('what would go wrong the other ways', () {
    test('pricing both animals invents money the farm never spent', () {
      final twice = [
        ..._bought(),
        _txn(
          type: TxnType.purchase,
          amount: 500000,
          party: 'B-02 calf',
          category: 'Cattle purchase',
        ),
      ];
      expect(_books(twice).assetsBought, 1000000);
      expect(
        _books(twice).cash,
        6000000 - 1000000,
        reason: 'a lakh of cash gone that nobody handed over',
      );
    });
  });
}
