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

  group('what a co-founder is handed', () {
    MonthShare fresh({num share = 150000}) => MonthShare(
      partnerId: 'p1',
      name: 'Bilal Ahmed',
      ratio: 0.3,
      share: share,
    );

    test('nothing out leaves the whole slice in the farm', () {
      final handed = fresh().handing(0);
      expect(handed.taken, 0);
      expect(handed.held, 150000);
      expect(handed.isLoss, isFalse);
    });

    test('part of it out leaves the rest in', () {
      final handed = fresh().handing(50000);
      expect(handed.taken, 50000);
      expect(handed.held, 100000);
    });

    test('all of it out leaves nothing in', () {
      final handed = fresh().handing(150000);
      expect(handed.held, 0);
    });

    test('a loss is a slice like any other, pointing the other way', () {
      final bad = fresh(share: -60000);
      expect(bad.isLoss, isTrue);
      expect(bad.taken, 0);
      expect(bad.held, -60000);
    });

    test('the period adds up what went out and what stayed', () {
      final period = FarmMonth(
        id: '2026-09',
        status: 'closed',
        openingCash: 0,
        sharedPercent: 40,
        shares: [
          fresh().handing(50000),
          const MonthShare(
            partnerId: 'p2',
            name: 'Adnan Khan',
            ratio: 0.25,
            share: 125000,
          ).handing(125000),
        ],
      );
      expect(period.totalTaken, 175000);
      expect(period.totalHeld, 100000);
      expect(period.sharedPercent, 40);
    });

    test('who has seen the figures is recorded, and blocks nothing', () {
      final period = FarmMonth(
        id: '2026-09',
        status: 'closed',
        openingCash: 0,
        shares: [fresh()],
        seen: {'p1': DateTime(2026, 10, 1)},
      );
      expect(period.seenBy('p1'), isTrue);
      expect(period.seenBy('p2'), isFalse);
      expect(period.notSeen, isEmpty);
    });
  });

  group('a period that lost money still closes', () {
    // A farm that spent more than it sold this month is an ordinary thing.
    // The books have to roll forward whatever the figure says, so a loss must
    // not be able to jam the settling-up shut — and, since version 2, it must
    // not quietly vanish off four people's accounts either.
    FarmMonth atLoss() => FarmMonth(
      id: '2026-09',
      status: 'sealed',
      openingCash: 0,
      profit: -377960,
      profitShared: -377960,
      shares: const [
        MonthShare(
          partnerId: 'p1',
          name: 'Saleem Rehman',
          ratio: 0.24,
          share: -90710,
        ),
        MonthShare(
          partnerId: 'p2',
          name: 'Ghulam Ali',
          ratio: 0.48,
          share: -181421,
        ),
      ],
    );

    test('it knows it is a loss', () {
      expect(atLoss().isLoss, isTrue);
      expect(atLoss().nothingToShare, isTrue);
    });

    test('nothing is handed out of it', () {
      expect(atLoss().totalTaken, 0);
    });

    test('but every slice of it lands on somebody', () {
      expect(atLoss().totalHeld, -272131);
      expect(atLoss().shares.every((s) => s.isLoss), isTrue);
    });

    test('a period that made money is not a loss', () {
      final good = FarmMonth(
        id: '2026-09',
        status: 'sealed',
        openingCash: 0,
        profit: 500000,
        profitShared: 500000,
        shares: const [
          MonthShare(
            partnerId: 'p1',
            name: 'Saleem Rehman',
            ratio: 0.24,
            share: 120000,
          ),
        ],
      );
      expect(good.isLoss, isFalse);
      expect(good.nothingToShare, isFalse);
    });

    test('a farm with no co-founders yet has nothing to hand round', () {
      final none = FarmMonth(id: '2026-09', status: 'sealed', openingCash: 0);
      expect(none.nothingToShare, isTrue);
      expect(none.totalTaken, 0);
    });
  });

  group('a capital record', () {
    Partner record({num invested = 0, num held = 0, num withdrawn = 0}) =>
        Partner(
          id: 'p1',
          userId: 'u1',
          name: 'Saleem Rehman',
          email: 'saleem@example.com',
          invested: invested,
          profitHeld: held,
          withdrawn: withdrawn,
          createdAt: DateTime(2026),
        );

    test('with nothing in it can be cleared away', () {
      // Which is how the duplicates a second sign-in left behind are removed.
      expect(record().isEmpty, isTrue);
    });

    test('with money in it never can', () {
      expect(record(invested: 1000000).isEmpty, isFalse);
      expect(record(held: 50000).isEmpty, isFalse);
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

    test('a version 1 withdrawal still reads as what was handed over', () {
      // Periods closed under version 1 called it a withdrawal, because the
      // co-founder had asked for it. Nothing about the money changed.
      final took = MonthShare.fromMap({
        'partnerId': 'p1',
        'name': 'Someone',
        'ratio': 0.5,
        'share': 80000,
        'withdraw': 80000,
      });
      expect(took.taken, 80000);
      expect(took.held, 0);

      final left = MonthShare.fromMap({
        'partnerId': 'p2',
        'name': 'Someone else',
        'ratio': 0.5,
        'share': 80000,
        'withdraw': 0,
      });
      expect(left.taken, 0);
      expect(left.held, 80000);
    });

    test('a version 1 record reads its profit out of the old field', () {
      // It was called `reinvested` when it was capital. It is the same money.
      final old = Partner(
        id: 'p1',
        userId: 'u1',
        name: 'Someone',
        invested: 1000000,
        profitHeld: 0,
        withdrawn: 0,
        createdAt: DateTime(2026),
      );
      expect(old.inTheFarm, 1000000);
    });
  });
}
