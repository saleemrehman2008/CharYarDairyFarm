import 'package:char_yar_dairy_farm/theme/tokens.dart';
import 'package:char_yar_dairy_farm/widgets/farm_icons.dart';
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
          home: Scaffold(body: ListView(children: children)),
        ),
      );

  group('a card survives a page with no bottom to it', () {
    testWidgets('a plain card draws its content', (tester) async {
      await inAList(tester, const [RegCard(child: Text('Cash in hand'))]);

      expect(tester.takeException(), isNull);
      expect(find.text('Cash in hand'), findsOneWidget);
    });

    testWidgets('a striped card draws its content and its stripe', (
      tester,
    ) async {
      await inAList(tester, const [
        RegCard(stripe: T.moneyIn, child: Text('Delivered')),
      ]);

      expect(tester.takeException(), isNull);
      expect(find.text('Delivered'), findsOneWidget);
      expect(find.byType(ColoredBox), findsWidgets);
    });

    testWidgets('a card does not stop the ones after it', (tester) async {
      await inAList(tester, const [
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
      await inAList(tester, const [
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
      await inAList(tester, const [
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
}
