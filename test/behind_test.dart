import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';

/// Every figure has to be able to say what it is made of.
///
/// The farm's own words, looking at its Co-founders page: Ghulam Ali has made
/// an entry, the card says the farm owes him three thousand three hundred and
/// fifty rupees, and pressing the figure does nothing. In the ledger every
/// row opens and tells you the whole story of itself; a total that will not
/// is a number one of four partners has to be *trusted* on, and trust is the
/// one thing these books exist to make unnecessary.
///
/// What the sheet behind a figure offers is [inHand] — the entries a man's
/// name is on, each with the id of the entry it came from so the sheet can
/// open it. These tests are about the one way that can fail quietly: a figure
/// above nothing with an empty list under it. A reader who presses a live
/// figure and is shown nothing learns only that the app will not say.

var _n = 0;

Txn _txn({
  required TxnType type,
  required String category,
  required num amount,
  required String handledBy,
  String party = 'Somebody',
  int day = 12,
}) => Txn(
  id: 'b${_n++}',
  date: DateTime(2026, 10, day),
  monthId: '2026-10',
  type: type,
  party: party,
  category: category,
  amount: amount,
  paid: true,
  paidOnCreate: true,
  handledBy: handledBy,
  note: '',
  createdBy: 'u1',
  createdAt: DateTime(2026, 10, day),
);

Txn _took(num amount, String by, {int day = 12}) => _txn(
  type: TxnType.receipt,
  category: khaataReceiptCategory,
  party: 'Urooj Dairy Shop',
  amount: amount,
  handledBy: by,
  day: day,
);

Txn _spent(num amount, String by, {int day = 13}) => _txn(
  type: TxnType.expense,
  category: 'Feed',
  party: 'Ghas Wala',
  amount: amount,
  handledBy: by,
  day: day,
);

List<Txn> _handover(num amount, String from, String to, {int day = 19}) => [
  _txn(
    type: TxnType.payment,
    category: handoverOutCategory,
    party: to,
    amount: amount,
    handledBy: from,
    day: day,
  ),
  _txn(
    type: TxnType.receipt,
    category: handoverInCategory,
    party: from,
    amount: amount,
    handledBy: to,
    day: day,
  ),
];

/// The two lists the sheet is built from, for one man.
({List<InHand> took, List<InHand> gave}) _behind(
  List<Txn> ledger,
  String who, {
  List<CashTransfer> moving = const [],
}) => (
  took: inHand(ledger, who: who, incoming: true, moving: moving),
  gave: inHand(ledger, who: who, incoming: false, moving: moving),
);

