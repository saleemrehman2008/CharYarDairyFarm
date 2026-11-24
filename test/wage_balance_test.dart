// A wage handed over in pieces, and the balance that keeps track of it.
//
// The farm pays Rafique five thousand one week and a thousand the next, and
// the form used to ask for the whole month's wage every time with nothing
// on the screen to say what had already gone out. So it was held in
// somebody's head, and a month paid twice looked exactly like a month paid
// once.
//
// Every wage entry now carries the month it is for, so the pieces find each
// other however they happen to be dated — November's wage handed over on
// the 3rd of December is still November's. Entries written before this have
// no such mark and fall back to the old way of looking: the days around
// them.

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';
import 'package:flutter_test/flutter_test.dart';

var _n = 0;

Txn _wage({
  required num amount,
  String who = 'Rafique Gawala',
  String? wageFor = '2026-11',
  int month = 11,
  int day = 10,
  bool deleted = false,
}) => Txn(
  id: 'w${_n++}',
  date: DateTime(2026, month, day),
  monthId: '2026-${month.toString().padLeft(2, '0')}',
  type: TxnType.expense,
  party: who,
  category: salariesCategory,
  amount: amount,
  paid: true,
  paidOnCreate: true,
  paidSoFar: amount,
  note: '',
  createdBy: 'u1',
  createdAt: DateTime(2026, month, day),
  wageFor: wageFor,
  deletedAt: deleted ? DateTime(2026, 11, 20) : null,
);

num _paid(List<Txn> ledger, {String who = 'Rafique Gawala'}) => wagePaidSoFar(
  ledger,
  who: who,
  wageFor: '2026-11',
  from: DateTime(2026, 11, 1),
  to: DateTime(2026, 11, 30),
);

void main() {
  group('a wage paid in pieces', () {
    test('nothing out yet, so the whole month is still to pay', () {
      expect(_paid(const []), 0);
      expect(wageLeftToPay(monthly: 30000, paidSoFar: 0), 30000);
    });

    test('five thousand goes out and the balance comes down by it', () {
      final ledger = [_wage(amount: 5000)];
      expect(_paid(ledger), 5000);
      expect(wageLeftToPay(monthly: 30000, paidSoFar: 5000), 25000);
    });

    test('then a thousand more, and the pieces add up', () {
      // The morning this came from: 5,000 then 1,000 against a 24,000 wage
      // with 6,000 of milk allowance on top.
      final ledger = [_wage(amount: 5000), _wage(amount: 1000, day: 14)];
      expect(_paid(ledger), 6000);
      expect(wageLeftToPay(monthly: 30000, paidSoFar: 6000), 24000);
    });

    test('and the month closes when the rest goes out', () {
      final ledger = [
        _wage(amount: 5000),
        _wage(amount: 1000, day: 14),
        _wage(amount: 24000, day: 30),
      ];
      expect(_paid(ledger), 30000);
      expect(wageLeftToPay(monthly: 30000, paidSoFar: 30000), 0);
    });
  });

  group('which month a piece belongs to', () {
    test('a November wage handed over in December is still November', () {
      // The whole reason the month is written on the entry. Found by date
      // alone, this one fell into December and November looked unpaid.
      final ledger = [_wage(amount: 24000, month: 12, day: 3)];
      expect(_paid(ledger), 24000);
    });

    test("and December's wage is not counted against November", () {
      final ledger = [
        _wage(amount: 5000),
        _wage(amount: 30000, wageFor: '2026-12', month: 12, day: 2),
      ];
      expect(_paid(ledger), 5000);
    });
  });

  group('entries written before the month was recorded', () {
    test('fall back to the days around them', () {
      final old = _wage(amount: 7000, wageFor: null, day: 12);
      expect(_paid([old]), 7000);
    });

    test('and one dated outside the month is left alone', () {
      final old = _wage(amount: 7000, wageFor: null, month: 10, day: 12);
      expect(_paid([old]), 0);
    });

    test('a month holding some of each still adds up once', () {
      // The fallback only picks up rows carrying no mark of their own, so
      // nothing is counted twice while the books hold both kinds.
      final ledger = [
        _wage(amount: 5000),
        _wage(amount: 1000, wageFor: null, day: 14),
      ];
      expect(_paid(ledger), 6000);
    });
  });

  group('what is left out', () {
    test('another man\'s wage', () {
      final ledger = [_wage(amount: 5000, who: 'Gul Din')];
      expect(_paid(ledger), 0);
    });

    test('an entry taken off the books', () {
      final ledger = [_wage(amount: 5000), _wage(amount: 9000, deleted: true)];
      expect(_paid(ledger), 5000);
    });

    test('and an advance, which is lent and not wages paid', () {
      final advance = Txn(
        id: 'a1',
        date: DateTime(2026, 11, 8),
        monthId: '2026-11',
        type: TxnType.payment,
        party: 'Rafique Gawala',
        category: salaryAdvanceCategory,
        amount: 4000,
        paid: true,
        paidOnCreate: true,
        paidSoFar: 4000,
        note: '',
        createdBy: 'u1',
        createdAt: DateTime(2026, 11, 8),
      );
      expect(_paid([_wage(amount: 5000), advance]), 5000);
    });
  });

  group('the balance never goes below nothing', () {
    test('a month overpaid shows no negative still-to-pay', () {
      expect(wageLeftToPay(monthly: 30000, paidSoFar: 34000), 0);
    });
  });

  group('the allowance is part of the month', () {
    test('so the balance is worked out on wage plus allowance', () {
      // 24,000 wage and 6,000 for the milk. Paying 5,000 leaves 25,000,
      // not 19,000 — which is what it would be on the wage alone.
      final man = Employee(
        id: 'e1',
        name: 'Rafique Gawala',
        basic: 24000,
        allowance: 6000,
        allowanceFor: 'doodh',
        joinedOn: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );
      expect(man.monthly, 30000);
      expect(wageLeftToPay(monthly: man.monthly, paidSoFar: 5000), 25000);
    });

    test('and the allowance carries the name it was given', () {
      final man = Employee(
        id: 'e2',
        name: 'Rafique Gawala',
        basic: 24000,
        allowance: 6000,
        allowanceFor: 'doodh',
        joinedOn: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );
      expect(man.allowanceFor, 'doodh');
      expect(man.copyWith(allowance: 7000).allowanceFor, 'doodh');
    });
  });
}
