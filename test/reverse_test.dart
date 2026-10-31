import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';

/// One record changed, and every record whose figure came from it.
///
/// Four bugs of one shape, found by reading the whole of the money side
/// after the farm lost six sales to the first of them. They are all the
/// same sentence: something was written in two places and only one of them
/// moved.
///
/// The forward direction has a thousand tests on it. None of these would
/// have been caught by any of them, because every one of those tests builds
/// the books up and none of them takes anything back out, corrects a figure
/// already settled, or deletes a thing other figures were derived from.
/// That is the gap, and these are written to sit in it.

var _n = 0;

Txn _txn({
  required TxnType type,
  required num amount,
  String category = 'Milk',
  String party = 'Babar Dairy',
  String handledBy = '',
  num paidSoFar = 0,
  bool paid = false,
  String? settles,
  int day = 9,
  String? id,
}) => Txn(
  id: id ?? 'x${_n++}',
  date: DateTime(2026, 10, day),
  monthId: '2026-10',
  type: type,
  party: party,
  category: category,
  amount: amount,
  paid: paid,
  paidOnCreate: paid,
  paidSoFar: paidSoFar,
  settlesTxnId: settles,
  handledBy: handledBy,
  note: '',
  createdBy: 'u1',
  createdAt: DateTime(2026, 10, day),
);

Contribution _share({
  required String partnerId,
  required String name,
  required num amount,
  required String txnId,
  bool deleted = false,
}) => Contribution(
  id: 'c${_n++}',
  partnerId: partnerId,
  partnerName: name,
  kind: ContributionKind.investment,
  source: ContributionSource.spent,
  amount: amount,
  txnId: txnId,
  date: DateTime(2026, 10, 9),
  createdAt: DateTime(2026, 10, 9),
  deletedAt: deleted ? DateTime(2026, 10, 30) : null,
);

/// `paid` worked out again from the money, which is the rule everywhere:
/// an entry is settled when nothing is left owing on it.
bool _settled({required num amount, required num paidSoFar}) =>
    paidSoFar >= amount;

