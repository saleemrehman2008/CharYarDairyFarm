import '../models/models.dart';

/// One line of a statement: what happened, and what the balance was after it.
class StatementLine {
  const StatementLine({
    required this.date,
    required this.party,
    required this.detail,
    required this.enteredBy,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  final DateTime date;
  final String party;
  final String detail;
  final String enteredBy;

  /// Exactly one of these is more than zero on an ordinary line.
  final num debit;
  final num credit;

  /// What the running balance stood at once this line had happened.
  final num balance;
}

/// A statement of account, read the way a bank statement is read.
///
/// Two of them, really, and which one you get depends on whether a name is
/// chosen — because the same column cannot mean two things at once:
///
///  * **One person.** The balance is what they owe the farm. Milk they took
///    puts it up whether they have paid or not; money they handed over brings
///    it down. This is the statement you print and give to them.
///
///  * **Everybody.** Ali's milk and the feed merchant's bill cannot share a
///    running total of who owes what, so the balance is the farm's cash
///    instead: only rows where money actually moved, opening at the capital
///    the co-founders put in and closing at what is in the box today.
///
/// The difference is the credit sale. It puts a customer's balance up on the
/// day it happens and does not touch the cash until somebody pays.
class Statement {
  const Statement({
    required this.lines,
    required this.opening,
    required this.closing,
    required this.debits,
    required this.credits,
    required this.forOneParty,
  });

  final List<StatementLine> lines;

  /// Where the balance stood before the first line — everything that happened
  /// before the window, and the partners' capital when this is the cash book.
  final num opening;
  final num closing;
  final num debits;
  final num credits;

  /// True when this is one person's account rather than the farm's cash.
  final bool forOneParty;

  bool get isEmpty => lines.isEmpty;
}

/// Money that has actually moved, for the cash book.
///
/// An entry booked on credit is not cash on the day it was written — its
/// money arrives later, on the settlement row — so it is left out here and
/// counted when it is paid.
bool _movedCash(Txn t) => t.type.isSettlement || t.paidOnCreate;

/// Which side of a person's account an entry falls on.
///
/// From the farm's side of the table: they took something, so they owe more;
/// they handed money over, so they owe less. A supplier runs the same way with
/// the signs the other way about, which is why one column can carry both — a
/// negative balance simply means the farm owes them.
({num debit, num credit}) _partySides(Txn t) => switch (t.type) {
  // Sold to them: they owe the farm.
  TxnType.sale => (debit: t.amount, credit: 0),
  // They paid: they owe less.
  TxnType.receipt => (debit: 0, credit: t.amount),
  // Bought from them: the farm owes them.
  TxnType.purchase || TxnType.expense => (debit: 0, credit: t.amount),
  // Paid them: the farm owes less.
  TxnType.payment => (debit: t.amount, credit: 0),
};

/// Which side of the cash book an entry falls on. Money out, money in.
({num debit, num credit}) _cashSides(Txn t) => t.type.isIncoming
    ? (debit: 0, credit: t.amount)
    : (debit: t.amount, credit: 0);

/// Which way a line pushes the balance.
///
/// The two statements disagree here, and both are right. On a bank
/// statement money out is a debit and takes the balance down. On a
/// person's account, goods taken are a debit and put up what they owe. So
/// the columns keep their ordinary meanings and the running total follows
/// whichever account this is — the alternative was to call money coming in
/// a debit, which nobody has ever done on a piece of paper.
num _moves(({num debit, num credit}) sides, bool forOneParty) =>
    forOneParty ? sides.debit - sides.credit : sides.credit - sides.debit;

/// What to write in the middle column.
String _detail(Txn t) {
  final parts = <String>[t.type.label, t.category];
  final line = t.qtyLine;
  if (line != null) parts.add(line);
  if (t.handOverLine.isNotEmpty) parts.add(t.handOverLine);
  return parts.join(' · ');
}

/// Builds the statement.
///
/// [rows] is the whole ledger; the window and the name are applied here so the
/// opening balance can count what came before rather than starting at nothing.
/// [capital] is what the co-founders have put in, and is where the cash book
/// starts — without it the closing balance would be short by exactly that and
/// would agree with nothing else in the app.
Statement buildStatement({
  required List<Txn> rows,
  String? party,
  DateTime? from,
  DateTime? to,
  num capital = 0,
}) {
  final forOneParty = party != null && party.trim().isNotEmpty;
  final key = forOneParty ? partyKey(party) : '';

  final mine =
      rows
          .where((t) => !t.isDeleted)
          .where((t) => !forOneParty || partyKey(t.party) == key)
          .where((t) => forOneParty || _movedCash(t))
          .toList()
        ..sort((a, b) {
          final byDate = a.date.compareTo(b.date);
          return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
        });

  // Midnight either end, so a day picked is the whole of that day.
  final start = from == null ? null : DateTime(from.year, from.month, from.day);
  final end = to == null
      ? null
      : DateTime(to.year, to.month, to.day, 23, 59, 59, 999);

  num balance = forOneParty ? 0 : capital;
  var opening = balance;

  // Everything before the window moves the balance without being listed —
  // which is what the "brought forward" line on a bank statement is.
  if (start != null) {
    for (final t in mine.where((t) => t.date.isBefore(start))) {
      final sides = forOneParty ? _partySides(t) : _cashSides(t);
      balance += _moves(sides, forOneParty);
    }
    opening = balance;
  }

  final lines = <StatementLine>[];
  num debits = 0;
  num credits = 0;

  for (final t in mine) {
    if (start != null && t.date.isBefore(start)) continue;
    if (end != null && t.date.isAfter(end)) continue;

    final sides = forOneParty ? _partySides(t) : _cashSides(t);
    balance += _moves(sides, forOneParty);
    debits += sides.debit;
    credits += sides.credit;

    lines.add(
      StatementLine(
        date: t.date,
        party: t.party,
        detail: _detail(t),
        enteredBy: t.createdByName,
        debit: sides.debit,
        credit: sides.credit,
        balance: balance,
      ),
    );
  }

  return Statement(
    lines: lines,
    opening: opening,
    closing: balance,
    debits: debits,
    credits: credits,
    forOneParty: forOneParty,
  );
}

/// What one party still owes the farm, and what the farm still owes them.
///
/// Both read [Txn.outstanding], never the amount the entry was booked at. A
/// sale of 16,000 with 14,000 already received is 2,000 owing; reading the
/// amount would put 16,000 on the card and have the farm asking a man twice
/// for money it has already had. Every spelling of the name is folded in,
/// because Ali and ali are one man and his account has to add up to what he
/// actually owes.
({num owesUs, num weOwe}) partyOwing(List<Txn> ledger, String party) {
  final key = partyKey(party);
  num owesUs = 0, weOwe = 0;
  for (final t in ledger) {
    if (partyKey(t.party) != key) continue;
    if (t.isReceivable) owesUs += t.outstanding;
    if (t.isPayable) weOwe += t.outstanding;
  }
  return (owesUs: owesUs, weOwe: weOwe);
}
