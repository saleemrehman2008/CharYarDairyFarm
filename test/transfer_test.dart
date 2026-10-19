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

  group('picking the entries a handover is made of', () {
    /// A figure in a box says how much moved. The farm wanted to say which
    /// money it was: Ghulam Ali took four payments from Urooj at the gate,
    /// and handing 8,600 to the farm account should be able to name those
    /// four rather than 8,600 of an indistinguishable pile.
    ///
    /// Once named they are spoken for, so the same thousand rupees cannot be
    /// handed over twice, and each entry can say on its own face where the
    /// money went.

    Txn receipt(num amount, String by, int day) => Txn(
      id: 'r${_n++}',
      date: DateTime(2026, 10, day),
      monthId: '2026-10',
      type: TxnType.receipt,
      party: 'Urooj Dairy Shop',
      category: khaataReceiptCategory,
      amount: amount,
      paid: true,
      paidOnCreate: true,
      handledBy: by,
      note: '',
      createdBy: 'u1',
      createdAt: DateTime(2026, 10, day),
    );

    Txn bill(num amount, String by, int day) => Txn(
      id: 'b${_n++}',
      date: DateTime(2026, 10, day),
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
      createdAt: DateTime(2026, 10, day),
    );

    CashTransfer move({
      required String from,
      required String to,
      required num amount,
      required List<String> ids,
      TransferState state = TransferState.waiting,
    }) => CashTransfer(
      id: 'm${ids.join()}',
      from: from,
      to: to,
      amount: amount,
      state: state,
      sentAt: DateTime(2026, 10, 12),
      txnIds: ids,
    );

    final urooj = [
      receipt(1000, 'Ghulam Ali', 12),
      receipt(2000, 'Ghulam Ali', 12),
      receipt(2000, 'Ghulam Ali', 12),
      receipt(3600, 'Ghulam Ali', 7),
    ];

    test('what a man took in, latest first and only his', () {
      final rows = inHand(
        [...urooj, receipt(5000, 'Rafeeq', 11)],
        who: 'Ghulam Ali',
        incoming: true,
      );

      expect(rows.length, 4);
      expect(rows.fold<num>(0, (a, r) => a + r.amount), 8600);
      expect(rows.first.date.day, 12, reason: 'latest first');
      expect(rows.last.amount, 3600, reason: 'the 7 Oct one is oldest');
      expect(rows.every((r) => r.incoming), isTrue);
    });

    test('the picked entries add up to the figure handed over', () {
      final rows = inHand(urooj, who: 'Ghulam Ali', incoming: true);
      final picked = {rows[0].txnId, rows[1].txnId};
      final sum = rows
          .where((r) => picked.contains(r.txnId))
          .fold<num>(0, (a, r) => a + r.amount);
      expect(sum, rows[0].amount + rows[1].amount);
    });

    test('an entry already handed over is not offered again', () {
      final gone = move(
        from: 'Ghulam Ali',
        to: farmAccountName,
        amount: 3600,
        ids: [urooj.last.id],
        state: TransferState.taken,
      );
      final rows = inHand(
        urooj,
        who: 'Ghulam Ali',
        incoming: true,
        moving: [gone],
      );
      expect(rows.where((r) => r.isSpokenFor).single.amount, 3600);
      expect(
        rows.where((r) => r.isSpokenFor).single.handedOnTo,
        'Farm account',
      );
      expect(rows.where((r) => !r.isSpokenFor).length, 3);
    });

    test('one refused gives its entries back', () {
      // Nothing moved, so the money is still sitting where it was and is
      // still his to hand over.
      final said = move(
        from: 'Ghulam Ali',
        to: 'Rafeeq',
        amount: 3600,
        ids: [urooj.last.id],
        state: TransferState.refused,
      );
      final rows = inHand(
        urooj,
        who: 'Ghulam Ali',
        incoming: true,
        moving: [said],
      );
      expect(rows.any((r) => r.isSpokenFor), isFalse);
    });

    test('an entry can say where its money went', () {
      final gone = move(
        from: 'Ghulam Ali',
        to: farmAccountName,
        amount: 3600,
        ids: [urooj.last.id],
        state: TransferState.taken,
      );
      expect(handoverOf([gone], urooj.last.id)?.to, farmAccountName);
      expect(handoverOf([gone], urooj.first.id), isNull);
    });

    test('what a man paid for himself, latest first and only his', () {
      // The other side of it: Saleem is out of pocket, and the farm wanted
      // to see which entries those are without settling them here.
      final rows = inHand(
        [
          bill(2700, 'Saleem', 15),
          bill(400, 'Saleem', 9),
          bill(9000, 'Rafeeq', 14),
        ],
        who: 'Saleem',
        incoming: false,
      );

      expect(rows.map((r) => r.amount).toList(), [2700, 400]);
      expect(rows.every((r) => !r.incoming), isTrue);
    });

    test('a split entry shows each payer only his own share', () {
      final cows = bill(1700000, 'Ghulam Ali', 5);
      final asifPaid = Contribution(
        id: 'c-asif',
        partnerId: 'p-asif',
        partnerName: 'Asif',
        kind: ContributionKind.investment,
        source: ContributionSource.spent,
        amount: 500000,
        date: DateTime(2026, 10, 5),
        txnId: cows.id,
        createdAt: DateTime(2026, 10, 5),
      );

      expect(
        inHand(
          [cows],
          who: 'Asif',
          incoming: false,
          putIn: [asifPaid],
        ).single.amount,
        500000,
      );
      expect(
        inHand(
          [cows],
          who: 'Ghulam Ali',
          incoming: false,
          putIn: [asifPaid],
        ).single.amount,
        1200000,
        reason: 'what is left on the entry belongs to the name on it',
      );
    });

    test('a handover row is not itself money he is holding', () {
      // Offering it back would let the same rupees go over twice.
      final handed = Txn(
        id: 'h1',
        date: DateTime(2026, 10, 12),
        monthId: '2026-10',
        type: TxnType.payment,
        party: farmAccountName,
        category: handoverOutCategory,
        amount: 8600,
        paid: true,
        paidOnCreate: true,
        handledBy: 'Ghulam Ali',
        note: '',
        createdBy: 'u1',
        createdAt: DateTime(2026, 10, 12),
      );
      final rows = inHand(
        [...urooj, handed],
        who: 'Ghulam Ali',
        incoming: false,
      );
      expect(rows, isEmpty);
    });
  });
}
