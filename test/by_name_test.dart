import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';

/// A line per name, and what that line comes to.
///
/// The farm read its ledger as one long column in date order and could not
/// answer the question it opens the page to ask: how much does Babar owe.
/// Twenty-one of his entries, in three places down the page, and nothing
/// anywhere adding them up.
///
/// These are the sums behind the new page: how entries fall into names,
/// what each name's figure is on each side, and the order they come out
/// in. The drawing of it is the easy half; getting a name's total wrong is
/// how four partners stop believing a page.

var _n = 0;

Txn _txn({
  required TxnType type,
  required num amount,
  String party = 'Babar Dairy',
  String category = 'Milk',
  num paidSoFar = 0,
  bool paid = false,
  required int day,
}) => Txn(
  id: 'n${_n++}',
  date: DateTime(2026, 10, day),
  monthId: '2026-10',
  type: type,
  party: party,
  category: category,
  amount: amount,
  paid: paid,
  paidOnCreate: paid,
  paidSoFar: paidSoFar,
  note: '',
  createdBy: 'u1',
  createdAt: DateTime(2026, 10, day),
);

/// Entries into names, the way the page groups them.
({List<String> order, Map<String, List<Txn>> held}) _group(List<Txn> rows) {
  final held = <String, List<Txn>>{};
  final names = <String, String>{};
  for (final txn in rows) {
    final said = txn.party.trim().isEmpty ? txn.category : txn.party.trim();
    final key = partyKey(said);
    held.putIfAbsent(key, () => []).add(txn);
    names[key] = said;
  }
  for (final list in held.values) {
    list.sort((a, b) => b.date.compareTo(a.date));
  }
  final keys = held.keys.toList()
    ..sort((a, b) => held[b]!.first.date.compareTo(held[a]!.first.date));
  return (order: [for (final k in keys) names[k]!], held: held);
}

num _owedBy(List<Txn> mine) => mine.fold<num>(0, (a, t) => a + t.outstanding);

num _movedBy(List<Txn> mine) =>
    mine.fold<num>(0, (a, t) => a + (t.type.isIncoming ? t.amount : -t.amount));

