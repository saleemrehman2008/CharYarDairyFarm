// A month's wages, one line a man — the record the farm asked to keep.
//
// Who was on the list that month, what each was due, what actually went
// out and what is still owed. Built from the ledger every time it is drawn
// rather than stored, so a wage corrected afterwards corrects the sheet
// with it and nobody reads a frozen copy of a figure that has since moved.

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';
import 'package:flutter_test/flutter_test.dart';

var _n = 0;

Employee _man({
  required String name,
  num basic = 24000,
  num allowance = 0,
  String allowanceFor = '',
  DateTime? joined,
  DateTime? left,
}) => Employee(
  id: 'e${_n++}',
  name: name,
  basic: basic,
  allowance: allowance,
  allowanceFor: allowanceFor,
  joinedOn: joined ?? DateTime(2026, 1, 1),
  leftOn: left,
  createdAt: DateTime(2026, 1, 1),
);

Txn _wage({
  required String who,
  required num amount,
  String? wageFor = '2026-11',
  int day = 10,
  String id = '',
}) => Txn(
  id: id.isEmpty ? 'w${_n++}' : id,
  date: DateTime(2026, 11, day),
  monthId: '2026-11',
  type: TxnType.expense,
  party: who,
  category: salariesCategory,
  amount: amount,
  paid: true,
  paidOnCreate: true,
  paidSoFar: amount,
  note: '',
  createdBy: 'u1',
  createdAt: DateTime(2026, 11, day),
  wageFor: wageFor,
);

Txn _tookBack({
  required String who,
  required num amount,
  required String offWage,
}) => Txn(
  id: 'b${_n++}',
  date: DateTime(2026, 11, 30),
  monthId: '2026-11',
  type: TxnType.receipt,
  party: who,
  category: salaryAdvanceBackCategory,
  amount: amount,
  paid: true,
  paidOnCreate: true,
  paidSoFar: amount,
  note: '',
  createdBy: 'u1',
  createdAt: DateTime(2026, 11, 30),
  settlesTxnId: offWage,
);

List<WageLine> _sheet(List<Txn> ledger, List<Employee> staff) => wageSheet(
  ledger,
  staff,
  wageFor: '2026-11',
  from: DateTime(2026, 11, 1),
  to: DateTime(2026, 11, 30),
);

void main() {
  group('a month with nothing paid yet', () {
    final rows = _sheet(const [], [_man(name: 'Gul Din')]);

    test('the man is still on the sheet', () {
      expect(rows, hasLength(1));
      expect(rows.single.who, 'Gul Din');
    });

    test('with the whole month owed', () {
      expect(rows.single.paid, 0);
      expect(rows.single.left, 24000);
      expect(rows.single.settled, isFalse);
    });
  });

  group('a wage handed over in pieces', () {
    final rows = _sheet(
      [
        _wage(who: 'Rafique Gawala', amount: 5000),
        _wage(who: 'Rafique Gawala', amount: 1000, day: 14),
      ],
      [_man(name: 'Rafique Gawala', allowance: 6000, allowanceFor: 'doodh')],
    );

    test('the pieces add up on one line', () {
      expect(rows.single.paid, 6000);
    });

    test('and the month is wage plus allowance', () {
      expect(rows.single.monthly, 30000);
      expect(rows.single.left, 24000);
    });

    test('and the allowance keeps the name it was given', () {
      expect(rows.single.allowanceFor, 'doodh');
    });
  });

  group('what an advance does to the line', () {
    final wage = _wage(who: 'Gul Din', amount: 24000, id: 'wage1');
    final rows = _sheet(
      [wage, _tookBack(who: 'Gul Din', amount: 16000, offWage: 'wage1')],
      [_man(name: 'Gul Din')],
    );

    test('the wage is still the whole wage', () {
      // The cost is the wage, whatever it recovered. What the advance
      // changes is the cash he walked away with.
      expect(rows.single.paid, 24000);
      expect(rows.single.settled, isTrue);
    });

    test('but the sheet says what reached his hand', () {
      expect(rows.single.advanceOff, 16000);
      expect(rows.single.inHand, 8000);
    });
  });

  group('who belongs on the sheet', () {
    test('a man who joined after the month is not on it', () {
      final rows = _sheet(const [], [
        _man(name: 'New Hand', joined: DateTime(2026, 12, 5)),
      ]);
      expect(rows, isEmpty);
    });

    test('a man who left before it began is not on it', () {
      final rows = _sheet(const [], [
        _man(name: 'Gone', left: DateTime(2026, 10, 20)),
      ]);
      expect(rows, isEmpty);
    });

    test('but a man who left during it is', () {
      // He worked part of the month and is owed for it, so a sheet that
      // dropped him would be a sheet somebody has to argue with.
      final rows = _sheet(const [], [
        _man(name: 'Left Midway', left: DateTime(2026, 11, 18)),
      ]);
      expect(rows, hasLength(1));
    });
  });

  group('the sheet as a whole', () {
    final rows = _sheet(
      [
        _wage(who: 'Gul Din', amount: 24000),
        _wage(who: 'Rafique Gawala', amount: 5000),
      ],
      [
        _man(name: 'Gul Din'),
        _man(name: 'Rafique Gawala', allowance: 6000),
        _man(name: 'Chhotu', basic: 12000),
      ],
    );

    test('lists everybody on the wage list that month', () {
      expect(rows, hasLength(3));
    });

    test('biggest month first, so the eye starts where the money is', () {
      expect(rows.first.who, 'Rafique Gawala');
      expect(rows.first.monthly, 30000);
      expect(rows.last.who, 'Chhotu');
    });

    test('and the three totals are what the foot of the page shows', () {
      expect(rows.fold<num>(0, (a, r) => a + r.monthly), 66000);
      expect(rows.fold<num>(0, (a, r) => a + r.paid), 29000);
      expect(rows.fold<num>(0, (a, r) => a + r.left), 37000);
    });
  });
}
