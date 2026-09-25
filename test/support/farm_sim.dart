import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';
import 'package:char_yar_dairy_farm/services/allocation.dart';
import 'package:char_yar_dairy_farm/services/statement.dart';

/// A farm that can be run day by day in a test, and the audit that has to
/// pass after every day of it.
///
/// Shared by the four-month run and the six-month one rather than copied into
/// both: an audit that exists twice is an audit that gets fixed once.

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
    bool? capital,
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
      capital: capital,
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

  /// A category nobody put on the list — written out on the entry, with the
  /// person saying at the time whether the farm keeps the thing or spent it.
  Txn buyTyped({
    required DateTime on,
    required String from,
    required String what,
    required num amount,
    required bool keeps,
    bool paidNow = true,
  }) => _write(
    on: on,
    type: TxnType.purchase,
    party: from,
    category: what,
    amount: amount,
    paid: paidNow,
    capital: keeps,
  );

  /// The vet, against one animal by her tag.
  Txn vet({required DateTime on, required String tag, required num amount}) =>
      _write(
        on: on,
        type: TxnType.purchase,
        party: tag,
        category: 'Vet & medicine',
        amount: amount,
        paid: true,
      );

  /// An animal sold: what she fetched, and what she cost coming off at the
  /// same moment. Either way round — a gain or a loss — this is the pair of
  /// entries the register writes.
  void sellAnimal({
    required DateTime on,
    required String tag,
    required num price,
    required num cost,
    String to = 'Cattle buyer',
  }) {
    _write(
      on: on,
      type: TxnType.sale,
      party: to,
      category: 'Cattle sale',
      amount: price,
      paid: true,
      litres: 1,
    );
    if (cost > 0) writeOff(on: on, tag: tag, cost: cost);
  }

  /// Money in against nothing the books have booked — scrap, dung, a hire.
  Txn takeLoose({
    required DateTime on,
    required String from,
    required num amount,
  }) => _write(
    on: on,
    type: TxnType.receipt,
    party: from,
    category: 'Other receipt',
    amount: amount,
    paid: true,
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
        profitHeld: reinvested[p.id] ?? 0,
        withdrawn: withdrawn[p.id] ?? 0,
        createdAt: p.createdAt,
      ),
  ];

  // ---- settling up ----

  /// Freeze the period, hand out the shares, open the next one.
  ///
  /// `percent` is what the master hands over, the same for all four — which
  /// is what keeps the ratio honest, since everybody then holds back the same
  /// proportion of what they earned.
  List<MonthShare> closePeriod({
    required DateTime on,
    required int percent,
    required String nextPeriod,
  }) {
    final b = books;
    final toShare = b.profit > 0 ? b.profit : 0;
    final shares = handOut(
      shareOut(partners: partnersNow, profit: toShare),
      percent,
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

    for (final share in shares) {
      final out = share.taken;
      if (share.held != 0) {
        reinvested[share.partnerId] =
            (reinvested[share.partnerId] ?? 0) + share.held;
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

  // 5. A statement says the same thing as the ledger it was built from.
  //
  // It is the one page that gets printed and handed to somebody, so it does
  // not get to have its own opinion. Two claims: what a person's statement
  // closes at is what that person owes, and what the cash book closes at is
  // the cash the farm has.
  for (final party in farm.ledger.map((t) => partyKey(t.party)).toSet()) {
    if (party.isEmpty) continue;
    final onPaper = buildStatement(rows: farm.ledger, party: party).closing;
    final owing = partyOwing(farm.ledger, party);
    expect(
      onPaper,
      owing.owesUs - owing.weOwe,
      reason: "$when — $party's statement and his account disagree",
    );
  }

  final cashBook = buildStatement(
    rows: farm.ledger,
    capital: farm.capitalIn,
  ).closing;
  expect(cashBook, b.cash, reason: '$when — the cash book is not the cash');

  // 6. An advance is never income and never a cost.
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
