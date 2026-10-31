import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/allocation.dart';

/// Taking something off the books, and putting it back.
///
/// Everything this farm's tests ask runs forwards: money comes in, a month
/// closes, a profit is shared. Nothing asked what happens when a figure is
/// taken back out — and that is where the farm lost six real sales.
///
/// What happened, in its own words. Babar Dairy owed 90,200 across 38
/// entries and paid 43,000. The app spread it over the oldest entries, as it
/// should, writing a receipt for each — all of them dated the day the money
/// arrived, not the day of the milk. The farm went looking for those
/// receipts on the days of the milk, found the sales there instead, marked
/// paid, and deleted five of the receipts it did find.
///
/// Deleting a receipt took the receipt off and left its money sitting on the
/// sale. The sale went on saying "paid in full" with nothing on the books
/// that had paid it, Babar's balance read short, and the farm — reasonably —
/// decided it must have typed something wrong and deleted the sales.
///
/// So these run the other way. A thing and the figures it moved go together,
/// in both directions, or the books tell a story nobody can walk back.

var _n = 0;

Txn _sale({
  required num amount,
  required int day,
  num paidSoFar = 0,
  bool paid = false,
  String? id,
}) => Txn(
  id: id ?? 's${_n++}',
  date: DateTime(2026, 10, day),
  monthId: '2026-10',
  type: TxnType.sale,
  party: 'Babar Dairy',
  category: 'Milk',
  amount: amount,
  paid: paid,
  paidSoFar: paidSoFar,
  note: '',
  createdBy: 'u1',
  createdAt: DateTime(2026, 10, day),
);

/// The receipt one payment writes against one sale: dated the day the money
/// came, carrying the id of the sale it pays.
Txn _receipt({required num amount, required String settles, int day = 30}) =>
    Txn(
      id: 'r${_n++}',
      date: DateTime(2026, 10, day),
      monthId: '2026-10',
      type: TxnType.receipt,
      party: 'Babar Dairy',
      category: khaataReceiptCategory,
      amount: amount,
      paid: true,
      paidOnCreate: true,
      settlesTxnId: settles,
      note: '',
      createdBy: 'u1',
      createdAt: DateTime(2026, 10, day),
    );

/// What a sale looks like after a settlement's money is moved on or off it.
///
/// The same sum TxnRepo does when a settlement is deleted or brought back:
/// move the figure, then work `paid` out again from it rather than carrying
/// it along beside — an entry is settled when nothing is left owing on it,
/// and that is one fact and not two that can come apart.
({num paidSoFar, bool paid}) _moved(Txn sale, num by) {
  var paid = sale.paidSoFar + by;
  if (paid < 0) paid = 0;
  if (paid > sale.amount) paid = sale.amount;
  return (paidSoFar: paid, paid: paid >= sale.amount);
}

