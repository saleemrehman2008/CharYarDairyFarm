// The day-by-day columns, and the share written beside a bar.
//
// The farm opened Report and found the day chart empty — fifty days of real
// trading drawn as dust along the floor, because one buffalo bought for
// lakhs set the height of every bar. The columns now leave out what the
// farm keeps and what it has only lent, so what is drawn is the trading.

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/widgets/day_chart.dart';
import 'package:flutter_test/flutter_test.dart';

var _n = 0;

Txn _row({
  required TxnType type,
  required String category,
  required num amount,
  int day = 14,
}) => Txn(
  id: 'd${_n++}',
  date: DateTime(2026, 10, day),
  monthId: '2026-10',
  type: type,
  party: 'Somebody',
  category: category,
  amount: amount,
  paid: true,
  paidOnCreate: true,
  paidSoFar: amount,
  note: '',
  createdBy: 'u1',
  createdAt: DateTime(2026, 10, day),
);

Txn _milk(num amount, {int day = 14}) =>
    _row(type: TxnType.sale, category: milkCategory, amount: amount, day: day);

Txn _feed(num amount, {int day = 14}) => _row(
  type: TxnType.purchase,
  category: 'Fodder / feed',
  amount: amount,
  day: day,
);

Txn _buffalo(num amount, {int day = 14}) => _row(
  type: TxnType.purchase,
  category: 'Cattle purchase',
  amount: amount,
  day: day,
);

Txn _advance(num amount, {int day = 14}) => _row(
  type: TxnType.payment,
  category: salaryAdvanceCategory,
  amount: amount,
  day: day,
);

void main() {
  group('what a day column counts', () {
    test('milk sold and feed bought, which is the trading', () {
      final days = dayTotals([_milk(9000), _feed(4000)]);
      expect(days, hasLength(1));
      expect(days.single.income, 9000);
      expect(days.single.spend, 4000);
    });

    test('and not a buffalo, which the farm still has', () {
      final days = dayTotals([_milk(9000), _feed(4000), _buffalo(250000)]);
      expect(days.single.spend, 4000);
    });

    test('and not an advance, which is lent and not spent', () {
      final days = dayTotals([_milk(9000), _feed(4000), _advance(16000)]);
      expect(days.single.spend, 4000);
    });

    test('so one big purchase cannot flatten the rest', () {
      // The fault as the farm met it: an ordinary day beside a cattle day.
      final rows = [
        _milk(9000, day: 1),
        _feed(4000, day: 1),
        _buffalo(250000, day: 2),
        _milk(11000, day: 2),
      ];
      final days = dayTotals(rows);
      final peak = days.fold<num>(0, (a, d) => d.most > a ? d.most : a);
      expect(peak, 11000);
      // Before the change the peak was the buffalo, and a 9,000 day drew
      // at 3.6% of the column height. Now it draws at 82%.
      expect(days.first.most / peak, greaterThan(0.8));
    });

    test('a row taken off the books is in none of it', () {
      final gone = Txn(
        id: 'x1',
        date: DateTime(2026, 10, 14),
        monthId: '2026-10',
        type: TxnType.sale,
        party: 'Somebody',
        category: milkCategory,
        amount: 5000,
        paid: true,
        paidOnCreate: true,
        paidSoFar: 5000,
        note: '',
        createdBy: 'u1',
        createdAt: DateTime(2026, 10, 14),
        deletedAt: DateTime(2026, 10, 15),
      );
      expect(dayTotals([_milk(9000), gone]).single.income, 9000);
    });

    test('nothing to draw is an empty list, not a row of noughts', () {
      expect(dayTotals(const []), isEmpty);
      expect(dayTotals([_buffalo(250000)]), isEmpty);
    });
  });

  group('the share written beside a bar', () {
    test('rounds to a whole per cent where that is honest', () {
      expect(pct(0.51), '51%');
      expect(pct(0.5), '50%');
      expect(pct(1), '100%');
    });

    test('but never rounds something real down to nothing', () {
      // A heading worth four thousand out of three lakh is 1.3%, and
      // writing 0% against a real figure is how a page loses trust.
      expect(pct(0.004), '0.4%');
      expect(pct(0.0009), '0.1%');
    });

    test('and nothing is nothing', () {
      expect(pct(0), '0%');
    });
  });
}
