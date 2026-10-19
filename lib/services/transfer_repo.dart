import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../util/money.dart';
import 'db.dart';
import 'log_service.dart';
import 'txn_repo.dart';

/// Cash passing between two pairs of hands, with the other man's word on it.
///
/// The farm had a way of writing this down that took one man's word for both
/// halves of it. That is the one place in a book kept by four friends where
/// one word will not do — the whole reason the figure exists is so that
/// nobody has to take anybody's word for what he is holding.
///
/// So it is sent, and then it is taken, and nothing reaches the ledger in
/// between. What is waiting belongs to neither of them: it has left one pair
/// of hands and has not arrived in the other. The farm's own cash never moves
/// through any of this — the rupees are the farm's wherever they are sitting.
class TransferRepo {
  TransferRepo._();

  /// Hands money over. Anybody who keeps the books may do this; only the man
  /// it was sent to can say it arrived.
  static Future<String> send(
    Actor actor, {
    required String from,
    required String to,
    required num amount,
    PayVia payVia = PayVia.cash,
    String note = '',

    /// The entries this handover is made of, where the farm named them.
    List<String> txnIds = const [],
  }) async {
    if (amount <= 0) throw StateError('How much is being handed over?');
    if (partyKey(from) == partyKey(to)) {
      throw StateError('Those are the same person.');
    }

    final move = CashTransfer(
      id: '',
      from: from.trim(),
      to: to.trim(),
      amount: amount,
      state: TransferState.waiting,
      sentAt: DateTime.now(),
      payVia: payVia,
      note: note.trim(),
      sentBy: actor.uid,
      sentByName: actor.name,
      txnIds: txnIds,
    );

    final doc = await Db.transfers.add({
      ...move.toMap(),
      'sentAt': FieldValue.serverTimestamp(),
    });

    await Log.write(
      actor,
      LogKind.transaction,
      '$from handed ${rs(amount)} to $to — waiting on $to to say it arrived',
      refType: 'transfer',
      refId: doc.id,
    );
    return doc.id;
  }

  /// Whether this person may answer for a handover.
  ///
  /// Ordinarily the man it was sent to, and nobody else — that is the whole
  /// point of the second word. Money paid into the farm's own account is the
  /// exception, because the farm account has no hands: whoever keeps the
  /// cash answers for it, and so does the master. Never the sender, whatever
  /// else he is, or the second word is the first one again.
  static bool mayAnswer(
    CashTransfer move, {
    required String asName,
    required bool isMaster,
    required bool keepsFarmCash,
  }) {
    if (!move.isWaiting) return false;
    if (partyKey(move.to) == partyKey(farmAccountName)) {
      if (partyKey(move.from) == partyKey(asName)) return false;
      return isMaster || keepsFarmCash;
    }
    return partyKey(move.to) == partyKey(asName);
  }

  /// The man it was sent to says he has it.
  ///
  /// Only now does anything reach the ledger, and it reaches it as the pair
  /// of rows the books have always used for this: one hands over, the other
  /// takes in. They carry the day the money actually moved rather than the
  /// day somebody got round to opening the app, because that is the day it
  /// left the first man's hands.
  static Future<void> take(Actor actor, CashTransfer move) async {
    if (!move.isWaiting) return;

    await TxnRepo.handOver(
      actor,
      from: move.from,
      to: move.to,
      amount: move.amount,
      payVia: move.payVia,
      note: move.note,
      date: move.sentAt,
    );

    await Db.transfers.doc(move.id).update({
      'state': TransferState.taken.name,
      'decidedAt': FieldValue.serverTimestamp(),
      'decidedBy': actor.uid,
    });

    await Log.write(
      actor,
      LogKind.transaction,
      '${move.to} confirmed ${rs(move.amount)} from ${move.from}',
      refType: 'transfer',
      refId: move.id,
    );
  }

  /// He says he did not get it.
  ///
  /// Nothing is written to the books, because nothing happened in them: the
  /// money is still where it was. The record of the refusal stays on both
  /// their pages, which is the whole point — a disagreement about money
  /// between four friends is worth more written down than settled quietly.
  static Future<void> refuse(
    Actor actor,
    CashTransfer move, {
    String because = '',
  }) async {
    if (!move.isWaiting) return;

    await Db.transfers.doc(move.id).update({
      'state': TransferState.refused.name,
      'decidedAt': FieldValue.serverTimestamp(),
      'decidedBy': actor.uid,
      'because': because.trim(),
    });

    await Log.write(
      actor,
      LogKind.correction,
      '${move.to} says he did not get the ${rs(move.amount)} ${move.from} '
      'sent${because.trim().isEmpty ? '' : ' — ${because.trim()}'}',
      refType: 'transfer',
      refId: move.id,
    );
  }

  /// Taking back one that has not been answered yet. The sender's own.
  static Future<void> cancel(Actor actor, CashTransfer move) async {
    if (!move.isWaiting) return;
    await Db.transfers.doc(move.id).delete();
    await Log.write(
      actor,
      LogKind.transaction,
      'took back the ${rs(move.amount)} sent to ${move.to}',
      refType: 'transfer',
      refId: move.id,
    );
  }
}
