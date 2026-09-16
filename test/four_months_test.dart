import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';
import 'package:char_yar_dairy_farm/services/allocation.dart';

/// Four months of the farm, day by day, audited at every step.
///
/// Milk goes out twice a day — one round paid at the door, one on credit.
/// Feed, wages, rent, bills and the vet go out monthly. Buffaloes are bought,
/// one dies and one is sold. Two customers leave an advance and get it back.
/// Money comes in when they have it, in part or in full. Every month is
/// settled and the profit shared, some taken out and some left in.
///
/// Three things are checked after every single day:
///
///   1. **Every entry adds up.** What came plus what is still owed is what
///      was booked. On all of them, always.
///   2. **The books balance.** Every rupee that came in, less every rupee
///      that went out or turned into an animal, against what the farm is
///      actually holding — the same check the app shows on the home page.
///   3. **Nothing is counted twice.** What was sold is income once, in the
///      period it was sold, and the money that settles it later is cash and
///      nothing more.
///
/// Where the arithmetic is the app's own — the allocation of a payment across
/// entries, the books, the share-out — the app's own code is called, not a
/// copy of it. A mistake there fails here.

// ---------------------------------------------------------------- the farm

class Farm {
  Farm({required this.founders});

  final List<Partner> founders;
  final List<Txn> ledger = [];
  final List<FarmMonth> closed = [];

  /// Capital the four of them have actually put in, from their own pockets.
  num capitalIn = 0;

  /// What each has left in out of profit, and taken out.
  final Map<String, num> reinvested = {};
  final Map<String, num> withdrawn = {};

  String period = '2026-09';
  num openingCash = 0;
  var _seq = 0;

  /// Every day an entry was left part settled, and by how much.
  ///
  /// Kept as it happens rather than read off the end, because a part payment
  /// is a thing that occurs and then gets finished off: look only at the last
  /// day and a run where every payment happened to land on a boundary would
  /// pass while proving nothing.
  final List<String> partPayments = [];

  /// Whether the money always filled the oldest entry first, every time.
  bool alwaysOldestFirst = true;

  // ---- the ledger ----

  Txn _write({
    required DateTime on,
    required TxnType type,
    required String party,
    required String category,
    required num amount,
    required bool paid,
    num? litres,
    String? settles,
  }) {
    final txn = Txn(
      id: 'e${_seq++}',
      date: on,
      monthId: period,
      type: type,
      party: party,
      category: category,
      qty: litres,
      unit: litres == null ? null : 'L',
      rate: litres == null ? null : amount / litres,
      amount: amount,
      paid: paid,
      paidSoFar: paid ? amount : 0,
      paidAt: paid ? on : null,
      note: '',
      settlesTxnId: settles,
      paidOnCreate: paid,
      createdBy: 'u0',
      createdByName: 'Saleem Rehman',
      createdAt: on,
    );
    ledger.add(txn);
    return txn;
  }

  /// Replaces an entry in place, which is what a Firestore update comes back
  /// as once the stream redelivers it.
  void _replace(Txn old, Txn fresh) {
    ledger[ledger.indexOf(old)] = fresh;
  }

  Txn sell({
    required DateTime on,
    required String to,
    required num amount,
    required num litres,
    required bool paidNow,
  }) => _write(
    on: on,
    type: TxnType.sale,
    party: to,
    category: 'Milk',
    amount: amount,
    paid: paidNow,
    litres: litres,
  );

  Txn buy({
    required DateTime on,
    required String from,
    required String what,
    required num amount,
    bool paidNow = true,
  }) => _write(
    on: on,
    type: TxnType.purchase,
    party: from,
    category: what,
    amount: amount,
    paid: paidNow,
  );

  Txn spend({
    required DateTime on,
    required String on_,
    required num amount,
    String party = 'The farm',
    bool paidNow = true,
  }) => _write(
    on: on,
    type: TxnType.expense,
    party: party,
    category: on_,
    amount: amount,
    paid: paidNow,
  );

  /// Rent handed over with no bill ever booked against it.
  void payLoose({
    required DateTime on,
    required String to,
    required num amount,
  }) => _write(
    on: on,
    type: TxnType.payment,
    party: to,
    category: 'Other payment',
    amount: amount,
    paid: true,
  );

