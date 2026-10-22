import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';
import 'package:char_yar_dairy_farm/services/statement.dart';

/// Six months of the farm as it now works, run day by day.
///
/// The farm asked for this before trusting the next build with real money:
/// run the whole thing forward half a year, close months at a hundred per
/// cent kept in, then fifty, then nothing kept at all, pay wages and
/// advances through it, and check after every step that the books still
/// say one thing.
///
/// Everything here is the rules the four of them settled on over the last
/// fortnight, now acting on each other rather than one at a time:
///
///  - a share follows what a man is in for, never what has arrived
///  - his own spending goes onto that promise until it is paid, and over it
///    the farm owes him the difference
///  - a month closed while he still owes puts his profit onto the promise
///    instead of into a second pile
///  - a losing month never touches anybody's capital
///  - whatever of the farm's money he takes in stands on its own
///  - a whole calendar month pays a whole wage, 28 days or 31
///
/// The audit at the bottom runs after every month. A rule that only holds
/// in the month it was written is not a rule.

var _n = 0;

// ---------------------------------------------------------------- the farm

/// The four of them, and what each undertook to put in.
class Books6 {
  Books6();

  final ledger = <Txn>[];
  final putIn = <Contribution>[];
  final crew = <Employee>[];
  var partners = <Partner>[];

  /// Every close the farm has made, so the run can be read back.
  final closes = <({String month, int percent, num profit, num toCapital})>[];

  Partner of(String name) =>
      partners.firstWhere((p) => partyKey(p.name) == partyKey(name));

  void sell({
    required num amount,
    required DateTime on,
    required String by,
    String party = 'Urooj Dairy Shop',
    bool paid = true,
  }) => ledger.add(
    Txn(
      id: 's${_n++}',
      date: on,
      monthId: _mid(on),
      type: TxnType.sale,
      party: party,
      category: milkCategory,
      amount: amount,
      paid: paid,
      paidOnCreate: paid,
      handledBy: by,
      note: '',
      createdBy: 'u1',
      createdAt: on,
    ),
  );

  void spend({
    required num amount,
    required DateTime on,
    required String by,
    String category = 'Fodder / feed',
    String party = 'Ghas Wala',
  }) => ledger.add(
    Txn(
      id: 'e${_n++}',
      date: on,
      monthId: _mid(on),
      type: TxnType.expense,
      party: party,
      category: category,
      amount: amount,
      paid: true,
      paidOnCreate: true,
      handledBy: by,
      note: '',
      createdBy: 'u1',
      createdAt: on,
    ),
  );

  /// A wage, or part of one paid early.
  void payWage({
    required Employee who,
    required num amount,
    required DateTime on,
    required String by,
    bool advance = false,
  }) => ledger.add(
    Txn(
      id: 'w${_n++}',
      date: on,
      monthId: _mid(on),
      type: TxnType.expense,
      party: who.name,
      category: advance ? salaryAdvanceCategory : salariesCategory,
      amount: amount,
      paid: true,
      paidOnCreate: true,
      handledBy: by,
      note: '',
      createdBy: 'u1',
      createdAt: on,
    ),
  );

  /// Cash passing from one pair of hands to another, both halves.
  void handOver({
    required num amount,
    required DateTime on,
    required String from,
    required String to,
  }) {
    ledger.add(
      Txn(
        id: 'ho${_n++}',
        date: on,
        monthId: _mid(on),
        type: TxnType.payment,
        party: to,
        category: handoverOutCategory,
        amount: amount,
        paid: true,
        paidOnCreate: true,
        handledBy: from,
        note: '',
        createdBy: 'u1',
        createdAt: on,
      ),
    );
    ledger.add(
      Txn(
        id: 'hi${_n++}',
        date: on,
        monthId: _mid(on),
        type: TxnType.receipt,
        party: from,
        category: handoverInCategory,
        amount: amount,
        paid: true,
        paidOnCreate: true,
        handledBy: to,
        note: '',
        createdBy: 'u1',
        createdAt: on,
      ),
    );
  }

  /// A co-founder's own money, counted as money put in.
  void countOwnMoney({
    required String name,
    required num amount,
    required DateTime on,
  }) {
    final p = of(name);
    final cut = splitByPledge(
      amount: amount,
      pledged: p.pledged,
      alreadyIn: p.invested,
    );

    if (cut.investment > 0) {
      putIn.add(_line(p, cut.investment, on, ContributionKind.investment));
      _bump(p, invested: p.invested + cut.investment);
    }
    if (cut.refundable > 0) {
      putIn.add(_line(p, cut.refundable, on, ContributionKind.loan));
    }
  }

