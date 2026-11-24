// A loan to somebody on the wage list.
//
// The farm keeps it apart from a wage advance because the men do: an
// advance is this month's wage taken early, a loan is a sum borrowed
// against the months to come at a figure agreed once. To the money they
// are the same thing — out of the cash, into his pocket, back off a wage —
// so the loan walks the advance's road exactly, and every figure that had
// to hold the advance out holds the loan out too.

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';
import 'package:flutter_test/flutter_test.dart';

var _n = 0;

Txn _row({
  required TxnType type,
  required String category,
  required num amount,
  String who = 'Rafique Gawala',
  int month = 11,
  int day = 10,
  bool deleted = false,
  String? settles,
}) => Txn(
  id: 'l${_n++}',
  date: DateTime(2026, month, day),
  monthId: '2026-${month.toString().padLeft(2, '0')}',
  type: type,
  party: who,
  category: category,
  amount: amount,
  paid: true,
  paidOnCreate: true,
  paidSoFar: amount,
  note: '',
  createdBy: 'u1',
  createdAt: DateTime(2026, month, day),
  settlesTxnId: settles,
  deletedAt: deleted ? DateTime(2026, 11, 20) : null,
);

Txn _lent(num amount, {String who = 'Rafique Gawala', bool deleted = false}) =>
    _row(
      type: TxnType.payment,
      category: staffLoanCategory,
      amount: amount,
      who: who,
      deleted: deleted,
    );

Txn _back(num amount, {String who = 'Rafique Gawala'}) => _row(
  type: TxnType.receipt,
  category: staffLoanBackCategory,
  amount: amount,
  who: who,
  day: 30,
);

num _owed(List<Txn> ledger, {String who = 'Rafique Gawala'}) =>
    staffLoanOwed(ledger, who: who);

void main() {
  group('what a loan does to the books', () {
    final loan = _lent(50000);

    test('it is not a cost — the farm still owns it', () {
      // The money is in his pocket rather than in the box. The cash goes
      // down; the profit does not move.
      expect(loan.isRunningCost, isFalse);
      expect(loan.isLoosePayment, isFalse);
      expect(loan.isStaffLoan, isTrue);
    });

    test('and an instalment coming back is not income', () {
      // The farm is getting its own money back, not earning any.
      final back = _back(5000);
      expect(back.isStaffLoanBack, isTrue);
      expect(back.isLooseReceipt, isFalse);
    });

    test('so the month that lent it is no dearer for having done so', () {
      final books = Books(
        monthId: '2026-11',
        openingCash: 0,
        capital: 0,
        monthTxns: [loan, _back(5000)],
        unpaidTxns: const [],
      );
      expect(books.costs, 0);
      expect(books.otherIncome, 0);
    });
  });

  group('the balance', () {
    test('is what went out, before anything comes back', () {
      expect(_owed([_lent(50000)]), 50000);
    });

    test('comes down by each instalment', () {
      expect(_owed([_lent(50000), _back(5000), _back(5000)]), 40000);
    });

    test('and reaches nothing when the last one is taken', () {
      expect(_owed([_lent(10000), _back(10000)]), 0);
    });

    test('never below nothing, however it was recovered', () {
      // A man recovered from twice is a thing to look at on the entries,
      // not a negative balance quietly paying down nothing.
      expect(_owed([_lent(10000), _back(10000), _back(5000)]), 0);
    });

    test('and a row taken off the books is in none of it', () {
      expect(_owed([_lent(50000), _lent(9000, deleted: true)]), 50000);
    });

    test("and another man's loan is his own", () {
      final ledger = [_lent(50000), _lent(20000, who: 'Gul Din')];
      expect(_owed(ledger), 50000);
      expect(_owed(ledger, who: 'Gul Din'), 20000);
    });
  });

  group('a loan and an advance stand apart', () {
    final ledger = [
      _lent(50000),
      _row(
        type: TxnType.payment,
        category: salaryAdvanceCategory,
        amount: 16000,
      ),
    ];

    test('the loan balance does not count the advance', () {
      expect(_owed(ledger), 50000);
    });

    test('and the advance balance does not count the loan', () {
      expect(advanceOwed(ledger, who: 'Rafique Gawala'), 16000);
    });

    test('which is the point — a man with both can see which is which', () {
      expect(_owed(ledger) + advanceOwed(ledger, who: 'Rafique Gawala'), 66000);
    });
  });

  group('what the whole wage list owes', () {
    test('is every man added up, each held at nothing', () {
      final ledger = [
        _lent(50000),
        _back(5000),
        _lent(20000, who: 'Gul Din'),
        // Gul Din recovered from twice over. His own balance stops at
        // nothing rather than paying down Rafique's.
        _back(25000, who: 'Gul Din'),
      ];
      expect(staffLoansOwed(ledger), 45000);
    });

    test('and nothing at all when nobody has borrowed', () {
      expect(staffLoansOwed(const []), 0);
    });
  });

  group('when he leaves', () {
    final man = Employee(
      id: 'e1',
      name: 'Rafique Gawala',
      basic: 24000,
      allowance: 6000,
      joinedOn: DateTime(2026, 10, 20),
      createdAt: DateTime(2026, 10, 20),
    );

    test('a standing loan counts against him, like an advance', () {
      final plain = settleUp(const [], man, upTo: DateTime(2026, 11, 18));
      final withLoan = settleUp(
        [_lent(5000)],
        man,
        upTo: DateTime(2026, 11, 18),
      );
      expect(withLoan.loanOwed, 5000);
      expect(withLoan.net, plain.net - 5000);
    });

    test('and both of them do, together', () {
      final s = settleUp(
        [
          _lent(5000),
          _row(
            type: TxnType.payment,
            category: salaryAdvanceCategory,
            amount: 3000,
          ),
        ],
        man,
        upTo: DateTime(2026, 11, 18),
      );
      expect(s.loanOwed, 5000);
      expect(s.advanceOwed, 3000);
      expect(s.earned - s.paid - 8000, s.net);
    });
  });

  _whereItGoes();

  group('the agreed instalment', () {
    test('rides on his record, so every wage can offer it', () {
      final man = Employee(
        id: 'e2',
        name: 'Rafique Gawala',
        basic: 24000,
        loanMonthly: 5000,
        joinedOn: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );
      expect(man.loanMonthly, 5000);
      expect(man.copyWith(basic: 26000).loanMonthly, 5000);
    });

    test('and nothing agreed is nothing offered', () {
      final man = Employee(
        id: 'e3',
        name: 'Gul Din',
        basic: 24000,
        joinedOn: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );
      expect(man.loanMonthly, 0);
    });
  });
}

