import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';

/// One handful of money, drawn once.
///
/// Babar Dairy owed 90,200 across thirty-eight unpaid days and handed over
/// 43,000. The books wrote a receipt against each day the money reached,
/// which is right — a month later the question is which days he has paid
/// for. But on the day the question is the other one, what did he hand
/// over, and the ledger could not answer it at all: twenty-three rows,
/// none of them 43,000, and no way to take the payment back off except one
/// row at a time. The farm tried exactly that, could not get back to where
/// it had started, and deleted six real sales in the attempt.
///
/// So every receipt one payment writes carries that payment's own id. The
/// ledger draws the handful once, with the whole figure on it, and the days
/// sit behind it. Every row is still on the books and every balance is
/// still worked out from all of them — this only says which ones not to
/// draw a second time.

var _n = 0;

Txn _receipt({
  required num amount,
  required String takeId,
  required int day,
  String party = 'Babar Dairy',
  bool deleted = false,
}) => Txn(
  id: 'r${_n++}',
  date: DateTime(2026, 10, day),
  monthId: '2026-10',
  type: TxnType.receipt,
  party: party,
  category: khaataReceiptCategory,
  amount: amount,
  paid: true,
  paidOnCreate: true,
  settlesTxnId: 'sale-$_n',
  takeId: takeId,
  note: '',
  createdBy: 'u1',
  createdAt: DateTime(2026, 10, day),
  deletedAt: deleted ? DateTime(2026, 10, 31) : null,
);

void main() {
  group('the handful is drawn once', () {
    test('five receipts of one payment leave one row standing', () {
      final rows = [
        _receipt(amount: 1600, takeId: 't1', day: 30),
        _receipt(amount: 1600, takeId: 't1', day: 30),
        _receipt(amount: 1800, takeId: 't1', day: 30),
        _receipt(amount: 1600, takeId: 't1', day: 30),
        _receipt(amount: 1800, takeId: 't1', day: 30),
      ];

      final behind = rowsBehindATake(rows);
      expect(behind, hasLength(4));
      expect(
        rows.where((r) => !behind.contains(r.id)),
        hasLength(1),
        reason: 'one handful, one line',
      );
    });

    test('and that row carries the whole of it', () {
      final rows = [
        _receipt(amount: 1600, takeId: 't1', day: 30),
        _receipt(amount: 1800, takeId: 't1', day: 30),
        _receipt(amount: 2000, takeId: 't1', day: 30),
      ];
      final take = theTake(rows, 't1');
      expect(take.amount, 5400);
      expect(take.rows, 3);
    });

    test('two payments on one day stay two lines', () {
      // He paid in the morning and again in the evening. Two handfuls,
      // and both deserve their line.
      final rows = [
        _receipt(amount: 1600, takeId: 't1', day: 30),
        _receipt(amount: 1600, takeId: 't1', day: 30),
        _receipt(amount: 2000, takeId: 't2', day: 30),
      ];
      final behind = rowsBehindATake(rows);
      expect(rows.where((r) => !behind.contains(r.id)), hasLength(2));
      expect(theTake(rows, 't1').amount, 3200);
      expect(theTake(rows, 't2').amount, 2000);
    });

    test('a single receipt is its own line and says nothing extra', () {
      final rows = [_receipt(amount: 1600, takeId: 't1', day: 30)];
      expect(rowsBehindATake(rows), isEmpty);
      expect(theTake(rows, 't1').rows, 1);
    });

    test('a receipt from before any of this is left alone', () {
      // Every row written before the payment carried an id of its own.
      // They have none, so nothing is hidden behind anything.
      final old = Txn(
        id: 'old',
        date: DateTime(2026, 10, 12),
        monthId: '2026-10',
        type: TxnType.receipt,
        party: 'Urooj Dairy Shop',
        category: khaataReceiptCategory,
        amount: 2000,
        paid: true,
        paidOnCreate: true,
        settlesTxnId: 'sale-old',
        note: '',
        createdBy: 'u1',
        createdAt: DateTime(2026, 10, 12),
      );
      expect(old.isPartOfATake, isFalse);
      expect(rowsBehindATake([old]), isEmpty);
    });
  });

  group('what is deleted is not counted or drawn', () {
    test('a deleted row is not part of the handful any more', () {
      final rows = [
        _receipt(amount: 1600, takeId: 't1', day: 30),
        _receipt(amount: 1800, takeId: 't1', day: 30, deleted: true),
      ];
      expect(theTake(rows, 't1').amount, 1600);
      expect(theTake(rows, 't1').rows, 1);
    });

    test('and the one still standing becomes the line', () {
      final rows = [
        _receipt(amount: 1600, takeId: 't1', day: 30, deleted: true),
        _receipt(amount: 1800, takeId: 't1', day: 30),
      ];
      final behind = rowsBehindATake(rows);
      final drawn = rows.where((r) => !r.isDeleted && !behind.contains(r.id));
      expect(drawn, hasLength(1));
      expect(drawn.single.amount, 1800);
    });

    test('the whole handful gone draws nothing at all', () {
      final rows = [
        _receipt(amount: 1600, takeId: 't1', day: 30, deleted: true),
        _receipt(amount: 1800, takeId: 't1', day: 30, deleted: true),
      ];
      expect(theTake(rows, 't1').amount, 0);
      expect(
        rows.where(
          (r) => !r.isDeleted && !rowsBehindATake(rows).contains(r.id),
        ),
        isEmpty,
      );
    });
  });

  group('the farm\'s own payment', () {
    test('43,000 reads as 43,000, which no row ever did', () {
      // Spread over the oldest days, as it was. The figures are the
      // farm's own: the six days of 9 to 11 October it went on to delete,
      // and enough of what followed to come to the handful.
      final rows = [
        _receipt(amount: 1600, takeId: 't1', day: 30),
        _receipt(amount: 1600, takeId: 't1', day: 30),
        _receipt(amount: 1800, takeId: 't1', day: 30),
        _receipt(amount: 1600, takeId: 't1', day: 30),
        _receipt(amount: 1800, takeId: 't1', day: 30),
        _receipt(amount: 2000, takeId: 't1', day: 30),
        _receipt(amount: 32600, takeId: 't1', day: 30),
      ];

      expect(theTake(rows, 't1').amount, 43000);
      expect(theTake(rows, 't1').rows, 7);
      expect(
        rows.where((r) => !rowsBehindATake(rows).contains(r.id)),
        hasLength(1),
        reason: 'one line, and it says 43,000',
      );
    });
  });
}
