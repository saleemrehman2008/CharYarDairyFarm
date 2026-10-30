import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show SetOptions;
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/accounting.dart';
import '../services/bill_clock.dart';
import '../services/bill_repo.dart';
import '../services/db.dart';
import '../services/log_service.dart';
import '../services/month_repo.dart';
import '../services/categories.dart';
import '../services/sheet_sync.dart';
import 'round_data.dart';

/// One name off the books, and what the farm knows about it.
class PartySummary {
  const PartySummary({
    required this.name,
    required this.entries,
    required this.owed,
  });

  /// The spelling the farm has used most, which is the one to file under.
  final String name;

  /// How many entries carry this name. Ordering by this puts the customer
  /// written down twice a day above the one written down twice a year.
  final int entries;

  /// What they still owe. Shown beside the name, because it is what tells two
  /// similar names apart faster than anything else can.
  final num owed;
}

/// A name the books carry more than once, and the spelling that won.
///
/// Used for customers and for categories alike — both are a word somebody
/// types twice and spells two ways, and both have to come back as one thing.
class _NameTally {
  int count = 0;

  /// Only a party owes anything; a category is just a word.
  num owed = 0;

  /// Every way this name has been written, and how often.
  final Map<String, int> spellings = {};

  String get commonest {
    var best = '';
    var most = -1;
    spellings.forEach((spelling, times) {
      if (times > most) {
        best = spelling;
        most = times;
      }
    });
    return best;
  }
}

/// One subscription set for the whole farm side of the app.
///
/// Home, Accounts, Orders, Co-founders and Close month all read the same
/// figures, so they are gathered once here instead of each screen opening its
/// own listeners.
class FarmStore extends ChangeNotifier implements RoundData {
  FarmStore({required this.isMaster}) {
    _subs.addAll(<StreamSubscription<dynamic>>[
      MonthRepo.watchOpen().listen((m) {
        final first = _month == null;
        _month = m;
        _resubscribeMonthTxns(m.id);
        if (first) MonthRepo.ensureOpen(m.id);
        notifyListeners();
      }),
      Db.watchUnpaidTxns().listen((v) {
        _unpaidTxns = v;
        notifyListeners();
      }),
      Db.watchAssetTxns().listen((v) {
        _assetTxns = v;
        notifyListeners();
      }),
      Db.watchProfitShareTxns().listen((v) {
        _shareTxns = v;
        notifyListeners();
      }),
      Db.watchAdvanceTxns().listen((v) {
        _advanceTxns = v;
        notifyListeners();
      }),
      Db.watchLoanTxns().listen((v) {
        _loanTxns = v;
        notifyListeners();
      }),
      Db.watchLoans().listen((v) {
        _loans = v;
        notifyListeners();
      }),
      // Every rupee the four of them have put in, line by line. Held here
      // because three screens ask the same question of it: what has each
      // put in, what is the farm holding for them, and who paid for that.
      Db.watchContributions().listen((v) {
        _contributions = v;
        notifyListeners();
      }),
      // Cash handed over and waiting on the other man's word.
      Db.watchTransfers().listen((v) {
        _transfers = v;
        notifyListeners();
      }),
      // The whole running account. Held here rather than opened again by
      // every screen that wants it: Accounts reads it, and so does the name
      // suggestion on a new entry, which needs every customer the farm has
      // ever traded with and not just the ones who still owe.
      Db.watchLedger().listen((v) {
        _ledger = v;
        notifyListeners();
      }),
      // One listener for every period, rather than one for closed and another
      // for sealed. A sealed period used to fall between the two, which is how
      // a whole month's figures went missing from the all-time totals.
      Db.watchPeriods().listen((v) {
        _periods = v;
        notifyListeners();
      }),
      Db.watchPartners().listen((v) {
        _partners = v;
        // A capital record opened for somebody who has never signed in is
        // the farm adding a co-founder, and the list of names every phone
        // picks from has to hear about it. It used to be rewritten only
        // when a user document changed, and a man with no user document
        // never changed one.
        _publishFounders();
        notifyListeners();
      }),
      Db.watchProducts().listen((v) {
        _products = v;
        notifyListeners();
      }),
      Db.watchSettings().listen((v) {
        _settings = v;
        _followFeatures(v.features);
        notifyListeners();
      }),
      if (isMaster)
        Db.watchUsers().listen((v) {
          _users = v;
          _publishFounders();
          notifyListeners();
        }),
    ]);

    _clock.start();
  }

  final bool isMaster;
  final List<StreamSubscription<dynamic>> _subs = [];
  StreamSubscription<List<Txn>>? _monthTxnSub;
  StreamSubscription<List<Delivery>>? _deliverySub;

  /// Listeners for the parts of the farm that can be switched off, kept by
  /// name so they can be started and stopped as the master changes his mind.
  ///
  /// The app used to open all fifteen of these the moment it launched, whether
  /// the farm was using them or not, and then wait on every one before it drew
  /// anything. A farm with orders and khaata switched off now opens about half
  /// as many, and reaches its first screen in about half the time.
  final Map<String, StreamSubscription<dynamic>> _optional = {};

