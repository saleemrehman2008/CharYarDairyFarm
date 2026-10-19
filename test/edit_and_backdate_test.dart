import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';
import 'package:char_yar_dairy_farm/services/log_service.dart';
import 'package:char_yar_dairy_farm/services/statement.dart';
import 'package:char_yar_dairy_farm/services/txn_repo.dart';

import 'support/farm_sim.dart';

/// What happens if an entry can be edited, and if one can be back-dated.
///
/// The farm asked for both before either was built, and asked whether they
/// would cause trouble. They would, but not everywhere, and the difference
/// is the whole answer: one period of the books is still being written and
/// every period before it has been settled and shared out.
///
/// A month that is open is a draft. Editing an entry in it changes a figure
/// nobody has acted on yet, and the next close simply works the new figure
/// out. Nothing anywhere else has to move.
///
/// A month that is closed is not a draft. Its sales, its costs and its
/// profit were written down on the day, each co-founder's slice was worked
/// out from that profit, and the money was handed over or credited to their
/// account. Change an entry in it afterwards and the ledger says one thing
/// while the period, the shares and four people's accounts say another —
/// and nothing in the app will ever notice, because a closed period does
/// not read the ledger again.
///
/// So these run a month, close it, and then do the two things to it.

/// Two co-founders, so a share is a share of something and not the whole.
List<Partner> _founders() => [
  Partner(
    id: 'p1',
    userId: 'u1',
    name: 'Saleem Rehman',
    invested: 300000,
    profitHeld: 0,
    withdrawn: 0,
    createdAt: DateTime(2026, 8, 1),
  ),
  Partner(
    id: 'p2',
    userId: 'u2',
    name: 'Ghulam Ali',
    invested: 200000,
    profitHeld: 0,
    withdrawn: 0,
    createdAt: DateTime(2026, 8, 1),
  ),
];