// ---------------------------------------------------------------------------
// Where the deducted money actually goes.
//
// The farm asked it plainly: a wage of 30,000 with 8,000 of advance and
// 5,000 of loan taken off it — the man walks away with 17,000, so where did
// the other 13,000 go?
//
// Nowhere. It never left. The two take-back rows exist so the ledger can
// say both true things at once: the month cost thirty thousand of wages,
// and thirteen thousand of the farm's own money came back off it. The cash
// in the hands that paid the wage moves by exactly what those hands handed
// over, and the profit moves by the wage alone.
void _whereItGoes() {
  group('a wage with both coming off it', () {
    const hands = 'Ghulam Ali';

    Txn row({
      required TxnType type,
      required String category,
      required num amount,
      String? settles,
    }) => Txn(
      id: 'x${_n++}',
      date: DateTime(2026, 12, 31),
      monthId: '2026-12',
      type: type,
      party: 'Rafique Gawala',
      category: category,
      amount: amount,
      paid: true,
      paidOnCreate: true,
      paidSoFar: amount,
      note: '',
      createdBy: 'u1',
      createdAt: DateTime(2026, 12, 31),
      handledBy: hands,
      settlesTxnId: settles,
    );

    final wage = row(
      type: TxnType.expense,
      category: salariesCategory,
      amount: 30000,
    );
    final ledger = [
      wage,
      row(
        type: TxnType.receipt,
        category: salaryAdvanceBackCategory,
        amount: 8000,
        settles: wage.id,
      ),
      row(
        type: TxnType.receipt,
        category: staffLoanBackCategory,
        amount: 5000,
        settles: wage.id,
      ),
    ];

    final books = Books(
      monthId: '2026-12',
      openingCash: 0,
      capital: 0,
      monthTxns: ledger,
      unpaidTxns: const [],
    );

    test('the month is out by the wage, and only the wage', () {
      // Neither take-back is income. The farm got its own money back; it
      // did not earn any.
      expect(books.costs, 30000);
      expect(books.otherIncome, 0);
    });

    test('and the cash is down by what actually left the hands', () {
      // 30,000 out, 13,000 straight back in: seventeen thousand gone,
      // which is what he was handed.
      expect(books.paidExpenses - books.receipts, 17000);
    });

    test('so the hands that paid it are 17,000 lighter, not 30,000', () {
      final held = cashInHands(ledger);
      final his = held.where((h) => partyKey(h.who) == partyKey(hands)).first;
      expect(his.holding, -17000);
    });

    test('and both balances have come down by what was taken', () {
      final withLoan = [...ledger, _lent(50000, who: 'Rafique Gawala')];
      expect(staffLoanOwed(withLoan, who: 'Rafique Gawala'), 45000);
    });

    test('the wage itself is settled in full — it was paid in full', () {
      // The take-back rows point at the wage so they can be found again,
      // not to settle it. Nothing of the 30,000 is still owed to him.
      expect(wage.outstanding, 0);
      expect(wage.paid, isTrue);
    });
  });
}