  /// Starts and stops the optional listeners to match what is switched on.
  void _followFeatures(Features f) {
    _watch(
      'orders',
      f.orders,
      () => Db.watchOrders().listen((v) {
        _orders = v;
        notifyListeners();
      }),
    );

    _watch(
      'khaata',
      f.khaata,
      () => Db.watchUdhaarAccounts().listen((v) {
        _udhaar = v;
        notifyListeners();
      }),
    );
    _watch(
      'bills',
      f.khaata,
      () => Db.watchBills().listen((v) {
        _bills = v;
        notifyListeners();
      }),
    );
    _watch(
      'unbilled',
      f.khaata,
      () => Db.watchUnbilledDeliveries().listen((v) {
        _unbilled = v;
        _raiseDueBills();
        notifyListeners();
      }),
    );

    _watch(
      'cattle',
      f.cattle,
      () => Db.watchAnimals().listen((v) {
        _animals = v;
        notifyListeners();
      }),
    );

    _watch(
      'riders',
      f.rider,
      () => Db.watchOpenRiderDays().listen((v) {
        _riderDays = v;
        notifyListeners();
      }),
    );

    // Nothing switched off should leave a stale figure behind on a badge.
    if (!f.orders) _orders = const [];
    if (!f.khaata) {
      _udhaar = const [];
      _bills = const [];
      _unbilled = const [];
    }
    if (!f.cattle) _animals = const [];
    if (!f.rider) _riderDays = const [];
  }

  void _watch(
    String key,
    bool wanted,
    StreamSubscription<dynamic> Function() open,
  ) {
    final running = _optional.containsKey(key);
    if (wanted == running) return;
    if (wanted) {
      _optional[key] = open();
    } else {
      _optional.remove(key)?.cancel();
    }
  }

  /// The 11pm sweep, for anyone the round missed on the last day.
  late final BillClock _clock = BillClock(_raiseDueBills);

  FarmMonth? _month;
  List<Txn> _monthTxns = const [];
  List<Txn> _unpaidTxns = const [];
  List<Txn> _assetTxns = const [];
  List<Txn> _shareTxns = const [];
  List<Txn> _advanceTxns = const [];
  List<Txn> _ledger = const [];
  List<Txn> _loanTxns = const [];
  List<FounderLoan> _loans = const [];
  List<Contribution> _contributions = const [];
  List<CashTransfer> _transfers = const [];

  /// Every period, newest first.
  List<FarmMonth> _periods = const [];
  List<Partner> _partners = const [];
  List<Product> _products = const [];
  List<FarmOrder> _orders = const [];
  List<UdhaarAccount> _udhaar = const [];
  List<Bill> _bills = const [];
  List<Delivery> _deliveries = const [];
  List<Delivery> _unbilled = const [];
  List<Animal> _animals = const [];
  List<RiderDay> _riderDays = const [];
  bool _running = false;
  bool _again = false;
  List<AppUser> _users = const [];
  FarmSettings _settings = FarmSettings.fallback;

  FarmMonth get month =>
      _month ??
      FarmMonth(id: monthIdOf(DateTime.now()), status: 'open', openingCash: 0);

  bool get ready => _month != null;

  List<Txn> get monthTxns => _monthTxns;

  /// The whole running account, newest first.
  List<Txn> get ledger => _ledger;
  List<Txn> get unpaidTxns => _unpaidTxns;
  List<Partner> get partners => _partners;

  /// Shop order, active items only.
  List<Product> get shopProducts => _products.where((p) => p.active).toList();
  List<Product> get allProducts => _products;
  List<FarmOrder> get orders => _orders;
  List<UdhaarAccount> get udhaarAccounts => _udhaar;

  /// Khaata customers who are approved and so on the daily round.
  @override
  List<UdhaarAccount> get khaataCustomers =>
      _udhaar.where((u) => u.isApproved).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  /// Everyone who can still be billed, closed khaatas included.
  List<UdhaarAccount> get billableKhaata =>
      _udhaar.where((u) => u.isBillable).toList();

  // ---- The cattle register ----

  /// Every animal ever registered, including the ones that have left.
  List<Animal> get animals => _animals;

  List<Animal> get herd => _animals.where((a) => a.status.isHere).toList();

  /// Animals that could be a mother: females still on the farm.
  List<Animal> get dams =>
      herd.where((a) => a.sex == Sex.female && a.species.milks).toList();

  /// A vaccination or check that has come round, soonest first. This is the
  /// whole reason for writing the next date down.
  List<Animal> get dueChecks =>
      herd.where((a) => a.dueSoon()).toList()
        ..sort((a, b) => a.nextDueOn!.compareTo(b.nextDueOn!));

  /// What the herd is giving a day, by the last reading of each animal.
  num get herdLitresPerDay =>
      herd.fold<num>(0, (a, x) => a + (x.isMilking ? x.dailyLitres : 0));

  int get milkingCount => herd.where((a) => a.isMilking).length;

