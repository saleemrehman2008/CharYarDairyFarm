import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/models.dart';
import '../util/money.dart';
import 'db.dart';
import 'log_service.dart';
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
      'photoUrl': '',
      'dailyLitres': dailyLitres,
      'bornOn': ?_ts(bornOn),
      'boughtOn': ?_ts(boughtOn),
      'price': price,
      'motherId': ?mother?.id,
      'motherTag': ?mother?.tag,
      'note': note,
      'createdBy': actor.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final url = await _putPhoto(doc.id, photo);
    await doc.update({'photoUrl': url});

    String? txnId;
    if (price > 0 && bookPurchase) {
      final on = boughtOn ?? DateTime.now();
      txnId = await TxnRepo.add(
        actor: actor,
        monthId: monthIdOf(on),
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

    if (price > 0) {
      await _writeEvent(
        actor,
        animalId: doc.id,
        animalTag: tag,
        kind: EventKind.bought,
        date: boughtOn ?? DateTime.now(),
        what: 'Bought for ${rs(price)}',
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
    final url = await _putPhoto(animal.id, file);
    await Db.animals.doc(animal.id).update({'photoUrl': url});
    await Log.write(
      actor,
      LogKind.cattle,
      'updated the photo for ${animal.tag}',
      refType: 'animal',
      refId: animal.id,
    );
    return url;
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
        monthId: monthIdOf(date),
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
  static Future<void> reinstate(Actor actor, Animal animal) async {
    await Db.animals.doc(animal.id).update({
      'status': AnimalStatus.onFarm.name,
    });
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
        monthId: monthIdOf(date),
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
      'photoUrl': '',
      'byName': actor.name,
      'byUid': actor.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (photo != null) {
      try {
        final url = await _putPhoto('events/${doc.id}', photo);
        await doc.update({'photoUrl': url});
      } catch (_) {
        // The line itself matters more than the picture attached to it.
      }
    }

    await Db.animals.doc(animalId).set({
      'lastEventAt': Timestamp.fromDate(date),
      ...updateAnimal,
    }, SetOptions(merge: true));
  }

  static Future<String> _putPhoto(String path, File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    final ref = FirebaseStorage.instance.ref(
      'animals/$path.${ext.isEmpty ? 'jpg' : ext}',
    );
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  static Timestamp? _ts(DateTime? d) =>
      d == null ? null : Timestamp.fromDate(d);
}
