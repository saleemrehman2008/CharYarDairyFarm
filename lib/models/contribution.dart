import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers.dart';
import 'txn.dart';

/// Whether the farm keeps this money or has to give it back.
enum ContributionKind {
  /// His own money, in for good. Counts towards what he promised.
  investment('Investment'),

  /// His own money, lent for the moment. The farm owes it back, and it
  /// counts towards nothing — not his promise, and not his share.
  ///
  /// This is the ordinary shape of "he paid for the feed out of his pocket
  /// on Tuesday". Whether it stays a loan or becomes part of what he
  /// promised is a decision the four of them make afterwards, and the app
  /// turns one into the other in a single tap.
  loan('To be returned');

  const ContributionKind(this.label);

  final String label;

  static ContributionKind parse(Object? v) =>
      s(v) == 'loan' ? ContributionKind.loan : ContributionKind.investment;
}

/// Where the money went on its way in.
enum ContributionSource {
  /// Handed to whoever keeps the farm's cash.
  cash('Handed over'),

  /// Paid straight out for something the farm bought, without passing
  /// through anybody's hands — three pockets to the cattle market.
  spent('Paid for something'),

  /// What the record already said before any of this was kept.
  ///
  /// Never written down: it is worked out as the difference between what
  /// the card says and what the lines come to, and shown at the foot of the
  /// list so that the lines always add up to the total. Writing it would
  /// have meant a migration that could double somebody's capital if it ran
  /// twice, for a figure the app can see plainly without one.
  opening('Already recorded'),

  /// The master putting a figure right.
  correction('Corrected');

  const ContributionSource(this.label);

  final String label;

  static ContributionSource parse(Object? v) => switch (s(v)) {
    'spent' => ContributionSource.spent,
    'opening' => ContributionSource.opening,
    'correction' => ContributionSource.correction,
    _ => ContributionSource.cash,
  };
}

/// One payment of a co-founder's own money into the farm.
///
/// The farm was started by four friends who could not put their whole shares
/// in on one day. They are paying as they can — some of it handed to whoever
/// is keeping the cash, and a great deal of it spent straight on cattle and
/// feed, two or three of them clubbing together for the big purchases. What
/// the app had was a single number on each man's card that the master typed
/// over, and the farm's own rule for this is now plain: **nobody's figure
/// moves without a line behind it.**
///
/// So every rupee has one of these: how much, whose, what day, where it went
/// and who recorded it. What each of them has put in is the sum of his lines
/// and nothing else, which makes it a figure four friends can argue with —
/// and settle — a year from now.
class Contribution {
  Contribution({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    required this.kind,
    required this.source,
    required this.amount,
    required this.date,
    this.payVia = PayVia.cash,
    this.receivedBy = '',
    this.txnId,
    this.note = '',
    this.createdBy = '',
    this.createdByName = '',
    required this.createdAt,
    this.deletedAt,
  });

  final String id;
  final String partnerId;

  /// The name as it stood when this was written, so a line still reads
  /// properly after a record is renamed.
  final String partnerName;

  final ContributionKind kind;
  final ContributionSource source;
  final num amount;

  /// The day the money moved, not the day somebody typed it in. A split of
  /// a purchase made in October takes that purchase's own date.
  final DateTime date;

  final PayVia payVia;

  /// Who took the money, when it was handed to somebody. Empty when it was
  /// paid straight out for something — then it passed through nobody's
  /// hands and nobody's holding should move because of it.
  final String receivedBy;

  /// The entry this paid for, when it was a share of one.
  ///
  /// Both ends point at each other: the entry's own page lists who paid it,
  /// and each line here says what it bought. Seventeen lakh of cattle, three
  /// men, one purchase — and no way to lose track of which part was whose.
  final String? txnId;

  final String note;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  /// Money the farm keeps, which is what a share is worked out against.
  bool get isInvestment => kind == ContributionKind.investment;

  /// Money the farm has to give back.
  bool get isLoan => kind == ContributionKind.loan;

  /// It passed through somebody's hands on the way in.
  bool get wasHandedOver =>
      source == ContributionSource.cash && receivedBy.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
    'partnerId': partnerId,
    'partnerName': partnerName,
    'kind': kind.name,
    'source': source.name,
    'amount': amount,
    'date': Timestamp.fromDate(date),
    'payVia': payVia.name,
    'receivedBy': receivedBy,
    'txnId': ?txnId,
    'note': note,
    'createdBy': createdBy,
    'createdByName': createdByName,
  };

  factory Contribution.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return Contribution(
      id: doc.id,
      partnerId: s(m['partnerId']),
      partnerName: s(m['partnerName']),
      kind: ContributionKind.parse(m['kind']),
      source: ContributionSource.parse(m['source']),
      amount: n(m['amount']),
      date: dtOr(m['date']),
      payVia: PayVia.parse(m['payVia']),
      receivedBy: s(m['receivedBy']),
      txnId: m['txnId'] == null ? null : s(m['txnId']),
      note: s(m['note']),
      createdBy: s(m['createdBy']),
      createdByName: s(m['createdByName']),
      createdAt: dtOr(m['createdAt']),
      deletedAt: dt(m['deletedAt']),
    );
  }
}

/// What one person has put in, out of a list of lines.
num investedFrom(List<Contribution> lines, String partnerId) => lines
    .where((c) => !c.isDeleted && c.isInvestment && c.partnerId == partnerId)
    .fold<num>(0, (a, c) => a + c.amount);

/// What the farm owes one person — money of theirs it is holding and has
/// not been told to keep.
num owedToFrom(List<Contribution> lines, String partnerId) => lines
    .where((c) => !c.isDeleted && c.isLoan && c.partnerId == partnerId)
    .fold<num>(0, (a, c) => a + c.amount);

/// Who paid for one entry, and how much of it each of them paid.
List<Contribution> paidFor(List<Contribution> lines, String txnId) =>
    lines.where((c) => !c.isDeleted && c.txnId == txnId).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