  /// What a calf's mother is called today.
  ///
  /// Her tag and her name are written onto the calf as well, the day he is
  /// registered, and that copy is only rewritten when the link between them
  /// is changed. Rename the mother, or give her a new tag — the numbers are
  /// the farm's to type now, so it does — and every calf went on printing
  /// what she used to be called. Two names for one buffalo, and the register
  /// is the one place the farm goes to settle which animal is which.
  ///
  /// So it is read off her own record, which is the only copy that can be
  /// wrong about her. The stored one is kept as the answer for a mother who
  /// is no longer in the register at all: she was somebody, and "Out of
  /// nobody" is worse than an old name.
  String? motherNameOf(Animal calf) {
    final live = animalById(calf.motherId);
    return live?.label ?? calf.motherTag;
  }

  /// What the calf named in an event is called today.
  ///
  /// The birth line on a mother's page — "Calf 24-07" — was the tag copied
  /// onto the event the evening he was born. The farm renamed him and his
  /// mother's page went on calling him by the old name, which is the
  /// complaint that found this and [motherNameOf] both: a name written down
  /// twice is a name that can be two things at once.
  ///
  /// The event keeps the copy and keeps it on purpose — it is what the
  /// Sheet carries and what a calf sold on years ago is still called in the
  /// history. It is the answer here only when he is no longer in the
  /// register to ask.
  String? calfNameOf(AnimalEvent event) {
    if (event.calfId == null) return event.calfTag;
    return animalById(event.calfId)?.label ?? event.calfTag;
  }

