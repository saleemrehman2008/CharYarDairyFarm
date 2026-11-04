import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';

import 'support/farm_sim.dart';

/// A year of the farm, with the things that only go wrong over months.
///
/// The four-month run is the ordinary day and the six-month run is every
/// option in the app used at least once. Neither of them touches the three
/// things that were added last, and all three are of the kind that reads
/// right on the day and drifts afterwards:
///
/// * **A handful of money.** A customer pays a month at once and it lands
///   across twenty-odd entries. The page draws one line for it. If a slice
///   ever loses its tie to what it settled, that slice reads as income of
///   its own on top of the sale — the same rupees earned twice, and the
///   farm would never see it, because the line looks the same.
///
/// * **An advance against a wage.** It used to come off the month it was
///   drawn in, all of it, and whatever the wage could not carry fell off
///   the books in the farm's favour with nothing anywhere saying so. It is
///   a debt now, and a debt has to still be there next month.
///
/// * **Taking an entry off the books and putting it back.** The farm did
///   this and lost six real sales. Every figure has to come back to
///   exactly where it was, not nearly.
///
/// Twelve months, every day, with the full audit after each one — now
/// eight checks rather than six. The two added: a handful is worth what
/// its slices are worth and every slice is tied, and every rupee advanced
/// against a wage is either recovered or still owed.