void main() {
  group('correcting the amount of an entry already settled', () {
    test('raising it leaves the money alone and reopens the entry', () {
      // A sale of 20,000 settled in full, then corrected up to 25,000.
      // This used to write paidSoFar = 25,000 against a receipt for
      // 20,000: five thousand owed, and no figure anywhere saying so.
      const was = 20000, now = 25000, received = 20000;

      expect(_settled(amount: now, paidSoFar: received), isFalse);
      expect(now - received, 5000, reason: 'still to come, and it shows');
      expect(_settled(amount: was, paidSoFar: received), isTrue);
    });

    test('raising a part-settled one keeps it part settled', () {
      expect(_settled(amount: 25000, paidSoFar: 8000), isFalse);
    });

    test('lowering it onto what has come in settles it exactly', () {
      expect(_settled(amount: 8000, paidSoFar: 8000), isTrue);
    });

    test('and lowering it below that is refused, not quietly absorbed', () {
      // The guard that was already there, and the other half of the same
      // thought: the money that came in is a fact, the entry's figure is
      // an opinion, and the opinion does not get to rewrite the fact.
      const paidSoFar = 20000, to = 15000;
      expect(paidSoFar > to, isTrue, reason: 'this is what throws');
    });
  });

  group('correcting a settlement moves the entry it settled', () {
    test('cutting the receipt puts the money back on the sale', () {
      // A receipt of 20,000 typed against a 20,000 sale, corrected to
      // 4,000. The sale used to go on saying paid in full.
      const sale = 20000;
      const was = 20000, now = 4000;
      final after = sale - (was - now) < 0 ? 0 : was + (now - was);

      expect(after, 4000);
      expect(_settled(amount: sale, paidSoFar: after), isFalse);
      expect(sale - after, 16000, reason: 'what Babar still owes');
    });

    test('raising it settles the sale', () {
      const sale = 20000;
      const was = 4000, now = 20000;
      expect(_settled(amount: sale, paidSoFar: was + (now - was)), isTrue);
    });
  });

  group('deleting a purchase takes the split written against it', () {
    test('the men credited with paying for it are credited no longer', () {
      // The farm's own: a duplicate cattle entry of 15,09,000 with two
      // men's own money written against it. Deleting the entry used to
      // leave both lines standing — their capital, their share of the
      // farm, and fifteen lakh of cash that was not there.
      // Paid on the spot, out of their own pockets, which is the whole
      // reason a split was written against it.
      final cows = _txn(
        type: TxnType.purchase,
        amount: 1509000,
        day: 9,
        paid: true,
      );
      final split = [
        _share(
          partnerId: 'p-rafeeq',
          name: 'Rafeeq',
          amount: 500000,
          txnId: cows.id,
        ),
        _share(
          partnerId: 'p-asif',
          name: 'Asif',
          amount: 1009000,
          txnId: cows.id,
        ),
      ];

      // While the purchase stands, each man's own money is charged to him
      // and the farm is charged the rest — nothing, here, since the two
      // of them covered all of it.
      final before = cashInHands([cows], putIn: split);
      num heldBy(List<HandsOn> hands, String who) => hands
          .where((h) => partyKey(h.who) == partyKey(who))
          .map((h) => h.holding)
          .fold<num>(0, (a, b) => a + b);
      expect(heldBy(before, 'Rafeeq'), 0);
      expect(heldBy(before, 'Asif'), 0);

      // With the purchase deleted and its split taken down with it, there
      // is nothing left to say anybody paid for anything.
      final gone = [
        for (final c in split)
          _share(
            partnerId: c.partnerId,
            name: c.partnerName,
            amount: c.amount,
            txnId: cows.id,
            deleted: true,
          ),
      ];
      final after = cashInHands(const [], putIn: gone);
      expect(after, isEmpty, reason: 'nobody handled anything');
    });

    test('a split left standing is exactly the wrong figure', () {
      // What the bug looked like: the purchase gone, the lines alive.
      // Each man reads as having taken in his share and spent it on
      // nothing, so the card credits him with holding it.
      final split = [
        _share(
          partnerId: 'p-rafeeq',
          name: 'Rafeeq',
          amount: 500000,
          txnId: 'a-purchase-that-is-gone',
        ),
      ];
      final hands = cashInHands(const [], putIn: split);
      expect(hands.single.holding, 500000, reason: 'the bug, in one line');
    });
  });

  group('what a month close hands out has hands against it', () {
    test('a profit share and an instalment are the farm account\'s', () {
      // These two rows are written with no name on them, and the card
      // that asks who is holding the farm's cash keyed them under nobody
      // — so "Not recorded" went further out of true with every month the
      // farm closed. The money leaves the farm's own account and the
      // instalment comes back into it.
      final rows = [
        _txn(
          type: TxnType.payment,
          category: profitShareCategory,
          party: 'Rafeeq',
          amount: 74000,
          paid: true,
          handledBy: farmAccountName,
          day: 30,
        ),
        _txn(
          type: TxnType.receipt,
          category: loanRepaidCategory,
          party: 'Rafeeq',
          amount: 10000,
          paid: true,
          handledBy: farmAccountName,
          day: 30,
        ),
      ];

      final hands = cashInHands(rows, unnamed: 'Not recorded');
      expect(
        hands.where((h) => h.who == 'Not recorded'),
        isEmpty,
        reason: 'every rupee has a pair of hands against it',
      );

      final farm = hands.single;
      expect(partyKey(farm.who), partyKey(farmAccountName));
      expect(farm.received, 10000);
      expect(farm.paid, 74000);
      expect(farm.holding, -64000, reason: 'paid out more than came in');
    });

    test('without a name they land on nobody, which is the bug', () {
      final rows = [
        _txn(
          type: TxnType.payment,
          category: profitShareCategory,
          party: 'Rafeeq',
          amount: 74000,
          paid: true,
          day: 30,
        ),
      ];
      final hands = cashInHands(rows, unnamed: 'Not recorded');
      expect(hands.single.who, 'Not recorded');
      expect(hands.single.holding, -74000);
    });
  });
}
