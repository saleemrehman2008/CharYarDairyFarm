import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';

/// One man is one man, however he has been written down.
///
/// A co-founder has two records: the capital record the master opens for
/// him, and the user document his own sign-in makes. They can carry
/// different spellings of him — the master wrote "Munawar Soomro" into
/// the sheet and Google told the app his account was "Munawar Ali" — and
/// the card that says who is holding the farm's cash keyed on the written
/// name, so one man stood in two places with two balances.
///
/// The farm's answer, in its own words: the founders have emails, so the
/// name should come off the record and not off the letters on a row. And
/// the other half of it, which matters more — a customer or a supplier
/// whose name happens to match a co-founder's is not that co-founder, and
/// none of his money passes through anybody's hands.

var _n = 0;

/// Munawar: one man, two records, two spellings.
final munawar = FarmPerson(
  uid: 'u-munawar',
  name: 'Munawar Ali',
  alsoKnownAs: const ['Munawar Soomro'],
);

final saleem = FarmPerson(uid: 'u-saleem', name: 'Saleem Rehman');

final crew = [munawar, saleem];

Txn _in(num amount, {required String handledBy, int day = 10}) => Txn(
  id: 'r${_n++}',
  date: DateTime(2026, 10, day),
  monthId: '2026-10',
  type: TxnType.sale,
  party: 'Counter',
  category: milkCategory,
  amount: amount,
  paid: true,
  paidOnCreate: true,
  paidSoFar: amount,
  note: '',
  handledBy: handledBy,
  createdBy: 'u1',
  createdAt: DateTime(2026, 10, day),
);

Txn _out(num amount, {required String handledBy, int day = 11}) => Txn(
  id: 'p${_n++}',
  date: DateTime(2026, 10, day),
  monthId: '2026-10',
  type: TxnType.expense,
  party: 'Wapda',
  category: 'Utilities (bijli, gas, pani)',
  amount: amount,
  paid: true,
  paidOnCreate: true,
  paidSoFar: amount,
  note: '',
  handledBy: handledBy,
  createdBy: 'u1',
  createdAt: DateTime(2026, 10, day),
);

HandsOn? _held(List<Txn> ledger, String who, {List<FarmPerson>? people}) {
  final hands = cashInHands(ledger, founders: people ?? crew);
  final mine = founderNamed(who, people ?? crew);
  for (final h in hands) {
    if (mine != null
        ? mine.answersTo(h.who)
        : partyKey(h.who) == partyKey(who)) {
      return h;
    }
  }
  return null;
}

