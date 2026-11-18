// Saying an entry was paid, or was not, as a correction.
//
// The farm found a 24,480 load of feed typed onto the account that had been
// paid in cash at the gate, opened the correction sheet to put it right,
// and found nothing there that said so — only "Paid by", which is whose
// hands the money passed through and not whether it was paid at all. The
// two look alike on a screen and mean quite different things.
//
// And the other half of the same morning: one co-founder had put 8,000 of
// his own money into that bill. The split sheet handed the other 16,480 to
// the farm's own account and said the farm had paid it, which it had not —
// the bill was still owed. So what nobody claims is now what nobody has
// paid, and the entry says so about itself.
//
// Both are corrections of what was written down, never payments: no receipt
// is made, and the money keeps the entry's own day. Both are refused the
// moment a real receipt stands against the entry, because a receipt is
// money that moved and is vouched for.

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/txn_repo.dart';
import 'package:flutter_test/flutter_test.dart';

var _n = 0;

Txn _feed({
  num amount = 24480,
  num paidSoFar = 0,
  bool paid = false,
  TxnType type = TxnType.purchase,
}) => Txn(
  id: 'f${_n++}',
  date: DateTime(2026, 11, 12),
  monthId: '2026-11',
  type: type,
  party: 'Shahjahan Tukra',
  category: 'Fodder / feed',
  amount: amount,
  paid: paid,
  paidOnCreate: paid,
  paidSoFar: paidSoFar,
  note: 'Total 288 kg tukra',
  createdBy: 'u1',
  createdAt: DateTime(2026, 11, 12),
);

void main() {
  group('saying a credit entry was paid in cash all along', () {
    final bill = _feed();
    final after = settledPatch(
      amount: bill.amount,
      alreadyPaid: bill.paidSoFar,
      want: bill.amount,
    );

    test('the whole of it is settled', () {
      expect(after.paidSoFar, 24480);
      expect(after.paid, isTrue);
    });

    test('and the cash book is told the money moved as it was written', () {
      // paidOnCreate is what the cash reads, not the flag. Without it the
      // entry would settle on the day somebody noticed rather than the day
      // the money actually left.
      expect(after.paidOnCreate, isTrue);
    });

    test('and a khaata customer stops owing it', () {
      expect(after.khaataBy, -24480);
    });
  });

  group('saying a cash entry was never paid', () {
    final bill = _feed(paid: true, paidSoFar: 24480);
    final after = settledPatch(
      amount: bill.amount,
      alreadyPaid: bill.paidSoFar,
      want: 0,
    );

    test('nothing is settled and it stands in what is owed', () {
      expect(after.paidSoFar, 0);
      expect(after.paid, isFalse);
      expect(after.paidOnCreate, isFalse);
    });

    test('and the customer owes it again', () {
      expect(after.khaataBy, 24480);
    });
  });

  group('one man pays part of a bill out of his own pocket', () {
    // The morning that started this: 8,000 of 24,480, and nobody else.
    final bill = _feed();
    final after = settledPatch(
      amount: bill.amount,
      alreadyPaid: bill.paidSoFar,
      want: 8000,
    );

    test('that much is paid', () {
      expect(after.paidSoFar, 8000);
    });

    test('and the rest is still owed, so the entry is not settled', () {
      expect(after.paid, isFalse);
      expect(bill.amount - after.paidSoFar, 16480);
    });

    test('which is the whole point — it used to read as the farm paying', () {
      // Before this, the split sheet gave the remainder to the farm's own
      // account and the bill stayed wholly unpaid at the same time. Two
      // answers, both wrong.
      expect(after.paidSoFar, lessThan(bill.amount));
      expect(after.paidSoFar, greaterThan(0));
    });
  });

  group('the figure is clamped to the entry', () {
    test('nothing is paid below nought', () {
      final after = settledPatch(amount: 24480, alreadyPaid: 0, want: -5000);
      expect(after.paidSoFar, 0);
      expect(after.paid, isFalse);
    });

    test('and nothing above what the entry is worth', () {
      // Otherwise the farm is owed money on something it has been overpaid
      // for, and no figure anywhere says so.
      final after = settledPatch(amount: 24480, alreadyPaid: 0, want: 99999);
      expect(after.paidSoFar, 24480);
      expect(after.paid, isTrue);
    });

    test('and an entry worth nothing is never called settled', () {
      final after = settledPatch(amount: 0, alreadyPaid: 0, want: 0);
      expect(after.paid, isFalse);
    });
  });

  group('correcting the amount and the paid flag in one breath', () {
    test('it ends up settled for what it is now worth, not what it was', () {
      // 24,480 typed as credit, corrected to 20,000 and marked paid.
      final after = settledPatch(amount: 20000, alreadyPaid: 0, want: 20000);
      expect(after.paidSoFar, 20000);
      expect(after.paid, isTrue);
    });
  });

  group('when the correction is refused', () {
    test('a receipt stands against it, so the receipt is the honest fix', () {
      final said = settledChangeRefusal(txn: _feed(), takenAgainst: 8000);
      expect(said, isNotNull);
      expect(said, contains('taken against this entry'));
    });

    test('the receipts could not be read, which refuses too', () {
      // -1 is the unreadable answer. Letting a correction through on a
      // figure nobody could read is how two books stop agreeing.
      expect(settledChangeRefusal(txn: _feed(), takenAgainst: -1), isNotNull);
    });

    test('the row is itself the money', () {
      final said = settledChangeRefusal(
        txn: _feed(type: TxnType.payment),
        takenAgainst: 0,
      );
      expect(said, isNotNull);
      expect(said, contains('is the money'));
    });

    test('the period has been settled and shared out', () {
      final said = settledChangeRefusal(
        txn: _feed(),
        takenAgainst: 0,
        periodIsOpen: false,
      );
      expect(said, isNotNull);
      expect(said, contains('already settled'));
    });

    test('and with nothing against it, in an open period, it is allowed', () {
      expect(settledChangeRefusal(txn: _feed(), takenAgainst: 0), isNull);
    });
  });

  group('what the books then read', () {
    test('a part-paid bill is outstanding for the rest', () {
      final bill = _feed(paidSoFar: 8000);
      expect(bill.outstanding, 16480);
      expect(bill.partlyPaid, isTrue);
      expect(bill.isPayable, isTrue);
    });

    test('and a corrected-to-paid bill is owed nothing', () {
      final bill = _feed(paid: true, paidSoFar: 24480);
      expect(bill.outstanding, 0);
      expect(bill.partlyPaid, isFalse);
      expect(bill.isPayable, isFalse);
    });
  });
}
