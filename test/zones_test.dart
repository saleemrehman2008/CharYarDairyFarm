// Where the money goes, and whether too much of it goes there.
//
// The farm's question: what should rent be, what should running cost be,
// what should be left as profit, and which zone are we overspending in.
// There is no law about it, so the app does the two things it honestly can:
// it splits the spending into zones that add up to exactly what the report
// says went out, and it says which zone is the most rupees past the band a
// dairy usually keeps it inside.

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';
import 'package:char_yar_dairy_farm/services/zones.dart';
import 'package:flutter_test/flutter_test.dart';

var _n = 0;

Txn _row({
  required TxnType type,
  required String category,
  required num amount,
  int day = 10,
  String party = 'Somebody',
  bool deleted = false,
  String? settles,
}) => Txn(
  id: 'z${_n++}',
  date: DateTime(2026, 11, day),
  monthId: '2026-11',
  type: type,
  party: party,
  category: category,
  amount: amount,
  paid: true,
  paidOnCreate: true,
  paidSoFar: amount,
  note: '',
  createdBy: 'u1',
  createdAt: DateTime(2026, 11, day),
  settlesTxnId: settles,
  deletedAt: deleted ? DateTime(2026, 11, 20) : null,
);

Txn _sale(num amount) =>
    _row(type: TxnType.sale, category: milkCategory, amount: amount);

Txn _spent(String category, num amount) =>
    _row(type: TxnType.expense, category: category, amount: amount);

/// A month that behaves: ten lakh of milk, and the costs a dairy has.
List<Txn> _aMonth() => [
  _sale(1000000),
  _spent('Fodder / feed', 550000),
  _spent(salariesCategory, 120000),
  _spent('Rent', 40000),
  _spent('Vet & medicine', 30000),
  _spent('Utilities (bijli, gas, pani)', 50000),
  _spent('Transport', 40000),
  _spent('Repairs', 20000),
];

ZoneLine _line(SpendZones z, Zone zone) =>
    z.lines.firstWhere((l) => l.zone == zone);

