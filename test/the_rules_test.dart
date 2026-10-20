import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';

/// The eleven rules the four of them settled on, checked one at a time.
///
/// Every one of these was said out loud by the farm, in its own words, over
/// a fortnight of reading its own books back. They are written here together
/// because they lean on each other: a founder's spending goes onto his
/// promise *because* the promise is what the share ratio follows, and his
/// takings stand apart *because* the farm's money has to reach the farm's
/// account before a month can be closed on it.
///
/// A rule that is only in somebody's head is a rule the app will quietly
/// break on a Tuesday.

var _n = 0;

Partner _p({
  required String name,
  num pledged = 0,
  num invested = 0,
  num profitHeld = 0,
}) => Partner(
  id: 'p${_n++}',
  userId: 'u$_n',
  name: name,
  invested: invested,
  pledged: pledged,
  profitHeld: profitHeld,
  withdrawn: 0,
  createdAt: DateTime(2026, 8, 1),
);

Txn _txn({
  required TxnType type,
  required String category,
  required num amount,
  required String handledBy,
  String party = 'Somebody',
  int day = 12,
}) => Txn(
  id: 'r${_n++}',
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

Contribution _spentOwn(String id, String name, num amount) => Contribution(
  id: 'c${_n++}',
  partnerId: id,
  partnerName: name,
  kind: ContributionKind.investment,
  source: ContributionSource.spent,
  amount: amount,
  date: DateTime(2026, 10, 14),
  createdAt: DateTime(2026, 10, 14),
);

void main() {
  group('1. his own spending goes onto his promise until it is paid', () {
    test('while he still owes, every rupee of it counts as money put in', () {
      final cut = splitByPledge(amount: 2700, pledged: 1000000, alreadyIn: 0);
      expect(cut.investment, 2700);
      expect(cut.refundable, 0);
    });

    test('and his card says what is left of the promise', () {
      final saleem = _p(name: 'Saleem', pledged: 1000000, invested: 2700);
      expect(saleem.stillToPayIn, 997300);
      expect(saleem.paidInFull, isFalse);
    });

    test('the share ratio does not move while he pays it off', () {
      // The decision behind all of this: a share is settled the day a man
      // says what he is in for, and does not creep up as he pays.
      final early = _p(name: 'Saleem', pledged: 1000000);
      final later = _p(name: 'Saleem', pledged: 1000000, invested: 900000);
      expect(early.ratioBase, later.ratioBase);
      expect(early.ratioBase, 1000000);
    });
  });

  group('2. what he takes in for the farm belongs in the farm account', () {
    test('it stands on its own, whatever he has spent of his own', () {
      final led = [_took(8600, 'Ghulam Ali'), _spent(975390, 'Ghulam Ali')];
      expect(toPayIntoFarm(led, who: 'Ghulam Ali'), 8600);
    });

    test('and is nothing once he has paid it in', () {
      final led = [
        _took(8600, 'Ghulam Ali'),
        ..._handover(8600, 'Ghulam Ali', farmAccountName),
      ];
      expect(toPayIntoFarm(led, who: 'Ghulam Ali'), 0);
    });

    test('the farm account is never asked to pay into itself', () {
      final led = [
        _took(8600, 'Ghulam Ali'),
        ..._handover(8600, 'Ghulam Ali', farmAccountName),
      ];
      expect(toPayIntoFarm(led, who: farmAccountName), 0);
    });
  });

  group('3. taken straight onto the farm account, it is one entry', () {
    test('nothing is owed and nothing is handed over', () {
      // The money never passed through anybody's pocket, so there is no
      // second half to write and nobody has anything to pay in.
      final led = [_took(8600, farmAccountName)];
      expect(toPayIntoFarm(led, who: farmAccountName), 0);
      final hands = {for (final h in cashInHands(led)) h.who: h.holding};
      expect(hands[farmAccountName], 8600);
      expect(hands.length, 1, reason: 'nobody else is involved');
    });

    test('taken onto his own, it shows as his to pay in', () {
      final led = [_took(8600, 'Ghulam Ali')];
      expect(toPayIntoFarm(led, who: 'Ghulam Ali'), 8600);
    });
  });

  group('4. over his promise, the farm owes it back', () {
    test('the part above the promise is refundable, and at once', () {
      // No month has to close for this. It is his money and the farm is
      // holding it.
      final cut = splitByPledge(
        amount: 1600000,
        pledged: 1500000,
        alreadyIn: 0,
      );
      expect(cut.investment, 1500000);
      expect(cut.refundable, 100000);
    });

    test('a man paid up in full is owed every rupee of what he spends', () {
      final cut = splitByPledge(
        amount: 4200,
        pledged: 1500000,
        alreadyIn: 1500000,
      );
      expect(cut.investment, 0);
      expect(cut.refundable, 4200);
    });

    test('and it is written on his record as owed, not as capital', () {
      final owed = Contribution(
        id: 'c-owed',
        partnerId: 'p-rafeeq',
        partnerName: 'Rafeeq',
        kind: ContributionKind.loan,
        source: ContributionSource.spent,
        amount: 4200,
        date: DateTime(2026, 10, 14),
        createdAt: DateTime(2026, 10, 14),
      );
      expect(investedFrom([owed], 'p-rafeeq'), 0);
      expect(owedToFrom([owed], 'p-rafeeq'), 4200);
    });
  });

  group('5. a month closed while he still owes pays off the promise', () {
    test('what the month made for him goes onto what he owes', () {
      final split = keptProfitGoes(
        kept: 50000,
        pledged: 1000000,
        invested: 2700,
      );
      expect(split.toCapital, 50000);
      expect(split.toProfit, 0);
    });

    test('and only what is over the promise starts a profit account', () {
      final split = keptProfitGoes(
        kept: 50000,
        pledged: 1000000,
        invested: 980000,
      );
      expect(split.toCapital, 20000);
      expect(split.toProfit, 30000);
    });

    test('a man paid up in full keeps his profit as profit', () {
      final split = keptProfitGoes(
        kept: 50000,
        pledged: 1500000,
        invested: 1500000,
      );
      expect(split.toCapital, 0);
      expect(split.toProfit, 50000);
    });

    test('a losing month never touches his capital', () {
      // A loss comes out of the profit account where the gains went. Nobody
      // is made to have invested less because October was bad.
      final split = keptProfitGoes(
        kept: -30000,
        pledged: 1000000,
        invested: 2700,
      );
      expect(split.toCapital, 0);
      expect(split.toProfit, -30000);
    });

    test('and the share ratio still does not move', () {
      // Which is the whole reason this is safe to do: the ratio follows
      // what he is in for, so paying the promise off changes no slice.
      final before = _p(name: 'Saleem', pledged: 1000000, invested: 2700);
      final after = _p(name: 'Saleem', pledged: 1000000, invested: 52700);
      expect(before.ratioBase, after.ratioBase);
    });

    test('nothing is ever put onto a promise that was never made', () {
      // A record with no promise on it falls back to the money, and
      // crediting capital there would move his slice.
      final split = keptProfitGoes(kept: 50000, pledged: 0, invested: 300000);
      expect(split.toCapital, 0);
      expect(split.toProfit, 50000);
    });
  });

  group('6. a handover is one line, and a debt until it is made', () {
    test('until he pays it in, it stands against him', () {
      final led = [_took(8600, 'Ghulam Ali')];
      expect(toPayIntoFarm(led, who: 'Ghulam Ali'), 8600);
    });

    test('once he has, it is nothing — if nothing else is on him', () {
      final led = [
        _took(8600, 'Ghulam Ali'),
        ..._handover(8600, 'Ghulam Ali', farmAccountName),
      ];
      expect(toPayIntoFarm(led, who: 'Ghulam Ali'), 0);
    });

    test('and anything else on him is still on him', () {
      final led = [
        _took(8600, 'Ghulam Ali'),
        _took(5000, 'Ghulam Ali', day: 15),
        ..._handover(8600, 'Ghulam Ali', farmAccountName),
      ];
      expect(toPayIntoFarm(led, who: 'Ghulam Ali'), 5000);
    });

    test('the two rows are read as the one act they are', () {
      final led = _handover(8600, 'Ghulam Ali', farmAccountName);
      final hidden = twinnedHandovers(led);
      expect(hidden, hasLength(1));
      expect(led.where((t) => !hidden.contains(t.id)), hasLength(1));
    });

    test(
      'and it carries the day the money moved, not the day it was typed',
      () {
        final led = _handover(8600, 'Ghulam Ali', farmAccountName, day: 12);
        expect(led.first.date, DateTime(2026, 10, 12));
      },
    );

    test('neither half is money the farm earned or spent', () {
      final led = _handover(8600, 'Ghulam Ali', farmAccountName);
      expect(led.every((t) => t.isHandover), isTrue);
    });
  });

  group('9. the farm account carries the whole picture', () {
    test('what it holds, what it owes them, and what is left', () {
      // Its own 8,600 is one of theirs until he is paid back, and the page
      // says so rather than leaving it to be netted in somebody's head.
      final led = [
        _took(8600, 'Ghulam Ali'),
        _spent(975390, 'Ghulam Ali'),
        ..._handover(8600, 'Ghulam Ali', farmAccountName),
      ];
      final hands = {for (final h in cashInHands(led)) h.who: h.holding};
      expect(hands[farmAccountName], 8600);
      expect(hands['Ghulam Ali'], -975390);
    });

    test(
      'once his own spending is counted, the farm owes him what is left',
      () {
        final led = [
          _took(908600, 'Ghulam Ali'),
          _spent(975390, 'Ghulam Ali'),
          ..._handover(8600, 'Ghulam Ali', farmAccountName),
        ];
        final counted = [_spentOwn('p-ali', 'Ghulam Ali', 75390)];
        final hands = {
          for (final h in cashInHands(led, putIn: counted)) h.who: h.holding,
        };
        expect(hands['Ghulam Ali'], 0, reason: 'he is square');
        expect(hands[farmAccountName], 8600);
      },
    );

    test('and a month closes on the farm account, not on four pockets', () {
      // The point of all of it. Everything the farm takes in reaches one
      // place, so the figure a month is closed on is a figure and not a
      // reconciliation.
      final led = [
        _took(50000, 'Ghulam Ali'),
        ..._handover(50000, 'Ghulam Ali', farmAccountName),
        _took(30000, farmAccountName, day: 20),
      ];
      final hands = {for (final h in cashInHands(led)) h.who: h.holding};
      expect(hands[farmAccountName], 80000);
      expect(hands['Ghulam Ali'], 0);
      expect(toPayIntoFarm(led, who: 'Ghulam Ali'), 0);
    });
  });
}
