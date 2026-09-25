import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/categories.dart';

/// A category somebody wrote out, rather than one off the list.
///
/// The list is short and a farm meets things nobody listed. Letting a word be
/// typed costs two things, and these are the two: the same word spelled two
/// ways is two headings in the summary, and a word on no list has nothing to
/// say whether the farm kept what it bought or spent it.

var _n = 0;

Txn _txn({
  required TxnType type,
  required String category,
  bool? capital,
  num amount = 1000,
}) => Txn(
  id: 'c${_n++}',
  date: DateTime(2026, 9, 12),
  monthId: '2026-09',
  type: type,
  party: 'Somebody',
  category: category,
  amount: amount,
  paid: true,
  capital: capital,
  note: '',
  createdBy: 'u',
  createdAt: DateTime(2026, 9, 12),
);

void main() {
  group('categories the books already carry', () {
    test('a word written twice comes back once', () {
      final rows = [
        _txn(type: TxnType.expense, category: 'Mazdoori'),
        _txn(type: TxnType.expense, category: 'mazdoori'),
        _txn(type: TxnType.expense, category: 'MAZDOORI'),
      ];
      expect(categoriesUsed(rows)[TxnType.expense], ['Mazdoori']);
    });

    test('the spelling that comes back is the one used most', () {
      final rows = [
        _txn(type: TxnType.expense, category: 'mazdoori'),
        _txn(type: TxnType.expense, category: 'Mazdoori'),
        _txn(type: TxnType.expense, category: 'Mazdoori'),
      ];
      expect(categoriesUsed(rows)[TxnType.expense], ['Mazdoori']);
    });

    test('each tab keeps its own words', () {
      final rows = [
        _txn(type: TxnType.expense, category: 'Mazdoori'),
        _txn(type: TxnType.sale, category: 'Milk'),
      ];
      final used = categoriesUsed(rows);
      expect(used[TxnType.expense], ['Mazdoori']);
      expect(used[TxnType.sale], ['Milk']);
      expect(used[TxnType.purchase], isNull);
    });
  });

  group('a word already in use somewhere', () {
    test('a listed word is found on the tab it is listed on', () {
      expect(tabsUsingCategory(const [], 'Rent'), [TxnType.expense]);
      expect(tabsUsingCategory(const [], 'rent'), [TxnType.expense]);
    });

    test('a word on two lists comes back with both', () {
      // Feed is bought and is also an expense; both are true and the person
      // is told both rather than one of them.
      expect(tabsUsingCategory(const [], 'Fodder / feed'), [
        TxnType.purchase,
        TxnType.expense,
      ]);
    });

    test('a word only ever typed is found too', () {
      final rows = [_txn(type: TxnType.expense, category: 'Tubewell repair')];
      expect(tabsUsingCategory(rows, 'tubewell repair'), [TxnType.expense]);
    });

    test('a genuinely new word is found nowhere', () {
      expect(tabsUsingCategory(const [], 'Trolley'), isEmpty);
    });

    test('an empty word is not a match for everything', () {
      expect(tabsUsingCategory(const [], '   '), isEmpty);
    });
  });

  group('what the app posts for itself', () {
    // The fixed lists have never offered these. What did offer them was the
    // entry form's other half: it hands back every heading the books already
    // carry, so a word written once is a tap from then on — and it read them
    // straight out of the ledger, where the app's own entries live. That is
    // how "Profit share" turned up as something to pick on the payment form.
    test('they are named in one place', () {
      expect(
        appPostedCategories,
        containsAll([
          khaataReceiptCategory,
          profitShareCategory,
          writeOffCategory,
          founderLoanCategory,
        ]),
      );
    });

    test('and none of them is on a fixed list', () {
      for (final type in TxnType.values) {
        for (final own in appPostedCategories) {
          expect(
            type.categories,
            isNot(contains(own)),
            reason: '$own is offered on the ${type.label} form',
          );
        }
      }
    });

    test('an advance is not one of them, and neither is an instalment', () {
      // Both are ordinary things somebody does at a counter, and both are
      // safe to type: neither can ever be read as income or as a cost.
      expect(appPostedCategories, isNot(contains(advanceCategory)));
      expect(appPostedCategories, isNot(contains(advanceReturnCategory)));
      expect(appPostedCategories, isNot(contains(loanRepaidCategory)));
    });

    test('the books still carry them, which is why the filter is needed', () {
      // They have to stay readable — a report on what the farm lent out is a
      // fair question. They just must not come back as something to write.
      final rows = [
        _txn(type: TxnType.payment, category: founderLoanCategory),
        _txn(type: TxnType.payment, category: 'Supplier payment'),
      ];
      final used = categoriesUsed(rows)[TxnType.payment] ?? const [];
      expect(used, contains(founderLoanCategory));
      expect(used, contains('Supplier payment'));
    });
  });

  group('kept or spent', () {
    test('a listed asset is still an asset with nothing said about it', () {
      expect(
        _txn(
          type: TxnType.purchase,
          category: 'Cattle purchase',
        ).isCapitalAsset,
        isTrue,
      );
    });

    test('a listed cost is still a cost', () {
      expect(
        _txn(type: TxnType.expense, category: 'Salaries').isCapitalAsset,
        isFalse,
      );
    });

    test('a typed word the farm keeps is an asset', () {
      expect(
        _txn(
          type: TxnType.purchase,
          category: 'Trolley',
          capital: true,
        ).isCapitalAsset,
        isTrue,
      );
    });

    test('a typed word that was spent is a cost', () {
      expect(
        _txn(
          type: TxnType.expense,
          category: 'Tubewell repair',
          capital: false,
        ).isCapitalAsset,
        isFalse,
      );
    });

    test('what was said at the time beats the list, either way', () {
      // The list would call this an asset. Somebody bought a second-hand part
      // and said it was spent, and the entry keeps its own answer — which is
      // why the answer lives on the entry and not in a list that can be
      // edited later and rewrite last year's profit.
      expect(
        _txn(
          type: TxnType.purchase,
          category: 'Equipment',
          capital: false,
        ).isCapitalAsset,
        isFalse,
      );
    });

    test('a sale is never an asset, whatever was said', () {
      expect(
        _txn(
          type: TxnType.sale,
          category: 'Trolley',
          capital: true,
        ).isCapitalAsset,
        isFalse,
      );
    });
  });
}