void main() {
  group('the zones add up to the money out', () {
    // The one rule this cannot break. Two pages counting the same money two
    // ways is how the farm found a sixteen thousand rupee hole and had to
    // be told which page to believe.
    test('on an ordinary month', () {
      final rows = _aMonth();
      final z = spendZones(rows);
      final report = ReportTotals.of(rows);
      expect(z.spent, report.moneyOut);
      expect(z.sales, report.moneyIn);
      expect(z.profit, report.net);
      expect(z.lines.fold<num>(0, (a, l) => a + l.spent), report.moneyOut);
    });

    test('with a buffalo bought in the middle of it', () {
      // The farm still has her, so she is not a running cost and not in any
      // zone — exactly as the report has it.
      final rows = [
        ..._aMonth(),
        _row(
          type: TxnType.purchase,
          category: 'Cattle purchase',
          amount: 400000,
        ),
      ];
      final z = spendZones(rows);
      expect(z.spent, ReportTotals.of(rows).moneyOut);
      // She did not land in "everything else" either — she landed nowhere,
      // because she is not spent money.
      expect(_line(z, Zone.other).spent, 60000);
    });

    test('with an advance against a wage', () {
      // Lent, not spent. It comes back off the wage.
      final rows = [
        ..._aMonth(),
        _row(
          type: TxnType.expense,
          category: salaryAdvanceCategory,
          amount: 16000,
        ),
      ];
      final z = spendZones(rows);
      expect(z.spent, ReportTotals.of(rows).moneyOut);
      expect(_line(z, Zone.wages).spent, 120000);
    });

    test('with a loan to a farm hand', () {
      // The report does not count it at all, so neither does this.
      final rows = [
        ..._aMonth(),
        _row(type: TxnType.payment, category: staffLoanCategory, amount: 50000),
      ];
      final z = spendZones(rows);
      expect(z.spent, ReportTotals.of(rows).moneyOut);
    });

    test('and an entry taken off the books is in none of it', () {
      final gone = [
        ..._aMonth(),
        _row(
          type: TxnType.expense,
          category: 'Fodder / feed',
          amount: 99000,
          deleted: true,
        ),
      ];
      expect(spendZones(gone).spent, spendZones(_aMonth()).spent);
      expect(spendZones(gone).spent, ReportTotals.of(gone).moneyOut);
    });
  });

  group('what each zone is', () {
    final z = spendZones(_aMonth());

    test('feed is the big one, and first on the list', () {
      expect(z.lines.first.zone, Zone.feed);
      expect(z.lines.first.spent, 550000);
      expect(z.lines.first.share, closeTo(0.55, 0.0001));
    });

    test('wages are second', () {
      expect(z.lines[1].zone, Zone.wages);
      expect(_line(z, Zone.wages).share, closeTo(0.12, 0.0001));
    });

    test('and transport, repairs and the rest are one zone together', () {
      // 40,000 of transport and 20,000 of repairs.
      expect(_line(z, Zone.other).spent, 60000);
    });

    test('a heading nobody listed still lands somewhere', () {
      // An unknown cost is a cost. Dropping it would make the zones stop
      // adding up to the money out, which is the one thing they must do.
      final rows = [..._aMonth(), _spent('Dhobi', 5000)];
      expect(_line(spendZones(rows), Zone.other).spent, 65000);
      expect(spendZones(rows).spent, ReportTotals.of(rows).moneyOut);
    });

    test('and a zone with nothing against it is not a line', () {
      final z = spendZones([_sale(100000), _spent('Fodder / feed', 50000)]);
      expect(z.lines.length, 1);
      expect(z.lines.single.zone, Zone.feed);
    });
  });

  group('the bands', () {
    test('a month inside them has nothing to focus on', () {
      // Feed 55%, wages 12%, rent 4%, vet 3%, power 5%, other 6%.
      expect(spendZones(_aMonth()).focus, isNull);
    });

    test('and a month out of them points at one zone', () {
      final rows = [..._aMonth(), _spent('Fodder / feed', 150000)];
      final z = spendZones(rows);
      // Feed is now 700,000 of 1,000,000 — seventy per cent, where the band
      // stops at sixty-five. Fifty thousand rupees past it.
      expect(z.focus!.zone, Zone.feed);
      expect(z.focus!.over, 50000);
      expect(z.focus!.share, closeTo(0.70, 0.0001));
    });

    test('ranked by rupees and not by how far past the band', () {
      // The vet bill is three times its band; feed is a tenth past its own.
      // Feed is still the one worth going after, because it is more money.
      final rows = [
        ..._aMonth(),
        _spent('Vet & medicine', 90000),
        _spent('Fodder / feed', 110000),
      ];
      final z = spendZones(rows);
      expect(_line(z, Zone.vet).over, 70000); // 120,000 against a 50,000 top
      expect(_line(z, Zone.feed).over, 10000);
      expect(z.focus!.zone, Zone.vet);

      // And with feed properly out of hand, feed wins it back.
      final worse = [...rows, _spent('Fodder / feed', 100000)];
      expect(spendZones(worse).focus!.zone, Zone.feed);
    });

    test('milk bought in has no band, so it never becomes the focus', () {
      // Buying milk to sell on is trading, not a farm cost. The question
      // about it is the margin, and this page does not pretend to answer
      // that.
      final rows = [
        ..._aMonth(),
        _row(
          type: TxnType.purchase,
          category: milkBoughtInCategory,
          amount: 400000,
        ),
      ];
      final z = spendZones(rows);
      expect(_line(z, Zone.milkIn).spent, 400000);
      expect(_line(z, Zone.milkIn).over, 0);
      expect(z.focus, isNull);
    });

    test('under the band is not over it', () {
      final rows = [_sale(1000000), _spent('Vet & medicine', 2000)];
      final z = spendZones(rows);
      expect(_line(z, Zone.vet).over, 0);
      expect(_line(z, Zone.vet).under, isTrue);
    });
  });

  group('what is left', () {
    test('is the profit, and its share of what came in', () {
      final z = spendZones(_aMonth());
      // 1,000,000 in and 850,000 out.
      expect(z.profit, 150000);
      expect(z.profitShare, closeTo(0.15, 0.0001));
      expect(z.spendShare, closeTo(0.85, 0.0001));
    });

    test('and a month that lost money says so', () {
      final rows = [..._aMonth(), _spent('Fodder / feed', 300000)];
      final z = spendZones(rows);
      expect(z.profit, -150000);
      expect(z.profitShare < 0, isTrue);
    });
  });

  group('a month with nothing in it', () {
    test('has no percentages, and does not divide by nothing', () {
      final z = spendZones(const []);
      expect(z.isEmpty, isTrue);
      expect(z.sales, 0);
      expect(z.spent, 0);
      expect(z.profitShare, 0);
      expect(z.spendShare, 0);
      expect(z.focus, isNull);
    });

    test('and spending with no sales shows the figures and no share', () {
      // The percentages would all be infinity. A farm that sold nothing
      // this month still wants to see what it spent.
      final z = spendZones([_spent('Fodder / feed', 50000)]);
      expect(z.spent, 50000);
      expect(z.lines.single.share, 0);
      expect(z.lines.single.over, 0);
      expect(z.focus, isNull);
    });
  });
}
