import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/screens/shared/statement_screen.dart';
import 'package:char_yar_dairy_farm/services/statement.dart';
import 'package:char_yar_dairy_farm/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The statement, on the narrowest phone anybody is going to hold.
///
/// It was laid out as a grid five hundred and eighty pixels wide inside a
/// sideways scroll. On a 360-wide phone that put the credit and the balance
/// off the right-hand edge — and a picture of the page was cut at the same
/// place, because a photograph of a scrolling box catches only what is on
/// screen. The figure down the right is the whole point of a statement, and
/// it was the part nobody could see.
///
/// So: no sideways scroll, and every column on the page at 360.

var _n = 0;

Txn _txn({
  required TxnType type,
  required num amount,
  required String party,
  required int day,
  String category = 'Milk',
  bool paid = true,
  String? settles,
}) => Txn(
  id: 's${_n++}',
  date: DateTime(2026, 9, day),
  monthId: '2026-09',
  type: type,
  party: party,
  category: category,
  qty: type == TxnType.sale ? 80 : null,
  unit: type == TxnType.sale ? 'L' : null,
  rate: type == TxnType.sale ? amount / 80 : null,
  amount: amount,
  paid: paid,
  paidOnCreate: paid,
  settlesTxnId: settles,
  note: '',
  createdBy: 'u',
  createdByName: 'Saleem Rehman',
  createdAt: DateTime(2026, 9, day),
);

void main() {
  // Ali's real week: milk on credit twice a day, part of it settled, and the
  // biggest figures the farm is likely to print.
  final sale = _txn(
    type: TxnType.sale,
    amount: 16000,
    party: 'Ali',
    day: 20,
    paid: false,
  );
  final rows = [
    sale,
    _txn(type: TxnType.sale, amount: 16000, party: 'Ali', day: 20, paid: false),
    _txn(
      type: TxnType.receipt,
      amount: 14000,
      party: 'Ali',
      day: 21,
      category: 'Khaata receipt',
      settles: sale.id,
    ),
    _txn(
      type: TxnType.purchase,
      amount: 1250000,
      party: 'Mandi',
      day: 22,
      category: 'Cattle purchase',
    ),
  ];

  Future<void> onAPhone(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: Scaffold(
          backgroundColor: T.bg,
          body: ListView(padding: const EdgeInsets.all(16), children: [child]),
        ),
      ),
    );
  }

  group('the whole page on a 360-wide phone', () {
    testWidgets('nothing runs off the edge', (tester) async {
      await onAPhone(
        tester,
        StatementSheet(
          statement: buildStatement(rows: rows, party: 'Ali'),
          farmName: 'Char Yar Dairy Farm',
          forWhom: 'Ali',
          period: 'Everything, from the start',
          advanceHeld: 0,
        ),
      );
      // A Row wider than it is allowed to be throws in a test run, so
      // reaching here without an exception is most of the claim.
      expect(tester.takeException(), isNull);
    });

    testWidgets('all three money columns are on the page', (tester) async {
      await onAPhone(
        tester,
        StatementSheet(
          statement: buildStatement(rows: rows, party: 'Ali'),
          farmName: 'Char Yar Dairy Farm',
          forWhom: 'Ali',
          period: 'Everything, from the start',
          advanceHeld: 0,
        ),
      );

      for (final head in [
        'DATE',
        'PARTICULARS',
        'DEBIT',
        'CREDIT',
        'BALANCE',
      ]) {
        expect(
          find.text(head),
          findsOneWidget,
          reason: '$head is not on the page',
        );
      }

      final width = tester.view.physicalSize.width;
      for (final head in ['DEBIT', 'CREDIT', 'BALANCE']) {
        final box = tester.getRect(find.text(head));
        expect(
          box.right,
          lessThanOrEqualTo(width),
          reason: '$head is off the right-hand edge',
        );
      }
    });

    testWidgets('the running balance is drawn on every row', (tester) async {
      final s = buildStatement(rows: rows, party: 'Ali');
      await onAPhone(
        tester,
        StatementSheet(
          statement: s,
          farmName: 'Char Yar Dairy Farm',
          forWhom: 'Ali',
          period: 'Everything, from the start',
          advanceHeld: 0,
        ),
      );

      // 16,000 · 32,000 · 18,000 · 18,000 — the last because a buffalo paid
      // for at the mandi leaves Ali's account alone.
      expect(find.text('16,000'), findsWidgets);
      expect(find.text('32,000'), findsWidgets);
      expect(find.text('18,000'), findsWidgets);
      expect(s.closing, 18000);
    });

    testWidgets('a lakh with its commas still fits its column', (tester) async {
      await onAPhone(
        tester,
        StatementSheet(
          statement: buildStatement(rows: rows, capital: 2000000),
          farmName: 'Char Yar Dairy Farm',
          forWhom: 'The whole farm',
          period: 'Everything, from the start',
          advanceHeld: 0,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('12,50,000'), findsWidgets);
    });
  });
}
