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

  /// Nothing is wider than the page it is on.
  ///
  /// Not "no exception at all": a headless run has no asset bundle, so the
  /// farm's mark cannot load and says so, and that is neither here nor there
  /// when the question is whether a column fits. An overflow is the thing
  /// being asked about and an overflow fails.
  void expectItFits(WidgetTester tester) {
    final e = tester.takeException();
    if (e == null) return;
    final what = e.toString();
    expect(
      what.contains('overflowed'),
      isFalse,
      reason: 'something is wider than the page — $what',
    );
    expect(
      what.contains('Unable to load asset'),
      isTrue,
      reason: 'an exception that is not about the missing mark — $what',
    );
  }

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
      expectItFits(tester);
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
      expectItFits(tester);
      expect(find.text('12,50,000'), findsWidgets);
    });
  });
}