void main() {
  group('a month, closed, and then meddled with', () {
    late Farm farm;
    late num closedSales;
    late num closedProfit;
    late List<MonthShare> shares;
    late Txn septemberSale;

    setUp(() {
      farm = Farm(founders: _founders())..capitalIn = 500000;

      // Twelve days of milk, one feed bill, one salary.
      for (var day = 1; day <= 12; day++) {
        final on = DateTime(2026, 9, day);
        final sale = farm.sell(
          on: on,
          to: 'Ali',
          amount: 8000,
          litres: 40,
          paidNow: true,
        );
        if (day == 5) septemberSale = sale;
      }
      farm.buy(
        on: DateTime(2026, 9, 6),
        from: 'Feed shop',
        what: 'Fodder / feed',
        amount: 30000,
      );
      farm.spend(on: DateTime(2026, 9, 28), on_: 'Salaries', amount: 20000);
      audit(farm, 'before the close');

      closedSales = farm.books.sales;
      closedProfit = farm.books.profit;
      shares = farm.closePeriod(
        on: DateTime(2026, 9, 30),
        percent: 100,
        nextPeriod: '2026-10',
      );
      audit(farm, 'after the close');
    });

    test('the close froze what it was closed on', () {
      expect(closedSales, 96000);
      expect(closedProfit, 96000 - 50000);
      expect(
        shares.fold<num>(0, (a, s) => a + s.share),
        closedProfit,
        reason: 'every rupee of it went to somebody',
      );
    });

    // ---- 1. Editing an entry that belongs to the closed month ----

    test(
      'editing a closed month entry leaves the books telling two stories',
      () {
        // Somebody notices day five was 9,000, not 8,000, and corrects it.
        farm.correct(septemberSale, amount: 9000);

        // The ledger now says one thing.
        final nowOnTheLedger = farm.ledger
            .where((t) => t.monthId == '2026-09' && t.type == TxnType.sale)
            .fold<num>(0, (a, t) => a + t.amount);
        expect(nowOnTheLedger, 97000);

        // And the closed period still says the other, because a closed
        // period does not read the ledger again — it kept its own figures.
        expect(farm.closed.single.sales, 96000);

        // Which means the shares were worked out on a profit that is no
        // longer what the books say the month made.
        final shared = shares.fold<num>(0, (a, s) => a + s.share);
        expect(shared, 46000);
        expect(
          nowOnTheLedger - 50000,
          47000,
          reason: 'a thousand of profit nobody has a share of',
        );
      },
    );

    test('and the balance check does not catch it', () {
      // This is the part that matters. The books-balance check is what the
      // farm trusts to say the figures hang together, and it is blind to
      // this: the cash moved with the entry, so both sides of it move by
      // the same thousand and it still reconciles. The damage is in the
      // shares, which it does not look at.
      farm.correct(septemberSale, amount: 9000);
      expect(farm.money.reconciles, isTrue);
    });

    test('an entry in the OPEN month can be edited freely', () {
      // Same correction, in the period still being written. Nothing has
      // been settled on it, so there is nothing to disagree with.
      final october = farm.sell(
        on: DateTime(2026, 10, 3),
        to: 'Ali',
        amount: 8000,
        litres: 40,
        paidNow: true,
      );
      final before = farm.books.sales;
      farm.correct(october, amount: 9000);
      expect(farm.books.sales, before + 1000);
      audit(farm, 'after editing an open entry');
    });

    // ---- 2. Back-dating ----

    test('a back-dated entry counts in the open month, not the dated one', () {
      // Written on 3 October but dated 20 September — a sale somebody
      // forgot to enter. The date is September; the money is October's,
      // because September is closed and its profit is already divided.
      farm.sell(
        on: DateTime(2026, 9, 20),
        to: 'Ali',
        amount: 5000,
        litres: 25,
        paidNow: true,
      );

      expect(
        farm.closed.single.sales,
        96000,
        reason: 'September is settled and stays settled',
      );
      expect(
        farm.books.sales,
        5000,
        reason: 'the money falls into the period that is open',
      );
      audit(farm, 'after a back-dated entry');
    });

    test('but a dated statement shows it where its date says', () {
      // The one place back-dating does show. A statement for September
      // lists it, because a statement is about what happened and when.
      // September's profit does not include it. Both are true and they
      // look like a contradiction.
      farm.sell(
        on: DateTime(2026, 9, 20),
        to: 'Ali',
        amount: 5000,
        litres: 25,
        paidNow: true,
      );
      final september = buildStatement(
        rows: farm.ledger,
        party: 'Ali',
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
      );
      final listed = september.lines.fold<num>(0, (a, l) => a + l.debit);
      expect(
        listed,
        96000 + 5000,
        reason: 'the statement counts it in September',
      );
      expect(
        farm.closed.single.sales,
        96000,
        reason: 'the period does not — and this is the gap to explain',
      );
    });

    test('back-dating inside the open month is ordinary and safe', () {
      // Dated two days ago, written today, and both are October.
      farm.sell(
        on: DateTime(2026, 10, 1),
        to: 'Ali',
        amount: 5000,
        litres: 25,
        paidNow: true,
      );
      expect(farm.books.sales, 5000);
      audit(farm, 'after back-dating within the open month');
    });
  });

  group('what an edit is allowed to touch', () {
    late Txn entry;

    setUp(() {
      entry = Txn(
        id: 'e1',
        date: DateTime(2026, 10, 8),
        monthId: '2026-10',
        type: TxnType.sale,
        party: 'Ali',
        category: milkCategory,
        qty: 40,
        unit: 'L',
        rate: 200,
        amount: 8000,
        paid: true,
        paidSoFar: 8000,
        paidOnCreate: true,
        note: '',
        shift: MilkShift.morning,
        createdBy: 'u1',
        createdByName: 'Saleem Rehman',
        createdAt: DateTime(2026, 10, 8),
      );
    });

    test('the date stays where the trade happened', () {
      // Corrected on the ninth, the entry is still the eighth's. The milk
      // went out on the eighth and moving it would take it off that day's
      // books and put it on a day it did not happen.
      expect(entry.date, DateTime(2026, 10, 8));
      final edit = TxnEdit(
        at: DateTime(2026, 10, 9),
        byUid: 'u1',
        byName: 'Saleem Rehman',
        changes: const [(field: 'Amount', from: '8,000', to: '9,000')],
      );
      expect(edit.at.day, 9, reason: 'the correction happened on the ninth');
      expect(entry.date.day, 8, reason: 'the trade did not');
    });

    test('a correction reads back in the words it was shown in', () {
      // Years from now, after the rates and the headings have moved on, a
      // record of a correction still has to be readable.
      final e = TxnEdit(
        at: DateTime(2026, 10, 9),
        byUid: 'u1',
        byName: 'Saleem Rehman',
        changes: const [
          (field: 'Amount', from: '8,000', to: '9,000'),
          (field: 'Which milking', from: 'Morning', to: 'Evening'),
        ],
      );
      final back = TxnEdit.listFrom([e.toMap()]).single;
      expect(back.byName, 'Saleem Rehman');
      expect(back.changes.length, 2);
      expect(back.changes.first.from, '8,000');
      expect(back.changes.last.to, 'Evening');
    });

    test('an entry nobody has touched carries no history', () {
      expect(entry.edits, isEmpty);
    });

    test('and one that has been shows every correction, oldest first', () {
      final withEdits = Txn(
        id: entry.id,
        date: entry.date,
        monthId: entry.monthId,
        type: entry.type,
        party: entry.party,
        category: entry.category,
        amount: 9000,
        paid: true,
        note: '',
        createdBy: 'u1',
        createdAt: entry.createdAt,
        edits: [
          TxnEdit(
            at: DateTime(2026, 10, 9),
            byUid: 'u2',
            byName: 'Ghulam Ali',
            changes: const [(field: 'Party', from: 'Ali', to: 'Ali Raza')],
          ),
          TxnEdit(
            at: DateTime(2026, 10, 10),
            byUid: 'u1',
            byName: 'Saleem Rehman',
            changes: const [(field: 'Amount', from: '8,000', to: '9,000')],
          ),
        ],
      );
      expect(withEdits.edits.length, 2);
      expect(withEdits.edits.first.byName, 'Ghulam Ali');
      expect(withEdits.edits.last.changes.single.to, '9,000');
    });
  });

  group('which period an entry may be corrected in', () {
    /// The rule the form and the rules both run: open, and only open.
    bool open(FarmMonth m) => m.isOpen;

    FarmMonth month(String id, String status) => FarmMonth(
      id: id,
      status: status,
      openingCash: 0,
      from: DateTime(2026, 10, 1),
    );

    test('the one being written, yes', () {
      expect(open(month('2026-10', 'open')), isTrue);
    });

    test('one that is sealed and waiting on the co-founders, no', () {
      // Its figures are already in front of four people to agree to.
      expect(open(month('2026-09', 'sealed')), isFalse);
    });

    test('one that is closed and shared out, no', () {
      expect(open(month('2026-08', 'closed')), isFalse);
    });
  });

  group('the day it happened and the day it was typed', () {
    /// An entry carries both, always, and neither is worked out from the
    /// other: [Txn.date] is the day the milk went out, [Txn.createdAt] is
    /// the evening somebody sat down with the phone. The books read the
    /// first; the second is how anybody can tell a late entry from one that
    /// was there all along.
    Txn written({required DateTime on, required DateTime typed}) => Txn(
      id: 't1',
      date: on,
      monthId: '2026-10',
      type: TxnType.sale,
      party: 'Urooj Dairy Shop',
      category: milkCategory,
      amount: 8000,
      paid: true,
      note: '',
      createdBy: 'u1',
      createdAt: typed,
    );

    test('written the same day, there is nothing to say', () {
      final t = written(
        on: DateTime(2026, 10, 13, 7),
        typed: DateTime(2026, 10, 13, 21),
      );
      expect(t.wasDatedBack, isFalse);
    });

    test('written two days later, the entry says so', () {
      final t = written(
        on: DateTime(2026, 10, 11, 12),
        typed: DateTime(2026, 10, 13, 21),
      );
      expect(t.wasDatedBack, isTrue);
      expect(t.date.day, 11, reason: 'the milk went out on the eleventh');
      expect(t.createdAt.day, 13, reason: 'it was typed on the thirteenth');
    });

    test('a back-dated entry still belongs to the open period', () {
      // The one thing back-dating must never do. The date moves where the
      // entry is read; the period is what a closed month's profit was
      // worked out from, and it stays where it was written.
      final t = written(
        on: DateTime(2026, 10, 2),
        typed: DateTime(2026, 10, 13),
      );
      expect(t.monthId, '2026-10');
    });

    test('a correction to the date is kept with both days on it', () {
      final moved = TxnEdit(
        at: DateTime(2026, 10, 13, 19, 40),
        byUid: 'u2',
        byName: 'Ghulam Ali',
        changes: const [
          (field: 'Date', from: '11 Oct 2026', to: '12 Oct 2026'),
        ],
      );
      final back = TxnEdit.listFrom([moved.toMap()]).single;
      expect(back.byName, 'Ghulam Ali');
      expect(back.at.hour, 19, reason: 'when the correction was made');
      expect(back.changes.single.from, '11 Oct 2026');
      expect(back.changes.single.to, '12 Oct 2026');
    });
  });

  group('how far a date may move', () {
    final periodStart = DateTime(2026, 9, 25, 19, 30);
    final today = DateTime(2026, 10, 13, 11, 56);

    String? refusal({
      required bool isMaster,
      required DateTime to,
      DateTime? start,
    }) => dateMoveRefusal(
      isMaster: isMaster,
      to: to,
      periodStart: start ?? periodStart,
      now: today,
    );

    test('a founder may go back inside the period', () {
      // The 8th that was really the 6th. This is the whole reason the
      // date can be touched at all.
      expect(refusal(isMaster: false, to: DateTime(2026, 10, 6)), isNull);
    });

    test('and forward inside it, as far as today', () {
      expect(refusal(isMaster: false, to: DateTime(2026, 10, 13)), isNull);
    });

    test('as far back as the day the period opened', () {
      // The period began at half past seven in the evening, because that is
      // when the one before it was sealed. An entry for the morning of that
      // same day is inside the period, and has to be allowed.
      expect(refusal(isMaster: false, to: DateTime(2026, 9, 25, 6)), isNull);
    });

    test('but not the day before it', () {
      // That day belongs to a period that has been sealed, agreed and
      // shared out.
      expect(refusal(isMaster: false, to: DateTime(2026, 9, 24)), isNotNull);
    });

    test('the master may reach back past it', () {
      expect(refusal(isMaster: true, to: DateTime(2026, 9, 24)), isNull);
    });

    test('nobody dates an entry tomorrow', () {
      expect(refusal(isMaster: false, to: DateTime(2026, 10, 14)), isNotNull);
      expect(refusal(isMaster: true, to: DateTime(2026, 10, 14)), isNotNull);
    });

    test('a period nobody has opened a document for holds nobody back', () {
      // The first entry of a period is written before anything opens it.
      expect(
        dateMoveRefusal(
          isMaster: false,
          to: DateTime(2026, 10, 1),
          periodStart: null,
          now: today,
        ),
        isNull,
      );
    });
  });

  group('one row per rupee', () {
    /// The two cash lists on the ledger page, which exist because the farm
    /// read its own books and found the same money twice: a sale on credit,
    /// and the receipt that settled it weeks later. Both rows are right.
    /// Counting both is not.
    late List<Txn> ledger;

    setUp(() {
      ledger = [
        // Paid at the door. Counted on itself.
        Txn(
          id: 'a',
          date: DateTime(2026, 10, 2),
          monthId: '2026-10',
          type: TxnType.sale,
          party: 'Counter',
          category: milkCategory,
          amount: 5000,
          paid: true,
          paidOnCreate: true,
          note: '',
          createdBy: 'u1',
          createdAt: DateTime(2026, 10, 2),
        ),
        // Sold on credit on the 5th and settled on the 20th. The sale row
        // moved no cash on the 5th; the receipt did on the 20th.
        Txn(
          id: 'b',
          date: DateTime(2026, 10, 5),
          monthId: '2026-10',
          type: TxnType.sale,
          party: 'Urooj Dairy Shop',
          category: milkCategory,
          amount: 38000,
          paid: true,
          paidSoFar: 38000,
          paidOnCreate: false,
          note: '',
          createdBy: 'u1',
          createdAt: DateTime(2026, 10, 5),
        ),
        Txn(
          id: 'b-settles',
          date: DateTime(2026, 10, 20),
          monthId: '2026-10',
          type: TxnType.receipt,
          party: 'Urooj Dairy Shop',
          category: khaataReceiptCategory,
          amount: 38000,
          paid: true,
          paidOnCreate: true,
          settlesTxnId: 'b',
          note: '',
          createdBy: 'u1',
          createdAt: DateTime(2026, 10, 20),
        ),
        // Feed paid for at the mandi.
        Txn(
          id: 'c',
          date: DateTime(2026, 10, 7),
          monthId: '2026-10',
          type: TxnType.purchase,
          party: 'Feed store',
          category: 'Wanda / feed',
          amount: 12000,
          paid: true,
          paidOnCreate: true,
          note: '',
          createdBy: 'u1',
          createdAt: DateTime(2026, 10, 7),
        ),
        // A buffalo written off. A real cost and not a rupee of cash.
        Txn(
          id: 'd',
          date: DateTime(2026, 10, 9),
          monthId: '2026-10',
          type: TxnType.expense,
          party: 'Herd',
          category: writeOffCategory,
          amount: 300000,
          paid: true,
          paidOnCreate: true,
          note: '',
          createdBy: 'u1',
          createdAt: DateTime(2026, 10, 9),
        ),
      ];
    });

    num sum(Iterable<Txn> rows) => rows.fold<num>(0, (a, t) => a + t.amount);

    test('the credit sale is counted on the day the money came, once', () {
      final inRows = ledger.where(movedCashIn).toList();
      expect(inRows.map((t) => t.id), ['a', 'b-settles']);
      expect(sum(inRows), 43000);
    });

    test('and what went out leaves the write-off alone', () {
      final outRows = ledger.where(movedCashOut).toList();
      expect(outRows.map((t) => t.id), ['c']);
      expect(sum(outRows), 12000);
    });

    test('the two lists come to what the balance card says', () {
      // The point of the whole exercise: a person adding up what is on
      // screen gets the farm's own figure, not something near it.
      final books = Books(
        monthId: '2026-10',
        openingCash: 0,
        capital: 0,
        monthTxns: ledger,
        unpaidTxns: const [],
      );
      final cashIn = sum(ledger.where(movedCashIn));
      final cashOut = sum(ledger.where(movedCashOut));
      expect(cashIn - cashOut, books.operatingCash);
    });

    test('nothing is in both lists, and no rupee is in neither', () {
      for (final t in ledger) {
        expect(
          movedCashIn(t) && movedCashOut(t),
          isFalse,
          reason: '${t.id} cannot be both',
        );
      }
      // The two rows that moved no cash are the credit sale before it was
      // settled, and the write-off. Everything else is on one list or the
      // other.
      final neither = ledger
          .where((t) => !movedCashIn(t) && !movedCashOut(t))
          .map((t) => t.id);
      expect(neither, ['b', 'd']);
    });
  });

  group('who has been back over the books', () {
    /// The count the four of them read at the head of the log. It is the
    /// answer to the question that would sour a farm run by friends — not
    /// "was a figure changed", which happens and has to, but "who has been
    /// changing them, and how often".
    LogEntry line(String who, LogKind kind, [int day = 1]) => LogEntry(
      id: 'l$day$who',
      at: DateTime(2026, 10, day),
      uid: who.toLowerCase(),
      who: who,
      kind: kind,
      what: 'did something',
    );

    test('corrections and deletions both count', () {
      final tally = correctionTally([
        line('Saleem Rehman', LogKind.correction, 1),
        line('Saleem Rehman', LogKind.entryDeleted, 2),
      ]);
      expect(tally.single.who, 'Saleem Rehman');
      expect(tally.single.times, 2);
    });

    test('writing an entry, or logging in, is not a change to one', () {
      // The whole point of the list. An evening of ordinary work must not
      // read as an evening of going back over things.
      final tally = correctionTally([
        line('Ghulam Ali', LogKind.transaction, 1),
        line('Ghulam Ali', LogKind.login, 1),
        line('Ghulam Ali', LogKind.monthClose, 2),
      ]);
      expect(tally, isEmpty);
    });

    test('busiest first, and alphabetical between equals', () {
      // So the list does not reshuffle itself every time it is opened.
      final tally = correctionTally([
        line('Ghulam Ali', LogKind.correction, 1),
        line('Saleem Rehman', LogKind.correction, 1),
        line('Saleem Rehman', LogKind.correction, 2),
        line('Saleem Rehman', LogKind.correction, 3),
        line('Bilal', LogKind.correction, 4),
      ]);
      expect(tally.map((t) => t.who), ['Saleem Rehman', 'Bilal', 'Ghulam Ali']);
      expect(tally.map((t) => t.times), [3, 1, 1]);
    });

    test('a line with no name against it still has to be counted', () {
      final tally = correctionTally([line('', LogKind.correction)]);
      expect(tally.single.who, 'Someone');
      expect(tally.single.times, 1);
    });
  });

  group('the order the ledger is read in', () {
    Txn on(
      String id,
      DateTime date, {
      String monthId = '2026-10',
      DateTime? written,
    }) => Txn(
      id: id,
      date: date,
      monthId: monthId,
      type: TxnType.expense,
      party: 'Feed store',
      category: 'Wanda / feed',
      amount: 1000,
      paid: true,
      paidOnCreate: true,
      note: '',
      createdBy: 'u1',
      createdAt: written ?? date,
    );

    test('newest day at the top, whatever period it belongs to', () {
      // The farm found a feed bill from the sixteenth at the bottom of the
      // page because of which month it had been booked into. Nobody reading
      // a ledger expects that, and this is the test that says so.
      final rows = ledgerOrder([
        on('old-period-16th', DateTime(2026, 10, 16), monthId: '2026-09'),
        on('new-period-2nd', DateTime(2026, 10, 2), monthId: '2026-10'),
        on('new-period-20th', DateTime(2026, 10, 20), monthId: '2026-10'),
      ]);
      expect(rows.map((t) => t.id), [
        'new-period-20th',
        'old-period-16th',
        'new-period-2nd',
      ]);
    });

    test('a back-dated entry sits on the day it is for', () {
      // Written on the twentieth for the fifth. It belongs with the fifth,
      // which is where somebody looking for the fifth will look.
      final rows = ledgerOrder([
        on('written-today', DateTime(2026, 10, 20)),
        on(
          'back-dated',
          DateTime(2026, 10, 5),
          written: DateTime(2026, 10, 20),
        ),
        on('the-sixth', DateTime(2026, 10, 6)),
      ]);
      expect(rows.map((t) => t.id), [
        'written-today',
        'the-sixth',
        'back-dated',
      ]);
    });

    test('two on one day keep the order they were written in', () {
      final rows = ledgerOrder([
        on('morning', DateTime(2026, 10, 8), written: DateTime(2026, 10, 8, 7)),
        on(
          'evening',
          DateTime(2026, 10, 8),
          written: DateTime(2026, 10, 8, 19),
        ),
      ]);
      expect(rows.map((t) => t.id), ['evening', 'morning']);
    });

    test('and it leaves what it was given alone', () {
      // A sort in place would reorder the store's own list underneath every
      // other screen reading it.
      final given = [
        on('a', DateTime(2026, 10, 1)),
        on('b', DateTime(2026, 10, 9)),
      ];
      ledgerOrder(given);
      expect(given.map((t) => t.id), ['a', 'b']);
    });
  });
}
