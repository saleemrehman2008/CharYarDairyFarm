import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers.dart';
import 'txn.dart';

/// Where a transfer has got to.
enum TransferState {
  /// Handed over and not yet acknowledged. It belongs to neither of them.
  waiting('On its way'),

  /// The man it was sent to has said he has it.
  taken('Taken'),

  /// He has said he has not. Nothing was written to the books.
  refused('Says he did not get it');

  const TransferState(this.label);

  final String label;

  static TransferState parse(Object? v) => switch (s(v)) {
    'taken' => TransferState.taken,
    'refused' => TransferState.refused,
    _ => TransferState.waiting,
  };

  bool get isWaiting => this == TransferState.waiting;
  bool get isTaken => this == TransferState.taken;
}

/// Cash passing from one pair of hands to another, with the other man's word
/// on it.
///
/// The farm already had a way to write down that money had moved between two
/// of them, and it took one man's word for both halves. That is the one place
/// in a book kept by four friends where one word is not enough: the whole
/// reason the figure exists is so that nobody has to take anybody's word for
/// what he is holding.
///
/// So it is sent, and then it is taken. In between it belongs to neither of
/// them — it has left the sender's hands and has not reached the receiver's —
/// and both their pages say so. The farm's cash does not move at all, because
/// the rupees are still the farm's wherever they are sitting; what is waiting
/// is only the answer to whose hands they are in.
///
/// Nothing is written to the ledger until it is taken. A refusal leaves no
/// trace in the books on purpose: no money moved, and a row saying it did
/// would have to be deleted afterwards by somebody.
class CashTransfer {
  CashTransfer({
    required this.id,
    required this.from,
    required this.to,
    required this.amount,
    required this.state,
    required this.sentAt,
    this.payVia = PayVia.cash,
    this.note = '',
    this.sentBy = '',
    this.sentByName = '',
    this.decidedAt,
    this.decidedBy = '',
    this.because = '',
    this.txnIds = const [],
  });

  final String id;

  /// Names, not ids. The farm's own account is a name like any other — see
  /// [farmAccountName] — and so is a worker who has never signed in.
  final String from;
  final String to;

  final num amount;
  final TransferState state;
  final DateTime sentAt;
  final PayVia payVia;
  final String note;

  /// Who typed it in, which is not always the man whose hands it left.
  final String sentBy;
  final String sentByName;

  final DateTime? decidedAt;
  final String decidedBy;

  /// What the man said when he refused it.
  final String because;

  /// The entries this handover is made of.
  ///
  /// A figure typed into a box says how much moved. These say which money it
  /// was — the four Urooj receipts Ghulam Ali took at the gate, rather than
  /// "8,600 from Ghulam Ali". Once they are named here they are spoken for,
  /// so nobody hands the same thousand rupees over twice, and each of those
  /// entries can say on its own face where the money went.
  ///
  /// Empty is allowed and always will be: a man may hand over a round sum
  /// out of a pocket that holds a dozen entries' worth.
  final List<String> txnIds;

  bool get isWaiting => state.isWaiting;

  Map<String, dynamic> toMap() => {
    'from': from,
    'to': to,
    'amount': amount,
    'state': state.name,
    'payVia': payVia.name,
    'note': note,
    'sentBy': sentBy,
    'sentByName': sentByName,
    'because': because,
    'txnIds': txnIds,
  };

  factory CashTransfer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return CashTransfer(
      id: doc.id,
      from: s(m['from']),
      to: s(m['to']),
      amount: n(m['amount']),
      state: TransferState.parse(m['state']),
      sentAt: dtOr(m['sentAt']),
      payVia: PayVia.parse(m['payVia']),
      note: s(m['note']),
      sentBy: s(m['sentBy']),
      sentByName: s(m['sentByName']),
      decidedAt: dt(m['decidedAt']),
      decidedBy: s(m['decidedBy']),
      because: s(m['because']),
      txnIds: [
        for (final v in (m['txnIds'] as List<dynamic>? ?? const []))
          if (s(v).isNotEmpty) s(v),
      ],
    );
  }
}

/// What is on its way out of one pair of hands, and into another.
num sentWaitingBy(List<CashTransfer> moves, String name) => moves
    .where((t) => t.isWaiting && partyKey(t.from) == partyKey(name))
    .fold<num>(0, (a, t) => a + t.amount);

num comingTo(List<CashTransfer> moves, String name) => moves
    .where((t) => t.isWaiting && partyKey(t.to) == partyKey(name))
    .fold<num>(0, (a, t) => a + t.amount);

/// Entries already named by a handover, so they are not offered twice.
///
/// A refused one lets its entries go again: the money never moved, so it is
/// still sitting where it was and is still his to hand over.
Set<String> alreadyHandedOn(List<CashTransfer> moves) => {
  for (final t in moves)
    if (t.state != TransferState.refused) ...t.txnIds,
};

/// Which handover an entry went out on, if any.
CashTransfer? handoverOf(List<CashTransfer> moves, String txnId) {
  for (final t in moves) {
    if (t.state == TransferState.refused) continue;
    if (t.txnIds.contains(txnId)) return t;
  }
  return null;
}

/// Everything still waiting on somebody's word, oldest first — the farm
/// should be asked about the one that has been sitting longest.
List<CashTransfer> waitingFor(List<CashTransfer> moves, String name) =>
    moves.where((t) => t.isWaiting && partyKey(t.to) == partyKey(name)).toList()
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