void main() {
  group('entries fall into names', () {
    test('one name gathers every entry of its own', () {
      final rows = [
        _txn(type: TxnType.sale, amount: 2000, day: 20),
        _txn(type: TxnType.sale, amount: 1600, day: 19),
        _txn(
          type: TxnType.purchase,
          amount: 9300,
          party: 'Riaz Memon',
          day: 10,
        ),
      ];
      final g = _group(rows);
      expect(g.order, ['Babar Dairy', 'Riaz Memon']);
      expect(g.held[partyKey('Babar Dairy')], hasLength(2));
      expect(g.held[partyKey('Riaz Memon')], hasLength(1));
    });

    test('one spelling, however it was typed', () {
      // The thing the books have always done: a name is one name, and
      // "babar dairy" is not a second customer.
      final rows = [
        _txn(type: TxnType.sale, amount: 2000, party: 'Babar Dairy', day: 20),
        _txn(type: TxnType.sale, amount: 1600, party: 'babar dairy', day: 19),
      ];
      expect(_group(rows).order, hasLength(1));
    });

    test('an entry with no name goes under what it was for', () {
      // Electricity, a month's salary, a load of chara bought off a man
      // nobody wrote down. They keep their own line — the farm chose that
      // over a bag marked other, because a name is a name.
      final rows = [
        _txn(
          type: TxnType.expense,
          amount: 23150,
          party: '',
          category: 'Bijli ka bill',
          day: 16,
          paid: true,
          paidSoFar: 23150,
        ),
      ];
      expect(_group(rows).order, ['Bijli ka bill']);
    });
  });

  group('what a name comes to', () {
    test('still owed is what is left on it, not what it was', () {
      // Two sales of 2,000, one of them half collected.
      final mine = [
        _txn(type: TxnType.sale, amount: 2000, day: 20),
        _txn(type: TxnType.sale, amount: 2000, paidSoFar: 1200, day: 19),
      ];
      expect(_owedBy(mine), 2800);
    });

    test('and nothing is owed once it is all in', () {
      final mine = [
        _txn(
          type: TxnType.sale,
          amount: 2000,
          paidSoFar: 2000,
          paid: true,
          day: 20,
        ),
      ];
      expect(_owedBy(mine), 0);
    });

    test('done with counts which way the money went', () {
      // A supplier the farm bought from and paid: the purchase and the
      // payment are both money out, and the line says so.
      final mine = [
        _txn(
          type: TxnType.purchase,
          amount: 5800,
          party: 'Khalid Kutar',
          paid: true,
          paidSoFar: 5800,
          day: 30,
        ),
        _txn(
          type: TxnType.payment,
          amount: 5800,
          party: 'Khalid Kutar',
          paid: true,
          paidSoFar: 5800,
          day: 30,
        ),
      ];
      expect(_movedBy(mine), -11600);
    });

    test('and money in reads the other way', () {
      final mine = [
        _txn(
          type: TxnType.receipt,
          amount: 43000,
          paid: true,
          paidSoFar: 43000,
          day: 31,
        ),
      ];
      expect(_movedBy(mine), 43000);
    });
  });

  group('the order they come out in', () {
    test('the name something last happened with is at the top', () {
      final rows = [
        _txn(type: TxnType.sale, amount: 1000, party: 'Urooj', day: 12),
        _txn(type: TxnType.sale, amount: 1000, party: 'Babar Dairy', day: 20),
        _txn(type: TxnType.purchase, amount: 1100, party: 'Gaah', day: 30),
      ];
      expect(_group(rows).order, ['Gaah', 'Babar Dairy', 'Urooj']);
    });

    test('and the newest day is at the top inside a name', () {
      final rows = [
        _txn(type: TxnType.sale, amount: 1000, day: 12),
        _txn(type: TxnType.sale, amount: 1000, day: 20),
        _txn(type: TxnType.sale, amount: 1000, day: 18),
      ];
      final mine = _group(rows).held[partyKey('Babar Dairy')]!;
      expect([for (final t in mine) t.date.day], [20, 18, 12]);
    });

    test('a name is placed by its newest, not by one old entry', () {
      // Urooj traded on the 12th and again on the 31st; he belongs at the
      // top, not down beside the 12th.
      final rows = [
        _txn(type: TxnType.sale, amount: 1000, party: 'Urooj', day: 12),
        _txn(type: TxnType.sale, amount: 1000, party: 'Urooj', day: 31),
        _txn(type: TxnType.sale, amount: 1000, party: 'Babar Dairy', day: 20),
      ];
      expect(_group(rows).order.first, 'Urooj');
    });
  });

  group('nothing is lost between the sections', () {
    test('every entry lands in exactly one name', () {
      final rows = [
        _txn(type: TxnType.sale, amount: 2000, day: 20),
        _txn(type: TxnType.sale, amount: 1600, party: 'Urooj', day: 19),
        _txn(type: TxnType.purchase, amount: 1100, party: 'Gaah', day: 30),
        _txn(type: TxnType.expense, amount: 500, party: '', day: 18),
      ];
      final g = _group(rows);
      final counted = g.held.values.fold<int>(0, (a, l) => a + l.length);
      expect(counted, rows.length);
    });

    test('and the section total is the sum of its names', () {
      final rows = [
        _txn(type: TxnType.sale, amount: 2000, day: 20),
        _txn(type: TxnType.sale, amount: 1600, party: 'Urooj', day: 19),
      ];
      final g = _group(rows);
      final byName = g.held.values.fold<num>(0, (a, l) => a + _owedBy(l));
      expect(byName, _owedBy(rows));
      expect(byName, 3600);
    });
  });
}
