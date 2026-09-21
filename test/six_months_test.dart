import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/categories.dart';
import 'package:char_yar_dairy_farm/services/statement.dart';

import 'support/farm_sim.dart';

/// Six months of the farm with every option in the app actually used.
///
/// The four-month run proves the ordinary day: milk out twice, money in, a
/// month settled. This one is for everything else — the things that happen
/// four times a year and are therefore the things nobody has ever checked.
///
/// Used here, at least once and mostly many times over: milk sold for cash
/// and on credit; feed bought on credit and paid off in parts and in full; a
/// supplier overpaid nothing and underpaid often; wages, bijli, transport,
/// repairs; rent handed over with no bill; scrap and dung sold with no
/// invoice; two categories nobody put on the list, one the farm keeps and one
/// it spends; buffaloes bought; a calf that came with one of them, at no
/// price of its own; the vet, three times; one animal sold above what she
/// cost and one below; one that died; advances taken and given back; six
/// periods settled with the profit split four ways, some taken out and some
/// left in.
///
/// After every single day the audit in [audit] runs — every entry adds up,
/// what is owed is what the entries say, profit is sales plus other income
/// less costs, the books balance, every person's statement says what their
/// account says, the cash book is the cash, and an advance is neither income
/// nor cost.

void main() {
  final founders = [
    Partner(
      id: 'p0',
      userId: 'u0',
      name: 'Saleem Rehman',
      invested: 800000,
      reinvested: 0,
      withdrawn: 0,
      createdAt: DateTime(2026, 8, 1),
    ),
    Partner(
      id: 'p1',
      userId: 'u1',
      name: 'Ghulam Ali',
      invested: 600000,
      reinvested: 0,
      withdrawn: 0,
      createdAt: DateTime(2026, 8, 1),
    ),
    Partner(
      id: 'p2',
      userId: 'u2',
      name: 'Asif Soomro',
      invested: 400000,
      reinvested: 0,
      withdrawn: 0,
      createdAt: DateTime(2026, 8, 1),
    ),
    Partner(
      id: 'p3',
      userId: 'u3',
      name: 'Rafeeque Memon',
      invested: 200000,
      reinvested: 0,
      withdrawn: 0,
      createdAt: DateTime(2026, 8, 1),
    ),
  ];

  final farm = Farm(founders: founders)..capitalIn = 2000000;
  final shareLog = <List<MonthShare>>[];
  final startedAudits = auditsRun;

  // Spelled four ways on purpose. One man, one account.
  const credit = ['Ali', 'ali', 'ALI', 'Kashif'];
  const periods = [
    '2026-09',
    '2026-10',
    '2026-11',
    '2026-12',
    '2027-01',
    '2027-02',
  ];

  setUpAll(() {
    final day1 = DateTime(2026, 9, 1);

    // ---- the herd, the shed, and two securities ----
    farm.buy(on: day1, from: 'Mandi', what: 'Cattle purchase', amount: 1200000);
    farm.buy(on: day1, from: 'Dealer', what: 'Equipment', amount: 200000);
    // A calf came with one of the buffaloes. The price was paid for the pair
    // and all of it is already on her mother, so this costs nothing — which
    // means there is no entry to write at all, and that is the point.
    farm.takeAdvance(on: day1, from: 'Ali', amount: 50000);
    farm.takeAdvance(on: day1, from: 'Kashif', amount: 30000);
    audit(farm, 'day one');

    for (var month = 0; month < 6; month++) {
      final year = month < 4 ? 2026 : 2027;
      final mon = month < 4 ? 9 + month : month - 3;
      final days = daysInMonth(DateTime(year, mon));
      farm.period = periods[month];

      for (var day = 1; day <= days; day++) {
        final on = DateTime(year, mon, day);

        // Morning round over the counter, paid at the door.
        farm.sell(
          on: on,
          to: 'Counter',
          amount: 12000,
          litres: 60,
          paidNow: true,
        );
        // Evening round on credit, the name spelled differently each day.
        farm.sell(
          on: on,
          to: credit[day % credit.length],
          amount: 8000,
          litres: 40,
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
        if (day == 5) {
          farm.spend(on: on, on_: 'Salaries', amount: 60000);
          farm.payLoose(on: on, to: 'Landlord', amount: 35000);
        }
        if (day == 8) {
          farm.spend(
            on: on,
            on_: 'Utilities (bijli, gas, pani)',
            amount: 14000,
          );
        }
        if (day == 12) {
          farm.spend(on: on, on_: 'Transport', amount: 9000);
        }
        if (day == 17) {
          farm.spend(on: on, on_: 'Repairs', amount: 6000, paidNow: false);
        }

        // ---- a word nobody put on the list ----
        //
        // One the farm keeps and one it spends, because those are two
        // different things and the app has nothing to look either up in.
        if (day == 15) {
          farm.buyTyped(
            on: on,
            from: 'Tubewell wala',
            what: 'Tubewell repair',
            amount: 7000,
            keeps: false,
          );
        }
        if (month == 1 && day == 15) {
          farm.buyTyped(
            on: on,
            from: 'Trolley wala',
            what: 'Trolley',
            amount: 90000,
            keeps: true,
          );
        }

        // ---- money in with nothing booked against it ----
        if (day == 22) {
          farm.takeLoose(on: on, from: 'Scrap dealer', amount: 4000);
        }

        // ---- the vet ----
        if (day == 11) farm.vet(on: on, tag: 'B-02', amount: 9000);

        // ---- money coming in, part and whole ----
        if (day == 10) {
          farm.settleWith(on: on, party: 'Ali', amount: 30000, theyOweUs: true);
        }
        if (day == 20) {
          final owed = farm.stillOwing
              .where(
                (t) =>
                    t.isReceivable && partyKey(t.party) == partyKey('Kashif'),
              )
              .fold<num>(0, (a, t) => a + t.outstanding);
          farm.settleWith(
            on: on,
            party: 'Kashif',
            amount: owed,
            theyOweUs: true,
          );
        }
        if (day == 24) {
          farm.settleWith(
            on: on,
            party: 'Arbab Traders',
            amount: 55000,
            theyOweUs: false,
          );
        }
        if (day == 27) {
          // The repairs bill, in full.
          farm.settleWith(
            on: on,
            party: 'The farm',
            amount: 6000,
            theyOweUs: false,
          );
        }

        // ---- the herd ----
        if (month == 1 && day == 14) {
          // She died. Nothing came in; her cost comes off.
          farm.writeOff(on: on, tag: 'B-04', cost: 150000);
        }
        if (month == 2 && day == 9) {
          // Sold for more than she cost: 50,000 earned.
          farm.sellAnimal(on: on, tag: 'B-07', price: 200000, cost: 150000);
        }
        if (month == 4 && day == 18) {
          // And one sold for less than she cost: 40,000 lost.
          farm.sellAnimal(on: on, tag: 'B-09', price: 110000, cost: 150000);
        }

        // ---- the securities go back ----
        if (month == 5 && day == 20) {
          farm.giveAdvanceBack(on: on, to: 'Ali', amount: 50000);
          farm.giveAdvanceBack(on: on, to: 'Kashif', amount: 30000);
        }

        audit(farm, '${periods[month]} day $day');
      }

      shareLog.add(
        farm.closePeriod(
          on: DateTime(year, mon, days),
          // Taken out differently every month, and differently by each of
          // them — which is what changes the ratios underneath.
          takeOut: switch (month) {
            0 => const [1.0, 0.5, 0, 0],
            1 => const [0, 0, 1.0, 0.25],
            2 => const [0.5, 0.5, 0.5, 0.5],
            3 => const [0, 0, 0, 0],
            4 => const [1.0, 1.0, 1.0, 1.0],
            _ => const [0.3, 0, 0.6, 0],
          },
          nextPeriod: month == 5 ? '2027-03' : periods[month + 1],
        ),
      );
      audit(farm, 'after closing ${periods[month]}');
    }
  });

  group('the whole six months', () {
    test('audited after every day, and not a rupee out of place', () {
      // 30+31+30+31+31+28 days, plus the opening day and six closes.
      expect(auditsRun - startedAudits, 181 + 1 + 6);
      expect(farm.closed.length, 6);
    });

    test('the books balance at the end of it', () {
      final m = farm.money;
      expect(m.expected, m.farmMoney);
      expect(m.reconciles, isTrue);
    });

    test('every option in the ledger was actually used', () {
      final used = farm.ledger.map((t) => t.category).toSet();
      expect(
        used,
        containsAll([
          'Milk',
          'Cattle purchase',
          'Equipment',
          'Fodder / feed',
          'Salaries',
          'Utilities (bijli, gas, pani)',
          'Transport',
          'Repairs',
          'Vet & medicine',
          'Cattle sale',
          'Other receipt',
          'Other payment',
          'Khaata receipt',
          'Supplier payment',
          advanceCategory,
          advanceReturnCategory,
          writeOffCategory,
          profitShareCategory,
          'Tubewell repair',
          'Trolley',
        ]),
      );
      final types = farm.ledger.map((t) => t.type).toSet();
      expect(types, containsAll(TxnType.values));
    });
  });

  group('all time, against the periods it is made of', () {
    test('profit is the periods added up', () {
      final fromPeriods =
          farm.closed.fold<num>(0, (a, m) => a + (m.profit ?? 0)) +
          farm.books.profit;
      expect(
        farm.lifetimeSales + farm.lifetimeOtherIncome - farm.lifetimeCosts,
        fromPeriods,
      );
    });

    test('a closed period reads its own costs back', () {
      for (final m in farm.closed) {
        expect(
          (m.sales ?? 0) + (m.otherIncome ?? 0) - m.runningCosts,
          m.profit,
          reason: '${m.id} — the line does not add up to itself',
        );
      }
    });

    test('other income is in the all-time figure, not taken off it', () {
      // 4,000 of scrap on day 22, six months running.
      expect(farm.lifetimeOtherIncome, 4000 * 6);
    });

    test('the rent paid straight out is inside the costs', () {
      // It never was a purchase or an expense, so a period that adds those
      // up and nothing else loses it.
      final rent = farm.ledger
          .where((t) => t.isLoosePayment && t.party == 'Landlord')
          .fold<num>(0, (a, t) => a + t.amount);
      expect(rent, 35000 * 6);

      final storedOnly = farm.closed.fold<num>(
        0,
        (a, m) => a + (m.purchases ?? 0) + (m.expenses ?? 0) - (m.assets ?? 0),
      );
      final real = farm.closed.fold<num>(0, (a, m) => a + m.runningCosts);
      expect(
        real - storedOnly,
        35000 * 6,
        reason: 'six closed periods of rent that the old sum dropped',
      );
    });
  });

  group('the herd', () {
    test('a buffalo sold above her cost earns the difference', () {
      // 200,000 in and 150,000 off the books: 50,000, not 200,000.
      final sale = farm.ledger.firstWhere(
        (t) => t.category == 'Cattle sale' && t.amount == 200000,
      );
      final off = farm.ledger.firstWhere(
        (t) => t.isWriteOff && t.party == 'B-07',
      );
      expect(sale.amount - off.amount, 50000);
    });

    test('a buffalo sold below her cost is a loss, and shows as one', () {
      final sale = farm.ledger.firstWhere(
        (t) => t.category == 'Cattle sale' && t.amount == 110000,
      );
      final off = farm.ledger.firstWhere(
        (t) => t.isWriteOff && t.party == 'B-09',
      );
      expect(sale.amount - off.amount, -40000);
    });

    test('one that died earns nothing and costs what she cost', () {
      final off = farm.ledger.firstWhere(
        (t) => t.isWriteOff && t.party == 'B-04',
      );
      expect(off.amount, 150000);
      expect(
        farm.ledger.any(
          (t) => t.category == 'Cattle sale' && t.party.contains('B-04'),
        ),
        isFalse,
      );
    });

    test('the vet is a cost, never an asset', () {
      final vet = farm.ledger.where((t) => t.category == 'Vet & medicine');
      expect(vet, isNotEmpty);
      expect(vet.every((t) => !t.isCapitalAsset), isTrue);
      expect(vet.every((t) => t.isRunningCost), isTrue);
    });

    test('what the farm owns is what it bought less what came off', () {
      // Cattle, shed, trolley — less the three animals gone.
      expect(farm.assetsOwned, 1200000 + 200000 + 90000 - 450000);
    });
  });

  group('a category nobody put on the list', () {
    test('one the farm keeps is an asset and does not eat the profit', () {
      final trolley = farm.ledger.firstWhere((t) => t.category == 'Trolley');
      expect(trolley.isCapitalAsset, isTrue);
      expect(trolley.isRunningCost, isFalse);
    });

    test('one that was spent is a cost like any other', () {
      final repair = farm.ledger.where((t) => t.category == 'Tubewell repair');
      expect(repair.length, 6);
      expect(repair.every((t) => t.isCapitalAsset), isFalse);
      expect(repair.every((t) => t.isRunningCost), isTrue);
    });

    test('both come back on the list for next time', () {
      final used = categoriesUsed(farm.ledger)[TxnType.purchase] ?? const [];
      expect(used, containsAll(['Trolley', 'Tubewell repair']));
    });

    test('a typed word is found on the tab it was typed on', () {
      expect(tabsUsingCategory(farm.ledger, 'trolley'), [TxnType.purchase]);
    });
  });

  group('what somebody is handed', () {
    test("a customer's statement is what his account says", () {
      final s = buildStatement(rows: farm.ledger, party: 'ALI');
      final owing = partyOwing(farm.ledger, 'ali');
      expect(s.closing, owing.owesUs - owing.weOwe);
      expect(owing.owesUs, greaterThan(0), reason: 'he is still on credit');
    });

    test('the advance never came off what he owed', () {
      // Taken on day one, given back in the last month, and in between it
      // moved his balance not at all.
      final held = farm.ledger
          .where((t) => t.isAdvanceIn && partyKey(t.party) == 'ali')
          .fold<num>(0, (a, t) => a + t.amount);
      expect(held, 50000);

      // Day one: he left 50,000 as security and took 8,000 of milk on
      // credit. He owes eight thousand. If the security were being counted
      // as a payment the page would say the farm owed him forty-two, which
      // is not a thing anybody would believe of a man who has paid nothing.
      final dayOne = buildStatement(
        rows: farm.ledger,
        party: 'Ali',
        to: DateTime(2026, 9, 1),
      );
      expect(dayOne.closing, 8000);
    });

    test('the man at the counter is never shown owing anything', () {
      expect(buildStatement(rows: farm.ledger, party: 'Counter').closing, 0);
    });

    test('the mandi, paid on the spot, is owed nothing', () {
      expect(buildStatement(rows: farm.ledger, party: 'Mandi').closing, 0);
    });

    test('the landlord is owed nothing and owes nothing', () {
      expect(buildStatement(rows: farm.ledger, party: 'Landlord').closing, 0);
    });

    test('the cash book closes at the cash', () {
      final s = buildStatement(rows: farm.ledger, capital: farm.capitalIn);
      expect(s.closing, farm.books.cash);
      expect(s.opening, farm.capitalIn);
    });

    test('a dead buffalo is not a line in the cash book', () {
      final s = buildStatement(rows: farm.ledger, capital: farm.capitalIn);
      expect(s.lines.any((l) => l.detail.contains(writeOffCategory)), isFalse);
    });

    test('a window of days opens where the one before it closed', () {
      final upToNov = buildStatement(
        rows: farm.ledger,
        party: 'Ali',
        to: DateTime(2026, 11, 30),
      );
      final fromDec = buildStatement(
        rows: farm.ledger,
        party: 'Ali',
        from: DateTime(2026, 12, 1),
      );
      expect(fromDec.opening, upToNov.closing);
    });
  });

  group('settling up, six times over', () {
    test('every rupee of profit was handed out or left in', () {
      for (var i = 0; i < shareLog.length; i++) {
        final shares = shareLog[i];
        final handed = shares.fold<num>(0, (a, s) => a + s.share);
        expect(
          handed,
          farm.closed[i].profitShared,
          reason: '${periods[i]} — the shares do not add to the profit',
        );
      }
    });

    test('a founder who leaves his share in ends up with more of the next', () {
      // Rafeeque took almost nothing out for four months running. His slice
      // has to have grown, and the man who took everything out has to have
      // shrunk against him.
      final first = shareLog.first;
      final last = shareLog.last;
      num sliceOf(List<MonthShare> shares, String id) {
        final total = shares.fold<num>(0, (a, s) => a + s.share);
        if (total <= 0) return 0;
        return shares.firstWhere((s) => s.partnerId == id).share / total;
      }

      expect(sliceOf(last, 'p3'), greaterThan(sliceOf(first, 'p3')));
      expect(sliceOf(last, 'p0'), lessThan(sliceOf(first, 'p0')));
    });

    test('nobody was paid out more than the farm made', () {
      expect(
        farm.paidToFounders,
        lessThanOrEqualTo(
          farm.closed.fold<num>(0, (a, m) => a + (m.profitShared ?? 0)),
        ),
      );
    });

    test('a profit share is money out but never a cost', () {
      final shares = farm.ledger.where((t) => t.isProfitShare);
      expect(shares, isNotEmpty);
      expect(shares.every((t) => !t.isRunningCost), isTrue);
    });
  });

  group('part payments happened, and behaved', () {
    test('entries were left half settled, over and over', () {
      expect(
        farm.partPayments.length,
        greaterThan(5),
        reason: 'a run where every payment landed on a boundary proves little',
      );
    });

    test('the money always filled the oldest entry first', () {
      expect(farm.alwaysOldestFirst, isTrue);
    });

    test('nothing ever took more than it was worth', () {
      for (final t in farm.ledger) {
        expect(t.paidSoFar, lessThanOrEqualTo(t.amount));
        expect(t.paidSoFar + t.outstanding, t.amount);
      }
    });
  });
}
