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
    String? take,
    num? advanceCut,
    bool? capital,
    MilkShift? shift,
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
      shift: shift,
      paid: paid,
      paidSoFar: paid ? amount : 0,
      paidAt: paid ? on : null,
      note: '',
      settlesTxnId: settles,
      takeId: take,
      advanceCut: advanceCut,
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
    // Found by id, not by being the same object. A row that has already
    // been moved once is a different object with the same id, and the app
    // never holds a row any other way — it writes to a document id and
    // the stream hands back whatever is there now. Matching on the object
    // made the harness refuse a second change to one entry, which is not
    // a rule the farm has.
    final at = ledger.indexWhere((t) => t.id == old.id);
    if (at < 0) return;
    ledger[at] = fresh;
  }

  /// The row with this id as it stands now, or null if it has gone.
  Txn? live(String id) =>
      ledger.where((t) => t.id == id && !t.isDeleted).firstOrNull;

  /// An entry corrected after the fact — what the master would be doing
  /// with an edit button.
  ///
  /// Everything else about the row stays as it was, including the period it
  /// was booked into. That is the whole question: a row booked into a month
  /// that has since been closed cannot be corrected without the period and
  /// the shares worked out from it going out of step with it, and nothing
  /// in the app re-reads a closed period to find out.
  Txn correct(Txn old, {num? amount, bool? paid}) {
    final to = amount ?? old.amount;
    final settled = paid ?? old.paid;
    final fresh = Txn(
      id: old.id,
      date: old.date,
      monthId: old.monthId,
      type: old.type,
      party: old.party,
      category: old.category,
      qty: old.qty,
      unit: old.unit,
      rate: old.qty == null || old.qty == 0 ? old.rate : to / old.qty!,
      amount: to,
      capital: old.capital,
      shift: old.shift,
      paid: settled,
      paidSoFar: settled ? to : 0,
      paidAt: settled ? old.paidAt ?? old.date : null,
      note: old.note,
      settlesTxnId: old.settlesTxnId,
      paidOnCreate: old.paidOnCreate,
      createdBy: old.createdBy,
      createdByName: old.createdByName,
      createdAt: old.createdAt,
    );
    _replace(old, fresh);
    return fresh;
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

  /// Milk bought off another farm to sell on.
  ///
  /// A cost of the sale rather than a cost of running the place, and the
  /// thing the farm wanted apart: without it the month reads as one the
  /// buffaloes had, and some of the milk was somebody else's passing
  /// through.
  void buyMilkIn({
    required DateTime on,
    required String from,
    required num litres,
    required num rate,
    MilkShift shift = MilkShift.morning,
    bool paid = true,
  }) => _write(
    on: on,
    type: TxnType.purchase,
    party: from,
    category: milkBoughtInCategory,
    amount: litres * rate,
    paid: paid,
    litres: litres,
    shift: shift,
  );

  /// An advance the farm hands somebody and expects back — peshgi to a
  /// labourer, a deposit with a supplier.
  ///
  /// Cash out of the box and not a cost: the farm has not spent it, it is
  /// owed it. The mirror of [takeAdvance].
  void payAdvance({
    required DateTime on,
    required String to,
    required num amount,
  }) => _write(
    on: on,
    type: TxnType.payment,
    party: to,
    category: securityOutCategory,
    amount: amount,
    paid: true,
  );

  /// That advance coming back — handed over, or stopped out of wages.
  void recoverAdvance({
    required DateTime on,
    required String from,
    required num amount,
  }) => _write(
    on: on,
    type: TxnType.receipt,
    party: from,
    category: securityRefundCategory,
    amount: amount,
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
    category: securityInCategory,
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
    category: securityBackCategory,
    amount: amount,
    paid: true,
  );

  // ---- a wage, and the advance standing against it ----

  /// Part of a wage handed over before the month is out.
  void wageAdvance({
    required DateTime on,
    required String to,
    required num amount,
  }) => _write(
    on: on,
    type: TxnType.payment,
    party: to,
    category: salaryAdvanceCategory,
    amount: amount,
    paid: true,
  );

  /// Payday. Takes off as much of his standing advance as the farm says,
  /// held to what he owes and what the wage can carry, and hands over the
  /// rest — which is what the card and the form both do, through the same
  /// two functions they use.
  ({num took, num handed}) payWage({
    required DateTime on,
    required Employee who,
    required DateTime from,
    required DateTime to,
    required num asked,
    int daysOff = 0,
  }) {
    final wage = who.payForWindow(from: from, to: to, daysOff: daysOff);
    final took = advanceComingOff(
      asked: asked,
      owed: advanceOwed(ledger, who: who.name),
      wage: wage,
    );
    final handed = wageToHand(
      who: who,
      from: from,
      to: to,
      daysOff: daysOff,
      drawn: took,
    );
    // The whole wage is the cost, in the month the man worked.
    _write(
      on: on,
      type: TxnType.expense,
      party: who.name,
      category: salariesCategory,
      amount: wage,
      paid: true,
      advanceCut: 0,
    );
    // And the taking-back is its own row, which is what the farm asked
    // for: a wage paid short has to say somewhere where the rest went.
    if (took > 0) {
      _write(
        on: on,
        type: TxnType.receipt,
        party: who.name,
        category: salaryAdvanceBackCategory,
        amount: took,
        paid: true,
      );
    }
    return (took: took, handed: handed);
  }

  // ---- one handful of money across the days it reaches ----

  /// What the farm actually does when a customer hands over a month at
  /// once: one payment, spread over the entries it reaches, every slice
  /// stamped with the same handful so the ledger can draw it as one thing
  /// and take it back off as one thing.
  ///
  /// Returns the handful's id.
  String takeInOneGo({
    required DateTime on,
    required String party,
    required num amount,
  }) {
    final theirs = ledger
        .where(
          (t) =>
              partyKey(t.party) == partyKey(party) &&
              !t.isDeleted &&
              t.outstanding > 0 &&
              t.isReceivable,
        )
        .toList();
    final landings = allocate(theirs, amount);
    final handful = 'take${_seq++}';

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
      _write(
        on: on,
        type: TxnType.receipt,
        party: txn.party,
        category: khaataReceiptCategory,
        amount: landing.take,
        paid: true,
        settles: txn.id,
        take: handful,
      );
    }
    return handful;
  }

  // ---- taking an entry off the books, and putting it back ----

  /// Marks an entry deleted and unwinds what it had done, the way
  /// `TxnRepo.softDelete` does: the rows it settled go back to owing, and
  /// the rest of its handful goes down with it.
  List<String> takeOff(Txn entry, {required DateTime on}) {
    final going = <String>[entry.id];

    // The rest of the handful this belongs to. One payment went out
    // together and it comes off together — the farm took one off a row
    // at a time, could not get back to where it started, and deleted six
    // real sales trying.
    if (entry.isPartOfATake) {
      for (final t in _live) {
        if (t.takeId == entry.takeId && !going.contains(t.id)) {
          going.add(t.id);
        }
      }
    }

    // And whatever settled any of them. A receipt carries the money it
    // put onto the entry it was paying; leaving it live would have the
    // farm holding cash against a sale that is no longer on the books.
    for (final id in [...going]) {
      for (final t in _live) {
        if (t.settlesTxnId == id && !going.contains(t.id)) going.add(t.id);
      }
    }

    // Each one gives back what it put on, then goes.
    for (final id in going) {
      final row = live(id);
      if (row == null || row.settlesTxnId == null) continue;
      final paid = live(row.settlesTxnId!);
      if (paid == null) continue;
      _replace(paid, _withPaid(paid, paid.paidSoFar - row.amount));
    }
    for (final id in going) {
      final row = live(id);
      if (row != null) _replace(row, _asDeleted(row, on));
    }
    return going;
  }

  /// And back on again, every figure where it was.
  void putBack(List<String> ids, {required DateTime on}) {
    for (final id in ids) {
      final row = ledger.where((t) => t.id == id).firstOrNull;
      if (row == null || !row.isDeleted) continue;
      _replace(row, _asLive(row));
    }
    for (final id in ids) {
      final row = live(id);
      if (row == null || row.settlesTxnId == null) continue;
      final paid = live(row.settlesTxnId!);
      if (paid == null) continue;
      _replace(paid, _withPaid(paid, paid.paidSoFar + row.amount));
    }
  }

  Txn _withPaid(Txn t, num paid) {
    final held = paid < 0 ? 0 as num : (paid > t.amount ? t.amount : paid);
    return Txn(
      id: t.id,
      date: t.date,
      monthId: t.monthId,
      type: t.type,
      party: t.party,
      category: t.category,
      qty: t.qty,
      unit: t.unit,
      rate: t.rate,
      amount: t.amount,
      capital: t.capital,
      shift: t.shift,
      paid: held >= t.amount,
      paidSoFar: held,
      paidAt: held >= t.amount ? t.paidAt ?? t.date : null,
      note: t.note,
      settlesTxnId: t.settlesTxnId,
      takeId: t.takeId,
      advanceCut: t.advanceCut,
      paidOnCreate: t.paidOnCreate,
      createdBy: t.createdBy,
      createdByName: t.createdByName,
      createdAt: t.createdAt,
    );
  }

  Txn _asDeleted(Txn t, DateTime on) => Txn(
    id: t.id,
    date: t.date,
    monthId: t.monthId,
    type: t.type,
    party: t.party,
    category: t.category,
    qty: t.qty,
    unit: t.unit,
    rate: t.rate,
    amount: t.amount,
    capital: t.capital,
    shift: t.shift,
    paid: t.paid,
    paidSoFar: t.paidSoFar,
    paidAt: t.paidAt,
    note: t.note,
    settlesTxnId: t.settlesTxnId,
    takeId: t.takeId,
    advanceCut: t.advanceCut,
    paidOnCreate: t.paidOnCreate,
    createdBy: t.createdBy,
    createdByName: t.createdByName,
    createdAt: t.createdAt,
    deletedAt: on,
  );

  Txn _asLive(Txn t) => Txn(
    id: t.id,
    date: t.date,
    monthId: t.monthId,
    type: t.type,
    party: t.party,
    category: t.category,
    qty: t.qty,
    unit: t.unit,
    rate: t.rate,
    amount: t.amount,
    capital: t.capital,
    shift: t.shift,
    paid: t.paid,
    paidSoFar: t.paidSoFar,
    paidAt: t.paidAt,
    note: t.note,
    settlesTxnId: t.settlesTxnId,
    takeId: t.takeId,
    advanceCut: t.advanceCut,
    paidOnCreate: t.paidOnCreate,
    createdBy: t.createdBy,
    createdByName: t.createdByName,
    createdAt: t.createdAt,
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

  num get securitiesHeld => _live.fold<num>(
    0,
    (a, t) =>
        t.isSecurityIn ? a + t.amount : (t.isSecurityBack ? a - t.amount : a),
  );

  /// Advances the farm has handed out and not had back. The mirror of
  /// [securitiesHeld], and it has to be on the summary or the balance check
  /// goes out by exactly this much the first time one is paid.
  num get securitiesOut => _live.fold<num>(
    0,
    (a, t) => t.isSecurityOut
        ? a + t.amount
        : (t.isSecurityRefund ? a - t.amount : a),
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
    securitiesHeld: securitiesHeld,
    securitiesOut: securitiesOut,
    wagesAdvanced: wageAdvancesOwed(_live),
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

  // 6. A handful of money is worth what its slices are worth, and every
  //    slice is tied to what it settled.
  //
  //    This is the one the ledger page reads to draw a payment as one
  //    line. A slice that lost its tie would read as income of its own, on
  //    top of the sale it was paying for — the same rupees earned twice.
  final handfuls = <String, List<Txn>>{};
  for (final t in farm.ledger) {
    if (t.isDeleted || !t.isPartOfATake) continue;
    handfuls.putIfAbsent(t.takeId!, () => []).add(t);
  }
  for (final slices in handfuls.values) {
    for (final slice in slices) {
      expect(
        slice.settlesAnotherEntry,
        isTrue,
        reason: '$when — a slice of a payment settles nothing',
      );
      expect(
        slice.isLooseReceipt,
        isFalse,
        reason: '$when — a slice of a payment reads as income of its own',
      );
    }
    final whole = theTake(farm.ledger, slices.first.takeId!);
    expect(
      whole.amount,
      slices.fold<num>(0, (a, t) => a + t.amount),
      reason: '$when — a payment is not what its slices come to',
    );
    // And the page draws exactly one of them.
    final hidden = rowsBehindATake(farm.ledger);
    expect(
      slices.where((t) => !hidden.contains(t.id)).length,
      1,
      reason: '$when — a payment is drawn more than once, or not at all',
    );
  }

  // 7. Every rupee advanced against a wage is either recovered or still
  //    owed — never both, and never neither.
  //
  //    The one that goes wrong quietly over months: an advance that could
  //    not come off this month's wage used to fall off the books in the
  //    farm's favour, and nothing anywhere said so.
  final crew = farm.ledger
      .where((t) => t.category == salaryAdvanceCategory && !t.isDeleted)
      .map((t) => partyKey(t.party))
      .toSet();
  for (final man in crew) {
    final name = farm.ledger.firstWhere((t) => partyKey(t.party) == man).party;
    final advanced = farm.ledger
        .where(
          (t) =>
              !t.isDeleted &&
              t.category == salaryAdvanceCategory &&
              partyKey(t.party) == man,
        )
        .fold<num>(0, (a, t) => a + t.amount);
    // What has come back off him: the rows that say so, and whatever a
    // wage written before those rows existed says on itself.
    final recovered = farm.ledger
        .where((t) => !t.isDeleted && partyKey(t.party) == man)
        .fold<num>(
          0,
          (a, t) =>
              a +
              (t.isWageAdvanceBack || t.isAdvanceGivenUpOn
                  ? t.amount
                  : t.category == salariesCategory
                  ? (t.advanceCut ?? 0)
                  : 0),
        );
    expect(
      recovered + advanceOwed(farm.ledger, who: name),
      advanced,
      reason: '$when — $name: advanced $advanced, recovered $recovered',
    );
    expect(
      advanceOwed(farm.ledger, who: name),
      greaterThanOrEqualTo(0),
      reason: '$when — $name is owed money against an advance',
    );
  }

  // 8. An advance is never income and never a cost.
  final advanceIn = farm.ledger
      .where((t) => t.isSecurityIn)
      .fold<num>(0, (a, t) => a + t.amount);
  if (advanceIn > 0) {
    expect(
      farm.ledger.where((t) => t.isSecurityIn).every((t) => !t.isLooseReceipt),
      isTrue,
      reason: '$when — an advance has crept into income',
    );
  }
}