  Contribution _line(
    Partner p,
    num amount,
    DateTime on,
    ContributionKind kind,
  ) => Contribution(
    id: 'c${_n++}',
    partnerId: p.id,
    partnerName: p.name,
    kind: kind,
    source: ContributionSource.spent,
    amount: amount,
    date: on,
    createdAt: on,
  );

  void _bump(Partner p, {num? invested, num? profitHeld}) {
    partners = [
      for (final q in partners)
        if (q.id == p.id)
          Partner(
            id: q.id,
            userId: q.userId,
            name: q.name,
            email: q.email,
            invested: invested ?? q.invested,
            pledged: q.pledged,
            profitHeld: profitHeld ?? q.profitHeld,
            withdrawn: q.withdrawn,
            createdAt: q.createdAt,
          )
        else
          q,
    ];
  }

  /// Closing a month: the profit split by the ratio, then [percent] of each
  /// slice handed out and the rest kept — onto the promise while a man
  /// still owes on it, into his profit account once he does not.
  void close(DateTime monthStart, int percent) {
    final end = DateTime(monthStart.year, monthStart.month + 1, 0);
    final b = _booksFor(monthStart, end);
    final ratios = ratiosOf(partners);

    var toCapital = 0 as num;
    for (final p in [...partners]) {
      final slice = b.profit * (ratios[p.id] ?? 0);
      final taken = slice <= 0 ? 0 : (slice * percent / 100).round();
      final kept = slice - taken;

      final split = keptProfitGoes(
        kept: kept,
        pledged: p.pledged,
        invested: p.invested,
      );
      toCapital += split.toCapital;

      _bump(
        p,
        invested: p.invested + split.toCapital,
        profitHeld: p.profitHeld + split.toProfit,
      );
      if (split.toCapital > 0) {
        putIn.add(_line(p, split.toCapital, end, ContributionKind.investment));
      }
    }

    closes.add((
      month: _mid(monthStart),
      percent: percent,
      profit: b.profit,
      toCapital: toCapital,
    ));
  }

  Books _booksFor(DateTime from, DateTime to) {
    final rows = ledger
        .where((t) => !t.date.isBefore(from) && !t.date.isAfter(to))
        .toList();
    return Books(
      monthId: _mid(from),
      openingCash: 0,
      capital: partners.fold<num>(0, (a, p) => a + p.invested),
      monthTxns: rows,
      unpaidTxns: rows.where((t) => t.outstanding > 0).toList(),
    );
  }

  Books get all => Books(
    monthId: 'all',
    openingCash: 0,
    capital: partners.fold<num>(0, (a, p) => a + p.invested),
    monthTxns: ledger,
    unpaidTxns: ledger.where((t) => t.outstanding > 0).toList(),
  );

