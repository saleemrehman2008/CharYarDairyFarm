import 'package:char_yar_dairy_farm/screens/shared/new_entry_screen.dart';
import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';
import 'package:char_yar_dairy_farm/util/money.dart';
import 'package:char_yar_dairy_farm/theme/tokens.dart';
import 'package:char_yar_dairy_farm/widgets/balance_check.dart';
import 'package:char_yar_dairy_farm/widgets/photo.dart';
import 'package:char_yar_dairy_farm/widgets/pick_sheet.dart';
import 'package:char_yar_dairy_farm/widgets/day_chart.dart';
import 'package:char_yar_dairy_farm/widgets/farm_icons.dart';
import 'package:char_yar_dairy_farm/widgets/month_chart.dart';
import 'package:char_yar_dairy_farm/widgets/worth_bar.dart';
import 'package:char_yar_dairy_farm/widgets/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every card in a scrolling page, laid out with no height to stretch to.
///
/// This is where a whole build went wrong once. A card was built as a Row
/// stretched down its cross axis, which inside a list means "be as tall as the
/// space", and in a list there is no space — it is unbounded. Debug would have
/// shown a red box; the release build the farm installed drew nothing at all,
/// and took every card after it in the list down with it. Three screens came
/// up blank.
///
/// `flutter analyze` cannot see that, and no test existed to trip over it. So
/// the rule now is: anything that goes in a page gets pumped inside a
/// ListView here, where the height is unbounded exactly as it is on a phone.
void main() {
  Future<void> inAList(WidgetTester tester, List<Widget> children) =>
      tester.pumpWidget(
        MaterialApp(
          // No ripple. Material's default splash is drawn by a shader that
          // ships with the engine but is not there in a headless test run, so
          // tapping anything threw where it matters least: these tests are
          // about what a card lays out and what a button does, not about the
          // animation on the way.
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Scaffold(body: ListView(children: children)),
        ),
      );

  group('the name and kind pills', () {
    testWidgets('reads as a word when nothing is picked', (tester) async {
      await inAList(tester, [
        PickPill(
          icon: Icons.person_outline,
          label: 'Anyone',
          onTap: () {},
          onClear: () {},
        ),
      ]);

      expect(tester.takeException(), isNull);
      expect(find.text('Anyone'), findsOneWidget);
    });

    testWidgets('shows the choice and a way out of it', (tester) async {
      var cleared = false;
      await inAList(tester, [
        PickPill(
          icon: Icons.person_outline,
          label: 'Kashif',
          chosen: true,
          onTap: () {},
          onClear: () => cleared = true,
        ),
      ]);

      expect(tester.takeException(), isNull);
      expect(find.text('Kashif'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      expect(cleared, isTrue);
    });
  });

  group('the books-balance check', () {
    MoneySummary summary({required num cash, num paidOut = 0}) => MoneySummary(
      capital: 2000000,
      assets: 1400000,
      runningCosts: 400000,
      sales: 500000,
      cash: cash,
      receivable: 0,
      payable: 0,
      paidOut: paidOut,
    );

    testWidgets('says so plainly when everything ties up', (tester) async {
      await inAList(tester, [BalanceCheck(money: summary(cash: 700000))]);

      expect(tester.takeException(), isNull);
      expect(find.text('Every rupee is accounted for.'), findsOneWidget);
    });

    testWidgets('names the gap rather than hiding it', (tester) async {
      // 50,000 short of what the four lines above it come to.
      await inAList(tester, [BalanceCheck(money: summary(cash: 650000))]);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('50,000'), findsOneWidget);
      expect(find.text('Every rupee is accounted for.'), findsNothing);
    });
  });

  group('a card survives a page with no bottom to it', () {
    testWidgets('a plain card draws its content', (tester) async {
      await inAList(tester, const [RegCard(child: Text('Cash in hand'))]);

      expect(tester.takeException(), isNull);
      expect(find.text('Cash in hand'), findsOneWidget);
    });

    testWidgets('a striped card draws its content and its stripe', (
      tester,
    ) async {
      await inAList(tester, [
        RegCard(stripe: T.moneyIn, child: Text('Delivered')),
      ]);

      expect(tester.takeException(), isNull);
      expect(find.text('Delivered'), findsOneWidget);
      expect(find.byType(ColoredBox), findsWidgets);
    });

    testWidgets('a card does not stop the ones after it', (tester) async {
      await inAList(tester, [
        RegCard(child: Text('First')),
        RegCard(stripe: T.moneyDue, child: Text('Second')),
        Text('After the cards'),
      ]);

      expect(tester.takeException(), isNull);
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('After the cards'), findsOneWidget);
    });

    testWidgets('a tall card grows to its content', (tester) async {
      await inAList(tester, [
        RegCard(
          stripe: T.moneyOut,
          child: Column(
            children: [for (var i = 0; i < 12; i++) Text('Line $i')],
          ),
        ),
      ]);

      expect(tester.takeException(), isNull);
      expect(find.text('Line 11'), findsOneWidget);
      // Taller than one line, which is what the stripe has to run down.
      expect(tester.getSize(find.byType(RegCard)).height, greaterThan(200));
    });
  });

  group('the rest of the page furniture', () {
    testWidgets('the headline figure and the tiles under it', (tester) async {
      await inAList(tester, [
        HeroCard(
          label: 'Cash in hand',
          value: 'Rs 6,12,400',
          note: 'Everything the farm can spend today.',
        ),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Sales',
                value: 'Rs 4,45,120',
                tone: T.moneyIn,
                note: 'Sep 2026',
              ),
            ),
            Expanded(
              child: StatTile(
                label: 'To pay',
                value: 'Rs 72,500',
                tone: T.moneyDue,
              ),
            ),
          ],
        ),
      ]);

      expect(tester.takeException(), isNull);
      expect(find.text('Rs 6,12,400'), findsOneWidget);
      expect(find.text('Rs 4,45,120'), findsOneWidget);
    });

    testWidgets('the grid of things to go and do', (tester) async {
      await inAList(tester, [
        ActionGrid(
          tiles: [
            ActionTile(icon: Icons.add, label: 'New entry', tone: T.accent600),
            ActionTile(icon: Icons.pets, label: 'Cattle', tone: T.accent500),
            ActionTile(
              icon: Icons.bar_chart,
              label: 'Report',
              tone: T.moneyIn,
              badge: 3,
            ),
          ],
        ),
      ]);

      expect(tester.takeException(), isNull);
      expect(find.text('New entry'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('a switch that cannot be used says why', (tester) async {
      await inAList(tester, [
        SwitchRow(
          title: "The rider's work",
          note: 'Round, spot sale, handover, collection',
          value: false,
          enabled: false,
          why: 'Online orders and khaata are both off.',
          onChanged: (_) {},
        ),
      ]);

      expect(tester.takeException(), isNull);
      expect(
        find.text('Online orders and khaata are both off.'),
        findsOneWidget,
      );
    });

    testWidgets('the farm draws its own animal', (tester) async {
      // Material has no cattle, so this one is painted. If it ever stops
      // drawing, the tile beside "Cattle" would quietly go empty.
      await inAList(tester, const [
        ActionGrid(
          tiles: [
            ActionTile(
              drawn: CattleIcon(size: 22, color: Color(0xFF6544B0)),
              label: 'Cattle',
              tone: Color(0xFF6544B0),
            ),
          ],
        ),
      ]);

      expect(tester.takeException(), isNull);
      expect(find.byType(CattleIcon), findsOneWidget);
      expect(tester.getSize(find.byType(CattleIcon)), const Size(22, 22));
    });

    testWidgets('the day chart draws inside a page', (tester) async {
      // Bars are sized against the tallest day, so an unbounded page is where
      // this would go wrong — the same way the cards once did.
      await inAList(tester, [
        DayChart(
          days: [
            DayTotals(DateTime(2026, 9, 12), 16000, 4000, byWeek: false),
            DayTotals(DateTime(2026, 9, 13), 0, 0, byWeek: false),
            DayTotals(DateTime(2026, 9, 14), 22000, 40000, byWeek: false),
          ],
        ),
      ]);

      expect(tester.takeException(), isNull);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
    });

    testWidgets('a day chart with nothing in it still draws', (tester) async {
      await inAList(tester, const [DayChart(days: [])]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('money is written in the colour of its state', (tester) async {
      await inAList(tester, const [
        Money(14200, incoming: true, settled: false),
        Money(14200, incoming: true, settled: true),
      ]);

      expect(tester.takeException(), isNull);

      final texts = tester.widgetList<Text>(find.byType(Text)).toList();
      expect(texts.first.style!.color, T.moneyGet);
      expect(texts.last.style!.color, T.moneyIn);
    });
  });

  group('the day an entry is for', () {
    testWidgets('opens on today and says so', (tester) async {
      final today = DateTime.now();
      await inAList(tester, [
        DayPicker(
          day: today,
          isToday: true,
          floor: DateTime(today.year, today.month),
          period: 'October 2026',
          onPick: () {},
          onToday: () {},
        ),
      ]);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('today'), findsWidgets);
      expect(find.text('Change'), findsOneWidget);
      // Nothing to go back to while it is already today.
      expect(find.text('Back to today'), findsNothing);
    });

    testWidgets('a day gone by says what will happen and offers the way '
        'back', (tester) async {
      await inAList(tester, [
        DayPicker(
          day: DateTime(2026, 10, 11),
          isToday: false,
          floor: DateTime(2026, 9, 25),
          period: 'October 2026',
          onPick: () {},
          onToday: () {},
        ),
      ]);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('not today'), findsOneWidget);
      expect(find.text('Back to today'), findsOneWidget);
      // Which period it lands in, which is the thing back-dating must not
      // move and so the thing the form has to say out loud.
      expect(find.textContaining('October 2026'), findsOneWidget);
    });
  });

  group('a picture opened out', () {
    testWidgets('fills the screen, and closes again', (tester) async {
      // Every photo in the app was a thumbnail and nothing more. The register
      // exists so one black buffalo can be told from the next, and at a
      // hundred pixels it cannot.
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showFarmPhoto(context, title: 'B-05 Kaali'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('B-05 Kaali'), findsOneWidget);
      // Pinch to go closer — the marks that identify an animal are small.
      expect(find.byType(InteractiveViewer), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('B-05 Kaali'), findsNothing);
    });
  });

  group('the month-by-month columns', () {
    FarmMonth done(String id, {num sales = 0, num profit = 0}) => FarmMonth(
      id: id,
      status: 'closed',
      openingCash: 0,
      sales: sales,
      profit: profit,
    );

    Books books({num sales = 0}) => Books(
      monthId: '2026-10',
      openingCash: 0,
      capital: 0,
      monthTxns: const [],
      unpaidTxns: const [],
    );

    final open = FarmMonth(id: '2026-10', status: 'open', openingCash: 0);

    test('settled periods oldest first, with the open one last', () {
      // Read left to right the way a year is read, and the period still
      // being written is the one on the right.
      final bars = periodBars(
        [done('2026-09'), done('2026-07'), done('2026-08')],
        open: open,
        books: books(),
        shortName: (id) => id,
      );
      expect(bars.map((b) => b.id), [
        '2026-07',
        '2026-08',
        '2026-09',
        '2026-10',
      ]);
      expect(bars.last.isOpen, isTrue);
      expect(bars.where((b) => b.isOpen).length, 1);
    });

    test('a settled period keeps the figures frozen into it', () {
      // Never worked out again. That is the whole point of freezing them:
      // a closed month is what four people were paid out of.
      final bars = periodBars(
        [done('2026-09', sales: 900000, profit: 92000)],
        open: open,
        books: books(),
        shortName: (id) => id,
      );
      expect(bars.first.sales, 900000);
      expect(bars.first.profit, 92000);
      expect(bars.first.costs, 808000, reason: 'sales less profit');
    });

    test('only the last few fit on a phone', () {
      final bars = periodBars(
        [for (var m = 1; m <= 9; m++) done('2026-0$m')],
        open: open,
        books: books(),
        shortName: (id) => id,
        last: 6,
      );
      expect(bars.length, 6);
      expect(bars.first.id, '2026-05', reason: 'the oldest ones drop off');
      expect(bars.last.id, '2026-10');
    });

    test('a farm that has never closed a month still has a column', () {
      final bars = periodBars(
        const [],
        open: open,
        books: books(),
        shortName: (id) => id,
      );
      expect(bars.single.isOpen, isTrue);
    });
  });

  group('the dashboard charts draw inside a page', () {
    testWidgets('the months, with nothing in them', (tester) async {
      await inAList(tester, [const MonthChart(bars: [])]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('and with six periods in them', (tester) async {
      await inAList(tester, [
        MonthChart(
          bars: [
            for (var m = 5; m <= 9; m++)
              PeriodBar(
                id: '2026-0$m',
                label: 'M$m',
                sales: 100000 * m,
                costs: 60000 * m,
                profit: 40000 * m,
                isOpen: false,
              ),
            const PeriodBar(
              id: '2026-10',
              label: 'Oct',
              sales: 120000,
              costs: 90000,
              profit: 30000,
              isOpen: true,
            ),
          ],
        ),
      ]);
      expect(tester.takeException(), isNull);
      expect(find.text('Oct'), findsOneWidget);
      // The one still running says so rather than showing half a month's
      // profit as though it were a month's.
      expect(find.text('so far'), findsOneWidget);
    });

    testWidgets('a loss is drawn and said in red', (tester) async {
      await inAList(tester, [
        const MonthChart(
          bars: [
            PeriodBar(
              id: '2026-07',
              label: 'Jul',
              sales: 400000,
              costs: 419000,
              profit: -19000,
              isOpen: false,
            ),
          ],
        ),
      ]);
      expect(tester.takeException(), isNull);
      expect(find.text('−19k'), findsOneWidget);
    });

    testWidgets('what the farm is worth, split by where it sits', (
      tester,
    ) async {
      await inAList(tester, [
        const WorthBar(
          money: MoneySummary(
            capital: 2000000,
            assets: 1700000,
            runningCosts: 0,
            sales: 0,
            cash: 440700,
            receivable: 224000,
            payable: 118000,
          ),
        ),
      ]);
      expect(tester.takeException(), isNull);
      expect(find.text('Rs 22,46,700'), findsOneWidget);
    });

    testWidgets('and a farm with nothing in it still draws', (tester) async {
      await inAList(tester, [
        const WorthBar(
          money: MoneySummary(
            capital: 0,
            assets: 0,
            runningCosts: 0,
            sales: 0,
            cash: 0,
            receivable: 0,
            payable: 0,
          ),
        ),
      ]);
      expect(tester.takeException(), isNull);
    });
  });

  group('a figure small enough to sit under a column', () {
    test('thousands and lakhs, the way the farm says them', () {
      expect(shortRs(92000), '92k');
      expect(shortRs(1700000), '17L');
      expect(shortRs(240000), '2.4L');
      expect(shortRs(9500), '9.5k');
    });

    test('under a thousand is written whole', () {
      // Rounding a hundred and twenty rupees to 0k is worse than saying
      // nothing at all.
      expect(shortRs(120), '120');
      expect(shortRs(0), '0');
    });

    test('a loss carries its sign whether asked or not', () {
      expect(shortRs(-19000), '−19k');
      expect(shortRs(-19000, signed: true), '−19k');
      expect(shortRs(19000, signed: true), '+19k');
      expect(shortRs(19000), '19k');
    });
  });
}