void main() {
  final founders = [
    Partner(
      id: 'p0',
      userId: 'u0',
      name: 'Saleem Rehman',
      invested: 800000,
      profitHeld: 0,
      withdrawn: 0,
      createdAt: DateTime(2026, 8, 1),
    ),
    Partner(
      id: 'p1',
      userId: 'u1',
      name: 'Ghulam Ali',
      invested: 600000,
      profitHeld: 0,
      withdrawn: 0,
      createdAt: DateTime(2026, 8, 1),
    ),
    Partner(
      id: 'p2',
      userId: 'u2',
      name: 'Asif Soomro',
      invested: 400000,
      profitHeld: 0,
      withdrawn: 0,
      createdAt: DateTime(2026, 8, 1),
    ),
    Partner(
      id: 'p3',
      userId: 'u3',
      name: 'Rafeeque Memon',
      invested: 200000,
      profitHeld: 0,
      withdrawn: 0,
      createdAt: DateTime(2026, 8, 1),
    ),
  ];

  // Two men on the wage list. One draws an advance he can clear in a
  // month; the other draws more than a month's wage, over and over, which
  // is the case that used to lose money.
  final jalbani = Employee(
    id: 'w1',
    name: 'Jalbani',
    basic: 24000,
    joinedOn: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  );
  final gulDin = Employee(
    id: 'w2',
    name: 'Gul Din',
    basic: 18000,
    allowance: 2000,
    joinedOn: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  );

  final farm = Farm(founders: founders)..capitalIn = 2000000;
  final startedAudits = auditsRun;

  // One customer who pays a month at a time, which is what makes a
  // handful of money. Spelled three ways on purpose.
  const khaata = ['Babar Dairy', 'babar dairy', 'BABAR DAIRY'];

  // What was true before an entry was taken off the books, and after it
  // was put back. They have to be the same thing.
  final undoneCleanly = <String, bool>{};

  // Every handful raised, so the end of the run can check them all again.
  final handfuls = <String>[];

  // What each man was advanced and what came back off his wages.
  final advanced = <String, num>{'Jalbani': 0, 'Gul Din': 0};
  final recovered = <String, num>{'Jalbani': 0, 'Gul Din': 0};

  setUpAll(() {
    final day1 = DateTime(2026, 9, 1);
    farm.period = '2026-09';
    farm.buy(on: day1, from: 'Mandi', what: 'Cattle purchase', amount: 1200000);
    farm.buy(on: day1, from: 'Dealer', what: 'Equipment', amount: 200000);
    audit(farm, 'day one');

    for (var month = 0; month < 12; month++) {
      final year = 2026 + ((8 + month) ~/ 12);
      final mon = ((8 + month) % 12) + 1;
      final days = daysInMonth(DateTime(year, mon));
      final monthStart = DateTime(year, mon, 1);
      final monthEnd = DateTime(year, mon, days);
      farm.period = '$year-${mon.toString().padLeft(2, '0')}';

      for (var day = 1; day <= days; day++) {
        final on = DateTime(year, mon, day);

        // ---- the round ----
        farm.sell(
          on: on,
          to: 'Counter',
          amount: 12000,
          litres: 60,
          paidNow: true,
        );
        // The khaata customer, who pays nothing until the month is out.
        farm.sell(
          on: on,
          to: khaata[day % khaata.length],
          amount: 2000,
          litres: 10,
          paidNow: false,
        );

        // ---- running the place ----
        if (day == 3) {
          farm.buy(
            on: on,
            from: 'Arbab Traders',
            what: 'Fodder / feed',
            amount: 110000,
            paidNow: false,
          );
        }
        if (day == 8) {
          farm.spend(
            on: on,
            on_: 'Utilities (bijli, gas, pani)',
            amount: 14000,
          );
        }
        if (day == 12) farm.spend(on: on, on_: 'Transport', amount: 9000);
        if (day == 22) {
          farm.takeLoose(on: on, from: 'Scrap dealer', amount: 4000);
        }

        // ---- the wage list ----
        //
        // Jalbani draws 16,000 against a 24,000 wage in some months and
        // the farm takes back only part of it. Gul Din draws 30,000
        // against a 20,000 wage, which no single month can carry.
        if (day == 14 && month % 3 == 0) {
          farm.wageAdvance(on: on, to: 'Jalbani', amount: 16000);
          advanced['Jalbani'] = advanced['Jalbani']! + 16000;
        }
        if (day == 14 && month % 4 == 1) {
          farm.wageAdvance(on: on, to: 'Gul Din', amount: 30000);
          advanced['Gul Din'] = advanced['Gul Din']! + 30000;
        }

        if (day == days) {
          // Payday. Jalbani is asked for 6,000 of whatever he owes;
          // Gul Din for the lot, which the wage will hold to what it can
          // carry. Some months nothing is taken from either.
          final jal = farm.payWage(
            on: on,
            who: jalbani,
            from: monthStart,
            to: monthEnd,
            asked: month % 2 == 0 ? 6000 : 0,
          );
          recovered['Jalbani'] = recovered['Jalbani']! + jal.took;

          final gul = farm.payWage(
            on: on,
            who: gulDin,
            from: monthStart,
            to: monthEnd,
            asked: 999999,
            daysOff: month == 5 ? 3 : 0,
          );
          recovered['Gul Din'] = recovered['Gul Din']! + gul.took;
        }

        // ---- the month's milk, paid at once ----
        //
        // Not the whole of it every time: some months he pays short and
        // the rest rides into the next.
        if (day == days) {
          final owed = farm.stillOwing
              .where((t) => partyKey(t.party) == partyKey('Babar Dairy'))
              .fold<num>(0, (a, t) => a + t.outstanding);
          final paying = month % 3 == 2 ? owed - 2600 : owed;
          if (paying > 0) {
            handfuls.add(
              farm.takeInOneGo(on: on, party: 'Babar Dairy', amount: paying),
            );
          }
        }

        // ---- a mistake, and taking it back ----
        //
        // Twice a year somebody deletes something and puts it back. Every
        // figure has to come home: the farm did this for real and lost
        // six sales doing it.
        if (day == 19 && month % 6 == 3) {
          final before = _snapshot(farm);
          final wrong = farm.sell(
            on: on,
            to: 'Wande wala',
            amount: 7400,
            litres: 37,
            paidNow: false,
          );
          farm.settleWith(
            on: on,
            party: 'Wande wala',
            amount: 3000,
            theyOweUs: true,
          );
          audit(farm, '$year-$mon-$day with the wrong entry on the books');

          // Re-read before acting on it: settling moved it, so the copy
          // the sale handed back is no longer the row on the books.
          final off = farm.takeOff(farm.live(wrong.id)!, on: on);
          audit(farm, '$year-$mon-$day with it taken off');
          farm.putBack(off, on: on);
          audit(farm, '$year-$mon-$day with it put back');

          // And off again, for good this time — so the comparison is
          // against the books as they stood before any of it. Looked up
          // by id each time round: taking a row off replaces it, and a
          // copy taken before that is no longer the row on the books.
          final ids = farm.ledger
              .where((t) => partyKey(t.party) == partyKey('Wande wala'))
              .map((t) => t.id)
              .toList();
          for (final id in ids) {
            final live = farm.ledger
                .where((t) => t.id == id && !t.isDeleted)
                .firstOrNull;
            if (live != null) farm.takeOff(live, on: on);
          }
          undoneCleanly['$year-$mon'] = _snapshot(farm) == before;
        }

        audit(farm, '$year-${mon.toString().padLeft(2, '0')}-$day');
      }

      // ---- settling up ----
      final nextYear = 2026 + ((9 + month) ~/ 12);
      final nextMon = ((9 + month) % 12) + 1;
      farm.closePeriod(
        on: monthEnd,
        percent: month.isEven ? 50 : 100,
        nextPeriod: '$nextYear-${nextMon.toString().padLeft(2, '0')}',
      );
      audit(farm, 'after settling $year-$mon');
    }
  });

  group('a year of it', () {
    test('the books were checked after every day of it', () {
      // 365 days, plus day one, plus twelve settlings, plus three days
      // that are audited three extra times for the deletion.
      expect(auditsRun - startedAudits, greaterThan(370));
    });

    test('and they balance at the end of the year', () {
      expect(
        farm.money.reconciles,
        isTrue,
        reason:
            'out by ${farm.money.expected - farm.money.farmMoney} after a '
            'year',
      );
    });

    test('every entry still adds up', () {
      for (final t in farm.ledger) {
        expect(t.paidSoFar + t.outstanding, t.amount, reason: t.id);
        expect(t.paidSoFar, lessThanOrEqualTo(t.amount), reason: t.id);
        expect(t.paidSoFar, greaterThanOrEqualTo(0), reason: t.id);
      }
    });
  });

  group('the advances, a year on', () {
    test('Jalbani was advanced money and some of it came back', () {
      expect(advanced['Jalbani'], greaterThan(0));
      expect(recovered['Jalbani'], greaterThan(0));
    });

    test('and what came back plus what he owes is what he was given', () {
      expect(
        recovered['Jalbani']! + advanceOwed(farm.ledger, who: 'Jalbani'),
        advanced['Jalbani'],
      );
    });

    test('Gul Din drew more than a month and it was not lost', () {
      // The old rule took what the wage could carry and dropped the rest.
      // Over a year of it he would have been 'forgiven' tens of
      // thousands that the farm had actually handed him.
      expect(advanced['Gul Din'], greaterThan(0));
      expect(
        recovered['Gul Din']! + advanceOwed(farm.ledger, who: 'Gul Din'),
        advanced['Gul Din'],
      );
    });

    test('and more came off him across the months than one wage holds', () {
      expect(recovered['Gul Din'], greaterThan(gulDin.monthly));
    });

    test('nobody is owed money against an advance', () {
      for (final man in ['Jalbani', 'Gul Din']) {
        expect(advanceOwed(farm.ledger, who: man), greaterThanOrEqualTo(0));
      }
    });

    test('and one man\'s advance never reached the other', () {
      expect(
        advanceOwed(farm.ledger, who: 'Jalbani'),
        isNot(advanceOwed(farm.ledger, who: 'Gul Din')),
      );
    });
  });

  group('the payments that landed across a month', () {
    test('a year of months were paid at once', () {
      expect(handfuls.length, greaterThan(8));
    });

    test('each one is worth what its slices are worth', () {
      for (final id in handfuls) {
        final whole = theTake(farm.ledger, id);
        final slices = farm.ledger.where((t) => t.takeId == id && !t.isDeleted);
        expect(
          whole.amount,
          slices.fold<num>(0, (a, t) => a + t.amount),
          reason: id,
        );
        expect(whole.rows, slices.length, reason: id);
      }
    });

    test('and every slice settles something, so nothing is earned twice', () {
      for (final id in handfuls) {
        for (final slice in farm.ledger.where((t) => t.takeId == id)) {
          expect(slice.settlesAnotherEntry, isTrue, reason: slice.id);
          expect(slice.isLooseReceipt, isFalse, reason: slice.id);
        }
      }
    });

    test('the page draws each one exactly once', () {
      final hidden = rowsBehindATake(farm.ledger);
      for (final id in handfuls) {
        final shown = farm.ledger
            .where((t) => t.takeId == id && !t.isDeleted)
            .where((t) => !hidden.contains(t.id));
        expect(shown.length, 1, reason: id);
      }
    });

    test('and the days behind one are the days it paid for', () {
      final behind = daysBehindTakes(farm.ledger);
      for (final id in handfuls) {
        final slices = farm.ledger
            .where((t) => t.takeId == id && !t.isDeleted)
            .length;
        expect(behind[id]?.length, slices, reason: id);
      }
    });

    test('the khaata customer owes only the last month he paid short', () {
      // Four of the twelve months he paid 2,600 light. Each shortfall was
      // swept up by the next month's payment, which pays everything still
      // owing and not just that month — so only the last one is left.
      // Nothing else of his should be open: a slice that missed its mark
      // would show up here as an entry paid and never marked off.
      final owed = farm.ledger
          .where(
            (t) =>
                !t.isDeleted &&
                t.isReceivable &&
                partyKey(t.party) == partyKey('Babar Dairy'),
          )
          .fold<num>(0, (a, t) => a + t.outstanding);
      expect(owed, 2600);
    });

    test('and what he paid is what he was sold, less that', () {
      // The sum that says no rupee was counted twice or lost over a
      // year: everything billed to him, against everything received.
      final his = farm.ledger.where(
        (t) => !t.isDeleted && partyKey(t.party) == partyKey('Babar Dairy'),
      );
      final sold = his
          .where((t) => t.type == TxnType.sale)
          .fold<num>(0, (a, t) => a + t.amount);
      final took = his
          .where((t) => t.type == TxnType.receipt)
          .fold<num>(0, (a, t) => a + t.amount);
      expect(sold - took, 2600);
    });

    test('and his milk was earned once, not once per receipt', () {
      final sold = farm.ledger
          .where(
            (t) =>
                !t.isDeleted &&
                t.type == TxnType.sale &&
                partyKey(t.party) == partyKey('Babar Dairy'),
          )
          .fold<num>(0, (a, t) => a + t.amount);
      final asIncome = farm.ledger
          .where(
            (t) =>
                !t.isDeleted &&
                t.isLooseReceipt &&
                partyKey(t.party) == partyKey('Babar Dairy'),
          )
          .fold<num>(0, (a, t) => a + t.amount);
      expect(sold, greaterThan(0));
      expect(asIncome, 0, reason: 'a khaata payment read as income of itself');
    });
  });

  group('an entry taken off and put back', () {
    test('it happened', () {
      expect(undoneCleanly, isNotEmpty);
    });

    test('and every figure came home, both times', () {
      for (final entry in undoneCleanly.entries) {
        expect(
          entry.value,
          isTrue,
          reason:
              '${entry.key} — the books did not come back to where '
              'they were',
        );
      }
    });
  });
}

/// Every figure the farm shows, as one string.
///
/// Compared before a deletion and after the undo. A snapshot rather than a
/// list of checks because the failure the farm actually hit was not in any
/// figure anybody thought to check — six sales went and the totals still
/// looked plausible.
String _snapshot(Farm farm) {
  final b = farm.books;
  final m = farm.money;
  final live = farm.ledger.where((t) => !t.isDeleted).toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  return [
    'sales=${b.sales}',
    'other=${b.otherIncome}',
    'costs=${b.costs}',
    'profit=${b.profit}',
    'receivable=${b.receivable}',
    'payable=${b.payable}',
    'cash=${b.cash}',
    'worth=${m.farmMoney}',
    'waterfall=${m.expected}',
    'rows=${live.length}',
    for (final t in live) '${t.id}:${t.amount}:${t.paidSoFar}:${t.paid}',
  ].join('|');
}