  static String _mid(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';
}

// --------------------------------------------------------------- the audit

var checksRun = 0;

/// Everything that has to stay true, whatever month it is.
void audit6(Books6 f, String when) {
  checksRun++;

  // 1. A share follows the promise, not the money.
  //
  // The decision behind all of this. If a slice moved as men paid their
  // promises off, every closed month would have been shared on a ratio
  // that no longer existed by the time the next one closed.
  final ratios = ratiosOf(f.partners);
  final sum = ratios.values.fold<double>(0, (a, r) => a + r);
  expect(sum, closeTo(1.0, 0.0001), reason: '$when — shares do not make one');
  for (final p in f.partners) {
    expect(
      p.ratioBase,
      p.pledged > p.invested ? p.pledged : p.invested,
      reason: '$when — ${p.name} is rated on the wrong figure',
    );
  }

  // 2. Nobody's capital is more than his own lines account for.
  //
  // Typed capital with nothing behind it was the fault that started all
  // this: it said the farm held cash it did not hold, and counted every
  // rupee twice the moment somebody wrote down who paid for what.
  for (final p in f.partners) {
    expect(
      investedFrom(f.putIn, p.id),
      lessThanOrEqualTo(p.invested),
      reason: '$when — ${p.name} has lines the card does not know about',
    );
  }

  // 3. What a man took in for the farm is never negative, and never his.
  for (final p in f.partners) {
    expect(
      toPayIntoFarm(f.ledger, who: p.name),
      greaterThanOrEqualTo(0),
      reason: '$when — ${p.name} owes the farm a negative amount',
    );
  }
  expect(
    toPayIntoFarm(f.ledger, who: farmAccountName),
    0,
    reason: '$when — the farm account owes itself money',
  );

  // 4. Profit is sales and other money in, less what running it cost.
  final b = f.all;
  // Compared loosely on purpose. These are sums of thirds of a figure
  // and the last decimal place drifts; a farm cannot be paid a
  // ten-billionth of a rupee and should not fail an audit over one.
  expect(
    b.profit.toDouble(),
    closeTo((b.sales + b.otherIncome - b.costs).toDouble(), 0.01),
    reason: '$when — profit is not sales less costs',
  );

  // 5. Buffaloes are not a cost.
  expect(
    b.costs.toDouble(),
    closeTo(
      (b.purchases + b.expenses - b.assetsBought + b.loosePayments).toDouble(),
      0.01,
    ),
    reason: '$when — an asset has crept into the running costs',
  );

  // 6. Every man's statement agrees with his own account.
  for (final who in f.ledger.map((t) => partyKey(t.party)).toSet()) {
    if (who.isEmpty) continue;
    final onPaper = buildStatement(rows: f.ledger, party: who).closing;
    final owing = partyOwing(f.ledger, who);
    expect(
      onPaper,
      owing.owesUs - owing.weOwe,
      reason: "$when — $who's statement disagrees with his account",
    );
  }

  // 7. The cash book's foot balances on its own page.
  final cash = buildStatement(rows: f.ledger, capital: b.capital);
  expect(
    (cash.opening + cash.credits - cash.debits).toDouble(),
    closeTo(cash.closing.toDouble(), 0.01),
    reason: '$when — the cash book does not add up',
  );

  // 8. Money changing hands earns and spends nothing.
  final moved = f.ledger.where((t) => t.isHandover);
  final out = moved
      .where((t) => t.isHandoverOut)
      .fold<num>(0, (a, t) => a + t.amount);
  final back = moved
      .where((t) => t.isHandoverIn)
      .fold<num>(0, (a, t) => a + t.amount);
  expect(out, back, reason: '$when — a handover has only one half');

  // 9. Every handover is read as the one act it is.
  expect(
    twinnedHandovers(f.ledger).length * 2,
    moved.length,
    reason: '$when — a handover is being shown twice',
  );

  // 10. A wage went to somebody on the wage list.
  for (final t in f.ledger) {
    if (t.category != salariesCategory && t.category != salaryAdvanceCategory) {
      continue;
    }
    expect(
      f.crew.any((e) => partyKey(e.name) == partyKey(t.party)),
      isTrue,
      reason: '$when — ${t.party} was paid a wage and is not on the list',
    );
  }
}

// ----------------------------------------------------------------- the run

Partner _p(String name, num pledged) => Partner(
  id: 'p-${partyKey(name)}',
  userId: 'u-${partyKey(name)}',
  name: name,
  invested: 0,
  pledged: pledged,
  profitHeld: 0,
  withdrawn: 0,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  group('six months of the farm, run forward', () {
    late Books6 f;

    setUp(() {
      _n = 0;
      f = Books6();
      f.partners = [
        _p('Saleem', 1000000),
        _p('Asif', 1500000),
        _p('Rafeeq', 1500000),
        _p('Ghulam Ali', 2000000),
      ];
      f.crew.addAll([
        Employee(
          id: 'e-jalbani',
          name: 'Jalbani',
          basic: 24000,
          joinedOn: DateTime(2026, 1, 1),
          createdAt: DateTime(2026, 1, 1),
        ),
        Employee(
          id: 'e-gawalo',
          name: 'Gawalo Rafiq Jatt',
          basic: 24000,
          joinedOn: DateTime(2026, 2, 20),
          createdAt: DateTime(2026, 2, 20),
        ),
      ]);
    });

    /// One month of ordinary trading, in the shapes the farm actually has.
    void runMonth(int month, {num sales = 300000, num feed = 90000}) {
      final start = DateTime(2026, month, 1);
      final end = DateTime(2026, month + 1, 0);

      // Milk sold at the gate, taken in by whoever was standing there.
      f.sell(
        amount: sales * 0.6,
        on: start.add(const Duration(days: 4)),
        by: 'Ghulam Ali',
      );
      f.sell(
        amount: sales * 0.4,
        on: start.add(const Duration(days: 17)),
        by: 'Rafeeq',
      );

      // And paid into the farm's own account, which is the whole point.
      f.handOver(
        amount: sales * 0.6,
        on: start.add(const Duration(days: 5)),
        from: 'Ghulam Ali',
        to: farmAccountName,
      );
      f.handOver(
        amount: sales * 0.4,
        on: start.add(const Duration(days: 18)),
        from: 'Rafeeq',
        to: farmAccountName,
      );

      // Feed, out of the farm's account now that the money reaches it.
      f.spend(
        amount: feed,
        on: start.add(const Duration(days: 9)),
        by: farmAccountName,
      );

      // Wages. A whole month pays a whole wage, 28 days or 31.
      for (final e in f.crew) {
        final due = e.payForWindow(from: start, to: end);
        if (due > 0) {
          f.payWage(who: e, amount: due, on: end, by: farmAccountName);
        }
      }
    }

    test('a whole wage every month, February included', () {
      // The fault the farm caught: every month counted as thirty days, so
      // February paid 22,400 of a 24,000 wage — short by sixteen hundred
      // rupees of a man's money, every year.
      final jalbani = f.crew.first;
      for (var m = 1; m <= 6; m++) {
        expect(
          jalbani.payForWindow(
            from: DateTime(2026, m, 1),
            to: DateTime(2026, m + 1, 0),
          ),
          24000,
          reason: 'month $m',
        );
      }
    });

    test('and a man taken on mid-month is paid for his own days', () {
      // Gawalo started on the 20th of February: nine days of a 28-day
      // month, which is nine twenty-eighths and not nine thirtieths.
      final gawalo = f.crew.last;
      expect(
        gawalo.payForWindow(
          from: DateTime(2026, 2, 1),
          to: DateTime(2026, 2, 28),
        ),
        7714,
      );
      expect(
        gawalo.payForWindow(
          from: DateTime(2026, 3, 1),
          to: DateTime(2026, 3, 31),
        ),
        24000,
      );
    });

    test('six months with nothing kept back, then half, then all of it', () {
      // The three the farm asked for, one after another on the same books:
      // everything shared out, half of it, and none of it at all.
      final plan = [100, 100, 50, 50, 0, 0];

      for (var m = 1; m <= 6; m++) {
        runMonth(m);
        f.close(DateTime(2026, m, 1), plan[m - 1]);
        audit6(f, 'after month $m at ${plan[m - 1]}%');
      }

      expect(f.closes, hasLength(6));
      expect(checksRun, greaterThanOrEqualTo(6));
    });

    test('a hundred per cent shared out leaves nothing on any record', () {
      runMonth(1);
      f.close(DateTime(2026, 1, 1), 100);
      audit6(f, 'all shared out');

      for (final p in f.partners) {
        expect(p.profitHeld, 0, reason: '${p.name} kept something back');
        expect(p.invested, 0, reason: '${p.name} gained capital from a close');
      }
    });

    test('nothing shared out goes onto the promise while he still owes it', () {
      // His rule, and the one that needed building. A man who has not
      // finished paying in does not start a second pile of money.
      runMonth(1);
      final before = f.partners.map((p) => p.invested).toList();
      f.close(DateTime(2026, 1, 1), 0);
      audit6(f, 'nothing shared out');

      final after = f.partners.map((p) => p.invested).toList();
      expect(after, isNot(before), reason: 'the promise did not move');
      for (final p in f.partners) {
        expect(
          p.profitHeld,
          0,
          reason: '${p.name} started a profit account while still owing',
        );
      }
    });

    test('and into the profit account once the promise is paid in full', () {
      // Everybody paid up, then a month closed with nothing shared out.
      f.partners = [
        for (final p in f.partners)
          Partner(
            id: p.id,
            userId: p.userId,
            name: p.name,
            invested: p.pledged,
            pledged: p.pledged,
            profitHeld: 0,
            withdrawn: 0,
            createdAt: p.createdAt,
          ),
      ];

      runMonth(1);
      f.close(DateTime(2026, 1, 1), 0);
      audit6(f, 'paid up, nothing shared');

      for (final p in f.partners) {
        expect(p.invested, p.pledged, reason: '${p.name} capital moved');
        expect(p.profitHeld, greaterThan(0), reason: '${p.name} kept nothing');
      }
    });

    test('a losing month never touches anybody capital', () {
      // A loss comes out of the profit account where the gains went.
      // Nobody is made to have invested less because the farm had a bad
      // October.
      runMonth(1, sales: 40000, feed: 200000);
      expect(f.all.profit, lessThan(0));

      final before = f.partners.map((p) => p.invested).toList();
      f.close(DateTime(2026, 1, 1), 50);
      audit6(f, 'a bad month');

      expect(f.partners.map((p) => p.invested).toList(), before);
      for (final p in f.partners) {
        expect(p.profitHeld, lessThan(0), reason: '${p.name} escaped the loss');
      }
    });

    test('the share ratio does not move across all six months', () {
      // Which is what makes the rest of it safe. Men paid their promises
      // off out of profit all through, and nobody's slice shifted.
      final at = <List<double>>[];
      for (var m = 1; m <= 6; m++) {
        runMonth(m);
        f.close(DateTime(2026, m, 1), m <= 2 ? 0 : 50);
        final r = ratiosOf(f.partners);
        at.add([for (final p in f.partners) r[p.id] ?? 0]);
      }
      for (final row in at) {
        expect(row, at.first, reason: 'a slice moved between months');
      }
    });

    test('every rupee the farm took in reached the farm account', () {
      for (var m = 1; m <= 6; m++) {
        runMonth(m);
      }
      audit6(f, 'six months of takings');

      for (final p in f.partners) {
        expect(
          toPayIntoFarm(f.ledger, who: p.name),
          0,
          reason: '${p.name} is still holding the farm\'s money',
        );
      }
    });

    test('and the books balance after every one of them', () {
      for (var m = 1; m <= 6; m++) {
        runMonth(m);
        f.close(DateTime(2026, m, 1), 50);
        audit6(f, 'month $m');
      }

      final b = f.all;
      expect(b.profit, b.sales + b.otherIncome - b.costs);
      final cash = buildStatement(rows: f.ledger, capital: b.capital);
      expect(cash.opening + cash.credits - cash.debits, cash.closing);
    });
  });

  group('what each kind of account may do', () {
    /// The farm asked for every account type to be checked, after a build
    /// where a co-founder's own figures opened nothing at all.

    test('the master writes everything and reads everything', () {
      expect(Role.master.isPartner, isTrue);
      expect(Role.master.seesTheBooks, isTrue);
      expect(Role.master.readOnly, isFalse);
    });

    test('a co-founder writes the books and runs the round', () {
      expect(Role.investor.isPartner, isTrue);
      expect(Role.investor.seesTheBooks, isTrue);
      expect(Role.investor.readOnly, isFalse);
      expect(Role.investor.canDeliver, isTrue);
    });

    test('a silent investor reads all of it and writes none of it', () {
      expect(Role.silent.seesTheBooks, isTrue);
      expect(Role.silent.isPartner, isFalse);
      expect(Role.silent.readOnly, isTrue);
      expect(Role.silent.canDeliver, isFalse);
    });

    test('delivery staff walk the round and see no books', () {
      expect(Role.staff.canDeliver, isTrue);
      expect(Role.staff.seesTheBooks, isFalse);
      expect(Role.staff.isPartner, isFalse);
    });

    test('a customer sees neither', () {
      expect(Role.customer.seesTheBooks, isFalse);
      expect(Role.customer.canDeliver, isFalse);
      expect(Role.customer.isPartner, isFalse);
    });

    test('and read-only is one role, never two by accident', () {
      for (final r in Role.values) {
        expect(r.readOnly, r == Role.silent, reason: r.name);
      }
    });

    test('only the cash keeper or the master answers for the farm account', () {
      final paidIn = CashTransfer(
        id: 'tf',
        from: 'Ghulam Ali',
        to: farmAccountName,
        amount: 8600,
        state: TransferState.waiting,
        sentAt: DateTime(2026, 3, 1),
      );

      expect(
        TransferRepoRules.mayAnswer(
          paidIn,
          asName: 'Rafeeq',
          isMaster: false,
          keepsFarmCash: true,
        ),
        isTrue,
      );
      expect(
        TransferRepoRules.mayAnswer(
          paidIn,
          asName: 'Asif',
          isMaster: false,
          keepsFarmCash: false,
        ),
        isFalse,
      );
      expect(
        TransferRepoRules.mayAnswer(
          paidIn,
          asName: 'Ghulam Ali',
          isMaster: true,
          keepsFarmCash: true,
        ),
        isFalse,
        reason: 'the man who sent it never answers for it',
      );
    });
  });
}

/// The transfer rule, reached without importing the repository.
///
/// `TransferRepo` talks to the database on construction of nothing in
/// particular, but it carries one pure decision worth checking here, and a
/// copy that could drift is worse than an import.
typedef TransferRepoRules = _Rules;

abstract final class _Rules {
  static bool mayAnswer(
    CashTransfer move, {
    required String asName,
    required bool isMaster,
    required bool keepsFarmCash,
  }) {
    if (!move.isWaiting) return false;
    if (partyKey(move.to) == partyKey(farmAccountName)) {
      if (partyKey(move.from) == partyKey(asName)) return false;
      return isMaster || keepsFarmCash;
    }
    return partyKey(move.to) == partyKey(asName);
  }
}