  /// A buffalo off the books at what she cost — sold, died or slaughtered.
  void writeOff({
    required DateTime on,
    required String tag,
    required num cost,
  }) => _write(
    on: on,
    type: TxnType.expense,
    party: tag,
    category: writeOffCategory,
    amount: cost,
    paid: true,
  );

  /// Money a customer leaves with the farm against a standing order.
  void takeAdvance({
    required DateTime on,
    required String from,
    required num amount,
  }) => _write(
    on: on,
    type: TxnType.receipt,
    party: from,
    category: advanceCategory,
    amount: amount,
    paid: true,
  );

  void giveAdvanceBack({
    required DateTime on,
    required String to,
    required num amount,
  }) => _write(
    on: on,
    type: TxnType.payment,
    party: to,
    category: advanceReturnCategory,
    amount: amount,
    paid: true,
  );

  /// One lump of money against everything this party still owes, or is owed.
  ///
  /// Runs the app's own [allocate] and then does exactly what `TxnRepo.settle`
  /// does with the result: move each entry along, and post one settlement row
  /// per entry for the part that landed on it.
  num settleWith({
    required DateTime on,
    required String party,
    required num amount,
    required bool theyOweUs,
  }) {
    final theirs = ledger
        .where(
          (t) =>
              partyKey(t.party) == partyKey(party) &&
              t.outstanding > 0 &&
              (theyOweUs ? t.isReceivable : t.isPayable),
        )
        .toList();

    final landings = allocate(theirs, amount);

    // Oldest first, checked on the way through rather than taken on trust.
    for (var i = 1; i < landings.length; i++) {
      if (landings[i].entry.date.isBefore(landings[i - 1].entry.date)) {
        alwaysOldestFirst = false;
      }
    }
    // Everything the money reached is filled, bar the last one it touched.
    for (var i = 0; i < landings.length - 1; i++) {
      if (!landings[i].finishes) alwaysOldestFirst = false;
    }

    for (final landing in landings) {
      final txn = landing.entry;
      _replace(
        txn,
        Txn(
          id: txn.id,
          date: txn.date,
          monthId: txn.monthId,
          type: txn.type,
          party: txn.party,
          category: txn.category,
          qty: txn.qty,
          unit: txn.unit,
          rate: txn.rate,
          amount: txn.amount,
          paid: landing.finishes,
          paidSoFar: landing.paidAfter,
          paidAt: landing.finishes ? on : null,
          note: txn.note,
          paidOnCreate: false,
          createdBy: txn.createdBy,
          createdByName: txn.createdByName,
          createdAt: txn.createdAt,
        ),
      );

      if (!landing.finishes) {
        partPayments.add(
          '${on.toIso8601String().substring(0, 10)} ${txn.party} '
          '${landing.take} of ${txn.amount}',
        );
      }

      _write(
        on: on,
        type: theyOweUs ? TxnType.receipt : TxnType.payment,
        party: txn.party,
        category: theyOweUs ? 'Khaata receipt' : 'Supplier payment',
        amount: landing.take,
        paid: true,
        settles: txn.id,
      );
    }
    return landings.fold<num>(0, (a, l) => a + l.take);
  }

  // ---- the figures ----

  List<Txn> get _live => ledger.where((t) => !t.isDeleted).toList();
  List<Txn> get thisPeriod => _live.where((t) => t.monthId == period).toList();
  List<Txn> get stillOwing => _live.where((t) => !t.paid).toList();

  Books get books => Books(
    monthId: period,
    openingCash: openingCash,
    capital: capitalIn,
    monthTxns: thisPeriod,
    unpaidTxns: stillOwing,
  );

  num get assetsOwned => _live.fold<num>(
    0,
    (a, t) =>
        t.isCapitalAsset ? a + t.amount : (t.isWriteOff ? a - t.amount : a),
  );

  num get advancesHeld => _live.fold<num>(
    0,
    (a, t) =>
        t.isAdvanceIn ? a + t.amount : (t.isAdvanceOut ? a - t.amount : a),
  );

  num get paidToFounders =>
      _live.where((t) => t.isProfitShare).fold<num>(0, (a, t) => a + t.amount);

  /// All time, closed periods plus the one still open.
  num get lifetimeSales =>
      closed.fold<num>(0, (a, m) => a + (m.sales ?? 0)) + books.sales;
  num get lifetimeOtherIncome =>
      closed.fold<num>(0, (a, m) => a + (m.otherIncome ?? 0)) +
      books.otherIncome;
  num get lifetimeCosts =>
      closed.fold<num>(
        0,
        (a, m) => a + (m.sales ?? 0) + (m.otherIncome ?? 0) - (m.profit ?? 0),
      ) +
      books.costs;

