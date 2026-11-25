// The books, checked against themselves.
//
// Everything in here is a thing that cannot be true at the same time as
// something else in the same books — not a thing that merely looks unusual.
// A page that cries wolf is a page nobody opens the month something is
// actually wrong, so the quiet half of these tests matters as much as the
// loud half: an ordinary farm's ordinary month must come back clean.

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/audit.dart';
import 'package:flutter_test/flutter_test.dart';

var _n = 0;

Txn _row({
  required TxnType type,
  required String category,
  required num amount,
  String party = 'Amir Dairy',
  int month = 11,
  int day = 10,
  int year = 2026,
  num? paidSoFar,
  bool? paid,
  bool deleted = false,
  String? settles,
  String? pairId,
  String? takeId,
  String? id,
}) {
  final on = DateTime(year, month, day);
  final so = paidSoFar ?? amount;
  return Txn(
    id: id ?? 'a${_n++}',
    date: on,
    monthId: '$year-${month.toString().padLeft(2, '0')}',
    type: type,
    party: party,
    category: category,
    amount: amount,
    paid: paid ?? (so >= amount),
    paidOnCreate: so >= amount,
    paidSoFar: so,
    note: '',
    createdBy: 'u1',
    createdAt: on,
    settlesTxnId: settles,
    pairId: pairId,
    takeId: takeId,
    deletedAt: deleted ? DateTime(year, month, 25) : null,
  );
}

Txn _sale(num amount, {int day = 10, String? id, num? paidSoFar}) => _row(
  type: TxnType.sale,
  category: milkCategory,
  amount: amount,
  day: day,
  id: id,
  paidSoFar: paidSoFar,
);

/// An ordinary month, with nothing wrong in it.
List<Txn> _ordinary() => [
  for (var d = 1; d <= 20; d++) _sale(1000 + d * 10, day: d),
  _row(
    type: TxnType.expense,
    category: 'Fodder / feed',
    amount: 40000,
    party: 'Wande wala',
    day: 4,
  ),
  _row(
    type: TxnType.expense,
    category: salariesCategory,
    amount: 30000,
    party: 'Rafique Gawala',
    day: 19,
  ),
];

bool _found(AuditResult r, AuditCheck c) => r.notes.any((n) => n.check == c);

AuditNote _note(AuditResult r, AuditCheck c) =>
    r.notes.firstWhere((n) => n.check == c);

AuditResult _audit(List<Txn> rows) =>
    auditTheBooks(rows, today: DateTime(2026, 11, 30));

