import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/statement.dart';

/// The statement, read the way a bank statement is read — and the one thing
/// that makes it two statements rather than one.
///
/// A credit sale puts a customer's balance up on the day it happens and does
/// not touch the farm's cash until somebody pays. So one person's account and
/// the farm's cash book cannot share a running total: they part company on
/// exactly that row, and they have to part company, because both answers are
/// right about different questions.

var _n = 0;

Txn _txn({
  required TxnType type,
  required num amount,
  required String party,
  required int day,
  String category = 'Milk',
  bool paid = true,
  String by = 'Ghulam Ali',
}) => Txn(
  id: 'e${_n++}',
  date: DateTime(2026, 9, day),
  monthId: '2026-09',
  type: type,
  party: party,
  category: category,
  amount: amount,
  paid: paid,
  paidOnCreate: paid,
  note: '',
  createdBy: 'u',
  createdByName: by,
  createdAt: DateTime(2026, 9, day),
);

void main() {
  // Ali takes milk on credit and pays some of it. The feed merchant sells to
  // the farm and is paid. One cash sale over the counter.
  final ledger = [
    _txn(type: TxnType.sale, amount: 40000, party: 'Ali', day: 2, paid: false),
    _txn(type: TxnType.sale, amount: 12000, party: 'Counter', day: 3),
    _txn(type: TxnType.sale, amount: 40000, party: 'ali', day: 5, paid: false),
    _txn(
      type: TxnType.purchase,
      amount: 30000,
      party: 'Arbab Traders',
      day: 6,
      category: 'Fodder / feed',
      paid: false,
    ),
    _txn(
      type: TxnType.receipt,
      amount: 50000,
      party: 'ALI',
      day: 9,
      category: 'Khaata receipt',
      by: 'Saleem Rehman',
    ),
    _txn(
      type: TxnType.payment,
      amount: 30000,
      party: 'Arbab Traders',
      day: 11,
      category: 'Supplier payment',
    ),
  ];

  group("one person's account", () {
    final s = buildStatement(rows: ledger, party: 'Ali');

    test('every spelling of the name, and nobody else', () {
      expect(s.forOneParty, isTrue);
      expect(s.lines.length, 3, reason: 'Ali, ali and ALI are one man');
      expect(s.lines.every((l) => l.party.toLowerCase() == 'ali'), isTrue);
    });

    test('milk taken puts the balance up, paid for or not', () {
      expect(s.lines[0].debit, 40000);
      expect(s.lines[0].balance, 40000);
      expect(s.lines[1].balance, 80000);
    });

    test('money handed over brings it down', () {
      expect(s.lines[2].credit, 50000);
      expect(s.lines[2].balance, 30000);
      expect(s.closing, 30000, reason: 'he still owes 30,000');
    });

    test('the two columns and the balance agree', () {
      expect(s.debits - s.credits, s.closing - s.opening);
    });

    test('who typed each one is on the line', () {
      expect(s.lines[2].enteredBy, 'Saleem Rehman');
      expect(s.lines[0].enteredBy, 'Ghulam Ali');
    });
  });

  group("a supplier's account runs the other way", () {
    final s = buildStatement(rows: ledger, party: 'Arbab Traders');

    test('what the farm bought is owed to them', () {
      expect(s.lines[0].credit, 30000);
      expect(s.lines[0].balance, -30000, reason: 'the farm owes them');
    });

    test('paying them clears it', () {
      expect(s.lines[1].debit, 30000);
      expect(s.closing, 0);
    });
  });

  group("the farm's cash book", () {
    final s = buildStatement(rows: ledger, capital: 500000);

    test('it opens at what the co-founders put in', () {
      expect(s.forOneParty, isFalse);
      expect(s.opening, 500000);
    });

    test('a credit sale is not cash and is not in it', () {
      // Two credit sales and one credit purchase are left out; the counter
      // sale, the receipt and the payment are in.
      expect(s.lines.length, 3);
      expect(
        s.lines.any((l) => l.party.toLowerCase() == 'ali' && l.debit > 0),
        isFalse,
      );
    });

    test('the closing balance is the money in the box', () {
      // 500,000 + 12,000 over the counter + 50,000 from Ali − 30,000 to the
      // feed merchant.
      expect(s.closing, 532000);
    });

    test('money in is credit, money out is debit', () {
      final counter = s.lines.firstWhere((l) => l.party == 'Counter');
      expect(counter.credit, 12000);
      expect(counter.debit, 0);
      final paid = s.lines.firstWhere((l) => l.party == 'Arbab Traders');
      expect(paid.debit, 30000);
    });
  });

  group('the two are different on purpose', () {
    test('a credit sale moves one and not the other', () {
      final before = buildStatement(rows: ledger, party: 'Ali').closing;
      final cashBefore = buildStatement(rows: ledger, capital: 0).closing;

      final withOneMore = [
        ...ledger,
        _txn(
          type: TxnType.sale,
          amount: 25000,
          party: 'Ali',
          day: 20,
          paid: false,
        ),
      ];
      expect(
        buildStatement(rows: withOneMore, party: 'Ali').closing,
        before + 25000,
        reason: 'he owes more the day the milk goes out',
      );
      expect(
        buildStatement(rows: withOneMore, capital: 0).closing,
        cashBefore,
        reason: 'and the farm has not been paid a rupee for it',
      );
    });
  });

  group('a window of dates', () {
    test('what came before it is the balance it opens on', () {
      final s = buildStatement(
        rows: ledger,
        party: 'Ali',
        from: DateTime(2026, 9, 5),
      );
      expect(s.opening, 40000, reason: 'the 2 Sep milk, brought forward');
      expect(s.lines.length, 2);
      expect(s.closing, 30000, reason: 'the same figure either way');
    });

    test('the last day of the window is a whole day', () {
      final s = buildStatement(
        rows: ledger,
        party: 'Ali',
        to: DateTime(2026, 9, 9),
      );
      expect(s.lines.length, 3, reason: "the 9th's receipt is in it");
    });

    test('a window with nothing in it still balances', () {
      final s = buildStatement(
        rows: ledger,
        party: 'Ali',
        from: DateTime(2026, 9, 25),
      );
      expect(s.isEmpty, isTrue);
      expect(s.opening, 30000);
      expect(s.closing, 30000);
    });
  });
}
