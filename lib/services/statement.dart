import '../models/models.dart';

/// Which of the three documents this is.
///
/// They share a shape and answer three different questions, and the page has
/// to say which one it is or the figure at the foot means nothing. A
/// customer's balance is what he owes; the cash book's is what is in the box;
/// a co-founder's is what they own of the farm.
enum StatementKind {
  party('Statement of account', 'Balance owed'),
  cashBook('Cash book', 'Cash in hand'),
  capital('Profit account', 'Kept in the farm'),

  /// Narrowed to one kind of entry, or one category, or both.
  ///
  /// It has to be its own thing, because once part of the account is hidden
  /// the last column has stopped being a balance. Only the sales listed and
  /// the money that settled them left out, and the figure at the foot is a
  /// running total of what is on the page — not a rupee of it is owed by
  /// anybody. Calling that "balance owed" would be handing somebody a bill.
  extract('Extract', 'Total shown');

  const StatementKind(this.title, this.footLabel);

  final String title;
  final String footLabel;
}

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
    required this.kind,
    this.showing = '',
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

  /// Which of the documents this is, and so what to call the figure at the
  /// foot of it.
  final StatementKind kind;

  /// What it was narrowed to, said in words, for the line under the account
  /// name. Empty when the whole account is on the page.
  final String showing;

  bool get isEmpty => lines.isEmpty;
}

/// Money that has actually moved, for the cash book.
///
/// An entry booked on credit is not cash on the day it was written — its
/// money arrives later, on the settlement row — so it is left out here and
/// counted when it is paid.
/// A write-off is the one entry that looks like cash and is not. An animal
/// coming off the books is a real cost, but the rupees left when she was
/// bought — nothing moves on the day she dies. Counting it here had the cash
/// book short by the price of every dead and sold animal.
bool _movedCash(Txn t) =>
    !t.isWriteOff && (t.type.isSettlement || t.paidOnCreate);

/// Which side of a person's account an entry falls on.
///
/// From the farm's side of the table: they took something, so they owe more;
/// they handed money over, so they owe less. A supplier runs the same way with
/// the signs the other way about, which is why one column can carry both — a
/// negative balance simply means the farm owes them.
/// What settled at the moment the entry was written, and so belongs in the
/// column opposite the entry itself.
///
/// Without this the statement only worked for a man who buys on credit. A
/// sale paid at the door put twelve thousand on the customer's account and
/// nothing against it, so the counter trade showed as owing the whole day's
/// milk; a buffalo bought and paid for at the mandi had the farm owing the
/// seller twelve lakh for ever. Both had already been settled on the same
/// row — a statement that only counts one side of a cash trade is a bill for
/// money nobody owes.
///
/// A receipt or a payment tied to another entry leaves this at nothing: the
/// entry it settles carries the other side. One tied to nothing carries both
/// — rent handed over with no bill, scrap sold with no invoice, a profit
/// share, an advance — and so moves the running balance not at all. Which is
/// what the farm means by an advance: a security it is holding, not a payment
/// against anything.
num _settledOnTheSpot(Txn t) => switch (t.type) {
  TxnType.sale ||
  TxnType.purchase ||
  TxnType.expense => t.paidOnCreate ? t.amount : 0,
  TxnType.receipt || TxnType.payment => t.settlesAnotherEntry ? 0 : t.amount,
};

