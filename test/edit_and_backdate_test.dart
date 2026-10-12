import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/statement.dart';

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
}
