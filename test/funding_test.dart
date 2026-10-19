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

    test('and nobody is holding a rupee of it', () {
      // The money went from three pockets to the cattle market without
      // passing through the farm's hands. A card saying one of them was
      // holding seventeen lakh would be a card nobody could act on.
      expect(cashInHands(const [], putIn: split), isEmpty);
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
}