void main() {
  group('which name is whose', () {
    test('a man answers to the name on his record', () {
      expect(munawar.answersTo('Munawar Ali'), isTrue);
    });

    test('and to every other way he has been written down', () {
      expect(munawar.answersTo('Munawar Soomro'), isTrue);
      expect(munawar.answersTo('munawar soomro'), isTrue);
      expect(munawar.answersTo('  MUNAWAR   SOOMRO '), isTrue);
    });

    test('and to nobody else', () {
      expect(munawar.answersTo('Munawar Utero Booh'), isFalse);
      expect(munawar.answersTo('Munawar'), isFalse);
      expect(munawar.answersTo(''), isFalse);
    });

    test('a written name finds the one man it belongs to', () {
      expect(founderNamed('Munawar Soomro', crew)?.uid, 'u-munawar');
      expect(founderNamed('Munawar Ali', crew)?.uid, 'u-munawar');
      expect(founderNamed('Saleem Rehman', crew)?.uid, 'u-saleem');
    });

    test('and a name that is nobody of the farm\'s finds nobody', () {
      // The half that matters more. A customer called Munawar is a
      // customer, and a supplier is a supplier.
      expect(founderNamed('Munawar Utero Booh', crew), isNull);
      expect(founderNamed('Babar Dairy', crew), isNull);
      expect(founderNamed('Khalid Kutar', crew), isNull);
    });
  });

  group('who is holding the money', () {
    test('two spellings of one man are one line, not two', () {
      // 48,100 through one spelling and 3,85,675 through the other. The
      // card showed two men with two balances.
      final led = [
        _in(48100, handledBy: 'Munawar Ali'),
        _in(385675, handledBy: 'Munawar Soomro'),
      ];
      final hands = cashInHands(led, founders: crew);
      expect(hands, hasLength(1));
      expect(hands.first.received, 433775);
    });

    test('and the line is shown under the name on his record', () {
      final led = [_in(48100, handledBy: 'Munawar Soomro')];
      expect(cashInHands(led, founders: crew).first.who, 'Munawar Ali');
    });

    test('money in under one spelling comes out under the other', () {
      // Which is the whole point: his holding has to net off whichever
      // way each row happens to spell him.
      final led = [
        _in(50000, handledBy: 'Munawar Soomro'),
        _out(50000, handledBy: 'Munawar Ali'),
      ];
      expect(_held(led, 'Munawar Ali')?.holding, 0);
    });

    test('a man asked for by either name gives the same answer', () {
      final led = [
        _in(50000, handledBy: 'Munawar Soomro'),
        _out(20000, handledBy: 'Munawar Ali'),
      ];
      expect(_held(led, 'Munawar Ali')?.holding, 30000);
      expect(_held(led, 'Munawar Soomro')?.holding, 30000);
    });

    test('a stranger with a similar name keeps his own line', () {
      final led = [
        _in(50000, handledBy: 'Munawar Ali'),
        _in(9000, handledBy: 'Munawar Utero Booh'),
      ];
      final hands = cashInHands(led, founders: crew);
      expect(hands, hasLength(2));
      expect(_held(led, 'Munawar Ali')?.received, 50000);
    });

    test('and nothing of his is counted as a co-founder\'s', () {
      final led = [_in(9000, handledBy: 'Munawar Utero Booh')];
      expect(_held(led, 'Munawar Ali'), isNull);
    });

    test('two real co-founders stay two', () {
      final led = [
        _in(10000, handledBy: 'Munawar Ali'),
        _in(20000, handledBy: 'Saleem Rehman'),
      ];
      expect(cashInHands(led, founders: crew), hasLength(2));
    });

    test('with no founder list at all, names stand for themselves', () {
      // How every phone read this before the list carried spellings, and
      // how a rider's phone reads it if the list has not reached him.
      final led = [
        _in(48100, handledBy: 'Munawar Ali'),
        _in(385675, handledBy: 'Munawar Soomro'),
      ];
      expect(cashInHands(led), hasLength(2));
    });
  });

  group('who the farm traded with is a different question', () {
    test('a party named like a co-founder is not one', () {
      // The entry's party is who the milk went to. It is never put
      // through the founder list, and this is the test that says so.
      final led = [
        Txn(
          id: 's1',
          date: DateTime(2026, 10, 12),
          monthId: '2026-10',
          type: TxnType.sale,
          party: 'Munawar Ali',
          category: milkCategory,
          amount: 7000,
          paid: true,
          paidOnCreate: true,
          paidSoFar: 7000,
          note: '',
          handledBy: 'Saleem Rehman',
          createdBy: 'u1',
          createdAt: DateTime(2026, 10, 12),
        ),
      ];
      final hands = cashInHands(led, founders: crew);
      expect(hands, hasLength(1));
      expect(hands.first.who, 'Saleem Rehman');
      expect(_held(led, 'Munawar Ali'), isNull);
    });
  });

  group('a name the master says is also him', () {
    /// Munawar's own case. His record is "Munawar Ali"; 3,85,675 of the
    /// farm's money went through his hands on entries that say "Munawar
    /// Soomro", and 48,100 on entries that say "Munawar Ali". His
    /// capital already counted both, because contributions hang off his
    /// record — only the card that reads the name on each row split him.
    final led = [
      _in(48100, handledBy: 'Munawar Ali'),
      _out(48100, handledBy: 'Munawar Ali'),
      _in(385675, handledBy: 'Munawar Soomro'),
      _out(385675, handledBy: 'Munawar Soomro'),
      _in(51600, handledBy: 'Farm account'),
    ];

    /// Before the master says anything: two rows, as the farm saw it.
    final apart = [FarmPerson(uid: 'u-munawar', name: 'Munawar Ali')];

    /// After: the one name added to his record travels with him.
    final together = [
      FarmPerson(
        uid: 'u-munawar',
        name: 'Munawar Ali',
        alsoKnownAs: const ['Munawar Soomro'],
      ),
    ];

    test('without it he stands in two places', () {
      final hands = cashInHands(led, founders: apart);
      expect(hands.where((h) => h.who.startsWith('Munawar')), hasLength(2));
    });

    test('with it he is one line, under his own name', () {
      final hands = cashInHands(led, founders: together);
      final his = hands.where((h) => h.who.startsWith('Munawar')).toList();
      expect(his, hasLength(1));
      expect(his.first.who, 'Munawar Ali');
    });

    test('and his two sides add up', () {
      final his = cashInHands(
        led,
        founders: together,
      ).firstWhere((h) => h.who == 'Munawar Ali');
      expect(his.received, 433775);
      expect(his.paid, 433775);
      expect(his.holding, 0);
    });

    test('the total does not move — which is the whole point', () {
      // The farm's instruction, in its own words: the values go onto
      // Munawar Ali and the total must not change. Nothing in the books
      // is touched to do it, so nothing in the books can move.
      num held(List<FarmPerson> crew) => cashInHands(
        led,
        founders: crew,
      ).fold<num>(0, (a, h) => a + h.holding);

      expect(held(apart), held(together));
      expect(held(together), 51600);
    });

    test('and every rupee that went through hands is still counted once', () {
      num through(List<FarmPerson> crew) => cashInHands(
        led,
        founders: crew,
      ).fold<num>(0, (a, h) => a + h.received + h.paid);

      expect(through(apart), through(together));
    });

    test('one row fewer, and nobody else is touched', () {
      expect(
        cashInHands(led, founders: together).length,
        cashInHands(led, founders: apart).length - 1,
      );
      expect(
        cashInHands(
          led,
          founders: together,
        ).firstWhere((h) => h.who == 'Farm account').holding,
        51600,
      );
    });

    test('a stranger is not swept in with him', () {
      final withAStranger = [
        ...led,
        _in(9000, handledBy: 'Munawar Utero Booh'),
      ];
      final hands = cashInHands(withAStranger, founders: together);
      expect(hands.where((h) => h.who.startsWith('Munawar')), hasLength(2));
      expect(hands.firstWhere((h) => h.who == 'Munawar Ali').received, 433775);
    });
  });

  group('a record renamed after its lines were written', () {
    /// The farm's real case, and the one the alias was not needed for.
    ///
    /// Munawar's record was opened as "Munawar Soomro". 3,85,675 of
    /// capital went in against it. The master later put the name right
    /// to "Munawar Ali", and 48,100 more went in after that. A capital
    /// line keeps the name it was written under — which is right for
    /// reading that line — so the card that says who is holding what saw
    /// two men. His own card never did: capital hangs off the record.
    final his = [
      Contribution(
        id: 'c1',
        partnerId: 'p-munawar',
        partnerName: 'Munawar Soomro',
        amount: 385675,
        source: ContributionSource.spent,
        kind: ContributionKind.investment,
        date: DateTime(2026, 9, 20),
        createdAt: DateTime(2026, 9, 20),
        createdBy: 'u1',
      ),
      Contribution(
        id: 'c2',
        partnerId: 'p-munawar',
        partnerName: 'Munawar Ali',
        amount: 48100,
        source: ContributionSource.spent,
        kind: ContributionKind.investment,
        date: DateTime(2026, 10, 20),
        createdAt: DateTime(2026, 10, 20),
        createdBy: 'u1',
      ),
    ];

    /// What his record is called today.
    const today = {'p-munawar': 'Munawar Ali'};

    test('without the record, his old lines read as another man', () {
      final hands = cashInHands([], putIn: his);
      expect(
        hands.map((h) => h.who),
        containsAll(['Munawar Soomro', 'Munawar Ali']),
      );
    });

    test('read through the record, he is one man', () {
      final hands = cashInHands([], putIn: his, nameOf: today);
      expect(hands, hasLength(1));
      expect(hands.first.who, 'Munawar Ali');
    });

    test('and every rupee of his is on him', () {
      final hands = cashInHands([], putIn: his, nameOf: today);
      expect(hands.first.received, 433775);
    });

    test('the total does not move', () {
      // Nothing in the books is touched to do this: the lines keep the
      // names they were written under. Only who they are read as moves.
      num all(Map<String, String> names) => cashInHands(
        [],
        putIn: his,
        nameOf: names,
      ).fold<num>(0, (a, h) => a + h.received);

      expect(all(const {}), all(today));
      expect(all(today), 433775);
    });

    test('a line whose record is gone keeps the name it was written with', () {
      // Nothing is lost when a record cannot be found: the line still
      // says who it was for.
      final hands = cashInHands(
        [],
        putIn: his,
        nameOf: const {'somebody-else': 'Asif Soomro'},
      );
      expect(
        hands.map((h) => h.who),
        containsAll(['Munawar Soomro', 'Munawar Ali']),
      );
    });

    test('and two real co-founders are still two', () {
      final two = [
        his.first,
        Contribution(
          id: 'c3',
          partnerId: 'p-asif',
          partnerName: 'Asif Soomro',
          amount: 100000,
          source: ContributionSource.spent,
          kind: ContributionKind.investment,
          date: DateTime(2026, 9, 21),
          createdAt: DateTime(2026, 9, 21),
          createdBy: 'u1',
        ),
      ];
      final hands = cashInHands(
        [],
        putIn: two,
        nameOf: const {'p-munawar': 'Munawar Ali', 'p-asif': 'Asif Soomro'},
      );
      expect(hands, hasLength(2));
    });
  });
}
