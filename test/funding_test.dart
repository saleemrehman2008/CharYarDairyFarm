import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';

/// Four friends funding a farm out of four unequal pockets, none of them in
/// one go.
///
/// Three things had to be told apart before any of this could be counted.
/// What a man is in for, which settles his share the day he says it. What has
/// actually arrived, which is what the farm has to spend. And what the farm
/// is holding of his that it owes back — the feed he paid for himself on
/// Tuesday, until the four of them say it comes off his promise instead.
///
/// Before this the app had one number for the lot of it, typed over by hand.

var _n = 0;

Partner _p({
  required String name,
  num pledged = 0,
  num invested = 0,
  num profitHeld = 0,
}) => Partner(
  id: 'p${_n++}',
  userId: 'u$_n',
  name: name,
  invested: invested,
  pledged: pledged,
  profitHeld: profitHeld,
  withdrawn: 0,
  createdAt: DateTime(2026, 8, 1),
);

Contribution _c({
  required String partnerId,
  required num amount,
  ContributionKind kind = ContributionKind.investment,
  ContributionSource source = ContributionSource.cash,
  String receivedBy = 'Rafeeq',
  String? txnId,
}) => Contribution(
  id: 'c${_n++}',
  partnerId: partnerId,
  partnerName: 'Somebody',
  kind: kind,
  source: source,
  amount: amount,
  date: DateTime(2026, 10, 8),
  receivedBy: source == ContributionSource.spent ? '' : receivedBy,
  txnId: txnId,
  createdAt: DateTime(2026, 10, 8),
);