({num debit, num credit}) _partySides(Txn t) {
  final settled = _settledOnTheSpot(t);
  return switch (t.type) {
    // Sold to them: they owe the farm, less whatever they paid on the spot.
    TxnType.sale => (debit: t.amount, credit: settled),
    // They paid: they owe less.
    TxnType.receipt => (debit: settled, credit: t.amount),
    // Bought from them: the farm owes them, less whatever it paid there.
    TxnType.purchase || TxnType.expense => (debit: settled, credit: t.amount),
    // Paid them: the farm owes less.
    TxnType.payment => (debit: t.amount, credit: settled),
  };
}

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
  Set<TxnType>? types,
  String? category,
}) {
  final forOneParty = party != null && party.trim().isNotEmpty;
  final key = forOneParty ? partyKey(party) : '';

  // Narrowed to one kind of entry or one category. Both are ordinary
  // questions — what did the feed cost this year, what did Ali take in
  // October — and the answer has to come out on the same sheet of paper as
  // everything else, or the farm has two formats and one of them is nobody's
  // idea of a statement.
  final kinds = types == null || types.isEmpty ? null : types;
  final cat = category == null || category.trim().isEmpty
      ? null
      : partyKey(category);
  final narrowed = kinds != null || cat != null;

  final mine =
      rows
          .where((t) => !t.isDeleted)
          .where((t) => !forOneParty || partyKey(t.party) == key)
          .where((t) => forOneParty || narrowed || _movedCash(t))
          .where((t) => kinds == null || kinds.contains(t.type))
          .where((t) => cat == null || partyKey(t.category) == cat)
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

  // A narrowed page opens at nothing. Part of the account is hidden, so a
  // brought-forward figure would be the balance of something that is not
  // what is printed underneath it.
  num balance = forOneParty || narrowed ? 0 : capital;
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
    kind: narrowed
        ? StatementKind.extract
        : forOneParty
        ? StatementKind.party
        : StatementKind.cashBook,
    showing: narrowed ? _showing(kinds, category) : '',
  );
}

/// What the page was narrowed to, in the words the person picked it by.
String _showing(Set<TxnType>? kinds, String? category) {
  final parts = <String>[
    if (kinds != null) kinds.map((t) => t.label).join(', '),
    if (category != null && category.trim().isNotEmpty) category.trim(),
  ];
  return parts.join(' · ');
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

/// A co-founder's profit account, written the way an account is written.
///
/// Their own money is not on it. What somebody put in out of their pocket is
/// a fixed figure that moves only when they put in more, and mixing it with
/// the running profit was the thing version 2 was asked to stop: every month
/// settled used to shift everybody's share of the next one. So the money in
/// their pocket decides the share, and this page is only about what the farm
/// has earned in their name.
///
/// It cannot be built from the ledger, because none of it went through the
/// ledger — a share that stays in the farm moves no rupee at all, it is a
/// label put on cash that is already there. So it is built from what every
/// settled period handed them.
///
/// Each closed period credits their slice and debits whatever was handed
/// over. A period that lost money debits their part of the loss, and if the
/// losses run past what has been earned the balance goes below zero and stays
/// there: Saleem was asked directly and was plain about it.
///
/// A period that is sealed but not yet closed is deliberately absent. Nothing
/// has been settled and nothing handed over, and putting it here would be
/// promising money the four of them have not finished settling.
Statement profitAccount({
  required Partner partner,
  required List<FarmMonth> periods,
  required String Function(FarmMonth) label,
}) {
  final settled = periods.where((m) => m.isClosed).toList()
    ..sort(
      (a, b) => (a.closedAt ?? a.to ?? DateTime(2000)).compareTo(
        b.closedAt ?? b.to ?? DateTime(2000),
      ),
    );

  num balance = 0;
  num debits = 0;
  num credits = 0;
  final lines = <StatementLine>[];

  void add(DateTime on, String what, {num debit = 0, num credit = 0}) {
    balance += credit - debit;
    debits += debit;
    credits += credit;
    lines.add(
      StatementLine(
        date: on,
        party: partner.name,
        detail: what,
        enteredBy: '',
        debit: debit,
        credit: credit,
        balance: balance,
      ),
    );
  }

  for (final m in settled) {
    final share = m.shareFor(partner.id);
    if (share == null || share.share == 0) continue;
    final on = m.closedAt ?? m.to ?? DateTime(2000);
    if (share.isLoss) {
      add(on, 'Loss · ${label(m)}', debit: share.share.abs());
      continue;
    }
    add(on, 'Profit share · ${label(m)}', credit: share.share);
    if (share.taken > 0) {
      add(on, 'Paid out · ${label(m)}', debit: share.taken);
    }
  }

  return Statement(
    lines: lines,
    opening: 0,
    closing: balance,
    debits: debits,
    credits: credits,
    forOneParty: true,
    kind: StatementKind.capital,
  );
}