void main() {
  group('an ordinary month', () {
    test('comes back clean', () {
      final r = _audit(_ordinary());
      expect(r.clean, isTrue, reason: r.notes.map((n) => n.check).join(', '));
      expect(r.checked, 22);
    });

    test('and an entry taken off the books is not read at all', () {
      final r = _audit([
        ..._ordinary(),
        _row(
          type: TxnType.sale,
          category: milkCategory,
          amount: 99999,
          paidSoFar: 200000,
          deleted: true,
        ),
      ]);
      expect(r.clean, isTrue);
      expect(r.checked, 22);
    });
  });

  group('more taken than the entry is for', () {
    test('is found, with the difference', () {
      final r = _audit([..._ordinary(), _sale(5000, paidSoFar: 8000)]);
      expect(_note(r, AuditCheck.paidPastAmount).amount, 3000);
      expect(_note(r, AuditCheck.paidPastAmount).level, AuditLevel.wrong);
    });
  });

  group('settled on paper but not in money', () {
    test('is found', () {
      final r = _audit([..._ordinary(), _sale(10000, paidSoFar: 4000, day: 7)]);
      // paidSoFar below the amount with paid left to work itself out is an
      // ordinary part-paid entry, not a fault.
      expect(_found(r, AuditCheck.saidPaidStillOwing), isFalse);

      final lying = _row(
        type: TxnType.sale,
        category: milkCategory,
        amount: 10000,
        paidSoFar: 4000,
        paid: true,
      );
      final r2 = _audit([..._ordinary(), lying]);
      expect(_note(r2, AuditCheck.saidPaidStillOwing).amount, 6000);
    });
  });

  group('money settling nothing', () {
    test('is found when the entry it points at has gone', () {
      final r = _audit([
        ..._ordinary(),
        _row(
          type: TxnType.receipt,
          category: 'Khaata receipt',
          amount: 5000,
          settles: 'an-entry-that-is-gone',
        ),
      ]);
      expect(_note(r, AuditCheck.settlesNothing).amount, 5000);
    });

    test('and is not found when it points at a real one', () {
      final r = _audit([
        ..._ordinary(),
        _sale(5000, id: 'parent', paidSoFar: 5000),
        _row(
          type: TxnType.receipt,
          category: 'Khaata receipt',
          amount: 5000,
          settles: 'parent',
        ),
      ]);
      expect(_found(r, AuditCheck.settlesNothing), isFalse);
    });
  });

  group('settled past what it was for', () {
    test('is found', () {
      final r = _audit([
        ..._ordinary(),
        _sale(5000, id: 'p2', paidSoFar: 5000),
        _row(
          type: TxnType.receipt,
          category: 'Khaata receipt',
          amount: 4000,
          settles: 'p2',
        ),
        _row(
          type: TxnType.receipt,
          category: 'Khaata receipt',
          amount: 3000,
          settles: 'p2',
        ),
      ]);
      expect(_note(r, AuditCheck.overSettled).amount, 2000);
    });

    test('but an advance coming back off a wage is not a settlement of it', () {
      // The take-back points at the wage so it can be found again. Counting
      // it here would call every wage with an advance against it broken.
      final wage = _row(
        type: TxnType.expense,
        category: salariesCategory,
        amount: 30000,
        party: 'Rafique Gawala',
        id: 'wage1',
      );
      final r = _audit([
        ..._ordinary(),
        wage,
        _row(
          type: TxnType.receipt,
          category: salaryAdvanceBackCategory,
          amount: 16000,
          party: 'Rafique Gawala',
          settles: 'wage1',
        ),
        _row(
          type: TxnType.receipt,
          category: staffLoanBackCategory,
          amount: 20000,
          party: 'Rafique Gawala',
          settles: 'wage1',
        ),
      ]);
      expect(_found(r, AuditCheck.overSettled), isFalse);
    });
  });

  group('half a handover', () {
    test('is found when only one side is on the books', () {
      final r = _audit([
        ..._ordinary(),
        _row(
          type: TxnType.payment,
          category: 'Handover',
          amount: 8600,
          party: 'Ghulam Ali',
          pairId: 'h1',
        ),
      ]);
      expect(_note(r, AuditCheck.halfHandover).amount, 8600);
    });

    test('and both sides together are not', () {
      final r = _audit([
        ..._ordinary(),
        _row(
          type: TxnType.payment,
          category: 'Handover',
          amount: 8600,
          party: 'Ghulam Ali',
          pairId: 'h2',
        ),
        _row(
          type: TxnType.receipt,
          category: 'Handover',
          amount: 8600,
          party: 'Farm',
          pairId: 'h2',
        ),
      ]);
      expect(_found(r, AuditCheck.halfHandover), isFalse);
    });
  });

  group('a man cannot give back more than he was given', () {
    test('on an advance', () {
      final r = _audit([
        ..._ordinary(),
        _row(
          type: TxnType.expense,
          category: salaryAdvanceCategory,
          amount: 10000,
          party: 'Gul Din',
        ),
        _row(
          type: TxnType.receipt,
          category: salaryAdvanceBackCategory,
          amount: 16000,
          party: 'Gul Din',
        ),
      ]);
      final n = _note(r, AuditCheck.advanceBackPastLent);
      expect(n.amount, 6000);
      expect(n.about, 'Gul Din');
    });

    test('on a loan', () {
      final r = _audit([
        ..._ordinary(),
        _row(
          type: TxnType.payment,
          category: staffLoanCategory,
          amount: 50000,
          party: 'Gul Din',
        ),
        _row(
          type: TxnType.receipt,
          category: staffLoanBackCategory,
          amount: 55000,
          party: 'Gul Din',
        ),
      ]);
      expect(_note(r, AuditCheck.loanBackPastLent).amount, 5000);
    });

    test('and one man paying up fully is not a fault', () {
      final r = _audit([
        ..._ordinary(),
        _row(
          type: TxnType.payment,
          category: staffLoanCategory,
          amount: 50000,
          party: 'Gul Din',
        ),
        _row(
          type: TxnType.receipt,
          category: staffLoanBackCategory,
          amount: 50000,
          party: 'Gul Din',
        ),
      ]);
      expect(_found(r, AuditCheck.loanBackPastLent), isFalse);
    });

    test("and one man's loan is never paid down by another's", () {
      final r = _audit([
        ..._ordinary(),
        _row(
          type: TxnType.payment,
          category: staffLoanCategory,
          amount: 50000,
          party: 'Rafique Gawala',
        ),
        _row(
          type: TxnType.receipt,
          category: staffLoanBackCategory,
          amount: 9000,
          party: 'Gul Din',
        ),
      ]);
      expect(_note(r, AuditCheck.loanBackPastLent).about, 'Gul Din');
      expect(_note(r, AuditCheck.loanBackPastLent).amount, 9000);
    });
  });

  group('the quiet findings', () {
    test('an entry with nothing on it', () {
      final r = _audit([
        ..._ordinary(),
        _row(type: TxnType.expense, category: '', party: '', amount: 2000),
      ]);
      expect(_note(r, AuditCheck.noName).level, AuditLevel.odd);
    });

    test('a date after today', () {
      final r = _audit([..._ordinary(), _sale(3000, day: 30)]);
      expect(_found(r, AuditCheck.future), isFalse);

      final ahead = _audit([
        ..._ordinary(),
        _row(
          type: TxnType.sale,
          category: milkCategory,
          amount: 3000,
          month: 12,
          day: 5,
        ),
      ]);
      expect(_note(ahead, AuditCheck.future).level, AuditLevel.odd);
    });

    test('the same entry twice over, and what the second one is worth', () {
      final twice = _sale(4500, day: 6);
      final r = _audit([..._ordinary(), twice, _sale(4500, day: 6)]);
      final n = _note(r, AuditCheck.twiceOver);
      expect(n.level, AuditLevel.odd);
      expect(n.amount, 4500);
      expect(n.ids.length, 2);
    });

    test('and three of the same says two are spare', () {
      final r = _audit([
        ..._ordinary(),
        _sale(4500, day: 6),
        _sale(4500, day: 6),
        _sale(4500, day: 6),
      ]);
      expect(_note(r, AuditCheck.twiceOver).amount, 9000);
    });

    test('but the days behind one payment are never called twins', () {
      // A handful of money reaches the books as many identical slices on
      // purpose. Calling those duplicates would bury the page in noise.
      final r = _audit([
        ..._ordinary(),
        _row(
          type: TxnType.receipt,
          category: 'Khaata receipt',
          amount: 2000,
          takeId: 't1',
        ),
        _row(
          type: TxnType.receipt,
          category: 'Khaata receipt',
          amount: 2000,
          takeId: 't1',
        ),
      ]);
      expect(_found(r, AuditCheck.twiceOver), isFalse);
    });
  });

  group('the order', () {
    test('puts what cannot be right above what is worth a look', () {
      final r = _audit([
        ..._ordinary(),
        _sale(4500, day: 6),
        _sale(4500, day: 6),
        _sale(5000, paidSoFar: 9000),
      ]);
      expect(r.notes.first.level, AuditLevel.wrong);
      expect(r.notes.last.level, AuditLevel.odd);
      expect(r.wrong.length, 1);
      expect(r.odd.length, 1);
    });
  });

  group('nothing at all', () {
    test('is clean, and says it read nothing', () {
      final r = _audit(const []);
      expect(r.clean, isTrue);
      expect(r.checked, 0);
    });
  });
}
