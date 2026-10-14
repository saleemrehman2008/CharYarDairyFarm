import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../util/money.dart';
import 'db.dart';
import 'log_service.dart';
import 'photo_store.dart';
import 'month_repo.dart';
import 'txn_repo.dart';

/// The cattle register: what the farm owns on four legs.
///
/// Every animal gets a tag number the day it arrives — `B-03`, `G-11` — and
/// that number goes on its ear and on every line of its history. A photo is
/// required, because a tag can fall off and a written description of a black
/// buffalo is worth nothing.
///
/// Money never lives in two places. A vet visit or an insemination booked here
/// is written into the farm's books as a real expense, and the animal keeps
/// the id of that entry, so the ledger and the register can always be checked
/// against each other.
/// What of a cattle purchase has already been given to animals on the
/// register, and what is left of it.
///
/// Four cows and three calves come home on one day for one price. That is
/// one entry in the books and seven animals in the register, and the thing
/// that goes wrong — the farm hit it on the first week — is that registering
/// each of the seven books the money again. Seven times over, out of a farm
/// that paid once.
///
/// So the money is entered once, and each animal takes a share of that one
/// entry. These two say how much of it is spoken for and how much is not, and
/// the form refuses a share larger than what is left. It matters beyond the
/// register: when an animal dies or is sold she comes off the books at what
/// she cost, so the shares have to add up to the entry or the asset never
/// comes back to nothing.
num cattleAssigned(List<Animal> animals, String txnId) => animals
    .where((a) => a.purchaseTxnId == txnId)
    .fold<num>(0, (a, animal) => a + animal.price);

num cattleLeftOn(Txn entry, List<Animal> animals, {Animal? except}) {
  final taken = animals
      .where((a) => a.purchaseTxnId == entry.id && a.id != except?.id)
      .fold<num>(0, (a, animal) => a + animal.price);
  final left = entry.amount - taken;
  return left > 0 ? left : 0;
}

/// The entry the register wrote for this animal all by itself, if there is
/// one, and if it can be told apart from a real one.
///
/// This is the cleanup for the seven animals registered before any of this
/// existed. Each of them had its price written into the ledger a second time
/// under its own tag, so the money is in the books twice and the farm should
/// not have to go hunting for the duplicates by hand.
///
/// Three things have to hold together before a row is offered for deletion,
/// because deleting money on a guess is worse than leaving it:
///
///  * it is a cattle or equipment purchase, not a feed bill;
///  * it is for exactly what this animal cost, which is how the register
///    wrote it — one animal, one price;
///  * and it is named after this animal, under her tag.
///
/// On top of that the caller checks no other animal is leaning on it. A row
/// that fails any of these is somebody's own entry and is left alone.
Txn? registerWrittenEntry(List<Txn> ledger, Animal animal) {
  if (animal.price <= 0) return null;
  final tag = animal.tag;
  for (final t in ledger) {
    if (t.isDeleted || !t.isCapitalAsset) continue;
    if (t.amount != animal.price) continue;
    final party = t.party.trim();
    if (party == tag || party == animal.label || t.note.trim().endsWith(tag)) {
      return t;
    }
  }
  return null;
}

/// The entries an animal can be registered against: cattle and equipment
/// bought, newest first, the ones with nothing left on them dropped.
List<Txn> cattleEntries(List<Txn> ledger, List<Animal> animals) =>
    ledger
        .where((t) => !t.isDeleted && t.isCapitalAsset)
        .where((t) => cattleLeftOn(t, animals) > 0)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

class AnimalRepo {
  AnimalRepo._();

  /// The next tag for this kind of animal: B-01, B-02, C-01…
  ///
  /// Counted per species on `settings/farm`, in a transaction, so two people
  /// registering a calf at the same moment cannot end up with one tag between
  /// them.
  static Future<String> nextTag(Species species) async {
    final letter = species.tagLetter;
    try {
      return await Db.fs.runTransaction<String>((tx) async {
        final snap = await tx.get(Db.farmSettings);
        final seqs =
            (snap.data() ?? const {})['animalSeq'] as Map<String, dynamic>?;
        final next = (((seqs?[letter]) as num?) ?? 0).toInt() + 1;
        tx.set(Db.farmSettings, {
          'animalSeq': {letter: next},
        }, SetOptions(merge: true));
        return formatTag(letter, next);
      });
    } catch (_) {
      // The counter is unreachable. Better an odd-looking tag than a refusal
      // to register the animal standing in front of you.
      final n = DateTime.now().millisecondsSinceEpoch.remainder(1000);
      return formatTag(letter, n);
    }
  }

