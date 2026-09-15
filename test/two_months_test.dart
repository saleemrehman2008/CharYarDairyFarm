import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';

/// Two months of a real farm, run end to end.
///
/// Four friends put money in, buy a herd, sell milk, let a customer take some
/// on credit, lose a buffalo, sell another, settle up, and do it again.
///
/// The farm is four people's savings, and a figure that is out by a rupee is
/// a figure one of them can point at. So at every step two things are
/// checked: the money the farm holds against the money the farm says it
/// holds, and the profit that is shared against the profit that was made.

var _n = 0;

Txn _e({
  required TxnType type,
  required num amount,
  required String category,
  required String monthId,
  String party = 'Someone',
  bool paid = true,
  String? settles,
  int day = 10,
}) {
  final on = DateTime(2026, monthId == '2026-09' ? 9 : 10, day);
  return Txn(
    id: 'txn${_n++}',
    date: on,
    monthId: monthId,
    type: type,
    party: party,
    category: category,
    amount: amount,
    paid: paid,
    paidAt: paid ? on : null,
    note: '',
    settlesTxnId: settles,
    paidOnCreate: paid,
    createdBy: 'u',
    createdByName: 'Ghulam Ali',
    createdAt: on,
  );
}

List<Partner> _partners(List<num> invested, [List<num>? reinvested]) => [
  for (var i = 0; i < invested.length; i++)
    Partner(
      id: 'p$i',
      userId: 'u$i',
      name: 'Founder $i',
      invested: invested[i],
      reinvested: reinvested == null ? 0 : reinvested[i],
      withdrawn: 0,
      createdAt: DateTime(2026, 1, 1),
    ),
];

/// The home page's breakdown, for whatever the books say at that moment.
MoneySummary _summary({
  required num capital,
  required num assets,
  required num runningCosts,
  required num sales,
  required Books books,
  num paidOut = 0,
}) => MoneySummary(
  capital: capital,
  assets: assets,
  runningCosts: runningCosts,
  sales: sales,
  cash: books.cash,
  receivable: books.receivable,
  payable: books.payable,
  paidOut: paidOut,
);

