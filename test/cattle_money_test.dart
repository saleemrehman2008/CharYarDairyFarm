import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';
import 'package:char_yar_dairy_farm/services/animal_repo.dart';

/// Four cows and three calves, bought on one day for one price.
///
/// The farm hit this in its first week and said it plainly: the purchase was
/// entered once under Accounts, then seven animals were registered, and the
/// register booked the money again for every one of them. Seven entries out
/// of a farm that had paid once — and nothing in the app to notice, because
/// each entry on its own was a perfectly ordinary cattle purchase.
///
/// So an animal now takes a share of an entry that already exists. These are
/// the rules that keeps the shares honest, which matters past the register:
/// when an animal is sold or dies she comes off the books at what she cost,
/// so the shares have to add up to the entry or the asset never returns to
/// nothing.

var _n = 0;

Animal _animal({required num price, String? on, String tag = 'C-01'}) => Animal(
  id: 'a${_n++}',
  tag: tag,
  name: '',
  species: Species.cow,
  sex: Sex.female,
  status: AnimalStatus.onFarm,
  photoUrl: '',
  thumb: '',
  dailyLitres: 0,
  price: price,
  purchaseTxnId: on,
  createdAt: DateTime(2026, 10, 8),
);

Txn _bought({
  String id = 'e1',
  num amount = 1200000,
  String category = 'Cattle purchase',
  DateTime? on,
  bool deleted = false,
}) => Txn(
  id: id,
  date: on ?? DateTime(2026, 10, 8),
  monthId: '2026-10',
  type: TxnType.purchase,
  party: 'Mandi',
  category: category,
  amount: amount,
  paid: true,
  paidOnCreate: true,
  note: '',
  createdBy: 'u1',
  createdAt: on ?? DateTime(2026, 10, 8),
  deletedAt: deleted ? DateTime(2026, 10, 9) : null,
);

void main() {
  group('one payment, seven animals', () {
    final entry = _bought();

    test('nothing registered against it yet, all of it is free', () {
      expect(cattleLeftOn(entry, const []), 1200000);
      expect(cattleAssigned(const [], entry.id), 0);
    });

    test('four cows take their share and the calves have the rest', () {
      final cows = [
        for (var i = 0; i < 4; i++) _animal(price: 250000, on: 'e1'),
      ];
      expect(cattleAssigned(cows, 'e1'), 1000000);
      expect(cattleLeftOn(entry, cows), 200000);
    });

    test('and once all seven are on it, there is nothing left to give', () {
      final herd = [
        for (var i = 0; i < 4; i++) _animal(price: 250000, on: 'e1'),
        for (var i = 0; i < 3; i++) _animal(price: 200000 / 3, on: 'e1'),
      ];
      expect(cattleLeftOn(entry, herd).round(), 0);
      // The figure that matters the day they leave the farm: every animal
      // comes off the books at what she cost, and the lot of them have to
      // come to exactly what was paid.
      expect(
        herd.fold<num>(0, (a, animal) => a + animal.price).round(),
        entry.amount,
      );
    });

    test('an animal on another entry is none of this one\'s business', () {
      final mixed = [
        _animal(price: 250000, on: 'e1'),
        _animal(price: 900000, on: 'e2'),
        _animal(price: 400000, on: null),
      ];
      expect(cattleAssigned(mixed, 'e1'), 250000);
      expect(cattleLeftOn(entry, mixed), 950000);
    });

    test('a share can never read as more than the entry was for', () {
      // Books from before this rule, or an entry corrected downwards
      // afterwards. Nothing is left, and nothing is less than nothing.
      final over = [_animal(price: 2000000, on: 'e1')];
      expect(cattleLeftOn(entry, over), 0);
    });

    test('correcting one animal measures her against the others, not '
        'herself', () {
      // Raising her share from 250,000 to 300,000 has to be allowed while
      // the entry has room for it. Counting her own share against her would
      // say the entry was full when it was not.
      final her = _animal(price: 250000, on: 'e1');
      final herd = [her, _animal(price: 250000, on: 'e1')];
      expect(cattleLeftOn(entry, herd), 700000);
      expect(cattleLeftOn(entry, herd, except: her), 950000);
    });
  });

  group('which entries the register offers', () {
    test('cattle and equipment, newest first', () {
      final ledger = [
        _bought(id: 'old', on: DateTime(2026, 9, 1)),
        _bought(id: 'new', on: DateTime(2026, 10, 8)),
        _bought(id: 'kit', category: 'Equipment', on: DateTime(2026, 10, 2)),
      ];
      expect(cattleEntries(ledger, const []).map((t) => t.id), [
        'new',
        'kit',
        'old',
      ]);
    });

    test('feed and wages are not offered — they are not things the farm '
        'keeps', () {
      final ledger = [
        _bought(id: 'feed', category: 'Wanda / feed'),
        _bought(id: 'cattle'),
      ];
      expect(cattleEntries(ledger, const []).map((t) => t.id), ['cattle']);
    });

    test('an entry with nothing left on it drops off the list', () {
      final ledger = [_bought()];
      final full = [_animal(price: 1200000, on: 'e1')];
      expect(cattleEntries(ledger, full), isEmpty);
    });

    test('and so does a deleted one', () {
      expect(cattleEntries([_bought(deleted: true)], const []), isEmpty);
    });
  });

  group('what the books see', () {
    test('one entry, however many animals point at it', () {
      // The whole point. The ledger carries the purchase once, so the farm
      // owns twelve lakh of cattle and not eighty-four.
      final ledger = [_bought()];
      final books = Books(
        monthId: '2026-10',
        openingCash: 0,
        capital: 0,
        monthTxns: ledger,
        unpaidTxns: const [],
      );
      expect(books.assetsBought, 1200000);
      // And it is not a running cost: the farm has the cattle, it has not
      // spent the money away.
      expect(books.costs, 0);
    });
  });
}
