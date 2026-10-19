import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';

/// Cash passing between two pairs of hands, with the other man's word on it.
///
/// The farm already had a way to write this down and it took one man's word
/// for both halves. That is the one place in a book kept by four friends
/// where one word will not do — the whole reason the figure exists is so that
/// nobody has to take anybody's word for what he is holding.
///
/// In between it belongs to neither of them: out of the sender's hands and
/// not yet in the receiver's. The farm's own cash never moves through any of
/// it, because the rupees are the farm's wherever they are sitting.

var _n = 0;

CashTransfer _sent({
  required String from,
  required String to,
  required num amount,
  TransferState state = TransferState.waiting,
}) => CashTransfer(
  id: 't${_n++}',
  from: from,
  to: to,
  amount: amount,
  state: state,
  sentAt: DateTime(2026, 10, 18, 16),
);

Txn _milk({required String handledBy, num amount = 38000}) => Txn(
  id: 'm${_n++}',
  date: DateTime(2026, 10, 18),
  monthId: '2026-10',
  type: TxnType.receipt,
  party: 'Urooj Dairy Shop',
  category: khaataReceiptCategory,
  amount: amount,
  paid: true,
  paidOnCreate: true,
  settlesTxnId: 'x',
  handledBy: handledBy,
  note: '',
  createdBy: 'u1',
  createdAt: DateTime(2026, 10, 18),
);