void main() {
  group('the promise, and what has arrived', () {
    test(
      'a share is worked out from what he is in for, not what he has paid',
      () {
        // The decision the four of them made, and the reason: none of them
        // could pay his whole share at once, and a ratio that followed the
        // money would have moved under all of them every month.
        final a = _p(name: 'Ali', pledged: 1000000, invested: 400000);
        final b = _p(name: 'Bilal', pledged: 1000000, invested: 1000000);
        final ratios = ratiosOf([a, b]);
        expect(ratios[a.id], 0.5);
        expect(ratios[b.id], 0.5);
      },
    );

    test('and it says what is still to come', () {
      final a = _p(name: 'Ali', pledged: 1000000, invested: 400000);
      expect(a.stillToPayIn, 600000);
      expect(a.paidInFull, isFalse);
      expect(a.overPaid, 0);
    });

    test('raising the promise moves the share and the shortfall at once', () {
      // His own example: in for ten, paid eight, wants to be in for fifteen.
      final before = _p(name: 'Ali', pledged: 1000000, invested: 800000);
      expect(before.stillToPayIn, 200000);

      final after = _p(name: 'Ali', pledged: 1500000, invested: 800000);
      expect(after.stillToPayIn, 700000);
      expect(after.ratioBase, 1500000);
    });

    test('putting in more than promised never costs him share', () {
      // The rule that is not in the agreement and has to be there: a man
      // who pays above what he said must not be given a smaller slice than
      // his own rupees are paying for.
      final a = _p(name: 'Ali', pledged: 500000, invested: 600000);
      expect(a.ratioBase, 600000);
      expect(a.overPaid, 100000);
      expect(a.stillToPayIn, 0);
    });

    test('a record with no promise on it falls back to the money', () {
      // Which is how the farm ran until today, so nothing breaks the day
      // this arrives and before anybody has typed a promise in.
      final a = _p(name: 'Ali', invested: 300000);
      final b = _p(name: 'Bilal', invested: 100000);
      final ratios = ratiosOf([a, b]);
      expect(ratios[a.id], 0.75);
      expect(ratios[b.id], 0.25);
    });

    test('and the profit kept in the farm never moves a share', () {
      // The whole point of version 2, and it survives the change.
      final a = _p(name: 'Ali', pledged: 500000, invested: 500000);
      final b = _p(
        name: 'Bilal',
        pledged: 500000,
        invested: 500000,
        profitHeld: 900000,
      );
      expect(ratiosOf([a, b])[b.id], 0.5);
    });
  });

  group('seventeen lakh of cattle, three pockets', () {
    /// One sauda, one entry, three men. The entry is never split; what is
    /// written is whose money paid it, in rupees.
    final jalbani = _p(name: 'Jalbani', pledged: 1000000, invested: 700000);
    final rafeeq = _p(name: 'Rafeeq', pledged: 1000000, invested: 500000);
    final saleem = _p(name: 'Saleem', pledged: 1000000, invested: 500000);

    final split = [
      _c(
        partnerId: jalbani.id,
        amount: 700000,
        source: ContributionSource.spent,
        txnId: 'cows',
      ),
      _c(
        partnerId: rafeeq.id,
        amount: 500000,
        source: ContributionSource.spent,
        txnId: 'cows',
      ),
      _c(
        partnerId: saleem.id,
        amount: 500000,
        source: ContributionSource.spent,
        txnId: 'cows',
      ),
    ];

    test('the three parts add up to the one entry', () {
      expect(
        paidFor(split, 'cows').fold<num>(0, (a, c) => a + c.amount),
        1700000,
      );
    });

    test('each man is credited with what he actually paid', () {
      expect(investedFrom(split, jalbani.id), 700000);
      expect(investedFrom(split, rafeeq.id), 500000);
      expect(investedFrom(split, saleem.id), 500000);
    });

    test('and once the purchase is on the books nobody is left holding '
        'it', () {
      // The whole of it, both sides. Each man's own money goes in and out
      // again on the same day, and the entry — which carries one name as
      // the payer, though three men paid — comes out of the three who
      // actually found it.
      final cows = Txn(
        id: 'cows',
        date: DateTime(2026, 10, 8),
        monthId: '2026-10',
        type: TxnType.purchase,
        party: 'Mandi',
        category: 'Cattle purchase',
        amount: 1700000,
        paid: true,
        paidOnCreate: true,
        handledBy: 'Jalbani',
        note: '',
        createdBy: 'u1',
        createdAt: DateTime(2026, 10, 8),
      );

      final hands = cashInHands([cows], putIn: split);
      for (final h in hands) {
        expect(
          h.holding,
          0,
          reason: '${h.who} put his own money in and it went straight out',
        );
      }
    });

    test('without the split it all lands on the one name on the entry', () {
      // Which is what the farm was looking at: eighteen lakh against one
      // man, because the entry can only carry one payer and nobody had
      // written down who really found the money.
      final cows = Txn(
        id: 'cows',
        date: DateTime(2026, 10, 8),
        monthId: '2026-10',
        type: TxnType.purchase,
        party: 'Mandi',
        category: 'Cattle purchase',
        amount: 1700000,
        paid: true,
        paidOnCreate: true,
        handledBy: 'Jalbani',
        note: '',
        createdBy: 'u1',
        createdAt: DateTime(2026, 10, 8),
      );
      final hands = cashInHands([cows]);
      expect(hands.single.who, 'Jalbani');
      expect(hands.single.holding, -1700000);
    });
    test('cash handed to whoever keeps it does land in his hands', () {
      final handed = [
        _c(partnerId: jalbani.id, amount: 200000, receivedBy: 'Rafeeq'),
      ];
      final hands = cashInHands(const [], putIn: handed);
      expect(hands.single.who, 'Rafeeq');
      expect(hands.single.received, 200000);
    });
  });

  group('money of theirs the farm is holding', () {
    final jalbani = _p(name: 'Jalbani', pledged: 1000000);

    test('a loan counts towards nothing until somebody says it does', () {
      final lines = [
        _c(
          partnerId: jalbani.id,
          amount: 12000,
          kind: ContributionKind.loan,
          source: ContributionSource.spent,
          txnId: 'feed',
        ),
      ];
      expect(investedFrom(lines, jalbani.id), 0);
      expect(owedToFrom(lines, jalbani.id), 12000);
    });

    test('and the cash sees it, because it is in the box', () {
      // He bought the feed with his own money. The feed is the farm's cost
      // and those rupees left the farm's books — but they were never the
      // farm's rupees. Without this the cash reads short by exactly what he
      // laid out, every time any of them does it.
      final feed = Txn(
        id: 'feed',
        date: DateTime(2026, 10, 8),
        monthId: '2026-10',
        type: TxnType.purchase,
        party: 'Feed store',
        category: 'Wanda / feed',
        amount: 12000,
        paid: true,
        paidOnCreate: true,
        note: '',
        createdBy: 'u1',
        createdAt: DateTime(2026, 10, 8),
      );
      final books = Books(
        monthId: '2026-10',
        openingCash: 0,
        capital: 0,
        founderFloat: 12000,
        monthTxns: [feed],
        unpaidTxns: const [],
      );
      expect(books.cash, 0, reason: 'in, then straight out again');

      final money = MoneySummary(
        capital: 0,
        assets: 0,
        runningCosts: books.costs,
        sales: 0,
        cash: books.cash,
        receivable: 0,
        payable: 0,
        owedToFounders: 12000,
      );
      expect(money.reconciles, isTrue);
      expect(money.farmMoney, -12000, reason: 'the farm owes him for it');
    });

    test('before he is paid back, the farm is holding his money', () {
      final books = Books(
        monthId: '2026-10',
        openingCash: 0,
        capital: 0,
        founderFloat: 12000,
        monthTxns: const [],
        unpaidTxns: const [],
      );
      expect(books.cash, 12000);
      final money = MoneySummary(
        capital: 0,
        assets: 0,
        runningCosts: 0,
        sales: 0,
        cash: books.cash,
        receivable: 0,
        payable: 0,
        owedToFounders: 12000,
      );
      expect(money.farmMoney, 0, reason: 'none of it is the farm\'s');
      expect(money.reconciles, isTrue);
    });
  });

  group('what the farm does with a co-founder\'s own money', () {
    /// The rule the farm settled, and the reason it is a rule rather than a
    /// question: while a man still owes on what he promised, every rupee he
    /// lays out is that promise being paid off. Once he has paid it in full,
    /// the next rupee is a loan the farm has to give back.

    test('short on his promise, it all counts towards it', () {
      // Jalbani is in for twenty lakh and has paid ten. The ten he hands
      // over finishes it.
      final cut = splitByPledge(
        amount: 1000000,
        pledged: 2000000,
        alreadyIn: 1000000,
      );
      expect(cut.investment, 1000000);
      expect(cut.refundable, 0);
    });

    test('paid in full, the next rupee is owed back to him', () {
      // Twenty thousand of feed, out of his own pocket, on a promise he has
      // already met. He asks Rafeeq for it or takes it out of the next
      // money that passes through his hands.
      final cut = splitByPledge(
        amount: 20000,
        pledged: 2000000,
        alreadyIn: 2000000,
      );
      expect(cut.investment, 0);
      expect(cut.refundable, 20000);
    });

    test('one payment can be both, and is cut where the promise ends', () {
      // Five thousand left on his promise and a twenty-five thousand feed
      // bill. Five finishes what he owed; twenty the farm has to return.
      final cut = splitByPledge(
        amount: 25000,
        pledged: 2000000,
        alreadyIn: 1995000,
      );
      expect(cut.investment, 5000);
      expect(cut.refundable, 20000);
      expect(cut.investment + cut.refundable, 25000, reason: 'nothing lost');
    });

    test('exactly finishing the promise leaves nothing owed', () {
      final cut = splitByPledge(
        amount: 5000,
        pledged: 2000000,
        alreadyIn: 1995000,
      );
      expect(cut.investment, 5000);
      expect(cut.refundable, 0);
    });

    test('a man who has already over-paid is owed every rupee of it', () {
      final cut = splitByPledge(
        amount: 10000,
        pledged: 500000,
        alreadyIn: 600000,
      );
      expect(cut.investment, 0);
      expect(cut.refundable, 10000);
    });

    test('with no promise on the record it is all investment', () {
      // How the farm ran before promises were kept at all, so nothing
      // breaks on the day this arrives.
      final cut = splitByPledge(amount: 10000, pledged: 0, alreadyIn: 300000);
      expect(cut.investment, 10000);
      expect(cut.refundable, 0);
    });

    test('nothing in, nothing out', () {
      final cut = splitByPledge(amount: 0, pledged: 500000, alreadyIn: 0);
      expect(cut.investment, 0);
      expect(cut.refundable, 0);
    });
  });

  group('taking back money of his own', () {
    /// Jalbani pays a twenty thousand feed bill out of his own pocket on a
    /// promise he has already met, and a week later forty thousand of milk
    /// money passes through his hands. Rather than handing over all forty and
    /// asking for twenty back, he keeps his twenty.
    ///
    /// The trap in this, and it took the long way round to find: the farm's
    /// cash formula carries a correction for money that was never in its box.
    /// That correction has to go on standing after he is repaid, because the
    /// purchase it cancels is on the page for ever. Clearing it and paying
    /// him at the same time took the cash down twice — once for a payment
    /// the farm made and once for one it never did.

    Txn feed({num amount = 20000}) => Txn(
      id: 'feed',
      date: DateTime(2026, 10, 8),
      monthId: '2026-10',
      type: TxnType.purchase,
      party: 'Feed store',
      category: 'Wanda / feed',
      amount: amount,
      paid: true,
      paidOnCreate: true,
      handledBy: 'Jalbani',
      note: '',
      createdBy: 'u1',
      createdAt: DateTime(2026, 10, 8),
    );

    Txn repaid({num amount = 20000}) => Txn(
      id: 'back',
      date: DateTime(2026, 10, 15),
      monthId: '2026-10',
      type: TxnType.payment,
      party: 'Jalbani',
      category: founderRepaidCategory,
      amount: amount,
      paid: true,
      paidOnCreate: true,
      handledBy: 'Jalbani',
      note: '',
      createdBy: 'u1',
      createdAt: DateTime(2026, 10, 15),
    );

    Contribution lent({num amount = 20000, num back = 0}) => Contribution(
      id: 'lent',
      partnerId: 'p1',
      partnerName: 'Jalbani',
      kind: ContributionKind.loan,
      source: ContributionSource.spent,
      amount: amount,
      repaidSoFar: back,
      date: DateTime(2026, 10, 8),
      txnId: 'feed',
      createdAt: DateTime(2026, 10, 8),
    );

    MoneySummary money(List<Txn> rows, List<Contribution> lines) {
      final b = Books(
        monthId: '2026-10',
        openingCash: 0,
        capital: 0,
        founderFloat: lines
            .where((c) => c.isLoan)
            .fold<num>(0, (a, c) => a + c.amount),
        monthTxns: rows,
        unpaidTxns: const [],
      );
      return MoneySummary(
        capital: 0,
        assets: 0,
        runningCosts: b.costs,
        sales: 0,
        cash: b.cash,
        receivable: 0,
        payable: 0,
        owedToFounders: lines.fold<num>(0, (a, c) => a + c.stillOwed),
      );
    }

    test('while he is owed it, the box is untouched', () {
      // He paid the feed merchant. Not one rupee of the farm's own money
      // moved, and the farm owes him twenty thousand.
      final m = money([feed()], [lent()]);
      expect(m.cash, 0);
      expect(m.owedToFounders, 20000);
      expect(m.farmMoney, -20000, reason: 'the cost, and nothing to show');
      expect(m.reconciles, isTrue);
    });

    test(
      'once he is paid back, the box is short by it and nothing is owed',
      () {
        final m = money([feed(), repaid()], [lent(back: 20000)]);
        expect(m.cash, -20000, reason: 'the farm really did pay him');
        expect(m.owedToFounders, 0);
        expect(m.reconciles, isTrue);
      },
    );

    test('and it is never counted as a cost of running the farm', () {
      // The cost was booked the day he bought the feed. Counting it again
      // when he is handed his money back would halve the profit twice over.
      final b = Books(
        monthId: '2026-10',
        openingCash: 0,
        capital: 0,
        founderFloat: 20000,
        monthTxns: [feed(), repaid()],
        unpaidTxns: const [],
      );
      expect(b.costs, 20000, reason: 'the feed, once');
      expect(repaid().isLoosePayment, isFalse);
    });

    test('taking back part of it leaves the rest owed', () {
      final m = money([feed(), repaid(amount: 5000)], [lent(back: 5000)]);
      expect(m.owedToFounders, 15000);
      expect(m.cash, -5000);
      expect(m.reconciles, isTrue);
    });

    test('and it comes out of the cash he is holding', () {
      // Forty thousand of milk money reached him; he keeps twenty.
      final collected = Txn(
        id: 'milk',
        date: DateTime(2026, 10, 15),
        monthId: '2026-10',
        type: TxnType.receipt,
        party: 'Urooj Dairy Shop',
        category: khaataReceiptCategory,
        amount: 40000,
        paid: true,
        paidOnCreate: true,
        settlesTxnId: 'x',
        handledBy: 'Jalbani',
        note: '',
        createdBy: 'u1',
        createdAt: DateTime(2026, 10, 15),
      );
      final hands = {
        for (final h in cashInHands(
          [feed(), collected, repaid()],
          putIn: [lent(back: 20000)],
        ))
          h.who: h,
      };
      // Twenty thousand of his own went in and straight out on the feed;
      // forty came in and twenty of it stayed with him as his own money.
      expect(hands['Jalbani']!.holding, 20000);
    });
  });

  group('a figure typed into the wrong column', () {
    /// The farm ran for months on one number per co-founder that the master
    /// typed onto his card. Nobody had handed that money over: it was what
    /// each of them had undertaken to put in. Read as money already in, it
    /// said the farm held cash it did not hold — and it counted every rupee
    /// twice the moment somebody wrote down which purchase that man had
    /// actually paid for.
    ///
    /// The farm found the second one itself, splitting a seventeen lakh
    /// cattle entry and watching the cards go up by money already spent.

    test('what it looks like, so the app can offer to put it right', () {
      // More claimed as put in than the lines can account for.
      final typed = _p(name: 'Ghulam Ali', invested: 2000000);
      expect(investedFrom(const [], typed.id), 0);
      expect(typed.invested > investedFrom(const [], typed.id), isTrue);
    });

    test('a card built from its own lines is left alone', () {
      final honest = _p(name: 'Rafeeq', invested: 500000, pledged: 1500000);
      final lines = [_c(partnerId: honest.id, amount: 500000)];
      expect(investedFrom(lines, honest.id), 500000);
      expect(honest.invested > investedFrom(lines, honest.id), isFalse);
    });

    test('moved across, the promise is kept and the money is not', () {
      // What the one-tap fix does, in figures: twenty lakh typed on the
      // card becomes twenty lakh promised, and what he has put in goes back
      // to what his lines say — nothing, until they are written.
      final before = _p(name: 'Ghulam Ali', invested: 2000000);
      final after = _p(name: 'Ghulam Ali', invested: 0, pledged: 2000000);

      expect(after.pledged, before.invested);
      expect(after.invested, 0);
      expect(after.stillToPayIn, 2000000);
      // And his share does not move, because the ratio follows the promise.
      expect(before.ratioBase, after.ratioBase);
    });

    test('splitting an entry afterwards no longer counts it twice', () {
      // Seventeen lakh of cattle, paid by three of them. Before the fix
      // their cards already held the money and the split added it again;
      // after it, the split is the only place it is counted.
      final after = _p(name: 'Ghulam Ali', invested: 0, pledged: 2000000);
      final split = [
        _c(
          partnerId: after.id,
          amount: 700000,
          source: ContributionSource.spent,
          txnId: 'cows',
        ),
      ];
      expect(investedFrom(split, after.id), 700000);
      expect(
        after.pledged - investedFrom(split, after.id),
        1300000,
        reason: 'what he still owes on his promise',
      );
    });

    test('and a man who has put in more than his lines show is the only '
        'one offered', () {
      // The offer is per man, not for the farm at large: one card can be
      // honest while another is not.
      final honest = _p(name: 'Rafeeq', invested: 500000);
      final typed = _p(name: 'Ghulam Ali', invested: 2000000);
      final lines = [_c(partnerId: honest.id, amount: 500000)];

      final affected = [
        for (final p in [honest, typed])
          if (p.invested > investedFrom(lines, p.id)) p.name,
      ];
      expect(affected, ['Ghulam Ali']);
    });
  });

  group('spending out of his own pocket, counted as money put in', () {
    /// What the farm asked for in its own words: Saleem has ten lakh to put
    /// in and has put in nothing, but he has paid for things — that should
    /// show on his investment. Asif has fifteen lakh to put in and has spent
    /// 3,80,000 of his own; it was in the expenses and nowhere on his card.
    ///
    /// The ledger had the answer all along. Every entry carries the name of
    /// whoever found the money, so a man who has paid out more than he has
    /// taken in is out of pocket by the difference. That difference is his
    /// own money the farm has had the use of. It only needed a line.

    Txn spentBy(num amount, String by) => Txn(
      id: 't${_n++}',
      date: DateTime(2026, 10, 9),
      monthId: '2026-10',
      type: TxnType.expense,
      party: 'Feed shop',
      category: 'Feed',
      amount: amount,
      paid: true,
      paidOnCreate: true,
      handledBy: by,
      note: '',
      createdBy: 'u1',
      createdAt: DateTime(2026, 10, 9),
    );

    test('the ledger already says how much he is out of pocket', () {
      final hands = cashInHands([spentBy(380000, 'Asif')], putIn: const []);
      expect(hands.single.who, 'Asif');
      expect(hands.single.holding, -380000);
    });

    test('counting it brings what he is holding back to nothing', () {
      final asif = _p(name: 'Asif', pledged: 1500000);
      final ledger = [spentBy(380000, 'Asif')];

      // The line the one tap writes: his own money, spent, not handed to
      // anybody. It lands in his hands on the way in and goes straight out
      // again on the purchase row that carries his name.
      final line = Contribution(
        id: 'c${_n++}',
        partnerId: asif.id,
        partnerName: 'Asif',
        kind: ContributionKind.investment,
        source: ContributionSource.spent,
        amount: 380000,
        date: DateTime(2026, 10, 9),
        createdAt: DateTime(2026, 10, 9),
      );

      final hands = cashInHands(ledger, putIn: [line]);
      expect(hands.single.holding, 0);
      expect(investedFrom([line], asif.id), 380000);
    });

    test('it goes against his promise first, and the rest is owed back', () {
      // Rafeeq is in for fifteen lakh and has spent sixteen of his own.
      // Fifteen is his promise kept; the lakh over it the farm owes him.
      final cut = splitByPledge(
        amount: 1600000,
        pledged: 1500000,
        alreadyIn: 0,
      );
      expect(cut.investment, 1500000);
      expect(cut.refundable, 100000);
    });

    test('a man already paid in full is owed every rupee of it back', () {
      final cut = splitByPledge(
        amount: 270000,
        pledged: 1000000,
        alreadyIn: 1000000,
      );
      expect(cut.investment, 0);
      expect(cut.refundable, 270000);
    });

    test('an entry split to its payers is not counted twice over', () {
      // Seventeen lakh of cattle, 7,00,000 of it Ghulam Ali's. Splitting it
      // writes a line against the entry, which both credits his hands and
      // takes the money back out on the row — so he is holding nothing and
      // the farm is not asked to count it again.
      final ali = _p(name: 'Ghulam Ali', pledged: 2000000);
      final cows = spentBy(1700000, 'Ghulam Ali');
      final line = Contribution(
        id: 'c${_n++}',
        partnerId: ali.id,
        partnerName: 'Ghulam Ali',
        kind: ContributionKind.investment,
        source: ContributionSource.spent,
        amount: 700000,
        date: DateTime(2026, 10, 9),
        txnId: cows.id,
        createdAt: DateTime(2026, 10, 9),
      );

      final hands = cashInHands([cows], putIn: [line]);
      expect(
        hands.single.holding,
        -1000000,
        reason: 'what is left of the cattle is still unaccounted for',
      );
      expect(investedFrom([line], ali.id), 700000);
    });

    test('a correction is not money anybody took in', () {
      // The master zeroing a typed figure wrote a minus ten lakh line, and
      // the card read "Rs -10,00,000 taken in". A correction is a note
      // about the books; no rupee moved.
      final ali = _p(name: 'Ghulam Ali');
      final fix = Contribution(
        id: 'c${_n++}',
        partnerId: ali.id,
        partnerName: 'Ghulam Ali',
        kind: ContributionKind.investment,
        source: ContributionSource.correction,
        amount: -1000000,
        date: DateTime(2026, 10, 9),
        createdAt: DateTime(2026, 10, 9),
      );
      expect(cashInHands(const [], putIn: [fix]), isEmpty);
    });
  });
}