  /// `B-03`, and `B-142` once the farm gets that far.
  static String formatTag(String letter, int number) =>
      '$letter-${number.toString().padLeft(2, '0')}';

  /// Registers an animal. The photo is not optional.
  ///
  /// A bought animal with a price is booked as a cattle purchase, which the
  /// books treat as something the farm owns rather than money burnt — unless
  /// the purchase was already entered by hand, in which case pass
  /// [bookPurchase] false.
  ///
  /// Better than that: pass [purchaseTxnId] and the animal is tied to the
  /// entry the money actually went out on. Nothing is booked, [price] is read
  /// as this animal's share of that entry, and the register and the ledger
  /// can be read back against each other afterwards. See [cattleLeftOn].
  static Future<Animal> add(
    Actor actor, {
    required Species species,
    required Sex sex,
    required File photo,
    String name = '',
    DateTime? bornOn,
    DateTime? boughtOn,
    num price = 0,
    Animal? mother,
    String note = '',
    num dailyLitres = 0,
    bool bookPurchase = true,
    String? purchaseTxnId,
    PayVia payVia = PayVia.cash,
    String handledBy = '',
  }) async {
    final tag = await nextTag(species);

    final doc = await Db.animals.add({
      'tag': tag,
      'name': name,
      'species': species.name,
      'sex': sex.name,
      'status': AnimalStatus.onFarm.name,
      'thumb': '',
      'dailyLitres': dailyLitres,
      'bornOn': ?_ts(bornOn),
      'boughtOn': ?_ts(boughtOn),
      'price': price,
      'motherId': ?mother?.id,
      'motherTag': ?mother?.tag,
      'purchaseTxnId': ?purchaseTxnId,
      'note': note,
      'createdBy': actor.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await doc.update({'thumb': await _putPhoto(doc.id, photo)});

    // Tied to an entry that is already in the books: nothing is written to
    // the ledger, because the money left the farm once and is already there.
    var txnId = purchaseTxnId;
    if (price > 0 && bookPurchase && purchaseTxnId == null) {
      final on = boughtOn ?? DateTime.now();
      txnId = await TxnRepo.add(
        actor: actor,
        monthId: MonthRepo.bookingId,
        type: TxnType.purchase,
        party: name.isEmpty ? tag : '$tag $name',
        // An asset category: the farm owns the animal, it has not spent the
        // money away.
        category: 'Cattle purchase',
        amount: price,
        paid: true,
        note: '${species.label} $tag',
        payVia: payVia,
        handledBy: handledBy,
        date: on,
      );
    }

    // An entry written here belongs on the animal too, so the register and
    // the ledger point at each other from both ends.
    if (purchaseTxnId == null && txnId != null) {
      await doc.update({'purchaseTxnId': txnId});
    }

    if (price > 0) {
      await _writeEvent(
        actor,
        animalId: doc.id,
        animalTag: tag,
        kind: EventKind.bought,
        date: boughtOn ?? DateTime.now(),
        what: purchaseTxnId == null
            ? 'Bought for ${rs(price)}'
            : 'Bought for ${rs(price)} — part of one entry already in the '
                  'books, not booked again',
        cost: price,
        txnId: txnId,
      );
    }

    await Log.write(
      actor,
      LogKind.cattle,
      'registered $tag'
      '${name.isEmpty ? '' : ' ($name)'}, a ${species.label.toLowerCase()}'
      '${price > 0 ? ' bought for ${rs(price)}' : ''}',
      refType: 'animal',
      refId: doc.id,
    );

    final snap = await doc.get();
    return Animal.fromDoc(snap);
  }

  /// Replaces the animal's photo — she grows, and tags get replaced.
  static Future<String> setPhoto(Actor actor, Animal animal, File file) async {
    final thumb = await _putPhoto(animal.id, file);
    await Db.animals.doc(animal.id).update({'thumb': thumb});
    await Log.write(
      actor,
      LogKind.cattle,
      'updated the photo for ${animal.tag}',
      refType: 'animal',
      refId: animal.id,
    );
    return thumb;
  }

  /// Name, note and the dates — the things that get corrected after the fact.
  static Future<void> edit(
    Actor actor,
    Animal animal, {
    String? name,
    String? note,
    DateTime? bornOn,
    num? dailyLitres,
  }) async {
    await Db.animals.doc(animal.id).update({
      'name': ?name,
      'note': ?note,
      'bornOn': ?_ts(bornOn),
      'dailyLitres': ?dailyLitres,
    });
    await Log.write(
      actor,
      LogKind.cattle,
      'updated ${animal.tag}',
      refType: 'animal',
      refId: animal.id,
    );
  }

  /// Correcting the record of an animal, which is the master's.
  ///
  /// The farm's own case: somebody registered a cow as a buffalo. Every
  /// figure built on a kind of animal is then wrong, and so is the letter on
  /// her ear — a cow tagged B-05 is a cow nobody can look up.
  ///
  /// So the species can be corrected, and with [retag] she is given a tag out
  /// of the right letter's run. Her old tag is kept in what is written to her
  /// history, because the number is painted on her ear and somebody has to be
  /// able to work out which animal this used to be.
  ///
  /// What is not here is the price, when the money is in the books. That
  /// figure belongs to a ledger entry and is corrected there, under the same
  /// rules as every other entry — a price changed in two places is a price
  /// that will disagree with itself by the end of the month.
  static Future<Animal> correct(
    Actor actor,
    Animal animal, {
    String? name,
    Species? species,
    Sex? sex,
    DateTime? bornOn,
    DateTime? boughtOn,
    num? price,
    num? dailyLitres,
    String? note,

    /// A number typed out by hand — `C-04` — for when the farm wants this
    /// animal to carry a particular one. Refused if another animal already
    /// has it: two animals under one number is a register that cannot be
    /// read, and the ear tag is the whole point of the thing.
    String? tag,
    bool retag = false,

    /// Tie her to the ledger entry her price was really paid on.
    ///
    /// For the animals registered before the register could say so — the
    /// four cows and three calves whose one payment got booked seven times.
    /// The duplicate entries are deleted under Accounts; this is what puts
    /// the animals back on the one that is left.
    String? linkTo,

    /// Whose calf she is. For the calves registered on their own, which the
    /// register then had no way of tying to their mother — so her page said
    /// nothing about them and theirs said nothing about her.
    Animal? mother,
    bool clearMother = false,
  }) async {
    final changes = <String>[];
    final fresh = <String, dynamic>{};

    void moved(String what, Object? was, Object? now, String key) {
      if (now == null || was == now) return;
      fresh[key] = now;
      changes.add('$what ${_said(was)} to ${_said(now)}');
    }

    moved('Name', animal.name, name?.trim(), 'name');
    moved('Note', animal.note, note?.trim(), 'note');
    moved('Price', animal.price, price, 'price');
    moved('Milk a day', animal.dailyLitres, dailyLitres, 'dailyLitres');

    if (species != null && species != animal.species) {
      fresh['species'] = species.name;
      changes.add('Kind ${animal.species.label} to ${species.label}');
    }
    if (sex != null && sex != animal.sex) {
      fresh['sex'] = sex.name;
      changes.add('Sex ${animal.sex.label} to ${sex.label}');
    }
    if (bornOn != null && bornOn != animal.bornOn) {
      fresh['bornOn'] = Timestamp.fromDate(bornOn);
      changes.add('Born ${_day(animal.bornOn)} to ${fmtDateFull(bornOn)}');
    }
    if (boughtOn != null && boughtOn != animal.boughtOn) {
      fresh['boughtOn'] = Timestamp.fromDate(boughtOn);
      changes.add(
        'Bought ${_day(animal.boughtOn)} to ${fmtDateFull(boughtOn)}',
      );
    }

    if (clearMother && animal.motherId != null) {
      fresh['motherId'] = FieldValue.delete();
      fresh['motherTag'] = FieldValue.delete();
      changes.add('Out of ${animal.motherTag} to nobody');
    } else if (mother != null && mother.id != animal.motherId) {
      // Nothing is its own mother, and a register that says otherwise is one
      // nobody can draw a line through.
      if (mother.id == animal.id) {
        throw StateError('An animal cannot be its own mother.');
      }
      fresh['motherId'] = mother.id;
      fresh['motherTag'] = mother.tag;
      changes.add('Out of ${animal.motherTag ?? 'nobody'} to ${mother.tag}');
    }

    if (linkTo != null && linkTo != animal.purchaseTxnId) {
      fresh['purchaseTxnId'] = linkTo;
      changes.add('Tied to the entry it was paid on');
    }

    // The number on her ear. Either one typed out by hand, or the next one
    // out of the corrected letter's run. The old number is not handed back:
    // it is on an ear somewhere in the farm's photographs, and giving it to a
    // second animal would make the register unreadable.
    var current = animal.tag;
    final kind = species ?? animal.species;
    final typed = tag?.trim().toUpperCase();

    if (typed != null && typed.isNotEmpty && typed != animal.tag) {
      // Asked of the register itself rather than of whatever this phone has
      // loaded, because two people can be correcting two animals at once.
      final taken = await Db.animals.where('tag', isEqualTo: typed).get();
      final clash = taken.docs.where((d) => d.id != animal.id);
      if (clash.isNotEmpty) {
        throw StateError('$typed is already on another animal.');
      }
      fresh['tag'] = typed;
      changes.add('Tag ${animal.tag} to $typed');
      current = typed;
    } else if (retag && kind.tagLetter != animal.tag.split('-').first) {
      current = await nextTag(kind);
      fresh['tag'] = current;
      changes.add('Tag ${animal.tag} to $current');
    }

    if (changes.isEmpty) return animal;

    await Db.animals.doc(animal.id).update(fresh);

    // On her own page as well as in the log, because the question "why does
    // this say cow when the ear says B" is asked standing in the shed.
    await _writeEvent(
      actor,
      animalId: animal.id,
      animalTag: current,
      kind: EventKind.note,
      date: DateTime.now(),
      what: 'Record corrected — ${changes.join(', ')}',
      cost: 0,
    );

    await Log.write(
      actor,
      LogKind.correction,
      'corrected ${animal.tag} — ${changes.join(', ')}',
      refType: 'animal',
      refId: animal.id,
    );

    final snap = await Db.animals.doc(animal.id).get();
    return Animal.fromDoc(snap);
  }

  static String _said(Object? v) {
    if (v == null) return '—';
    if (v is num) return groupPk(v);
    final text = v.toString().trim();
    return text.isEmpty ? '—' : text;
  }

  static String _day(DateTime? d) => d == null ? '—' : fmtDateFull(d);

  /// An animal leaves the farm: sold, died, or slaughtered.
  ///
  /// The record stays. A sale with a price is booked as income the same way a
  /// purchase is booked as an asset.
  static Future<void> setStatus(
    Actor actor,
    Animal animal, {
    required AnimalStatus status,
    num price = 0,
    String what = '',
    DateTime? on,
    bool bookSale = true,
    PayVia payVia = PayVia.cash,
    String handledBy = '',
  }) async {
    final date = on ?? DateTime.now();

    String? txnId;
    if (status == AnimalStatus.sold && price > 0 && bookSale) {
      txnId = await TxnRepo.add(
        actor: actor,
        monthId: MonthRepo.bookingId,
        type: TxnType.sale,
        party: animal.label,
        category: 'Cattle sale',
        amount: price,
        paid: true,
        note: '${animal.species.label} ${animal.tag}',
        payVia: payVia,
        handledBy: handledBy,
        date: date,
      );
    }

    // Off the books at what she cost. A sale of Rs 200,000 on a buffalo
    // bought for Rs 150,000 earned the farm Rs 50,000, not Rs 200,000 — the
    // rest is the co-founders' own money coming back, and sharing that out
    // as profit would be paying them with their own capital. A death earns
    // nothing and this is the whole of it: a real loss, in the period it
    // happened.
    //
    // Nothing is written for an animal born here. She cost nothing to come
    // by, so there is nothing to give up.
    if (animal.price > 0) {
      await TxnRepo.add(
        actor: actor,
        monthId: MonthRepo.bookingId,
        type: TxnType.expense,
        party: animal.label,
        category: writeOffCategory,
        amount: animal.price,
        paid: true,
        note:
            '${animal.species.label} ${animal.tag} — '
            '${status.label.toLowerCase()}, off the books at what she cost',
        date: date,
      );
    }

    await Db.animals.doc(animal.id).update({
      'status': status.name,
      'dailyLitres': 0,
      'nextDueOn': null,
      'nextDueWhat': null,
    });

    await _writeEvent(
      actor,
      animalId: animal.id,
      animalTag: animal.tag,
      kind: switch (status) {
        AnimalStatus.sold => EventKind.sold,
        AnimalStatus.dead || AnimalStatus.slaughtered => EventKind.died,
        AnimalStatus.onFarm => EventKind.note,
      },
      date: date,
      what: what.isEmpty ? status.label : what,
      cost: 0,
      txnId: txnId,
      earned: status == AnimalStatus.sold ? price : 0,
    );

    await Log.write(
      actor,
      LogKind.cattle,
      '${animal.tag} — ${status.label.toLowerCase()}'
      '${price > 0 ? ' for ${rs(price)}' : ''}',
      refType: 'animal',
      refId: animal.id,
    );
  }

  /// Puts an animal back on the farm — for when a status was picked in error.
  ///
  /// The write-off goes with her: she is back in the shed, so the farm owns
  /// her again and the cost of losing her was never real. A sale row, if
  /// there was one, is left alone — money did change hands, and only the
  /// master can say it did not.
  static Future<void> reinstate(Actor actor, Animal animal) async {
    await Db.animals.doc(animal.id).update({
      'status': AnimalStatus.onFarm.name,
    });

    try {
      final written = await Db.transactions
          .where('category', isEqualTo: writeOffCategory)
          .where('party', isEqualTo: animal.label)
          .get();
      for (final doc in written.docs) {
        if (Txn.fromDoc(doc).isDeleted) continue;
        await doc.reference.update({'deletedAt': FieldValue.serverTimestamp()});
      }
    } catch (_) {
      // Worst case the write-off stays and the master deletes it by hand.
    }
    await Log.write(
      actor,
      LogKind.cattle,
      'put ${animal.tag} back on the farm',
      refType: 'animal',
      refId: animal.id,
    );
  }

  /// Adds a line to an animal's history.
  ///
  /// Anything with a cost is booked into the books as a vet expense unless the
  /// caller says it was already entered. A milk reading updates what the
  /// animal is giving; a vaccination sets when the next one falls due.
  static Future<void> logEvent(
    Actor actor,
    Animal animal, {
    required EventKind kind,
    required DateTime date,
    required String what,
    num cost = 0,
    num litres = 0,
    num weightKg = 0,
    DateTime? nextDueOn,
    File? photo,
    bool bookCost = true,
    PayVia payVia = PayVia.cash,
    String handledBy = '',
  }) async {
    String? txnId;
    if (cost > 0 && bookCost) {
      txnId = await TxnRepo.add(
        actor: actor,
        monthId: MonthRepo.bookingId,
        type: TxnType.purchase,
        party: animal.label,
        category: 'Vet & medicine',
        amount: cost,
        paid: true,
        note: '${kind.label} · ${animal.tag}${what.isEmpty ? '' : ' · $what'}',
        payVia: payVia,
        handledBy: handledBy,
        date: date,
      );
    }

    await _writeEvent(
      actor,
      animalId: animal.id,
      animalTag: animal.tag,
      kind: kind,
      date: date,
      what: what,
      cost: cost,
      litres: litres,
      weightKg: weightKg,
      nextDueOn: nextDueOn,
      txnId: txnId,
      photo: photo,
      updateAnimal: {
        if (kind == EventKind.milkReading) 'dailyLitres': litres,
        if (nextDueOn != null) ...{
          'nextDueOn': Timestamp.fromDate(nextDueOn),
          'nextDueWhat': kind.label,
        },
      },
    );

    await Log.write(
      actor,
      LogKind.cattle,
      '${animal.tag}: ${kind.label.toLowerCase()}'
      '${what.isEmpty ? '' : ' — $what'}'
      '${cost > 0 ? ' (${rs(cost)})' : ''}',
      refType: 'animal',
      refId: animal.id,
    );
  }

  /// A birth: the calf joins the register with its own tag, and the mother's
  /// history records the day.
  static Future<Animal> recordBirth(
    Actor actor,
    Animal mother, {
    required Species species,
    required Sex sex,
    required File photo,
    required DateTime date,
    String name = '',
    String what = '',
  }) async {
    final calf = await add(
      actor,
      species: species,
      sex: sex,
      photo: photo,
      name: name,
      bornOn: date,
      mother: mother,
      note: what,
    );

    await _writeEvent(
      actor,
      animalId: mother.id,
      animalTag: mother.tag,
      kind: EventKind.calving,
      date: date,
      what: what.isEmpty
          ? 'Gave birth to ${calf.tag} (${sex.label.toLowerCase()})'
          : what,
      cost: 0,
      calfId: calf.id,
      calfTag: calf.tag,
      // A birth clears whatever check was pending; the next one is set after.
      updateAnimal: const {'nextDueOn': null, 'nextDueWhat': null},
    );

    await Log.write(
      actor,
      LogKind.cattle,
      '${mother.tag} gave birth — ${calf.tag} registered',
      refType: 'animal',
      refId: mother.id,
    );

    return calf;
  }

  /// A calf that came with a buffalo the farm bought, rather than one born
  /// here.
  ///
  /// Almost the same thing on paper and not the same thing at all in the
  /// register. Writing it down as a birth puts a calving on the mother's
  /// record on the day she arrived, which never happened — and her record is
  /// the thing four partners will be reading a year from now to work out what
  /// she has been worth.
  ///
  /// She costs nothing of her own. The price was paid for the pair and the
  /// whole of it already sits on the mother, so booking anything here would
  /// be the same money on the books twice. It comes right by itself: the day
  /// the mother goes, the whole price comes off, and whatever the calf then
  /// fetches is all earnings — over the two of them the farm is out exactly
  /// what it paid and in exactly what it got.
  static Future<Animal> recordCameWith(
    Actor actor,
    Animal mother, {
    required Species species,
    required Sex sex,
    required File photo,
    required DateTime date,
    String name = '',
    String what = '',
  }) async {
    final calf = await add(
      actor,
      species: species,
      sex: sex,
      photo: photo,
      name: name,
      bornOn: date,
      mother: mother,
      note: what,
    );

    await _writeEvent(
      actor,
      animalId: mother.id,
      animalTag: mother.tag,
      kind: EventKind.note,
      date: date,
      what: what.isEmpty
          ? 'Came with a calf — ${calf.tag} (${sex.label.toLowerCase()}), '
                'no separate price'
          : what,
      cost: 0,
      calfId: calf.id,
      calfTag: calf.tag,
    );

    await Log.write(
      actor,
      LogKind.cattle,
      '${calf.tag} registered — came with ${mother.tag}',
      refType: 'animal',
      refId: mother.id,
    );

    return calf;
  }

  // ---- internals ----

  static Future<void> _writeEvent(
    Actor actor, {
    required String animalId,
    required String animalTag,
    required EventKind kind,
    required DateTime date,
    required String what,
    required num cost,
    num litres = 0,
    num weightKg = 0,
    num earned = 0,
    DateTime? nextDueOn,
    String? txnId,
    String? calfId,
    String? calfTag,
    File? photo,
    Map<String, Object?> updateAnimal = const {},
  }) async {
    final doc = await Db.animalEvents.add({
      'animalId': animalId,
      'animalTag': animalTag,
      'kind': kind.name,
      'date': Timestamp.fromDate(date),
      'what': what,
      'cost': cost,
      'earned': earned,
      'litres': litres,
      'weightKg': weightKg,
      'nextDueOn': ?_ts(nextDueOn),
      'txnId': ?txnId,
      'calfId': ?calfId,
      'calfTag': ?calfTag,
      'thumb': '',
      'byName': actor.name,
      'byUid': actor.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (photo != null) {
      try {
        await doc.update({'thumb': await _putPhoto('evt_${doc.id}', photo)});
      } catch (_) {
        // The line itself matters more than the picture attached to it.
      }
    }

    await Db.animals.doc(animalId).set({
      'lastEventAt': Timestamp.fromDate(date),
      ...updateAnimal,
    }, SetOptions(merge: true));
  }

  /// Shrinks a photo and files it: the thumbnail onto the record itself, the
  /// bigger one into its own document so a list never drags it along.
  ///
  /// Returns the thumbnail, which is what the caller writes to the record.
  static Future<String> _putPhoto(String photoId, File file) async {
    final photo = await Photos.prepare(file);
    await Db.animalPhotos.doc(photoId).set({
      'data': photo.full,
      'at': FieldValue.serverTimestamp(),
    });
    return photo.thumb;
  }

  static Timestamp? _ts(DateTime? d) =>
      d == null ? null : Timestamp.fromDate(d);
}
