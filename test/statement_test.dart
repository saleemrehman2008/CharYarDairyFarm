import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';
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
  _narrowed();
  _everything();
}

/// The page that leaves nothing out.
///
/// The cash book is right to drop the feed bought on credit and the buffalo
/// that died — its last column is the money in the box and neither of those
/// touched it. But "what has this farm actually done" is a different question
/// and it deserves the same sheet of paper rather than four screens and a
/// calculator.
void _everything() {
  final onCredit = _txn(
    type: TxnType.purchase,
    amount: 110000,
    party: 'Arbab Traders',
    day: 3,
    category: 'Fodder / feed',
    paid: false,
  );
  final rows = [
    onCredit,
    _txn(type: TxnType.sale, amount: 12000, party: 'Counter', day: 4),
    _txn(type: TxnType.sale, amount: 16000, party: 'Ali', day: 5, paid: false),
    _txn(
      type: TxnType.expense,
      amount: 60000,
      party: 'The farm',
      day: 6,
      category: 'Salaries',
    ),
    _txn(
      type: TxnType.expense,
      amount: 150000,
      party: 'B-04',
      day: 7,
      category: writeOffCategory,
    ),
  ];

  group('the cash book, which leaves things out on purpose', () {
    final s = buildStatement(rows: rows, capital: 2000000);

    test('the feed bought on credit is not on it', () {
      expect(s.lines.any((l) => l.party == 'Arbab Traders'), isFalse);
    });

    test('nor the milk still owed for', () {
      expect(s.lines.any((l) => l.party == 'Ali'), isFalse);
    });

    test('nor the buffalo that died', () {
      expect(s.lines.any((l) => l.party == 'B-04'), isFalse);
    });

    test('and its closing figure is the cash', () {
      expect(s.closing, 2000000 + 12000 - 60000);
    });
  });

  group('everything, paid or not', () {
    final s = buildStatement(rows: rows, capital: 2000000, everything: true);

    test('every single entry is on the page', () {
      expect(s.lines.length, rows.length);
      for (final who in [
        'Arbab Traders',
        'Counter',
        'Ali',
        'The farm',
        'B-04',
      ]) {
        expect(
          s.lines.any((l) => l.party == who),
          isTrue,
          reason:
              '$who is missing from a page that claims to leave nothing out',
        );
      }
    });

    test('the buffalo that died is on it — that was the point', () {
      final off = s.lines.firstWhere((l) => l.party == 'B-04');
      expect(off.debit, 150000);
    });

    test('it says so across the top, rather than looking like a cash book', () {
      expect(s.kind, StatementKind.extract);
      expect(s.showing, 'Every entry, paid or not');
    });

    test('it opens at nothing, because it is not the cash any more', () {
      expect(s.opening, 0);
      expect(s.closing, 12000 + 16000 - 110000 - 60000 - 150000);
    });

    test('the two columns and the running total still agree', () {
      expect(s.credits - s.debits, s.closing - s.opening);
    });

    test('narrowing it further still works', () {
      final just = buildStatement(
        rows: rows,
        everything: true,
        types: {TxnType.expense},
      );
      expect(just.lines.length, 2, reason: 'the wages and the buffalo');
      expect(just.debits, 210000);
    });
  });

  group('a statement foot has to balance on its own page', () {
    /// The farm read the bottom of its own cash book and could not make the
    /// three figures agree: 17,200 of credit, 18,70,890 of debit, and a
    /// closing of nothing. It was right that they do not agree. The figure
    /// that reconciles them is the capital the co-founders put in, and that
    /// was printed in the header four screens above.
    ///
    /// A statement whose foot does not add up is the one thing a statement
    /// must not be, whatever is true further up the page.

    Txn row({
      required TxnType type,
      required String category,
      required num amount,
      String party = 'Urooj Dairy Shop',
      String handledBy = 'Ghulam Ali',
      int day = 12,
    }) => Txn(
      id: 'sb${_n++}',
      date: DateTime(2026, 10, day),
      monthId: '2026-10',
      type: type,
      party: party,
      category: category,
      amount: amount,
      paid: true,
      paidOnCreate: true,
      handledBy: handledBy,
      note: '',
      createdBy: 'u1',
      createdAt: DateTime(2026, 10, day),
    );

    test('opening plus credits less debits is the closing, always', () {
      final led = [
        row(
          type: TxnType.receipt,
          category: khaataReceiptCategory,
          amount: 8600,
        ),
        row(
          type: TxnType.expense,
          category: 'Feed',
          party: 'Ghas Wala',
          amount: 1862290,
          day: 13,
        ),
      ];

      final s = buildStatement(rows: led, capital: 1853690);
      expect(s.opening, 1853690);
      expect(s.credits, 8600);
      expect(s.debits, 1862290);
      expect(s.opening + s.credits - s.debits, s.closing);
      expect(s.closing, 0);
    });

    test('and the opening is the capital, which is what makes it zero', () {
      // His own figures. Without the opening on the page the foot reads as
      // eight thousand in and eighteen lakh out, closing at nothing.
      final led = [
        row(
          type: TxnType.receipt,
          category: khaataReceiptCategory,
          amount: 8600,
        ),
        row(
          type: TxnType.expense,
          category: 'Feed',
          party: 'Ghas Wala',
          amount: 1862290,
          day: 13,
        ),
      ];
      final s = buildStatement(rows: led, capital: 1853690);
      expect(s.opening, isNot(0), reason: 'so the foot has to print it');
    });

    test('money changing hands never reaches the cash book', () {
      // Both halves counted put the same 8,600 into the credits and the
      // debits, so a page showing 8,600 of takings totalled 17,200.
      final led = [
        row(
          type: TxnType.receipt,
          category: khaataReceiptCategory,
          amount: 8600,
        ),
        row(
          type: TxnType.payment,
          category: handoverOutCategory,
          party: farmAccountName,
          amount: 8600,
          day: 19,
        ),
        row(
          type: TxnType.receipt,
          category: handoverInCategory,
          party: 'Ghulam Ali',
          handledBy: farmAccountName,
          amount: 8600,
          day: 19,
        ),
      ];

      final s = buildStatement(rows: led);
      expect(s.credits, 8600, reason: 'the takings, and not the shuffle');
      expect(s.debits, 0);
      expect(s.lines, hasLength(1));
    });

    test(
      'and leaving it out changes no balance, because it netted to zero',
      () {
        final takings = row(
          type: TxnType.receipt,
          category: khaataReceiptCategory,
          amount: 8600,
        );
        final withShuffle = buildStatement(
          rows: [
            takings,
            row(
              type: TxnType.payment,
              category: handoverOutCategory,
              party: farmAccountName,
              amount: 8600,
              day: 19,
            ),
            row(
              type: TxnType.receipt,
              category: handoverInCategory,
              party: 'Ghulam Ali',
              handledBy: farmAccountName,
              amount: 8600,
              day: 19,
            ),
          ],
        );
        final without = buildStatement(rows: [takings]);
        expect(withShuffle.closing, without.closing);
      },
    );

    test("but one man's own page keeps every line of his", () {
      // What he handed over is the whole of what his account is about.
      final led = [
        row(
          type: TxnType.payment,
          category: handoverOutCategory,
          party: farmAccountName,
          amount: 8600,
          day: 19,
        ),
      ];
      final his = buildStatement(rows: led, party: farmAccountName);
      expect(his.lines, hasLength(1));
    });

    test('a page narrowed to one kind opens at nothing and still balances', () {
      final led = [
        row(
          type: TxnType.receipt,
          category: khaataReceiptCategory,
          amount: 8600,
        ),
      ];
      final s = buildStatement(
        rows: led,
        capital: 1853690,
        types: {TxnType.receipt},
      );
      expect(s.opening, 0, reason: 'part of the account is hidden');
      expect(s.opening + s.credits - s.debits, s.closing);
    });
  });

  group("a co-founder's own statement", () {
    /// Picking his name opened his profit account, which lists closed
    /// periods and nothing else. On a farm that has not closed a month it
    /// opened on an empty page — and an empty page under a man's name reads
    /// as the statement being broken, which is how the farm read it.
    ///
    /// What a man means by his statement is what has gone through his hands.

    Partner ali() => Partner(
      id: 'p-ali',
      userId: 'u-ali',
      name: 'Ghulam Ali',
      invested: 966790,
      pledged: 2000000,
      profitHeld: 0,
      withdrawn: 0,
      createdAt: DateTime(2026, 8, 1),
    );

    Txn row({
      required TxnType type,
      required String category,
      required num amount,
      String party = 'Urooj Dairy Shop',
      String handledBy = 'Ghulam Ali',
      int day = 12,
    }) => Txn(
      id: 'fa${_n++}',
      date: DateTime(2026, 10, day),
      monthId: '2026-10',
      type: type,
      party: party,
      category: category,
      amount: amount,
      paid: true,
      paidOnCreate: true,
      handledBy: handledBy,
      note: '',
      createdBy: 'u1',
      createdAt: DateTime(2026, 10, day),
    );

    test('it shows what he handled, with no month closed at all', () {
      final led = [
        row(
          type: TxnType.receipt,
          category: khaataReceiptCategory,
          amount: 8600,
        ),
        row(
          type: TxnType.expense,
          category: 'Feed',
          party: 'Ghas Wala',
          amount: 1680,
          day: 13,
        ),
      ];

      final s = founderAccount(partner: ali(), rows: led);
      expect(s.lines, hasLength(2));
      expect(s.credits, 8600);
      expect(s.debits, 1680);
      expect(s.closing, 6920);
    });

    test('oldest first, so the running balance builds down the page', () {
      final led = [
        row(
          type: TxnType.receipt,
          category: khaataReceiptCategory,
          amount: 1000,
          day: 12,
        ),
        row(
          type: TxnType.receipt,
          category: khaataReceiptCategory,
          amount: 2000,
          day: 15,
        ),
      ];
      final s = founderAccount(partner: ali(), rows: led);
      expect(s.lines.first.date.day, 12);
      expect(s.lines.first.balance, 1000);
      expect(s.lines.last.balance, 3000);
    });

    test('and the closing is what he is holding', () {
      final led = [
        row(
          type: TxnType.receipt,
          category: khaataReceiptCategory,
          amount: 8600,
        ),
      ];
      final s = founderAccount(partner: ali(), rows: led);
      final hands = cashInHands(led).firstWhere((h) => h.who == 'Ghulam Ali');
      expect(s.closing, hands.holding);
    });

    test('below nothing means the farm owes him, not that he owes it', () {
      final led = [
        row(
          type: TxnType.expense,
          category: 'Feed',
          party: 'Ghas Wala',
          amount: 2700,
        ),
      ];
      final s = founderAccount(partner: ali(), rows: led);
      expect(s.closing, -2700);
      expect(s.forOneParty, isTrue, reason: 'so the foot says who owes whom');
    });

    test('his own money going in is on it too', () {
      final led = [
        row(
          type: TxnType.expense,
          category: 'Feed',
          party: 'Ghas Wala',
          amount: 66790,
        ),
      ];
      final counted = [
        Contribution(
          id: 'c-ali',
          partnerId: 'p-ali',
          partnerName: 'Ghulam Ali',
          kind: ContributionKind.investment,
          source: ContributionSource.spent,
          amount: 66790,
          date: DateTime(2026, 10, 14),
          createdAt: DateTime(2026, 10, 14),
        ),
      ];

      final s = founderAccount(partner: ali(), rows: led, putIn: counted);
      expect(s.lines, hasLength(2));
      expect(s.closing, 0, reason: 'his own money, and what it paid for');
    });

    test('another man\'s entries are not on his page', () {
      final led = [
        row(
          type: TxnType.receipt,
          category: khaataReceiptCategory,
          amount: 5000,
          handledBy: 'Rafeeq',
        ),
      ];
      expect(founderAccount(partner: ali(), rows: led).lines, isEmpty);
    });

    test(
      'an empty page is empty because nothing happened, not by accident',
      () {
        final s = founderAccount(partner: ali(), rows: const []);
        expect(s.lines, isEmpty);
        expect(s.closing, 0);
      },
    );
  });

  group('a salary slip carries everything he was paid', () {
    /// The farm's question: does the advance show on it as well as the wage?
    /// Both are entries in his name, so both are on his page — which is the
    /// whole use of it. A man who drew five thousand on the 15th and took
    /// eighteen at the end of the month should be able to see both without
    /// taking anybody's word for the arithmetic.

    Txn his({
      required String category,
      required num amount,
      int day = 15,
      bool paid = true,
    }) => Txn(
      id: 'sl$day-${amount.toInt()}',
      date: DateTime(2026, 10, day),
      monthId: '2026-10',
      type: TxnType.expense,
      party: 'Gawalo Rafiq Jatt',
      category: category,
      amount: amount,
      paid: paid,
      paidOnCreate: paid,
      handledBy: 'Rafeeq',
      note: '',
      createdBy: 'u1',
      createdAt: DateTime(2026, 10, day),
    );

    final led = [
      his(category: salaryAdvanceCategory, amount: 16000, day: 15),
      his(category: salariesCategory, amount: 14000, day: 31),
    ];

    test('the advance and the wage are both on it', () {
      final slip = buildStatement(rows: led, party: 'Gawalo Rafiq Jatt');
      expect(slip.lines, hasLength(2));
      expect(
        slip.lines.map((l) => l.detail).join(' '),
        allOf(contains('Salary advance'), contains('Salaries')),
      );
    });

    test('oldest first, so the month reads in order', () {
      final slip = buildStatement(rows: led, party: 'Gawalo Rafiq Jatt');
      expect(slip.lines.first.date.day, 15);
      expect(slip.lines.last.date.day, 31);
    });

    test('and they add up to what he was handed that month', () {
      final slip = buildStatement(rows: led, party: 'Gawalo Rafiq Jatt');
      expect(slip.credits, 30000);
    });

    test('paid in full, nothing is left owing either way', () {
      // Which is what the foot of his slip should say at month end.
      final slip = buildStatement(rows: led, party: 'Gawalo Rafiq Jatt');
      expect(slip.closing, 0);
    });

    test('a wage still owed shows as owed to him', () {
      final owing = [
        his(category: salaryAdvanceCategory, amount: 16000, day: 15),
        his(category: salariesCategory, amount: 14000, day: 31, paid: false),
      ];
      final slip = buildStatement(rows: owing, party: 'Gawalo Rafiq Jatt');
      expect(slip.closing, -14000, reason: 'the farm owes him his wage');
    });

    test("another man's wage is not on his slip", () {
      final mixed = [
        ...led,
        Txn(
          id: 'other',
          date: DateTime(2026, 10, 31),
          monthId: '2026-10',
          type: TxnType.expense,
          party: 'Somebody Else',
          category: salariesCategory,
          amount: 25000,
          paid: true,
          paidOnCreate: true,
          handledBy: 'Rafeeq',
          note: '',
          createdBy: 'u1',
          createdAt: DateTime(2026, 10, 31),
        ),
      ];
      final slip = buildStatement(rows: mixed, party: 'Gawalo Rafiq Jatt');
      expect(slip.lines, hasLength(2));
      expect(slip.credits, 30000);
    });

    test('his name spelled a little differently is still his slip', () {
      final slip = buildStatement(rows: led, party: ' gawalo  rafiq jatt ');
      expect(slip.lines, hasLength(2));
    });
  });
}

