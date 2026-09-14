import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/util/money.dart';
import 'package:flutter_test/flutter_test.dart';

/// The farm settles up at the end of a stretch of trading, and that stretch is
/// usually — but not always — a calendar month. These are the rules that let a
/// September have two of them without anything falling down the gap.
void main() {
  group('a period that ends when the month does', () {
    test('is followed by the next month', () {
      expect(nextPeriodId('2026-09', DateTime(2026, 9, 30)), '2026-10');
      expect(nextPeriodId('2026-12', DateTime(2026, 12, 31)), '2027-01');
    });

    test('knows a short month when it sees one', () {
      expect(nextPeriodId('2027-02', DateTime(2027, 2, 28)), '2027-03');
      // 2028 is a leap year, so the 28th is not the end of it.
      expect(nextPeriodId('2028-02', DateTime(2028, 2, 28)), '2028-02b');
      expect(nextPeriodId('2028-02', DateTime(2028, 2, 29)), '2028-03');
    });
  });

  group('a period that ends mid-month', () {
    test('leaves the rest of the month to a period of its own', () {
      expect(nextPeriodId('2026-09', DateTime(2026, 9, 14)), '2026-09b');
      expect(nextPeriodId('2026-09b', DateTime(2026, 9, 22)), '2026-09c');
    });

    test('sorts after the first and before the next month', () {
      // The open period is found by taking the oldest id, so this ordering is
      // what keeps entries landing in the right place.
      final ids = ['2026-10', '2026-09b', '2026-09', '2026-09c']..sort();
      expect(ids, ['2026-09', '2026-09b', '2026-09c', '2026-10']);
    });

    test('still reads as its own month', () {
      expect(monthShort('2026-09b'), 'Sep 2026');
      expect(monthName('2026-09c'), 'September 2026');
    });
  });

  group('what a period is called', () {
    FarmMonth period(String id, DateTime? from, DateTime? to, String status) =>
        FarmMonth(id: id, status: status, openingCash: 0, from: from, to: to);

    test('a whole calendar month is just its name', () {
      expect(
        periodLabel(
          period(
            '2026-09',
            DateTime(2026, 9, 1),
            DateTime(2026, 9, 30),
            'closed',
          ),
        ),
        'September 2026',
      );
    });

    test('a part of a month is named by the days it covers', () {
      expect(
        periodLabel(
          period(
            '2026-09',
            DateTime(2026, 9, 1),
            DateTime(2026, 9, 14),
            'closed',
          ),
        ),
        '1–14 Sep 2026',
      );
      expect(
        periodLabel(
          period(
            '2026-09b',
            DateTime(2026, 9, 14),
            DateTime(2026, 9, 30),
            'closed',
          ),
        ),
        '14–30 Sep 2026',
      );
    });

    test('a period with no dates falls back to the month', () {
      expect(
        periodLabel(period('2026-09', null, null, 'open')),
        'September 2026',
      );
    });
  });

  group('what a co-founder decides', () {
    MonthShare fresh() => const MonthShare(
      partnerId: 'p1',
      name: 'Bilal Ahmed',
      ratio: 0.3,
      share: 150000,
      choice: 'reinvest',
    );

    test('starts undecided, and a period cannot close on it', () {
      final period = FarmMonth(
        id: '2026-09',
        status: 'sealed',
        openingCash: 0,
        shares: [fresh()],
      );
      expect(period.allDecided, isFalse);
      expect(period.undecided.single.name, 'Bilal Ahmed');
    });

    test('taking part of it leaves the rest as investment', () {
      final decided = fresh().decide(withdraw: 50000, by: 'u1');
      expect(decided.withdraw, 50000);
      expect(decided.reinvest, 100000);
      expect(decided.choice, 'split');
      expect(decided.decided, isTrue);
      expect(decided.byPhone, isFalse);
    });

    test('taking nothing puts the whole share back into the farm', () {
      final decided = fresh().decide(withdraw: 0, by: 'u1');
      expect(decided.reinvest, 150000);
      expect(decided.isReinvested, isTrue);
      expect(decided.choice, 'reinvest');
    });

    test('nobody can take more than their share', () {
      final decided = fresh().decide(withdraw: 999999, by: 'u1');
      expect(decided.withdraw, 150000);
      expect(decided.reinvest, 0);
      expect(decided.takesAll, isTrue);
    });

    test('the master entering it is recorded as second hand', () {
      final decided = fresh().decide(
        withdraw: 50000,
        by: 'master',
        byPhone: true,
      );
      expect(decided.byPhone, isTrue);
      expect(decided.decidedBy, 'master');
    });

    test('the period adds up what is going out and what is staying', () {
      final period = FarmMonth(
        id: '2026-09',
        status: 'sealed',
        openingCash: 0,
        shares: [
          fresh().decide(withdraw: 50000, by: 'a'),
          const MonthShare(
            partnerId: 'p2',
            name: 'Adnan Khan',
            ratio: 0.25,
            share: 125000,
            choice: 'reinvest',
          ).decide(withdraw: 125000, by: 'b'),
        ],
      );
      expect(period.allDecided, isTrue);
      expect(period.totalWithdraw, 175000);
      expect(period.totalReinvest, 100000);
    });
  });

  group('a period that made nothing still closes', () {
    // A farm that spent more than it sold this month is an ordinary thing.
    // The books have to roll forward whatever the figure says, so a loss must
    // not be able to jam the settling-up shut.
    FarmMonth atLoss() => FarmMonth(
      id: '2026-09',
      status: 'sealed',
      openingCash: 0,
      profitShared: -377960,
      shares: const [
        MonthShare(
          partnerId: 'p1',
          name: 'Saleem Rehman',
          ratio: 0.24,
          share: 0,
          choice: 'reinvest',
        ),
        MonthShare(
          partnerId: 'p2',
          name: 'Ghulam Ali',
          ratio: 0.48,
          share: 0,
          choice: 'reinvest',
        ),
      ],
    );

    test('has nothing to hand out', () {
      expect(atLoss().nothingToShare, isTrue);
      expect(atLoss().totalWithdraw, 0);
      expect(atLoss().totalReinvest, 0);
    });

    test('does not wait on anybody to decide', () {
      expect(atLoss().allDecided, isTrue);
    });

    test('a period with real shares still waits', () {
      final real = FarmMonth(
        id: '2026-09',
        status: 'sealed',
        openingCash: 0,
        profitShared: 500000,
        shares: const [
          MonthShare(
            partnerId: 'p1',
            name: 'Saleem Rehman',
            ratio: 0.24,
            share: 120000,
            choice: 'reinvest',
          ),
        ],
      );
      expect(real.nothingToShare, isFalse);
      expect(real.allDecided, isFalse);
    });

    test('a farm with no co-founders yet has nothing to wait for', () {
      final none = FarmMonth(id: '2026-09', status: 'sealed', openingCash: 0);
      expect(none.nothingToShare, isTrue);
      expect(none.allDecided, isTrue);
    });
  });

  group('a capital record', () {
    Partner record({num invested = 0, num reinvested = 0, num withdrawn = 0}) =>
        Partner(
          id: 'p1',
          userId: 'u1',
          name: 'Saleem Rehman',
          email: 'saleem@example.com',
          invested: invested,
          reinvested: reinvested,
          withdrawn: withdrawn,
          createdAt: DateTime(2026),
        );

    test('with nothing in it can be cleared away', () {
      // Which is how the duplicates a second sign-in left behind are removed.
      expect(record().isEmpty, isTrue);
    });

    test('with money in it never can', () {
      expect(record(invested: 1000000).isEmpty, isFalse);
      expect(record(reinvested: 50000).isEmpty, isFalse);
      expect(record(withdrawn: 50000).isEmpty, isFalse);
    });
  });

  group('a period read back from the database', () {
    test('a sealed one is frozen against new entries', () {
      expect(
        FarmMonth(id: '2026-09', status: 'sealed', openingCash: 0).isFrozen,
        isTrue,
      );
      expect(
        FarmMonth(id: '2026-09', status: 'open', openingCash: 0).isFrozen,
        isFalse,
      );
    });

    test('an old all-or-nothing choice still reads as an amount', () {
      // Periods closed before split decisions existed recorded only the word.
      final took = MonthShare.fromMap({
        'partnerId': 'p1',
        'name': 'Someone',
        'ratio': 0.5,
        'share': 80000,
        'choice': 'withdraw',
      });
      expect(took.withdraw, 80000);
      expect(took.reinvest, 0);

      final left = MonthShare.fromMap({
        'partnerId': 'p2',
        'name': 'Someone else',
        'ratio': 0.5,
        'share': 80000,
        'choice': 'reinvest',
      });
      expect(left.withdraw, 0);
      expect(left.reinvest, 80000);
    });
  });
}