  Animal? animalById(String? id) {
    if (id == null) return null;
    for (final a in _animals) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  List<Bill> get bills => _bills;
  @override
  List<Bill> get unpaidBills => _bills.where((b) => !b.isSettled).toList();
  @override
  List<Delivery> get monthDeliveries => _deliveries;

  @override
  String get monthId => month.id;

  /// Months already closed, newest first — the ledger can be looked back at.
  /// Periods that have been settled — closed, or sealed and waiting. Newest
  /// first.
  ///
  /// Both count towards the farm's all-time figures: a sealed period's trading
  /// happened, whatever is still being decided about the profit.
  List<FarmMonth> get settledPeriods =>
      _periods.where((m) => m.isFrozen).toList();

  List<FarmMonth> get closedMonths =>
      _periods.where((m) => m.isClosed).toList();

  /// Whether the period an entry was booked into is still being written.
  ///
  /// A period nobody has opened a document for yet counts as open: the
  /// first entry of a month is written before anything opens it.
  bool periodIsOpen(String monthId) {
    for (final m in _periods) {
      if (m.id == monthId) return m.isOpen;
    }
    return true;
  }

  /// Every period including the open one, newest first.
  List<FarmMonth> get periods => _periods;

  /// What the last settled period held back from its sharing.
  ///
  /// Only ever more than zero when the master chose to roll the receivables
  /// rather than share them on paper. It goes back into the next period's
  /// shareable profit, so money booked on credit is shared when it arrives
  /// instead of falling down the gap between two periods.
  num get carriedReceivable {
    for (final m in _periods) {
      if (m.isFrozen) return m.carriedReceivable ?? 0;
    }
    return 0;
  }

  /// The period waiting on the co-founders: frozen figures, decisions coming
  /// in. Null when there is none, which is most of the time.
  FarmMonth? get sealedPeriod {
    for (final m in _periods) {
      if (m.isSealed) return m;
    }
    return null;
  }

  List<AppUser> get users => _users;
  FarmSettings get settings => _settings;

  /// Which parts of the farm the master has switched on.
  Features get features => _settings.features;

  Books get books => Books(
    monthId: month.id,
    openingCash: month.openingCash,
    capital: capitalIn,
    // Co-founders' money the farm is holding and owes back. It is in the
    // box and it can be spent, exactly like a customer's security, so the
    // cash has to see it — and the farm's worth has to take it off again.
    founderFloat: founderFloat,
    monthTxns: _monthTxns,
    unpaidTxns: _unpaidTxns,
    withRider: cashWithRiders,
  );

  // ---- Out with the riders ----

  /// Every rider day still open or waiting to be taken in.
  List<RiderDay> get riderDays => _riderDays;

  /// Handovers a founder has been asked to take in.
  List<RiderDay> get handoversWaiting =>
      _riderDays.where((d) => d.isWaiting).toList();

  /// Riders out on the road right now with something on them.
  List<RiderDay> get ridersOut =>
      _riderDays.where((d) => d.isOpen && !d.isEmpty).toList();

  /// Cash taken at doors that no founder has taken in yet.
  num get cashWithRiders => _riderDays.fold<num>(
    0,
    (a, d) => a + (d.cashInHand > 0 ? d.cashInHand : 0),
  );

  /// Milk out with the riders and not yet accounted for.
  num get milkWithRiders => _riderDays
      .where((d) => d.isOpen)
      .fold<num>(
        0,
        (a, d) => a + (d.milkUnaccounted > 0 ? d.milkUnaccounted : 0),
      );

  // ---- Milk ----

  /// Litres of milk the farm has put out this period.
  ///
  /// Taken from the milk that was sold rather than from what the herd is
  /// recorded as giving. The farm books two or three milk sales a day, so this
  /// is the figure that exists and is kept up; the per-animal yield in the
  /// cattle register is a separate thing the farm has not started keeping yet.
  ///
  /// Khaata milk is counted from the deliveries, because a khaata delivery is
  /// not a sale — it becomes one only when the bill is paid, which can be a
  /// month later. Leaving it out would make the farm look like it was putting
  /// out half the milk it actually does.
  num get milkLitres {
    var litres = _monthTxns
        .where(
          (t) =>
              !t.isDeleted &&
              t.type == TxnType.sale &&
              t.category == 'Milk' &&
              (t.unit == null || t.unit == 'L'),
        )
        .fold<num>(0, (a, t) => a + (t.qty ?? 0));

    if (features.khaata) {
      litres += _deliveries.fold<num>(0, (a, d) => a + d.litres);
    }
    return litres;
  }

  /// How many days the open period has been running, counting today.
  int get periodDays {
    final from =
        month.from ?? DateTime(DateTime.now().year, DateTime.now().month);
    final days = DateTime.now().difference(from).inDays + 1;
    return days < 1 ? 1 : days;
  }

  /// Litres a day on average, across the days the period has run.
  num get milkPerDay => milkLitres / periodDays;

  Map<String, double> get ratios => ratiosOf(_partners);

  num get totalCapital => _partners.fold<num>(0, (a, p) => a + p.inTheFarm);

  /// Money the partners actually put in, which is cash the farm can spend.
  /// Reinvested profit is left out: it never left the farm in the first place.
  num get capitalIn => _partners.fold<num>(0, (a, p) => a + p.invested);

  /// Every line of co-founders' money going in, newest first.
  List<Contribution> get contributions => _contributions;

  /// One person's lines.
  List<Contribution> contributionsOf(String partnerId) =>
      _contributions.where((c) => c.partnerId == partnerId).toList();

  /// Who paid for one entry, and how much each of them paid.
  List<Contribution> paidForEntry(String txnId) =>
      paidFor(_contributions, txnId);

  /// Co-founders' own money the farm is holding and has to give back.
  ///
  /// The mirror of a customer's security, and it sits on the same side of
  /// the books: it is in the cash and it is not the farm's. Jalbani buys a
  /// load of feed out of his own pocket on Tuesday — until the four of them
  /// say otherwise, the farm owes him for it.
  num get owedToFounders => _contributions
      .where((c) => c.isLoan)
      .fold<num>(0, (a, c) => a + c.stillOwed);

  /// The correction the cash formula needs for money that was never in the
  /// farm's box.
  ///
  /// A co-founder pays the feed merchant out of his own pocket. The books
  /// carry a purchase saying twenty thousand left the farm, and it did not
  /// — it left him. This cancels that, and it has to go on cancelling it
  /// for ever, because the purchase row is there for ever.
  ///
  /// Which is why it is not the same figure as what the farm owes him. The
  /// day it pays him back, the box really does lose the money and the debt
  /// is gone; the purchase it never made is still on the page. Clearing both
  /// with one figure took the cash down twice — once for a payment the farm
  /// made and once for one it never did.
  num get founderFloat => _contributions
      .where((c) => c.isLoan)
      .fold<num>(0, (a, c) => a + c.amount);

  num owedToFounder(String partnerId) => owedToFrom(_contributions, partnerId);

  /// Every transfer, newest first.
  List<CashTransfer> get transfers => _transfers;

  /// Cash handed over and still waiting on somebody's word — out of one
  /// pair of hands and not yet in another.
  num get cashInTransit =>
      _transfers.where((t) => t.isWaiting).fold<num>(0, (a, t) => a + t.amount);

  /// What this person is being asked to confirm.
  /// The one who keeps the farm's cash, if the master has named anybody.
  Partner? get cashKeeper => _partners.where((p) => p.keepsCash).firstOrNull;

  /// Whether this account runs the farm's own account beside its own.
  ///
  /// Whoever keeps the farm's cash does: it is the job the farm gave him,
  /// and the rules already let him answer for the farm account's money.
  /// This is the same fact asked on the phone, so the switch between his
  /// own hands and the farm's is offered to him and to nobody else.
  bool runsTheFarmAccount(String uid) =>
      uid.isNotEmpty && cashKeeper?.userId == uid;

  /// What is waiting on one person's word.
  ///
  /// His own handovers, and — for whoever keeps the farm's cash, and for the
  /// master — money paid into the farm's own account. The farm account has no
  /// hands of its own to confirm with, and leaving it to confirm itself would
  /// let a man reduce his own holding on nothing but his own say-so.
  List<CashTransfer> waitingOn(String name, {bool alsoForFarm = false}) {
    final mine = waitingFor(_transfers, name);
    if (!alsoForFarm) return mine;

    final seen = {for (final t in mine) t.id};
    return [
      ...mine,
      for (final t in waitingFor(_transfers, farmAccountName))
        if (!seen.contains(t.id) && partyKey(t.from) != partyKey(name)) t,
    ]..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }

  /// Whether this person may say that money reached the farm's own account.
  bool keepsTheFarmCash(String name) {
    final k = cashKeeper;
    return k != null && partyKey(k.name) == partyKey(name);
  }

  /// Every pair of hands the farm's money can be in.
  ///
  /// The farm's own account first, then the co-founders, then anybody else
  /// who has already handled money for the farm — a worker who took a
  /// payment at the gate once belongs on the list, because the money he
  /// took is still somewhere.
  ///
  /// One list, read by every screen that asks whose hands money is in. They
  /// each built their own and they each drifted: the entry form offered the
  /// farm's account and the transfer sheet did not, so money could be taken
  /// into a place it could never be moved out of.
  List<String> get moneyHolders {
    final names = <String, String>{};
    for (final f in _settings.founders) {
      final name = f.name.trim();
      if (name.isNotEmpty) names.putIfAbsent(partyKey(name), () => name);
    }
    for (final p in _partners) {
      final name = p.name.trim();
      if (name.isNotEmpty) names.putIfAbsent(partyKey(name), () => name);
    }
    final people = names.values.toList()..sort();

    for (final h in cashInHands(
      _ledger,
      putIn: _contributions,
      moving: _transfers,
    )) {
      if (names.containsKey(partyKey(h.who))) continue;
      if (partyKey(h.who) == partyKey(farmAccountName)) continue;
      people.add(h.who);
    }
    return [farmAccountName, ...people];
  }

  /// What one pair of hands has taken in and handed out.
  ///
  /// Read off the ledger the same way the farm-wide card reads it, so a
  /// co-founder's own card and the list of who is holding what can never
  /// disagree — they did, and the farm spotted it on the first screen.
  HandsOn? handsOf(String name) {
    final key = partyKey(name);
    for (final h in cashInHands(
      _ledger,
      putIn: _contributions,
      moving: _transfers,
    )) {
      if (partyKey(h.who) == key) return h;
    }
    return null;
  }

  /// The entries behind what a man is holding, latest first.
  ///
  /// So a handover can name the money it is made of instead of being a bare
  /// figure — these four Urooj receipts, not 8,600 out of a pile.
  List<InHand> heldBy(String name) => inHand(
    _ledger,
    who: name,
    incoming: true,
    putIn: _contributions,
    moving: _transfers,
  );

  /// The entries behind what a man is out of pocket, latest first.
  ///
  /// What the farm owes him, entry by entry. It is shown to be read rather
  /// than settled: the farm's own rule is that his spending goes against his
  /// promise until that promise is paid in full, and only what is over it is
  /// his to take back.
  List<InHand> spentBy(String name) => inHand(
    _ledger,
    who: name,
    incoming: false,
    putIn: _contributions,
    moving: _transfers,
  );

  /// Farm money in a man's hands that belongs in the farm's own account.
  ///
  /// Not netted against anything he has spent of his own: the farm's rule
  /// is that whatever of its money he takes in stands on its own as money
  /// to be paid in. See [toPayIntoFarm].
  num owedToFarmBy(String name) {
    final owed = toPayIntoFarm(_ledger, who: name);
    final p = _partners
        .where((p) => partyKey(p.name) == partyKey(name))
        .firstOrNull;
    final settled = p?.takingsSettled ?? 0;
    final left = owed - settled;
    return left < 0 ? 0 : left;
  }

  /// What a man's old mixed-up takings and spending cancel down to, and
  /// has not been squared yet.
  num stillToSquare(Partner p) {
    final cancels = takingsSpentOnFarm(_ledger, who: p.name);
    final left = cancels - p.takingsSettled;
    return left < 0 ? 0 : left;
  }

  /// Which handover an entry went out on, if any.
  CashTransfer? handoverFor(String txnId) => handoverOf(_transfers, txnId);

  /// What is still to come in against what the four of them promised.
  num get pledgedStillToCome =>
      _partners.fold<num>(0, (a, p) => a + p.stillToPayIn);

  /// Everything promised has arrived.
  bool get fundingComplete =>
      _partners.any((p) => p.pledged > 0) && pledgedStillToCome == 0;

  /// Everything the farm owns — cattle and equipment, across every month,
  /// less whatever has been sold, died or been slaughtered since.
  num get assetsOwned => _assetTxns.fold<num>(
    0,
    (a, t) => t.isWriteOff ? a - t.amount : a + t.amount,
  );

  /// Every name the books already carry, busiest first.
  ///
  /// Read off the ledger rather than kept as a list of its own, because a
  /// second list is a second thing to fall out of step: a customer exists here
  /// the moment somebody trades with them, and can never be missing from it.
  ///
  /// Case and stray spaces are folded together, and the spelling that comes
  /// back is whichever one the farm has used most — so `kashif` typed in a
  /// hurry offers `Kashif`, and the account stays in one piece.
  List<PartySummary> get partyBook {
    final byKey = <String, _NameTally>{};
    for (final t in _ledger) {
      final name = t.party.trim();
      if (name.isEmpty) continue;
      final k = partyKey(name);
      final tally = byKey.putIfAbsent(k, _NameTally.new);
      tally.count++;
      tally.spellings[name] = (tally.spellings[name] ?? 0) + 1;
      if (t.isReceivable) tally.owed += t.outstanding;
    }

    final out =
        [
          for (final tally in byKey.values)
            PartySummary(
              name: tally.commonest,
              entries: tally.count,
              owed: tally.owed,
            ),
        ]..sort((a, b) {
          final byUse = b.entries.compareTo(a.entries);
          return byUse != 0 ? byUse : a.name.compareTo(b.name);
        });
    return out;
  }

  /// Every category the books already carry, and which tab each one sits on.
  Map<TxnType, List<String>> get categoryBook => categoriesUsed(_ledger);

  /// Which tabs a category is already being used on, if any.
  List<TxnType> tabsUsing(String category) =>
      tabsUsingCategory(_ledger, category);

  /// Advances the farm is holding right now, across every customer.
  ///
  /// Somebody else's money, sitting in the farm's cash. It is not income, it
  /// is not profit, and it has to come off what the farm is worth — the day
  /// a contract ends it goes back out again.
  num get securitiesHeld => securitiesHeldIn(_advanceTxns);

  /// Advances the farm has handed out and not had back — peshgi to a
  /// labourer, a deposit with a supplier. The farm's own money, out of the
  /// box, which is the exact mirror of an advance it is holding.
  num get securitiesOut => securitiesOutIn(_advanceTxns);

  /// What the farm has lent its co-founders and not had back.
  ///
  /// Money the farm owns that is not in the box, which is the exact mirror of
  /// an advance — somebody else's money that is. Neither is income or cost,
  /// and both have to be said out loud or the books stop adding up by what
  /// they come to.
  num get loansOut => _loanTxns.fold<num>(
    0,
    (a, t) => t.isLoanOut ? a + t.amount : a - t.amount,
  );

  /// Profit the four of them have earned and left in the farm.
  ///
  /// Sitting in the cash and spoken for. Can be negative, and is meant to be
  /// able to: a run of bad months eats into it and then past it, and the
  /// figure says so rather than stopping at nothing.
  num get profitHeldByFounders =>
      _partners.fold<num>(0, (a, p) => a + p.profitHeld);

  /// Every loan, with what has come back on it read off the ledger.
  ///
  /// Not stored on the loan itself: an instalment the close took and one the
  /// founder paid in over the counter are the same money, and a figure kept
  /// in two places is a figure that will one day disagree with itself.
  List<FounderLoan> get loans => [
    for (final loan in _loans)
      loan.withRepaid(
        _loanTxns
            .where(
              (t) => t.isLoanBack && partyKey(t.party) == partyKey(loan.name),
            )
            .fold<num>(0, (a, t) => a + t.amount),
      ),
  ];

  /// The loan running against a name, however it is spelled.
  ///
  /// By name rather than by id, because this is asked from the entry form
  /// where somebody has typed a name and not picked a person.
  FounderLoan? loanFor(String party) {
    if (party.trim().isEmpty) return null;
    for (final loan in loans) {
      if (loan.state.isOpen &&
          !loan.isCleared &&
          partyKey(loan.name) == partyKey(party)) {
        return loan;
      }
    }
    return null;
  }

  /// The loan one co-founder is still paying off, if there is one.
  FounderLoan? runningLoanFor(String partnerId) {
    for (final loan in loans) {
      if (loan.partnerId == partnerId && loan.state.isOpen && !loan.isCleared) {
        return loan;
      }
    }
    return null;
  }

  /// Loans waiting on the master to hand over or turn down.
  List<FounderLoan> get loansAsked =>
      loans.where((l) => l.state == LoanState.asked).toList();

  /// What one co-founder still owes on money the farm lent them.
  num loanOwedBy(String party) => _loanTxns
      .where((t) => partyKey(t.party) == partyKey(party))
      .fold<num>(0, (a, t) => t.isLoanOut ? a + t.amount : a - t.amount);

  /// What one customer has left with the farm, and not had back.
  num securityHeldFrom(String party) => securityHeldFromIn(_advanceTxns, party);

  /// What one person is carrying of the farm's money as an advance.
  num securityOutWith(String party) => securityOutWithIn(_advanceTxns, party);

  /// Profit the co-founders have taken out of the farm, across every close.
  ///
  /// Not a running cost — it is the farm's own earnings going to the people
  /// who own them — but it is real money gone, so the breakdown of where the
  /// money went has to show it. Without this line the breakdown reads high by
  /// exactly what was withdrawn, from the first close onwards.
  num get paidToFounders => _shareTxns.fold<num>(0, (a, t) => a + t.amount);

  /// All-time figures, read from the closed months plus the open one. Closed
  /// months keep their own totals, so this costs a dozen documents a year
  /// rather than re-reading the whole ledger every time the app opens.
  num get lifetimeSales =>
      settledPeriods.fold<num>(0, (a, m) => a + (m.sales ?? 0)) + books.sales;

  /// What it has cost to run the farm since day one — feed, salaries, bills,
  /// rent — with cattle and equipment left out.
  ///
  /// Read back out of each period's own frozen figures as sales minus profit,
  /// which is what its costs were by definition. Adding the stored purchases
  /// and expenses instead would quietly drop a rent paid straight out as a
  /// payment, and the all-time profit would jump the moment a period closed.
  num get lifetimeRunningCosts =>
      settledPeriods.fold<num>(0, (a, m) => a + m.runningCosts) + books.costs;

  /// Money that came in with no sale booked against it, since day one.
  ///
  /// Kept apart from [lifetimeSales] because nothing was sold — but it is
  /// income all the same, and the breakdown has to show it or the books stop
  /// adding up by exactly that much.
  num get lifetimeOtherIncome =>
      settledPeriods.fold<num>(0, (a, m) => a + (m.otherIncome ?? 0)) +
      books.otherIncome;

  /// What the farm has made since the day it started.
  ///
  /// Other income belongs in here and was missing from it. Each period's own
  /// profit counts it — [Books.profit] is sales plus other income less costs —
  /// so leaving it out of the all-time figure did not just lose it, it took it
  /// off twice over: the costs are read back as sales plus other income less
  /// profit, so the other income was inside the costs as well. A hundred
  /// rupees of scrap sold made the farm look a hundred rupees worse off.
  num get lifetimeProfit =>
      lifetimeSales + lifetimeOtherIncome - lifetimeRunningCosts;

  /// The whole route the farm's money has taken, for the Home breakdown.
  MoneySummary get money => MoneySummary(
    capital: capitalIn,
    assets: assetsOwned,
    runningCosts: lifetimeRunningCosts,
    sales: lifetimeSales,
    otherIncome: lifetimeOtherIncome,
    cash: books.cash,
    receivable: books.receivable,
    payable: books.payable,
    withRider: cashWithRiders,
    paidOut: paidToFounders,
    securitiesHeld: securitiesHeld,
    owedToFounders: owedToFounders,
    loansOut: loansOut,
    securitiesOut: securitiesOut,
    profitHeld: profitHeldByFounders,
  );

  Partner? partnerFor(String uid) {
    for (final p in _partners) {
      if (p.userId == uid) return p;
    }
    return null;
  }

  /// Milk rate quoted on the udhaar estimate; falls back to the cached value.
  num get milkRate {
    for (final p in shopProducts) {
      if (p.name.toLowerCase().contains('milk')) return p.price;
    }
    return _settings.milkPriceCache;
  }

  // ---- Things needing attention ----

  List<FarmOrder> get pendingOrders => _orders
      .where((o) => o.status == OrderStatus.newOrder && !o.isApproved)
      .toList();

  List<FarmOrder> get openOrders =>
      _orders.where((o) => o.status.isOpen).toList();

  @override
  List<FarmOrder> get roundOrders => _orders
      .where((o) => o.status.isOpen && o.isApproved && o.mode != 'pickup')
      .toList();

  @override
  List<FarmOrder> get allOpenOrders => openOrders;

  List<UdhaarAccount> get pendingUdhaar =>
      _udhaar.where((u) => u.status == UdhaarStatus.pending).toList();

  List<AppUser> get pendingUsers =>
      _users.where((u) => u.status == UserStatus.pending).toList();

  List<Txn> get payablesDue => _unpaidTxns.where((t) => t.isPayable).toList();

  List<Txn> get receivablesDue =>
      _unpaidTxns.where((t) => t.isReceivable).toList();

  int get approvalCount => pendingOrders.length + pendingUdhaar.length;

  /// Keeps the rider-readable list of co-founders in step with the real one.
  ///
  /// A rider's phone cannot read the users collection — it has no business
  /// knowing who else uses the app — but he does have to pick somebody to
  /// hand the day's cash to. So the master's app writes the names where
  /// everyone can see them, and rewrites them whenever they change.
  Future<void> _publishFounders() async {
    if (!isMaster) return;

    // One row per man, under the spelling the farm uses for him, so nobody
    // is on the list twice.
    final byKey = <String, FarmPerson>{};

    final shutOut = {
      for (final u in _users)
        if (u.status == UserStatus.blocked) u.uid,
    };

    // Everybody with a capital record, signed in or not.
    //
    // The list used to be built from the users collection alone, and that
    // is a list of people who have opened the app. The farm opens a man's
    // capital record months before he ever does — Munawar had put five
    // lakh in and was on the Co-founders page and in "Who paid for this?",
    // and was not among the names the entry form offered, because there
    // was no user document to find him in. He is on the farm's books; that
    // is what makes him one of the names.
    for (final p in _partners) {
      final name = p.name.trim();
      if (name.isEmpty || shutOut.contains(p.userId)) continue;
      byKey[partyKey(name)] = FarmPerson(
        uid: p.userId.isNotEmpty ? p.userId : p.id,
        name: name,
      );
    }

    // And everybody on the farm's side who has signed in, which is where a
    // name is freshest: a man who has signed in has told the app how he
    // spells it. A silent investor is on this side too — his money is in
    // the farm like anybody else's, so his name is offered like anybody
    // else's. See [Role.holdsCapital].
    for (final u in _users) {
      if (!u.role.holdsCapital || u.status == UserStatus.blocked) continue;
      final name = u.name.trim();
      if (name.isEmpty) continue;
      byKey[partyKey(name)] = FarmPerson(uid: u.uid, name: name);
    }

    final live = byKey.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (live.isEmpty) return;

    final known = _settings.founders;
    final same =
        known.length == live.length &&
        List.generate(
          live.length,
          (i) => known[i].uid == live[i].uid && known[i].name == live[i].name,
        ).every((x) => x);
    if (same) return;

    try {
      await Db.farmSettings.set({
        'founders': [for (final p in live) p.toMap()],
      }, SetOptions(merge: true));
    } catch (_) {
      // A rider picking from a stale list is a small thing; failing the
      // master's home screen over it is not.
    }
  }

  /// Raises any bill that has fallen due.
  ///
  /// This is the month-end job a scheduled Cloud Function would do. It runs
  /// when the unbilled milk changes and again at 11 at night, only ever raises
  /// what is genuinely due, and is safe to repeat — so the worst a second phone
  /// can do is find there was nothing left to raise.
  Future<void> _raiseDueBills() async {
    if (_running) {
      // Something arrived mid-run; go round once more when this one is done.
      _again = true;
      return;
    }
    // Closed khaatas are included: someone taken off the round mid-month is
    // still owed for the milk they had.
    final billable = billableKhaata;
    if (_unbilled.isEmpty || billable.isEmpty) return;

    _running = true;
    try {
      await BillRepo.raiseDue(
        Actor(uid: 'auto', name: 'The app'),
        accounts: billable,
        unbilled: _unbilled,
      );
    } catch (_) {
      // Nothing is lost: the 11 o'clock run tries again, so does whoever opens
      // the app next, and the bills screen can always raise them by hand.
    } finally {
      _running = false;
    }

    if (_again) {
      _again = false;
      await _raiseDueBills();
    }
  }

  void _resubscribeMonthTxns(String monthId) {
    _monthTxnSub?.cancel();
    _monthTxnSub = Db.watchMonthTxns(monthId).listen((v) {
      _monthTxns = v;
      notifyListeners();
    });
    _deliverySub?.cancel();
    _deliverySub = Db.watchMonthDeliveries(monthId).listen((v) {
      _deliveries = v;
      notifyListeners();
    });
  }

  // ---- The Google Sheet ----

  /// Anything at all changed, so the Sheet is due a rewrite.
  ///
  /// Hooked to the one place every change already passes through, rather than
  /// sprinkled through twenty listeners. The mirror itself waits for the
  /// changes to stop before it writes, so calling this on every tick of every
  /// stream costs a timer reset and nothing else.
  /// True once this app has written the Sheet at least once since it opened.
  bool _caughtUp = false;

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (_settings.sheetId.isEmpty) return;

    // The first write after the app opens ignores the other phones' cooldown.
    // Whatever happened while every partner's phone was shut — a rider's
    // round, a customer's order — is in the books and not yet in the Sheet,
    // and this is the moment to put that right.
    if (!_caughtUp) {
      _caughtUp = true;
      SheetSync.catchUp(sheetBooks);
      return;
    }
    SheetSync.nudge(sheetBooks);
  }

