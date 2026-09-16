import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';
import 'package:char_yar_dairy_farm/util/money.dart';

/// Ali takes milk on credit every day and pays when he has it — which is
/// rarely the exact figure he owes.
///
/// The rule the whole thing rests on: **jo mila + jo baqi = jo becha tha.**
/// Whatever the money does on the way in, those two have to add back up to
/// what was sold, on every entry and across all of them together. These tests
/// walk his account through four days, two part payments and a final
/// settling-up, checking that at every step.
///
/// The allocation itself lives in `TxnRepo.settle`, which writes to Firestore.
/// What is worked out here is the same arithmetic, so a mistake in the rule
/// shows up as a failing test rather than as a founder's missing rupees.

var _n = 0;

Txn _sale({
  required num amount,
  required int day,
  num paidSoFar = 0,
  num litres = 80,
}) => Txn(
  id: 'txn${_n++}',
  date: DateTime(2026, 9, day),
  monthId: '2026-09',
  type: TxnType.sale,
  party: 'Ali',
  category: 'Milk',
  qty: litres,
  unit: 'L',
  rate: amount / litres,
  amount: amount,
  paid: paidSoFar >= amount,
  paidSoFar: paidSoFar,
  note: '',
  createdBy: 'u',
  createdAt: DateTime(2026, 9, day),
);

/// What `TxnRepo.settle` does to the entries, without the database: fill the
/// oldest first and stop part way through whichever one the money runs out on.
List<Txn> _take(List<Txn> entries, num purse) {
  final owing = entries.where((t) => t.outstanding > 0).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final byId = {for (final t in entries) t.id: t};

  for (final t in owing) {
    if (purse <= 0) break;
    final take = purse < t.outstanding ? purse : t.outstanding;
    purse -= take;
    byId[t.id] = _sale(
      amount: t.amount,
      day: t.date.day,
      paidSoFar: t.paidSoFar + take,
      litres: t.qty ?? 80,
    );
  }
  // Keep them in the order they were handed in.
  return [for (final t in entries) byId[t.id]!];
}

