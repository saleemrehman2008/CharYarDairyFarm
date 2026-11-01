import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/animal_repo.dart';

/// The rules that stop a correction rewriting something it cannot see.
///
/// Each of these was a figure that could be moved from one screen while
/// another screen went on holding it up. None of them refused anything —
/// they just quietly stopped adding up, which is the kind of thing nobody
/// notices until four people are arguing about a share.

var _n = 0;

Animal _animal({
  num price = 100000,
  AnimalStatus status = AnimalStatus.onFarm,
  String? tiedTo,
  String name = 'Lali',
}) => Animal(
  id: 'an${_n++}',
  tag: 'B-0$_n',
  name: name,
  species: Species.buffalo,
  sex: Sex.female,
  status: status,
  photoUrl: '',
  thumb: '',
  dailyLitres: 8,
  createdAt: DateTime(2026, 9, 1),
  price: price,
  purchaseTxnId: tiedTo,
  boughtOn: DateTime(2026, 9, 1),
  note: '',
);

Txn _purchase(num amount) => Txn(
  id: 'p1',
  date: DateTime(2026, 9, 1),
  monthId: '2026-09',
  type: TxnType.purchase,
  party: 'Mandi',
  category: 'Cattle',
  amount: amount,
  paid: true,
  paidOnCreate: true,
  paidSoFar: amount,
  note: '',
  createdBy: 'u1',
  createdAt: DateTime(2026, 9, 1),
  capital: true,
);

void main() {
  group('the shares on one entry', () {
    test('four cows on one payment leave room for the fourth', () {
      // 400,000 paid once for four animals. Three are registered at
      // 100,000 each; the fourth may take what is left and no more.
      final entry = _purchase(400000);
      final three = [for (var i = 0; i < 3; i++) _animal(tiedTo: entry.id)];
      expect(cattleAssigned(three, entry.id), 300000);
      expect(cattleLeftOn(entry, three), 100000);
    });

    test('and raising one is measured against the others, not itself', () {
      // Leaving her out of the sum is the whole trick: counted in, a cow
      // already holding 100,000 could never be raised at all.
      final entry = _purchase(400000);
      final four = [for (var i = 0; i < 4; i++) _animal(tiedTo: entry.id)];
      final her = four.first;
      expect(cattleLeftOn(entry, four, except: her), 100000);
    });

    test('a full entry has no room left', () {
      final entry = _purchase(400000);
      final four = [for (var i = 0; i < 4; i++) _animal(tiedTo: entry.id)];
      expect(cattleLeftOn(entry, four), 0);
    });

    test('and over-assigned reads as nothing left, never as money back', () {
      final entry = _purchase(400000);
      final five = [for (var i = 0; i < 5; i++) _animal(tiedTo: entry.id)];
      expect(cattleLeftOn(entry, five), 0);
      expect(cattleAssigned(five, entry.id), 500000);
    });

    test('animals on another entry are nothing to do with this one', () {
      final entry = _purchase(400000);
      final mixed = [
        _animal(tiedTo: entry.id),
        _animal(tiedTo: 'another'),
        _animal(),
      ];
      expect(cattleAssigned(mixed, entry.id), 100000);
      expect(cattleLeftOn(entry, mixed), 300000);
    });
  });

  group('an animal already off the books', () {
    test('a dead one is not on the farm', () {
      // What the price guard turns on: her loss is in a period's figures,
      // which may already have been shared out between four people.
      expect(
        _animal(status: AnimalStatus.dead).status,
        isNot(AnimalStatus.onFarm),
      );
      expect(
        _animal(status: AnimalStatus.sold).status,
        isNot(AnimalStatus.onFarm),
      );
      expect(_animal().status, AnimalStatus.onFarm);
    });
  });

  group('putting one back', () {
    test('the rows she wrote are found by their ids, not her name', () {
      // The write-off carries the name she had the day she died. Rename
      // her afterwards — which the register lets anybody do — and the
      // name no longer matches anything, so putting her back found no
      // write-off and the farm went on carrying the loss of an animal
      // standing in its own shed.
      final died = _animal(status: AnimalStatus.dead, name: 'Lali');
      final renamed = Animal(
        id: died.id,
        tag: died.tag,
        name: 'Kaali',
        species: died.species,
        sex: died.sex,
        status: died.status,
        writeOffTxnId: 'wo1',
        photoUrl: '',
        thumb: '',
        dailyLitres: 0,
        createdAt: died.createdAt,
        price: died.price,
        boughtOn: died.boughtOn,
        note: '',
      );

      expect(renamed.label, isNot(died.label), reason: 'the name moved');
      expect(renamed.id, died.id, reason: 'she did not');
      expect(renamed.writeOffTxnId, 'wo1', reason: 'nor did the row');
    });

    test('and an animal that wrote none has none to find', () {
      final born = _animal(price: 0);
      expect(born.writeOffTxnId, isNull);
      expect(born.saleTxnId, isNull);
    });
  });

  group('a co-founder record and the lines under it', () {
    test('what the farm owes him is read off his lines', () {
      // The two figures came from two places — his capital off the
      // record, what the farm owed him off his lines — so removing the
      // record took one away and left the other standing.
      final loan = Contribution(
        id: 'c1',
        partnerId: 'p1',
        partnerName: 'Jalbani',
        amount: 20000,
        source: ContributionSource.spent,
        kind: ContributionKind.loan,
        date: DateTime(2026, 10, 5),
        createdAt: DateTime(2026, 10, 5),
        createdBy: 'u1',
      );
      expect(loan.isLoan, isTrue);
      expect(loan.stillOwed, 20000);
      expect(loan.isDeleted, isFalse);
    });

    test('and a line marked deleted is owed no longer', () {
      final gone = Contribution(
        id: 'c2',
        partnerId: 'p1',
        partnerName: 'Jalbani',
        amount: 20000,
        source: ContributionSource.spent,
        kind: ContributionKind.loan,
        date: DateTime(2026, 10, 5),
        createdAt: DateTime(2026, 10, 5),
        createdBy: 'u1',
        deletedAt: DateTime(2026, 10, 9),
      );
      expect(gone.isDeleted, isTrue);
    });

    test('an empty record holds nothing, so removing it loses nothing', () {
      final empty = Partner(
        id: 'p2',
        userId: '',
        name: 'A second account',
        email: '',
        invested: 0,
        pledged: 0,
        profitHeld: 0,
        withdrawn: 0,
        createdAt: DateTime(2026, 9, 1),
      );
      expect(empty.isEmpty, isTrue);

      final holds = Partner(
        id: 'p3',
        userId: 'u3',
        name: 'Jalbani',
        email: '',
        invested: 200000,
        pledged: 200000,
        profitHeld: 0,
        withdrawn: 0,
        createdAt: DateTime(2026, 9, 1),
      );
      expect(holds.isEmpty, isFalse);
    });
  });
}