  /// The whole of what the Sheet shows.
  ///
  /// The ledger and the deliveries are read fresh rather than taken from the
  /// store, because the store only holds the open period and the Sheet is
  /// meant to be the farm's second copy of everything.
  Future<SheetBooks> sheetBooks() async {
    // Everything, however many years of it there are. Read in pages, because
    // one query hands back ten thousand rows at most — see [Db.everything].
    final ledger = await Db.everything(
      Db.transactions.orderBy('date', descending: true),
      Txn.fromDoc,
    );
    final rounds = await Db.everything(
      Db.deliveries.orderBy('date', descending: true),
      Delivery.fromDoc,
    );

    final books = this.books;
    return SheetBooks(
      sheetId: _settings.sheetId,
      lastSyncAt: _settings.lastSyncAt,
      txns: ledger.where((t) => !t.isDeleted).toList(),
      periods: _periods,
      partners: _partners,
      contributions: _contributions,
      ratios: ratios,
      khaata: _udhaar,
      deliveries: rounds,
      animals: _animals,
      summary: [
        ('Cash in hand', books.cash),
        ('With the rider', books.withRider),
        ('To receive', books.receivable),
        ('To pay', books.payable),
        ('Capital the co-founders put in', capitalIn),
        ('Cattle & equipment owned', assetsOwned),
        ('Paid out to co-founders', paidToFounders),
        ('Security held for customers', securitiesHeld),
        ('Owed back to co-founders', owedToFounders),
        ('Promised and not yet in', pledgedStillToCome),
        // The mirror of the line above, and it has to be here for the same
        // reason: without it the Sheet's summary is short by whatever the
        // farm has handed out and not had back, and the one place the farm
        // goes to check a figure disagrees with the app.
        ('Security the farm paid out', securitiesOut),
        ('Lent to co-founders', loansOut),
        ('Sold since day one', lifetimeSales),
        ('Other money in since day one', lifetimeOtherIncome),
        ('Spent since day one', lifetimeRunningCosts),
        ('Made since day one', lifetimeProfit),
        ('This period — sales', books.sales),
        ('This period — running costs', books.costs),
        ('This period — profit', books.profit),
      ],
    );
  }

  @override
  void dispose() {
    SheetSync.stop();
    for (final s in _subs) {
      s.cancel();
    }
    for (final s in _optional.values) {
      s.cancel();
    }
    _optional.clear();
    _monthTxnSub?.cancel();
    _deliverySub?.cancel();
    _clock.dispose();
    super.dispose();
  }
}