void main() {
  group('the payment lands oldest first, which it always did', () {
    test('43,000 against 90,200 fills the oldest and stops part way', () {
      // The six oldest of Babar's, 9 to 11 October, which are the ones the
      // farm went on to delete.
      final sales = [
        _sale(amount: 1600, day: 9),
        _sale(amount: 1600, day: 9),
        _sale(amount: 1800, day: 10),
        _sale(amount: 1600, day: 10),
        _sale(amount: 1800, day: 11),
        _sale(amount: 2000, day: 11),
      ];

      final landings = allocate(sales, 10400);
      expect(landings, hasLength(6));
      expect(
        landings.fold<num>(0, (a, x) => a + x.take),
        10400,
        reason: 'every rupee handed over lands somewhere',
      );
      expect(landings.every((x) => x.finishes), isTrue);
      expect(landings.first.entry.date.day, 9, reason: 'oldest first');
    });

    test('and what is left over is what the screen promised', () {
      // 90,200 owed, 43,000 handed over, 47,200 still owed — the figures on
      // the farm's own screen. This part was never wrong.
      const owed = 90200;
      const handed = 43000;
      expect(owed - handed, 47200);
    });
  });

  group('deleting a receipt takes its money back off the sale', () {
    test('a sale settled in full goes back to owing all of it', () {
      // The bug, stated as the farm met it: this used to leave paidSoFar
      // where it was, so the sale said "paid" with no receipt behind it.
      final sale = _sale(amount: 1600, day: 9, paidSoFar: 1600, paid: true);
      final receipt = _receipt(amount: 1600, settles: sale.id);

      final after = _moved(sale, -receipt.amount);
      expect(after.paidSoFar, 0);
      expect(after.paid, isFalse, reason: 'nothing on the books paid it');
    });

    test('a part-settled sale goes back by exactly that receipt', () {
      // Two payments had reached one sale; only the second is deleted.
      final sale = _sale(amount: 5000, day: 9, paidSoFar: 5000, paid: true);
      final second = _receipt(amount: 2000, settles: sale.id);

      final after = _moved(sale, -second.amount);
      expect(after.paidSoFar, 3000);
      expect(after.paid, isFalse);
    });

    test('and never below nothing, whatever order they come off in', () {
      final sale = _sale(amount: 1600, day: 9, paidSoFar: 0);
      expect(_moved(sale, -1600).paidSoFar, 0);
    });
  });

  group('bringing it back puts the money back on', () {
    test('a receipt restored settles its sale again', () {
      final sale = _sale(amount: 1600, day: 9, paidSoFar: 0, paid: false);
      final receipt = _receipt(amount: 1600, settles: sale.id);

      final after = _moved(sale, receipt.amount);
      expect(after.paidSoFar, 1600);
      expect(after.paid, isTrue);
    });

    test('off and on again leaves the sale exactly where it started', () {
      // The whole promise of an undo, in one line.
      final sale = _sale(amount: 5000, day: 9, paidSoFar: 3200, paid: false);
      final receipt = _receipt(amount: 3200, settles: sale.id);

      final off = _moved(sale, -receipt.amount);
      expect(off.paidSoFar, 0);

      final back = _moved(
        _sale(amount: 5000, day: 9, paidSoFar: off.paidSoFar),
        receipt.amount,
      );
      expect(back.paidSoFar, 3200);
      expect(back.paid, isFalse, reason: '1,800 of it is still owed');
    });

    test('and never above what the entry came to', () {
      final sale = _sale(amount: 1600, day: 9, paidSoFar: 1600, paid: true);
      expect(_moved(sale, 1600).paidSoFar, 1600);
    });
  });

  group('the farm\'s own evening, run through', () {
    test('six sales and their receipts come back whole', () {
      // 9 to 11 October: six sales, 10,400, every one settled by the
      // payment and every one deleted afterwards. Deleting a sale takes
      // its receipt with it, so the undo has to bring back both — and the
      // sale has to come back settled, because the receipt does too.
      final sales = [
        _sale(amount: 1600, day: 9, paidSoFar: 1600, paid: true),
        _sale(amount: 1600, day: 9, paidSoFar: 1600, paid: true),
        _sale(amount: 1800, day: 10, paidSoFar: 1800, paid: true),
        _sale(amount: 1600, day: 10, paidSoFar: 1600, paid: true),
        _sale(amount: 1800, day: 11, paidSoFar: 1800, paid: true),
        _sale(amount: 2000, day: 11, paidSoFar: 2000, paid: true),
      ];
      final receipts = [
        for (final s in sales) _receipt(amount: s.amount, settles: s.id),
      ];

      expect(
        sales.fold<num>(0, (a, s) => a + s.amount),
        10400,
        reason: 'what the farm is missing',
      );

      // Every receipt comes off: each sale owes all of itself again.
      final emptied = [
        for (final (i, s) in sales.indexed) _moved(s, -receipts[i].amount),
      ];
      expect(emptied.every((x) => x.paidSoFar == 0), isTrue);
      expect(emptied.every((x) => !x.paid), isTrue);

      // And back on: every sale settled again, to the rupee.
      final restored = [
        for (final (i, s) in sales.indexed)
          _moved(
            _sale(amount: s.amount, day: 9, paidSoFar: 0),
            receipts[i].amount,
          ),
      ];
      expect(restored.every((x) => x.paid), isTrue);
      expect(
        restored.fold<num>(0, (a, x) => a + x.paidSoFar),
        10400,
        reason: 'every rupee of it back where it was',
      );
    });

    test('a part-settled sale comes back owing exactly what it owed', () {
      // The first version of this undo got this wrong, and the shape of the
      // mistake is worth keeping: deleting a sale took its receipts down
      // without taking their money off it, so the money sat there while the
      // sale was gone and the undo put it on a second time. A sale of
      // 50,000 with 10,000 against it came back owing 30,000 instead of
      // 40,000. A fully settled one was saved only by the clamp, which is
      // luck and not a rule — so this one is part settled.
      const amount = 50000;
      const already = 10000;

      final sale = _sale(amount: amount, day: 9, paidSoFar: already);
      final receipt = _receipt(amount: already, settles: sale.id);

      // Deleting the sale takes the receipt down, and takes the receipt's
      // money off the sale with it.
      final whileGone = _moved(sale, -receipt.amount);
      expect(whileGone.paidSoFar, 0);

      // And bringing it back puts that money on once, not twice.
      final back = _moved(
        _sale(amount: amount, day: 9, paidSoFar: whileGone.paidSoFar),
        receipt.amount,
      );
      expect(back.paidSoFar, already);
      expect(amount - back.paidSoFar, 40000, reason: 'what was owed before');
    });

    test(
      'a receipt is dated the day the money came, not the day of the milk',
      () {
        // Which is right, and is also why the farm could not find them: it
        // looked for them beside the sales and found the sales instead.
        final sale = _sale(amount: 1600, day: 9);
        final receipt = _receipt(amount: 1600, settles: sale.id);
        expect(receipt.date.day, 30);
        expect(sale.date.day, 9);
        expect(receipt.settlesTxnId, sale.id);
      },
    );
  });
}