void main() {
  group('one entry, part of it paid', () {
    final entry = _sale(amount: 40000, day: 12, paidSoFar: 15000);

    test('it knows what came and what is still to come', () {
      expect(entry.paidSoFar, 15000);
      expect(entry.outstanding, 25000);
      expect(entry.paid, isFalse);
      expect(entry.partlyPaid, isTrue);
    });

    test('it is a receivable for what is left, not for the whole of it', () {
      final books = Books(
        monthId: '2026-09',
        openingCash: 0,
        capital: 0,
        monthTxns: [entry],
        unpaidTxns: [entry],
      );
      expect(books.receivable, 25000, reason: 'not 40,000 — 15,000 has come');
      expect(books.sales, 40000, reason: 'he still bought 40,000 of milk');
    });

    test('what came and what is left always make what was sold', () {
      expect(entry.paidSoFar + entry.outstanding, entry.amount);
    });
  });

  group("Ali's four days, paid in two goes", () {
    // Four days at 40,000 each. 1,60,000 of milk on credit.
    final days = [
      _sale(amount: 40000, day: 12),
      _sale(amount: 40000, day: 13),
      _sale(amount: 40000, day: 14),
      _sale(amount: 40000, day: 15),
    ];

    test('he owes all of it to start with', () {
      expect(days.fold<num>(0, (a, t) => a + t.outstanding), 160000);
    });

    test('1,00,000 against the first three fills two and a half', () {
      final after = _take(days.take(3).toList(), 100000);

      expect(after[0].outstanding, 0, reason: '12 Sep, paid in full');
      expect(after[1].outstanding, 0, reason: '13 Sep, paid in full');
      expect(after[2].paidSoFar, 20000, reason: '14 Sep, half of it');
      expect(after[2].outstanding, 20000);
      expect(after[2].partlyPaid, isTrue);

      // Nothing made up, nothing lost.
      expect(after.fold<num>(0, (a, t) => a + t.paidSoFar), 100000);
      expect(after.fold<num>(0, (a, t) => a + t.outstanding), 20000);
    });

    test('the part paid one is then the oldest still owing', () {
      final after = _take(days.take(3).toList(), 100000);
      final owing = after.where((t) => t.outstanding > 0).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      expect(owing.first.date.day, 14);
    });

    test('the next payment fills that one before it touches any other', () {
      var all = [..._take(days.take(3).toList(), 100000), days[3]];
      // He comes back with 30,000.
      all = _take(all, 30000);

      expect(all[2].outstanding, 0, reason: '14 Sep finished off first');
      expect(all[3].paidSoFar, 10000, reason: 'then 10,000 onto 15 Sep');
      expect(all[3].outstanding, 30000);
    });

    test('paying the lot leaves nothing owing and nothing over', () {
      final all = _take(days, 160000);
      expect(all.every((t) => t.paid), isTrue);
      expect(all.fold<num>(0, (a, t) => a + t.outstanding), 0);
      expect(all.fold<num>(0, (a, t) => a + t.paidSoFar), 160000);
    });

    test('more than he owes settles the lot and no more', () {
      // The screen holds this down before it gets here; the arithmetic has to
      // hold it too, or a slipped digit becomes a credit nobody can explain.
      final all = _take(days, 999999);
      expect(all.fold<num>(0, (a, t) => a + t.paidSoFar), 160000);
      expect(all.every((t) => t.paidSoFar <= t.amount), isTrue);
    });

    test('paid or half paid, the books never lose a rupee', () {
      for (final purse in [0, 1, 19999, 40000, 100000, 160000]) {
        final all = _take(days, purse);
        for (final t in all) {
          expect(
            t.paidSoFar + t.outstanding,
            t.amount,
            reason: 'entry of ${t.date.day} Sep after $purse',
          );
        }
        expect(
          all.fold<num>(0, (a, t) => a + t.paidSoFar) +
              all.fold<num>(0, (a, t) => a + t.outstanding),
          160000,
          reason: 'after taking $purse',
        );
      }
    });
  });

  group('an entry written before part payments were kept', () {
    test('settled means the whole of it', () {
      final old = Txn(
        id: 'old',
        date: DateTime(2026, 8, 1),
        monthId: '2026-08',
        type: TxnType.sale,
        party: 'Ali',
        category: 'Milk',
        amount: 40000,
        paid: true,
        note: '',
        createdBy: 'u',
        createdAt: DateTime(2026, 8, 1),
      );
      expect(old.paidSoFar, 40000);
      expect(old.outstanding, 0);
      expect(old.partlyPaid, isFalse);
    });

    test('unsettled means none of it', () {
      final old = Txn(
        id: 'old2',
        date: DateTime(2026, 8, 1),
        monthId: '2026-08',
        type: TxnType.sale,
        party: 'Ali',
        category: 'Milk',
        amount: 40000,
        paid: false,
        note: '',
        createdBy: 'u',
        createdAt: DateTime(2026, 8, 1),
      );
      expect(old.paidSoFar, 0);
      expect(old.outstanding, 40000);
    });
  });

  group('money written the way it is said', () {
    test('the figures a milk round actually deals in', () {
      expect(rsInWords(120000), 'Ek lakh bees hazaar rupay');
      expect(rsInWords(100000), 'Ek lakh rupay');
      expect(rsInWords(20000), 'Bees hazaar rupay');
      expect(rsInWords(40000), 'Chalees hazaar rupay');
      // Written the way it goes on a receipt, not the way it is said across a
      // counter — "solah sau" is how anybody would say 1,600 out loud, and
      // "ek hazaar chhe sau" is how it is written down.
      expect(rsInWords(1600), 'Ek hazaar chhe sau rupay');
    });

    test('an awkward one, down to the last rupee', () {
      expect(rsInWords(123456), 'Ek lakh teis hazaar chaar sau chhappan rupay');
    });

    test('the big end of the scale', () {
      expect(rsInWords(10000000), 'Ek crore rupay');
      expect(rsInWords(2500000), 'Pachees lakh rupay');
    });

    test('nothing is nothing', () {
      expect(rsInWords(0), 'sifar rupay');
    });
  });
}