void main() {
  group('money on its way', () {
    final collected = _milk(handledBy: 'Jalbani');

    test('it leaves the sender the moment he says he handed it over', () {
      // He has given it away. Leaving it on his balance would have the farm
      // asking him for money that is in somebody else's pocket.
      final moving = [_sent(from: 'Jalbani', to: 'Rafeeq', amount: 20000)];
      final hands = {
        for (final h in cashInHands([collected], moving: moving)) h.who: h,
      };
      expect(hands['Jalbani']!.holding, 18000);
      expect(hands['Jalbani']!.onItsWay, 20000);
    });

    test('and does not reach the other man until he says it did', () {
      // A man is answerable for money when he says he has it, not when
      // somebody says they sent it.
      final moving = [_sent(from: 'Jalbani', to: 'Rafeeq', amount: 20000)];
      final hands = {
        for (final h in cashInHands([collected], moving: moving)) h.who: h,
      };
      expect(hands['Rafeeq']!.holding, 0);
      expect(hands['Rafeeq']!.coming, 20000);
    });

    test('so in between it is in neither pair of hands', () {
      final moving = [_sent(from: 'Jalbani', to: 'Rafeeq', amount: 20000)];
      final held = cashInHands([
        collected,
      ], moving: moving).fold<num>(0, (a, h) => a + h.holding);
      expect(held, 18000, reason: 'the other twenty are on their way');
      expect(held + 20000, 38000, reason: 'and nothing is lost');
    });

    test('once taken it is on the books and no longer waiting', () {
      // The pair of rows the ledger has always used for this. What was in
      // transit is now simply his.
      final handedOver = Txn(
        id: 'out',
        date: DateTime(2026, 10, 18),
        monthId: '2026-10',
        type: TxnType.payment,
        party: 'Rafeeq',
        category: handoverOutCategory,
        amount: 20000,
        paid: true,
        paidOnCreate: true,
        handledBy: 'Jalbani',
        note: '',
        createdBy: 'u1',
        createdAt: DateTime(2026, 10, 18),
      );
      final takenIn = Txn(
        id: 'in',
        date: DateTime(2026, 10, 18),
        monthId: '2026-10',
        type: TxnType.receipt,
        party: 'Jalbani',
        category: handoverInCategory,
        amount: 20000,
        paid: true,
        paidOnCreate: true,
        handledBy: 'Rafeeq',
        note: '',
        createdBy: 'u1',
        createdAt: DateTime(2026, 10, 18),
      );

      final moving = [
        _sent(
          from: 'Jalbani',
          to: 'Rafeeq',
          amount: 20000,
          state: TransferState.taken,
        ),
      ];
      final hands = {
        for (final h in cashInHands([
          collected,
          handedOver,
          takenIn,
        ], moving: moving))
          h.who: h,
      };
      expect(hands['Jalbani']!.holding, 18000);
      expect(hands['Jalbani']!.onItsWay, 0, reason: 'nothing is waiting now');
      expect(hands['Rafeeq']!.holding, 20000);
      expect(hands['Rafeeq']!.coming, 0);
    });

    test('a refusal leaves the money exactly where it was', () {
      // Nothing was written to the books, so there is nothing to undo.
      final moving = [
        _sent(
          from: 'Jalbani',
          to: 'Rafeeq',
          amount: 20000,
          state: TransferState.refused,
        ),
      ];
      final hands = {
        for (final h in cashInHands([collected], moving: moving)) h.who: h,
      };
      expect(hands['Jalbani']!.holding, 38000);
      expect(hands['Jalbani']!.onItsWay, 0);
    });

    test('the farm has the same money throughout', () {
      // Sent, waiting, taken — the rupees are the farm's wherever they are
      // sitting, and none of this touches the books until the end.
      Books books(List<Txn> rows) => Books(
        monthId: '2026-10',
        openingCash: 0,
        capital: 0,
        monthTxns: rows,
        unpaidTxns: const [],
      );
      expect(books([collected]).cash, 38000);

      final pair = [
        Txn(
          id: 'out',
          date: DateTime(2026, 10, 18),
          monthId: '2026-10',
          type: TxnType.payment,
          party: 'Rafeeq',
          category: handoverOutCategory,
          amount: 20000,
          paid: true,
          paidOnCreate: true,
          note: '',
          createdBy: 'u1',
          createdAt: DateTime(2026, 10, 18),
        ),
        Txn(
          id: 'in',
          date: DateTime(2026, 10, 18),
          monthId: '2026-10',
          type: TxnType.receipt,
          party: 'Jalbani',
          category: handoverInCategory,
          amount: 20000,
          paid: true,
          paidOnCreate: true,
          note: '',
          createdBy: 'u1',
          createdAt: DateTime(2026, 10, 18),
        ),
      ];
      expect(books([collected, ...pair]).cash, 38000);
      expect(books([collected, ...pair]).profit, 0);
    });
  });

  group('who is being asked', () {
    test('what is waiting on one man, oldest first', () {
      // The farm should be asked about the one that has been sitting
      // longest, because that is the one somebody has forgotten.
      final old = CashTransfer(
        id: 'old',
        from: 'Jalbani',
        to: 'Rafeeq',
        amount: 5000,
        state: TransferState.waiting,
        sentAt: DateTime(2026, 10, 10),
      );
      final recent = CashTransfer(
        id: 'recent',
        from: 'Saleem',
        to: 'Rafeeq',
        amount: 9000,
        state: TransferState.waiting,
        sentAt: DateTime(2026, 10, 18),
      );
      final other = CashTransfer(
        id: 'other',
        from: 'Rafeeq',
        to: 'Jalbani',
        amount: 1000,
        state: TransferState.waiting,
        sentAt: DateTime(2026, 10, 11),
      );

      final mine = waitingFor([recent, old, other], 'Rafeeq');
      expect(mine.map((t) => t.id), ['old', 'recent']);
    });

    test('and nothing that has already been answered', () {
      final done = CashTransfer(
        id: 'done',
        from: 'Jalbani',
        to: 'Rafeeq',
        amount: 5000,
        state: TransferState.taken,
        sentAt: DateTime(2026, 10, 10),
      );
      expect(waitingFor([done], 'Rafeeq'), isEmpty);
    });

    test('spelling his name two ways does not hide it from him', () {
      final sent = CashTransfer(
        id: 'x',
        from: 'Jalbani',
        to: 'rafeeq ',
        amount: 5000,
        state: TransferState.waiting,
        sentAt: DateTime(2026, 10, 10),
      );
      expect(waitingFor([sent], 'Rafeeq').single.id, 'x');
      expect(comingTo([sent], 'RAFEEQ'), 5000);
    });
  });
}