void main() {
  // Four friends, uneven pockets: 40, 30, 20 and 10 per cent.
  final founders = _partners([800000, 600000, 400000, 200000]);
  const capital = 2000000;

  // ---------------------------------------------------------------- September

  final herd = _e(
    type: TxnType.purchase,
    amount: 1200000,
    category: 'Cattle purchase',
    party: 'Mandi',
    monthId: '2026-09',
    day: 1,
  );
  final chiller = _e(
    type: TxnType.purchase,
    amount: 200000,
    category: 'Equipment',
    monthId: '2026-09',
    day: 1,
  );
  final feedPaid = _e(
    type: TxnType.purchase,
    amount: 90000,
    category: 'Fodder / feed',
    monthId: '2026-09',
  );
  final feedOwed = _e(
    type: TxnType.purchase,
    amount: 60000,
    category: 'Fodder / feed',
    party: 'Arbab Traders',
    paid: false,
    monthId: '2026-09',
    day: 25,
  );
  final wages = _e(
    type: TxnType.expense,
    amount: 55000,
    category: 'Salaries',
    monthId: '2026-09',
  );
  // Rent handed over with no bill ever booked against it — the hole the farm
  // found the hard way.
  final rentLoose = _e(
    type: TxnType.payment,
    amount: 35000,
    category: 'Other payment',
    party: 'Landlord',
    monthId: '2026-09',
  );
  final vet = _e(
    type: TxnType.purchase,
    amount: 12000,
    category: 'Vet & medicine',
    monthId: '2026-09',
  );
  final milkCash = _e(
    type: TxnType.sale,
    amount: 380000,
    category: 'Milk',
    monthId: '2026-09',
  );
  final milkKhaata = _e(
    type: TxnType.sale,
    amount: 120000,
    category: 'Milk',
    party: 'Ahmed',
    paid: false,
    monthId: '2026-09',
    day: 28,
  );
  // A buffalo dies. She cost 150,000 and the farm has lost it.
  final died = _e(
    type: TxnType.expense,
    amount: 150000,
    category: writeOffCategory,
    party: 'B-04',
    monthId: '2026-09',
    day: 20,
  );

  final sepLedger = [
    herd,
    chiller,
    feedPaid,
    feedOwed,
    wages,
    rentLoose,
    vet,
    milkCash,
    milkKhaata,
    died,
  ];
  final sepUnpaid = sepLedger.where((t) => !t.paid).toList();
  final sep = Books(
    monthId: '2026-09',
    openingCash: 0,
    capital: capital,
    monthTxns: sepLedger,
    unpaidTxns: sepUnpaid,
  );

  group('September', () {
    test('only the milk is income — what the friends put in is not', () {
      expect(sep.sales, 500000, reason: '380,000 cash and 120,000 on khaata');
    });

    test('the herd and the chiller are owned, not spent', () {
      expect(sep.assetsBought, 1400000);
    });

    test('costs are feed, wages, rent, vet, and the buffalo that died', () {
      // 90,000 + 60,000 feed, 12,000 vet, 55,000 wages,
      // 35,000 rent paid loose, 150,000 written off.
      expect(sep.costs, 402000);
      expect(sep.loosePayments, 35000, reason: 'the rent still counts');
      expect(sep.writeOffs, 150000);
    });

    test('profit is what was sold less what it cost to run the place', () {
      expect(sep.profit, 98000);
      expect(sep.profit, sep.sales - sep.costs);
    });

    test('a buffalo dying costs the farm but moves no money', () {
      final asIfAlive = Books(
        monthId: '2026-09',
        openingCash: 0,
        capital: capital,
        monthTxns: sepLedger.where((t) => !t.isWriteOff).toList(),
        unpaidTxns: sepUnpaid,
      );
      expect(
        sep.cash,
        asIfAlive.cash,
        reason: 'not a rupee moved the day she died',
      );
      expect(
        sep.profit,
        asIfAlive.profit - 150000,
        reason: 'but the farm is genuinely 150,000 poorer',
      );
    });

    test('credit is not cash until somebody hands it over', () {
      expect(sep.receivable, 120000, reason: "Ahmed's khaata");
      expect(sep.payable, 60000, reason: "Arbab Traders' feed");
      // 2,000,000 in, less 1,400,000 herd and chiller, 90,000 feed,
      // 12,000 vet, 55,000 wages and 35,000 rent, plus 380,000 milk.
      expect(sep.cash, 788000);
    });

    test('the books balance', () {
      final m = _summary(
        capital: capital,
        assets: sep.assetsBought - sep.writeOffs,
        runningCosts: sep.costs,
        sales: sep.sales,
        books: sep,
      );
      expect(m.expected, 848000);
      expect(m.farmMoney, 848000);
      expect(m.reconciles, isTrue);
    });
  });

  // ------------------------------------------------------- settling September

  final sepShared = sep.profitToShare(arIncluded: true);
  final sepShares = shareOut(
    partners: founders,
    profitToShare: sepShared,
    choices: const {},
  );

  group('settling September', () {
    test('the shares add up to the profit, to the rupee', () {
      expect(sepShared, 98000);
      expect(sepShares.fold<num>(0, (a, s) => a + s.share), 98000);
    });

    test("each slice is that founder's own share of the capital", () {
      expect(sepShares[0].share, 39200, reason: '40 per cent');
      expect(sepShares[1].share, 29400, reason: '30 per cent');
      expect(sepShares[2].share, 19600, reason: '20 per cent');
      expect(sepShares[3].share, 9800, reason: '10 per cent');
    });

    test('nobody can take out more than their share', () {
      final greedy = sepShares[3].decide(withdraw: 999999, by: 'u3');
      expect(greedy.withdraw, 9800);
      expect(greedy.reinvest, 0);
    });

    test('a share nobody has decided on takes nothing', () {
      expect(sepShares[0].decided, isFalse);
      expect(sepShares[0].withdraw, 0);
      expect(sepShares[0].reinvest, 39200);
    });

    test('what is taken out and what is left in always make the share', () {
      for (final s in sepShares) {
        final half = s.decide(withdraw: s.share / 2, by: 'u');
        expect(half.withdraw + half.reinvest, s.share);
      }
    });
  });

  // ------------------------------------------------------------------ October
  //
  // Founder 0 takes the lot out, 1 takes half, 2 and 3 leave theirs in.
  // Last month's credit is settled both ways, a bought buffalo is sold at a
  // gain and a calf born here is sold too.

  final shareOut0 = _e(
    type: TxnType.payment,
    amount: 39200,
    category: profitShareCategory,
    party: 'Founder 0',
    monthId: '2026-10',
    day: 1,
  );
  final shareOut1 = _e(
    type: TxnType.payment,
    amount: 14700,
    category: profitShareCategory,
    party: 'Founder 1',
    monthId: '2026-10',
    day: 1,
  );
  final ahmedPays = _e(
    type: TxnType.receipt,
    amount: 120000,
    category: 'Khaata receipt',
    party: 'Ahmed',
    settles: milkKhaata.id,
    monthId: '2026-10',
    day: 3,
  );
  final feedSettled = _e(
    type: TxnType.payment,
    amount: 60000,
    category: 'Supplier payment',
    party: 'Arbab Traders',
    settles: feedOwed.id,
    monthId: '2026-10',
    day: 4,
  );
  final octMilk = _e(
    type: TxnType.sale,
    amount: 460000,
    category: 'Milk',
    monthId: '2026-10',
  );
  final octFeed = _e(
    type: TxnType.purchase,
    amount: 110000,
    category: 'Fodder / feed',
    monthId: '2026-10',
  );
  final octWages = _e(
    type: TxnType.expense,
    amount: 55000,
    category: 'Salaries',
    monthId: '2026-10',
  );
  // A buffalo bought for 150,000 sells for 200,000.
  final soldPrice = _e(
    type: TxnType.sale,
    amount: 200000,
    category: 'Cattle sale',
    party: 'B-02',
    monthId: '2026-10',
    day: 12,
  );
  final soldCost = _e(
    type: TxnType.expense,
    amount: 150000,
    category: writeOffCategory,
    party: 'B-02',
    monthId: '2026-10',
    day: 12,
  );
  // A calf born here. She cost nothing to come by, so all of her price is
  // earnings and there is nothing to write off.
  final calfSold = _e(
    type: TxnType.sale,
    amount: 60000,
    category: 'Cattle sale',
    party: 'C-07',
    monthId: '2026-10',
    day: 15,
  );

  final octLedger = [
    shareOut0,
    shareOut1,
    ahmedPays,
    feedSettled,
    octMilk,
    octFeed,
    octWages,
    soldPrice,
    soldCost,
    calfSold,
  ];
  final oct = Books(
    monthId: '2026-10',
    openingCash: sep.operatingCash,
    capital: capital,
    monthTxns: octLedger,
    unpaidTxns: const [],
  );

  group('October', () {
    test("last month's milk is not income all over again", () {
      expect(
        oct.sales,
        720000,
        reason: '460,000 milk, 200,000 and 60,000 sold',
      );
      expect(
        octLedger.where((t) => t.type == TxnType.sale).length,
        3,
        reason: "Ahmed's receipt is not one of them",
      );
    });

    test("last month's feed is not a cost all over again", () {
      expect(oct.costs, 315000, reason: '110,000 feed, 55,000 wages, 150,000');
      expect(
        oct.loosePayments,
        0,
        reason: 'the supplier payment settles a bill, it is not a new cost',
      );
    });

    test('selling a buffalo earns the gain, not the whole price', () {
      expect(soldPrice.amount - soldCost.amount, 50000);
      expect(oct.writeOffs, 150000, reason: 'what she cost, given up');
      expect(oct.profit, 405000);
    });

    test('a calf born here is all earnings — she cost nothing', () {
      expect(
        octLedger.where((t) => t.isWriteOff && t.party == 'C-07'),
        isEmpty,
      );
    });

    test('paying the founders is money out, but not a cost of the farm', () {
      expect(oct.payments, 113900, reason: '39,200 + 14,700 + 60,000');
      expect(
        oct.costs,
        315000,
        reason: 'not a rupee of the 53,900 paid out is in here',
      );
    });

    test('both settlements reach the cash, exactly once each', () {
      expect(sep.operatingCash, -1212000, reason: 'what trading left behind');
      expect(oct.cash, 1349100);
    });

    test('nothing is owed either way any more', () {
      expect(oct.receivable, 0);
      expect(oct.payable, 0);
    });

    test('the books still balance, two months and a herd later', () {
      final m = _summary(
        capital: capital,
        assets: sep.assetsBought - sep.writeOffs - oct.writeOffs,
        runningCosts: sep.costs + oct.costs,
        sales: sep.sales + oct.sales,
        books: oct,
        paidOut: 53900,
      );
      expect(m.expected, 1349100);
      expect(m.farmMoney, 1349100);
      expect(m.reconciles, isTrue);
    });

    test('the farm owns the herd less the two buffaloes that left', () {
      expect(
        sep.assetsBought - sep.writeOffs - oct.writeOffs,
        1100000,
        reason: '1,400,000 bought, 150,000 died, 150,000 sold',
      );
    });
  });

  group('settling October, and what leaving profit in does', () {
    final after = _partners(
      [800000, 600000, 400000, 200000],
      [0, 14700, 19600, 9800],
    );

    // Your slice moves against what everybody else did, not against what
    // you took. Between them the four left 44,100 in. Leave in more than
    // your own share of that and your slice grows; leave in less and it
    // shrinks. Founder 1 took half of his out and his slice still grew,
    // because half of his was more than 30 per cent of the 44,100.
    test('leaving more in than the others raises your slice', () {
      final before = ratiosOf(founders);
      final now = ratiosOf(after);
      const pot = 44100;
      final left = {'p0': 0, 'p1': 14700, 'p2': 19600, 'p3': 9800};

      for (final id in left.keys) {
        final fairShare = before[id]! * pot;
        if (left[id]! > fairShare) {
          expect(now[id]!, greaterThan(before[id]!), reason: '$id left more');
        } else {
          expect(now[id]!, lessThan(before[id]!), reason: '$id left less');
        }
      }
    });

    test('taking the whole lot out shrinks your slice', () {
      expect(ratiosOf(after)['p0']!, lessThan(ratiosOf(founders)['p0']!));
    });

    test('if all four leave theirs in, nobody moves', () {
      final allIn = _partners(
        [800000, 600000, 400000, 200000],
        [39200, 29400, 19600, 9800],
      );
      final before = ratiosOf(founders);
      final now = ratiosOf(allIn);
      for (final id in before.keys) {
        expect(now[id]!, closeTo(before[id]!, 1e-9));
      }
    });

    test('the four slices always make one whole farm', () {
      final now = ratiosOf(after);
      expect(now.values.fold<double>(0, (a, r) => a + r), closeTo(1, 1e-9));
    });

    test('profit left in is not counted as fresh money put in', () {
      expect(
        after.fold<num>(0, (a, p) => a + p.invested),
        capital,
        reason: 'the cash only ever knows about this column',
      );
      expect(after.fold<num>(0, (a, p) => a + p.capital), 2044100);
    });

    test("October's shares add up to October's profit, to the rupee", () {
      final toShare = oct.profitToShare(arIncluded: true);
      final shares = shareOut(
        partners: after,
        profitToShare: toShare,
        choices: const {},
      );
      expect(shares.fold<num>(0, (a, s) => a + s.share), toShare.round());
    });

    test('two months of profit is two months of trading and no more', () {
      expect(sep.profit + oct.profit, 503000);
      expect(
        (sep.sales + oct.sales) - (sep.costs + oct.costs),
        503000,
        reason: 'read either way round, the same figure',
      );
    });
  });

  group('the awkward months', () {
    test('a month that lost money shares nothing, and still closes', () {
      final bad = Books(
        monthId: '2026-11',
        openingCash: 0,
        capital: capital,
        monthTxns: [
          _e(
            type: TxnType.sale,
            amount: 50000,
            category: 'Milk',
            monthId: '2026-10',
          ),
          _e(
            type: TxnType.purchase,
            amount: 90000,
            category: 'Fodder / feed',
            monthId: '2026-10',
          ),
        ],
        unpaidTxns: const [],
      );
      expect(bad.profit, -40000);
      final shares = shareOut(
        partners: founders,
        profitToShare: bad.profit > 0 ? bad.profit : 0,
        choices: const {},
      );
      expect(shares.every((s) => s.share == 0), isTrue);
      expect(shares.length, 4, reason: 'everybody still gets told');
    });

    test('a profit that will not divide still hands out every last rupee', () {
      final shares = shareOut(
        partners: _partners([1, 1, 1]),
        profitToShare: 100,
        choices: const {},
      );
      expect(shares.fold<num>(0, (a, s) => a + s.share), 100);
    });

    test('a farm with nobody signed up yet does not fall over', () {
      expect(
        shareOut(partners: const [], profitToShare: 5000, choices: const {}),
        isEmpty,
      );
    });

    test('an animal put back on the farm is owned again', () {
      // Reinstating soft-deletes the write-off, so it drops out of every
      // figure it was ever in.
      final undone = [...sepLedger]..remove(died);
      final back = Books(
        monthId: '2026-09',
        openingCash: 0,
        capital: capital,
        monthTxns: undone,
        unpaidTxns: sepUnpaid,
      );
      expect(back.writeOffs, 0);
      expect(back.profit, sep.profit + 150000);
    });

    test('a buffalo sold for less than she cost shows the loss', () {
      // Bought at 150,000, sold in a hurry for 100,000.
      final b = Books(
        monthId: '2026-10',
        openingCash: 0,
        capital: 0,
        monthTxns: [
          _e(
            type: TxnType.sale,
            amount: 100000,
            category: 'Cattle sale',
            party: 'B-06',
            monthId: '2026-10',
          ),
          _e(
            type: TxnType.expense,
            amount: 150000,
            category: writeOffCategory,
            party: 'B-06',
            monthId: '2026-10',
          ),
        ],
        unpaidTxns: const [],
      );
      expect(b.profit, -50000, reason: 'a loss, and it says so');
      expect(b.cash, 100000, reason: 'the money that actually came in');
    });

    test('an animal given away for nothing costs the farm what she cost', () {
      final given = Books(
        monthId: '2026-10',
        openingCash: 0,
        capital: 0,
        monthTxns: [
          _e(
            type: TxnType.expense,
            amount: 150000,
            category: writeOffCategory,
            party: 'B-09',
            monthId: '2026-10',
          ),
        ],
        unpaidTxns: const [],
      );
      expect(given.profit, -150000);
      expect(given.cash, 0, reason: 'no money moved');
    });
  });
}