/// The page narrowed to one kind of entry, or one heading.
///
/// "What has the feed cost this year" and "what did Ali take in October" are
/// ordinary questions, and the answer has to come out on the same sheet of
/// paper as everything else — otherwise the farm has two formats and one of
/// them is nobody's idea of a statement.
///
/// But hiding part of an account stops the last column being a balance. Show
/// only the sales and leave out the money that settled them, and the figure
/// at the foot is a running total of what is printed — not a rupee of it is
/// owed by anybody. So the page stops calling itself a statement of account
/// and stops calling that figure a balance owed. Handing somebody the other
/// version is handing them a bill.
void _narrowed() {
  final sale = _txn(
    type: TxnType.sale,
    amount: 40000,
    party: 'Ali',
    day: 2,
    paid: false,
  );
  final rows = [
    sale,
    _txn(type: TxnType.sale, amount: 12000, party: 'Ali', day: 3),
    _txn(
      type: TxnType.receipt,
      amount: 40000,
      party: 'Ali',
      day: 9,
      category: 'Khaata receipt',
      settles: sale.id,
    ),
    _txn(
      type: TxnType.purchase,
      amount: 30000,
      party: 'Arbab Traders',
      day: 6,
      category: 'Fodder / feed',
      paid: false,
    ),
    _txn(
      type: TxnType.expense,
      amount: 60000,
      party: 'The farm',
      day: 7,
      category: 'Salaries',
    ),
  ];

  group('narrowed to one kind of entry', () {
    test('only that kind is listed', () {
      // Nobody picked, so the columns are the farm's own: money in is a
      // credit, the way it is on a bank statement, and not a debit the way
      // it would be on the customer's own page.
      final s = buildStatement(rows: rows, types: {TxnType.sale});
      expect(s.lines.length, 2);
      expect(s.credits, 52000);
      expect(s.debits, 0);
    });

    test('it stops calling itself a statement of account', () {
      final s = buildStatement(rows: rows, party: 'Ali', types: {TxnType.sale});
      expect(s.kind, StatementKind.extract);
      expect(s.kind.title, 'Extract');
      expect(s.kind.footLabel, 'Total shown');
    });

    test('it opens at nothing, because half the account is not on it', () {
      final s = buildStatement(
        rows: rows,
        capital: 2000000,
        types: {TxnType.sale},
      );
      expect(s.opening, 0);
    });

    test('the page says what it was narrowed to', () {
      final s = buildStatement(rows: rows, types: {TxnType.expense});
      expect(s.showing, 'Expense');
    });

    test('a kind that never happened comes back empty, not wrong', () {
      final s = buildStatement(rows: rows, types: {TxnType.payment});
      expect(s.isEmpty, isTrue);
      expect(s.closing, 0);
    });

    test('a credit sale is on it even though no cash moved', () {
      // The unnarrowed cash book leaves a credit sale out, because no money
      // moved that day. Asked for the sales, the farm means all of them.
      final s = buildStatement(rows: rows, types: {TxnType.sale});
      expect(s.lines.any((l) => l.credit == 40000), isTrue);
    });
  });

  group('narrowed to one heading', () {
    test('only that heading is listed', () {
      final s = buildStatement(rows: rows, category: 'Salaries');
      expect(s.lines.single.debit, 60000, reason: 'money out of the farm');
      expect(s.showing, 'Salaries');
    });

    test('however the heading was spelled', () {
      expect(buildStatement(rows: rows, category: 'salaries').lines.length, 1);
      expect(buildStatement(rows: rows, category: 'SALARIES').lines.length, 1);
    });

    test('a heading and a kind together narrow to both', () {
      final s = buildStatement(
        rows: rows,
        types: {TxnType.expense},
        category: 'Salaries',
      );
      expect(s.lines.length, 1);
      expect(s.showing, 'Expense · Salaries');
    });

    test('one person, one heading', () {
      final s = buildStatement(rows: rows, party: 'Ali', category: 'Milk');
      expect(s.lines.length, 2);
      expect(s.lines.every((l) => l.party.toLowerCase() == 'ali'), isTrue);
    });
  });

  group('nothing narrowed', () {
    test('it is still the account it always was', () {
      final s = buildStatement(rows: rows, party: 'Ali');
      expect(s.kind, StatementKind.party);
      expect(s.showing, isEmpty);
      expect(s.closing, 0, reason: '40,000 owed and settled, 12,000 cash');
    });

    test('and the cash book still opens at the capital', () {
      final s = buildStatement(rows: rows, capital: 2000000);
      expect(s.kind, StatementKind.cashBook);
      expect(s.opening, 2000000);
    });
  });
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
          category: securityInCategory,
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
