import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers.dart';

/// Where a loan has got to.
///
/// Asked for, handed over, paid off. A request that is turned down is kept
/// rather than deleted — four friends in business should be able to look back
/// at what was asked and what was said, and a record that only holds the
/// answers somebody liked is not a record.
enum LoanState {
  asked('Asked for'),
  given('Running'),
  cleared('Paid off'),
  refused('Not given');

  const LoanState(this.label);

  final String label;

  static LoanState parse(Object? v) => switch (s(v)) {
    'given' => LoanState.given,
    'cleared' => LoanState.cleared,
    'refused' => LoanState.refused,
    _ => LoanState.asked,
  };

  bool get isOpen => this == LoanState.given;
}

/// Money the farm has lent one of its own.
///
/// It is not a cost and it is not income — the farm is out the cash and the
/// founder owes it, and both of those are true at once. Booking it as an
/// expense, which is the obvious thing to reach for, would drop that month's
/// profit by the whole loan and cut all four co-founders' shares for money
/// that one of them is going to repay.
///
/// No interest. It is a loan between four friends and they have said so, and
/// the app does not offer a field for it.
///
/// The instalment comes off what they are handed at a close. In a month where
/// nothing is handed out — which is every month of the first year, by their
/// own agreement — there is nothing to take it from, so it is skipped and the
/// term runs on. They can pay it in themselves any time instead.
class FounderLoan {
  FounderLoan({
    required this.id,
    required this.partnerId,
    required this.name,
    required this.amount,
    required this.months,
    required this.state,
    required this.askedAt,
    this.givenAt,
    this.note = '',
    this.repaid = 0,
  });

  final String id;
  final String partnerId;
  final String name;

  /// What was asked for, and what has to come back.
  final num amount;

  /// How many months they want to spread it over.
  final int months;

  final LoanState state;
  final DateTime askedAt;
  final DateTime? givenAt;
  final String note;

  /// How much has come back, from instalments and from anything they have
  /// paid in themselves. Read off the ledger rather than stored, so a
  /// repayment entered by hand counts the same as one the close took.
  final num repaid;

  /// What one month's instalment comes to.
  ///
  /// The odd rupee rides on the last month rather than being spread, because
  /// a figure somebody is going to check against their own arithmetic should
  /// be the one they would get.
  num get instalment => months <= 0 ? amount : (amount / months).round();

  num get left {
    final owing = amount - repaid;
    return owing > 0 ? owing : 0;
  }

  bool get isCleared => left <= 0;

  /// How much of it is behind them, for the bar.
  double get done => amount <= 0 ? 1 : (repaid / amount).clamp(0, 1).toDouble();

  FounderLoan withRepaid(num paid) => FounderLoan(
    id: id,
    partnerId: partnerId,
    name: name,
    amount: amount,
    months: months,
    state: state,
    askedAt: askedAt,
    givenAt: givenAt,
    note: note,
    repaid: paid,
  );

  factory FounderLoan.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return FounderLoan(
      id: doc.id,
      partnerId: s(m['partnerId']),
      name: s(m['name']),
      amount: n(m['amount']),
      months: n(m['months']).round(),
      state: LoanState.parse(m['state']),
      askedAt: dtOr(m['askedAt']),
      givenAt: dt(m['givenAt']),
      note: s(m['note']),
    );
  }
}