void main() {
  group('a live figure always has entries under it', () {
    test('a man out of pocket can see what he spent it on', () {
      // Ghulam Ali's own case, in miniature: he took farm money in at the
      // gate and paid more than that out on the farm's costs, so the card
      // says the farm owes him the difference.
      final ledger = [_took(10000, 'Ghulam Ali'), _spent(13350, 'Ghulam Ali')];

      final hands = cashInHands(
        ledger,
      ).where((h) => partyKey(h.who) == partyKey('Ghulam Ali')).single;
      expect(hands.outOfPocket, isTrue);
      expect(hands.holding, -3350);

      final rows = _behind(ledger, 'Ghulam Ali');
      expect(rows.gave, isNotEmpty, reason: 'the figure would open nothing');
      expect(rows.took, isNotEmpty);
    });

    test('and a man holding cash can see what he took in', () {
      final ledger = [_took(8600, 'Rafeeq'), _took(1400, 'Rafeeq', day: 14)];

      final hands = cashInHands(ledger).single;
      expect(hands.holding, 10000);
      expect(_behind(ledger, 'Rafeeq').took, hasLength(2));
    });

    test('every name on the card has something under it', () {
      // The guarantee the sheet rests on, said once: nobody reaches that
      // list without having handled a rupee, so nobody on it can press
      // their own figure and be shown an empty page.
      final ledger = [
        _took(8600, 'Rafeeq'),
        _spent(2000, 'Asif'),
        _took(5000, 'Ghulam Ali'),
        _spent(9000, 'Ghulam Ali', day: 15),
      ];

      for (final h in cashInHands(ledger)) {
        final rows = _behind(ledger, h.who);
        expect(
          [...rows.took, ...rows.gave],
          isNotEmpty,
          reason: '${h.who} is on the card with nothing behind the figure',
        );
      }
    });
  });

  group('what the sheet shows adds up to what it says it does', () {
    test('the rows it offers are the rows the figure was counted from', () {
      final ledger = [
        _took(8600, 'Rafeeq'),
        _took(1400, 'Rafeeq', day: 14),
        _spent(3000, 'Rafeeq', day: 15),
      ];

      final hands = cashInHands(ledger).single;
      final rows = _behind(ledger, 'Rafeeq');

      expect(rows.took.fold<num>(0, (a, r) => a + r.amount), hands.received);
      expect(rows.gave.fold<num>(0, (a, r) => a + r.amount), hands.paid);
    });

    test('a handover is neither side of it, so it is listed once or never', () {
      // The money Rafeeq passed to the farm is not a thing he is holding and
      // not a cost he paid — it is the act of passing it on. Counted on
      // either list the same rupees could be handed over twice.
      final ledger = [
        _took(8600, 'Rafeeq'),
        ..._handover(8600, 'Rafeeq', farmAccountName),
      ];

      final rows = _behind(ledger, 'Rafeeq');
      expect(rows.took, hasLength(1));
      expect(rows.took.single.amount, 8600);
      expect(rows.gave, isEmpty);

      // And the farm's own account shows the arrival as its own, not as a
      // second copy of Rafeeq's receipt.
      expect(_behind(ledger, farmAccountName).took, isEmpty);
    });

    test('a row already named by a handover says so', () {
      final ledger = [_took(8600, 'Rafeeq')];
      final moving = [
        CashTransfer(
          id: 'x1',
          from: 'Rafeeq',
          to: farmAccountName,
          amount: 8600,
          txnIds: [ledger.single.id],
          state: TransferState.waiting,
          sentAt: DateTime(2026, 10, 20),
        ),
      ];

      final row = _behind(ledger, 'Rafeeq', moving: moving).took.single;
      expect(row.isSpokenFor, isTrue);
      expect(row.handedOnTo, farmAccountName);
    });
  });

  group('each row carries the entry it came from', () {
    test('so pressing it can open that entry and no other', () {
      final ledger = [_took(8600, 'Rafeeq'), _spent(2000, 'Rafeeq', day: 15)];
      final rows = _behind(ledger, 'Rafeeq');

      for (final r in [...rows.took, ...rows.gave]) {
        expect(
          ledger.where((t) => t.id == r.txnId),
          hasLength(1),
          reason: 'a row pointing at no entry opens a blank sheet',
        );
      }
    });

    test(
      'a shared entry gives each man his own share of it, not all of it',
      () {
        // Three of them clubbed together on one load of feed. Each sees his
        // own part, and the parts come to the entry.
        final feed = _spent(9000, 'Ghulam Ali');
        final putIn = [
          Contribution(
            id: 'c1',
            partnerId: 'p1',
            partnerName: 'Asif',
            kind: ContributionKind.investment,
            source: ContributionSource.spent,
            amount: 4000,
            txnId: feed.id,
            date: DateTime(2026, 10, 13),
            createdAt: DateTime(2026, 10, 13),
          ),
        ];

        final his = inHand([feed], who: 'Asif', incoming: false, putIn: putIn);
        expect(his, hasLength(1));
        expect(his.single.amount, 4000);
        expect(his.single.txnId, feed.id);

        // And the rest of it is the farm's own, on the farm's own account —
        // not on Ghulam Ali, whose name is merely the one on the entry.
        expect(
          inHand([feed], who: 'Ghulam Ali', incoming: false, putIn: putIn),
          isEmpty,
        );
        final rest = inHand(
          [feed],
          who: farmAccountName,
          incoming: false,
          putIn: putIn,
        );
        expect(rest.single.amount, 5000);
        expect(rest.single.txnId, feed.id);
      },
    );
  });
}