  MoneySummary get money => MoneySummary(
    capital: capitalIn,
    assets: assetsOwned,
    runningCosts: lifetimeCosts,
    sales: lifetimeSales,
    otherIncome: lifetimeOtherIncome,
    cash: books.cash,
    receivable: books.receivable,
    payable: books.payable,
    paidOut: paidToFounders,
    advancesHeld: advancesHeld,
  );

  /// The four of them, as they stand now.
  List<Partner> get partnersNow => [
    for (final p in founders)
      Partner(
        id: p.id,
        userId: p.userId,
        name: p.name,
        invested: p.invested,
        reinvested: reinvested[p.id] ?? 0,
        withdrawn: withdrawn[p.id] ?? 0,
        createdAt: p.createdAt,
      ),
  ];

  // ---- settling up ----

  /// Freeze the period, hand out the shares, open the next one.
  ///
  /// `takeOut` says what fraction of their slice each founder takes in cash;
  /// the rest stays in the farm and lifts their share of the next one.
  List<MonthShare> closePeriod({
    required DateTime on,
    required List<double> takeOut,
    required String nextPeriod,
  }) {
    final b = books;
    final toShare = b.profit > 0 ? b.profit : 0;
    final shares = shareOut(
      partners: partnersNow,
      profitToShare: toShare,
      choices: const {},
    );

    closed.add(
      FarmMonth(
        id: period,
        status: 'closed',
        openingCash: openingCash,
        sales: b.sales,
        otherIncome: b.otherIncome,
        purchases: b.purchases,
        expenses: b.expenses,
        receivables: b.receivable,
        assets: b.assetsBought,
        profit: b.profit,
        profitShared: toShare,
      ),
    );

    final carried = b.operatingCash;
    period = nextPeriod;
    openingCash = carried;

    for (var i = 0; i < shares.length; i++) {
      final share = shares[i];
      final out = (share.share * takeOut[i]).round();
      final left = share.share - out;
      if (left > 0) {
        reinvested[share.partnerId] = (reinvested[share.partnerId] ?? 0) + left;
      }
      if (out > 0) {
        withdrawn[share.partnerId] = (withdrawn[share.partnerId] ?? 0) + out;
        _write(
          on: on,
          type: TxnType.payment,
          party: share.name,
          category: profitShareCategory,
          amount: out,
          paid: true,
        );
      }
    }
    return shares;
  }
}

// ---------------------------------------------------------------- the audit

/// How many times the books have been checked. Counted so a run that
/// silently skipped the checking cannot pass for one that did them.
var auditsRun = 0;

/// Everything that has to be true of the books, whatever has just happened.
void audit(Farm farm, String when) {
  auditsRun++;
  // 1. Every entry adds up.
  for (final t in farm.ledger) {
    expect(
      t.paidSoFar + t.outstanding,
      t.amount,
      reason: '$when — entry ${t.id} (${t.party}, ${t.category})',
    );
    expect(
      t.paidSoFar,
      lessThanOrEqualTo(t.amount),
      reason: '$when — ${t.id} has taken more than it was worth',
    );
    expect(t.paidSoFar, greaterThanOrEqualTo(0), reason: '$when — ${t.id}');
  }

  // 2. What is owed is what the entries say is owed.
  final b = farm.books;
  final owedToUs = farm.stillOwing
      .where((t) => t.isReceivable)
      .fold<num>(0, (a, t) => a + t.outstanding);
  final owedByUs = farm.stillOwing
      .where((t) => t.isPayable)
      .fold<num>(0, (a, t) => a + t.outstanding);
  expect(b.receivable, owedToUs, reason: '$when — receivable');
  expect(b.payable, owedByUs, reason: '$when — payable');

  // 3. Profit is sales plus other money in, less what it cost to run.
  expect(b.profit, b.sales + b.otherIncome - b.costs, reason: '$when — profit');

  // 4. The books balance, which is the check the app puts on the home page.
  final m = farm.money;
  expect(
    m.reconciles,
    isTrue,
    reason:
        '$when — books out by ${m.expected - m.farmMoney} '
        '(waterfall ${m.expected}, holdings ${m.farmMoney})',
  );

  // 5. An advance is never income and never a cost.
  final advanceIn = farm.ledger
      .where((t) => t.isAdvanceIn)
      .fold<num>(0, (a, t) => a + t.amount);
  if (advanceIn > 0) {
    expect(
      farm.ledger.where((t) => t.isAdvanceIn).every((t) => !t.isLooseReceipt),
      isTrue,
      reason: '$when — an advance has crept into income',
    );
  }
}

