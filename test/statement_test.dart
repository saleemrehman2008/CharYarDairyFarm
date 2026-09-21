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
  num? paidSoFar,
  String? settles,

  /// Whether the money moved as the row was written. Settled later by
  /// default when it is not settled at all — an entry that was paid off
  /// afterwards has a receipt of its own carrying that money.
  bool? onCreate,
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
  paidSoFar: paidSoFar,
  settlesTxnId: settles,
  paidOnCreate: onCreate ?? paid,
  note: '',
  createdBy: 'u',
  createdByName: by,
  createdAt: DateTime(2026, 9, day),
);

void main() {
  // Ali takes milk on credit and pays some of it. The feed merchant sells to
  // the farm and is paid. One cash sale over the counter.
  final first = _txn(
    type: TxnType.sale,
    amount: 40000,
    party: 'Ali',
    day: 2,
    paid: false,
  );
  final ledger = [
    first,
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
      settles: first.id,
      by: 'Saleem Rehman',
    ),
    _txn(
      type: TxnType.payment,
      amount: 30000,
      party: 'Arbab Traders',
      day: 11,
      category: 'Supplier payment',
      settles: 'the feed bill',
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

  _partyOwing();
  _cashTrade();
}

/// A statement for somebody who pays on the spot.
///
/// This was the hole: the balance only moved by what was booked, never by
/// what was settled on the same row. A man who paid at the door was shown
/// owing the lot, and the mandi the farm had already paid was shown owed
/// twelve lakh. Both are bills for money nobody owes, and both would have
/// been handed to somebody.
void _cashTrade() {
  group('paid on the spot', () {
    test('a sale paid at the door leaves nothing owing', () {
      final rows = [
        _txn(type: TxnType.sale, amount: 12000, party: 'Counter', day: 3),
      ];
      final s = buildStatement(rows: rows, party: 'Counter');
      expect(s.lines.single.debit, 12000, reason: 'the milk went out');
      expect(s.lines.single.credit, 12000, reason: 'and was paid for');
      expect(s.closing, 0);
    });

    test('a buffalo paid for at the mandi leaves nothing owed', () {
      final rows = [
        _txn(
          type: TxnType.purchase,
          amount: 1200000,
          party: 'Mandi',
          day: 1,
          category: 'Cattle purchase',
        ),
      ];
      expect(buildStatement(rows: rows, party: 'Mandi').closing, 0);
    });

    test('an advance is held, not taken off what he owes', () {
      final rows = [
        _txn(
          type: TxnType.receipt,
          amount: 50000,
          party: 'Ali',
          day: 1,
          category: advanceCategory,
        ),
        _txn(
          type: TxnType.sale,
          amount: 16000,
          party: 'Ali',
          day: 4,
          paid: false,
        ),
      ];
      expect(
        buildStatement(rows: rows, party: 'Ali').closing,
        16000,
        reason: 'the security deposit is not a payment against the milk',
      );
    });

    test('rent handed over with no bill leaves the landlord owing nothing', () {
      final rows = [
        _txn(
          type: TxnType.payment,
          amount: 35000,
          party: 'Landlord',
          day: 5,
          category: 'Other payment',
        ),
      ];
      expect(buildStatement(rows: rows, party: 'Landlord').closing, 0);
    });
  });

  group('the cash book', () {
    test('a dead buffalo costs the farm but takes no cash', () {
      // She was paid for the day she was bought. Writing her off is a real
      // cost and it is not a rupee leaving the box, and the cash book used
      // to take it out all the same.
      final rows = [
        _txn(type: TxnType.sale, amount: 20000, party: 'Counter', day: 2),
        _txn(
          type: TxnType.expense,
          amount: 150000,
          party: 'B-04',
          day: 6,
          category: writeOffCategory,
        ),
      ];
      final s = buildStatement(rows: rows, capital: 500000);
      expect(s.closing, 520000);
      expect(
        s.lines.any((l) => l.detail.contains(writeOffCategory)),
        isFalse,
        reason: 'it is not a cash line at all',
      );
    });
  });
}

/// The figure somebody is actually going to be asked for by name.
///
/// This is the one that was wrong: the card added up what the sales were
/// booked at instead of what was still owing on them, so a man who had paid
/// most of his bill was still shown owing all of it. Taken from a real day on
/// the farm — Ali, three loads of milk at 16,000, one paid in full, one paid
/// down to 2,000, one untouched.
void _partyOwing() {
  group('what one party still owes', () {
    final cleared = _txn(
      type: TxnType.sale,
      amount: 16000,
      party: 'Ali',
      day: 20,
      onCreate: false,
    );
    final part = _txn(
      type: TxnType.sale,
      amount: 16000,
      party: 'Ali',
      day: 20,
      paid: false,
      paidSoFar: 14000,
    );
    final ali = [
      cleared,
      part,
      _txn(
        type: TxnType.sale,
        amount: 16000,
        party: 'Ali',
        day: 20,
        paid: false,
      ),
      _txn(
        type: TxnType.receipt,
        amount: 16000,
        party: 'Ali',
        day: 20,
        category: 'Khaata receipt',
        settles: cleared.id,
      ),
      _txn(
        type: TxnType.receipt,
        amount: 14000,
        party: 'Ali',
        day: 20,
        category: 'Khaata receipt',
        settles: part.id,
      ),
    ];

    test('counts what is left on a part-paid sale, not the whole of it', () {
      // 16,000 untouched plus 2,000 still to come on the one he paid down.
      expect(partyOwing(ali, 'Ali').owesUs, 18000);
      expect(partyOwing(ali, 'Ali').weOwe, 0);
    });

    test('agrees with the balance on his statement', () {
      expect(
        partyOwing(ali, 'Ali').owesUs,
        buildStatement(rows: ali, party: 'Ali').closing,
      );
    });

    test('every spelling of the name is the same man', () {
      expect(partyOwing(ali, 'ALI').owesUs, 18000);
      expect(partyOwing(ali, ' ali ').owesUs, 18000);
    });

    test("another man's entries stay out of it", () {
      expect(partyOwing(ali, 'Ali Khan').owesUs, 0);
    });

    test('an unpaid bill from a supplier is owed the other way', () {
      final rows = [
        ..._feedBill(),
        _txn(type: TxnType.sale, amount: 5000, party: 'Ali', day: 20),
      ];
      expect(partyOwing(rows, 'Chaudhry Feed').weOwe, 9000);
      expect(partyOwing(rows, 'Chaudhry Feed').owesUs, 0);
    });
  });
}

/// A feed bill of 30,000 with 21,000 paid off it.
List<Txn> _feedBill() => [
  _txn(
    type: TxnType.purchase,
    amount: 30000,
    party: 'Chaudhry Feed',
    day: 18,
    category: 'Fodder / feed',
    paid: false,
    paidSoFar: 21000,
  ),
];