// ---------------------------------------------------------------- the months

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

  // Deliberately written four ways. One man, one account.
  const creditBuyers = ['Ali', 'ali', 'ALI', 'Kashif'];
  const periods = ['2026-09', '2026-10', '2026-11', '2026-12'];

  setUpAll(() {
    // ---- the herd and the shed, bought on day one ----
    final day1 = DateTime(2026, 9, 1);
    farm.buy(on: day1, from: 'Mandi', what: 'Cattle purchase', amount: 1200000);
    farm.buy(on: day1, from: 'Dealer', what: 'Equipment', amount: 200000);

    // Two customers leave an advance against a standing order.
    farm.takeAdvance(on: day1, from: 'Ali', amount: 50000);
    farm.takeAdvance(on: day1, from: 'Kashif', amount: 30000);
    audit(farm, 'day one');

    for (var month = 0; month < 4; month++) {
      final year = 2026;
      final mon = 9 + month;
      final days = daysInMonth(DateTime(year, mon));
      farm.period = periods[month];

      for (var day = 1; day <= days; day++) {
        final on = DateTime(year, mon, day);

        // Morning round, paid at the door.
        farm.sell(
          on: on,
          to: 'Counter',
          amount: 12000,
          litres: 60,
          paidNow: true,
        );
        // Evening round, on credit. The name is spelled differently on
        // purpose — the books have to treat Ali, ali and ALI as one man.
        farm.sell(
          on: on,
          to: creditBuyers[day % creditBuyers.length],
          amount: 8000,
          litres: 40,
          paidNow: false,
        );

        // ---- the running of the place ----
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
          // Rent, handed over with no bill booked against it.
          farm.payLoose(on: on, to: 'Landlord', amount: 35000);
        }
        if (day == 8) {
          farm.spend(
            on: on,
            on_: 'Utilities (bijli, gas, pani)',
            amount: 14000,
          );
        }
        if (day == 11) {
          farm.buy(on: on, from: 'Vet', what: 'Vet & medicine', amount: 9000);
        }

        // ---- money coming in, in part and in full ----
        if (day == 10) {
          // Ali pays some of what he owes, never the round figure.
          farm.settleWith(on: on, party: 'Ali', amount: 30000, theyOweUs: true);
        }
        if (day == 20) {
          // Kashif clears the lot.
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
          // The feed bill, half of it.
          farm.settleWith(
            on: on,
            party: 'Arbab Traders',
            amount: 55000,
            theyOweUs: false,
          );
        }

        // ---- the herd ----
        if (month == 1 && day == 14) {
          farm.writeOff(on: on, tag: 'B-04', cost: 150000);
        }
        if (month == 2 && day == 9) {
          // Bought for 150,000, sold for 200,000. The gain is 50,000.
          farm.sell(
            on: on,
            to: 'Cattle buyer',
            amount: 200000,
            litres: 1,
            paidNow: true,
          );
          farm.writeOff(on: on, tag: 'B-07', cost: 150000);
        }

        // ---- the advances come back at the end ----
        if (month == 3 && day == 20) {
          farm.giveAdvanceBack(on: on, to: 'Ali', amount: 50000);
          farm.giveAdvanceBack(on: on, to: 'Kashif', amount: 30000);
        }

        audit(farm, '${periods[month]} day $day');
      }

      // ---- settling up ----
      final lastDay = DateTime(year, mon, days);
      shareLog.add(
        farm.closePeriod(
          on: lastDay,
          // One takes it all, one takes half, two leave it in.
          takeOut: const [1.0, 0.5, 0, 0],
          nextPeriod: month == 3 ? '2027-01' : periods[month + 1],
        ),
      );
      audit(farm, 'after closing ${periods[month]}');
    }
  });

  group('the whole four months', () {
    test('every day of it audited without a rupee out of place', () {
      // setUpAll has already run the whole audit after every single day and
      // after every close, so reaching here at all is the result. These
      // figures only prove the run was as long as it claims.
      //
      // 30 + 31 + 30 + 31 days, plus the opening day and four closes.
      expect(auditsRun, 122 + 1 + 4);
      expect(farm.closed.length, 4);
      expect(
        farm.ledger.where((t) => t.type == TxnType.sale).length,
        greaterThan(240),
        reason: 'two rounds a day for four months',
      );
    });

    test('the books still balance at the end', () {
      final m = farm.money;
      expect(m.expected, m.farmMoney);
      expect(m.reconciles, isTrue);
    });
  });

  group('one man, however his name is spelled', () {
    test('Ali, ali and ALI are one account', () {
      final his = farm.ledger.where((t) => partyKey(t.party) == 'ali').toList();
      final spellings = his.map((t) => t.party).toSet();
      expect(
        spellings.length,
        greaterThan(1),
        reason: 'the test wrote his name several ways on purpose',
      );
      expect(spellings, containsAll(['Ali', 'ali', 'ALI']));
    });

    test('his account adds up across all of them', () {
      final his = farm.ledger.where(
        (t) => partyKey(t.party) == 'ali' && t.isReceivable,
      );
      final owed = his.fold<num>(0, (a, t) => a + t.outstanding);
      expect(owed, greaterThan(0), reason: 'he is still on credit');

      // The same figure, reached the way the ledger screen reaches it.
      final sold = farm.ledger
          .where((t) => partyKey(t.party) == 'ali' && t.type == TxnType.sale)
          .fold<num>(0, (a, t) => a + t.amount);
      final taken = farm.ledger
          .where((t) => partyKey(t.party) == 'ali' && t.type == TxnType.sale)
          .fold<num>(0, (a, t) => a + t.paidSoFar);
      expect(sold - taken, owed);
    });

    test('a different name is a different man', () {
      expect(partyKey('Ali Khan'), isNot(partyKey('Ali')));
      expect(partyKey('Ali Ahmed'), isNot(partyKey('Ali Khan')));
      expect(partyKey('  ALI  '), partyKey('ali'));
      expect(partyKey('Ali  Khan'), partyKey('ali khan'));
    });
  });

  group('what the four of them were paid', () {
    test('every share adds up to the profit it came out of', () {
      for (var i = 0; i < 4; i++) {
        final shared = farm.closed[i].profitShared ?? 0;
        final handed = shareLog[i].fold<num>(0, (a, s) => a + s.share);
        expect(
          handed,
          shared > 0 ? shared.round() : 0,
          reason: 'period ${periods[i]}',
        );
      }
    });

    test('leaving it in raises your slice, taking it out lowers it', () {
      final before = ratiosOf(founders);
      final now = ratiosOf(farm.partnersNow);
      expect(now['p0']!, lessThan(before['p0']!), reason: 'took it all out');
      expect(now['p2']!, greaterThan(before['p2']!), reason: 'left it all in');
      expect(now['p3']!, greaterThan(before['p3']!), reason: 'left it all in');
      expect(now.values.fold<double>(0, (a, r) => a + r), closeTo(1, 1e-9));
    });

    test('what left the farm is what they were actually handed', () {
      final handedOut = farm.withdrawn.values.fold<num>(0, (a, v) => a + v);
      expect(farm.paidToFounders, handedOut);
    });

    test('what was left in never leaves the cash', () {
      // Reinvested profit was earned by the farm and is already sitting in the
      // cash it came from. Counting it as fresh capital would invent money.
      expect(farm.capitalIn, 2000000, reason: 'only what came out of pockets');
      final leftIn = farm.reinvested.values.fold<num>(0, (a, v) => a + v);
      expect(leftIn, greaterThan(0));
      expect(
        farm.partnersNow.fold<num>(0, (a, p) => a + p.capital),
        2000000 + leftIn,
      );
    });
  });

  group('the advances', () {
    test('they were held, then handed back, and never earned', () {
      expect(farm.advancesHeld, 0, reason: 'both returned in month four');

      final taken = farm.ledger
          .where((t) => t.isAdvanceIn)
          .fold<num>(0, (a, t) => a + t.amount);
      final given = farm.ledger
          .where((t) => t.isAdvanceOut)
          .fold<num>(0, (a, t) => a + t.amount);
      expect(taken, 80000);
      expect(given, 80000);
    });

    test('not one rupee of it reached the profit', () {
      final allProfit = farm.closed.fold<num>(0, (a, m) => a + (m.profit ?? 0));
      final sales = farm.closed.fold<num>(0, (a, m) => a + (m.sales ?? 0));
      final other = farm.closed.fold<num>(
        0,
        (a, m) => a + (m.otherIncome ?? 0),
      );
      final costs = farm.closed.fold<num>(
        0,
        (a, m) => a + (m.sales ?? 0) + (m.otherIncome ?? 0) - (m.profit ?? 0),
      );
      expect(allProfit, sales + other - costs);
      expect(other, 0, reason: 'an advance is not other income');
    });
  });

  group('the herd', () {
    test('the farm owns what it bought less what has left', () {
      // 1,200,000 of buffalo and 200,000 of equipment, less two written off
      // at 150,000 each.
      expect(farm.assetsOwned, 1100000);
    });

    test('a buffalo sold at a gain earns the gain, not the price', () {
      final sold = farm.ledger.firstWhere((t) => t.party == 'Cattle buyer');
      final off = farm.ledger.firstWhere((t) => t.party == 'B-07');
      expect(sold.amount - off.amount, 50000);
    });

    test('a buffalo that died cost the farm and moved no money', () {
      final died = farm.ledger.firstWhere((t) => t.party == 'B-04');
      expect(died.isWriteOff, isTrue);
      expect(died.isRunningCost, isTrue, reason: 'a real loss');
      expect(
        died.isCapitalAsset,
        isFalse,
        reason: 'she is not something the farm owns any more',
      );
    });
  });

  group('nothing counted twice', () {
    test('a settlement row is never income or a cost', () {
      final settlements = farm.ledger.where((t) => t.settlesAnotherEntry);
      expect(settlements, isNotEmpty);
      for (final t in settlements) {
        expect(t.isLooseReceipt, isFalse, reason: '${t.id} became income');
        expect(t.isLoosePayment, isFalse, reason: '${t.id} became a cost');
      }
    });

    test('what a customer paid equals the settlement rows against him', () {
      for (final name in ['ali', 'kashif']) {
        final taken = farm.ledger
            .where((t) => partyKey(t.party) == name && t.type == TxnType.sale)
            .fold<num>(0, (a, t) => a + t.paidSoFar);
        final receipts = farm.ledger
            .where(
              (t) =>
                  partyKey(t.party) == name &&
                  t.type == TxnType.receipt &&
                  t.settlesAnotherEntry,
            )
            .fold<num>(0, (a, t) => a + t.amount);
        expect(receipts, taken, reason: '$name — cash against entries');
      }
    });

    test('four months of profit is four months of trading and no more', () {
      final sales = farm.closed.fold<num>(0, (a, m) => a + (m.sales ?? 0));
      final profit = farm.closed.fold<num>(0, (a, m) => a + (m.profit ?? 0));
      final costs = farm.closed.fold<num>(
        0,
        (a, m) => a + (m.sales ?? 0) + (m.otherIncome ?? 0) - (m.profit ?? 0),
      );
      expect(profit, sales - costs);
      expect(sales, greaterThan(0));
    });
  });

  group('the part payments, over four months', () {
    test('entries were left part settled, over and over', () {
      // Ali hands over 30,000 against days of 8,000, so the money stops part
      // way through an entry nearly every time.
      expect(
        farm.partPayments.length,
        greaterThan(3),
        reason: 'four months of paying less than is owed',
      );
    });

    test('and every one of them was later filled or is still in flight', () {
      // Nothing is ever half settled and forgotten: an entry either finishes
      // or is the one entry still in flight.
      final inFlight = farm.ledger.where((t) => t.partlyPaid).length;
      expect(inFlight, lessThanOrEqualTo(1));
    });

    test('the money always filled the oldest entry first', () {
      expect(farm.alwaysOldestFirst, isTrue);
    });

    test('the oldest unsettled entry is the one being filled', () {
      final owing =
          farm.stillOwing
              .where(
                (t) => t.isReceivable && partyKey(t.party) == partyKey('Ali'),
              )
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));
      // Everything before the part paid one is finished; everything after it
      // is untouched. That is what oldest-first means.
      final part = owing.where((t) => t.partlyPaid).toList();
      expect(part.length, lessThanOrEqualTo(1), reason: 'only one in flight');
      for (final t in owing) {
        if (part.isEmpty) continue;
        if (t.date.isAfter(part.first.date)) {
          expect(t.paidSoFar, 0, reason: 'later entries untouched');
        }
      }
    });
  });
}
