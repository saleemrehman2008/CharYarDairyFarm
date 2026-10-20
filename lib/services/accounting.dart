import '../models/models.dart';

/// The farm's figures, derived from the ledger rather than stored — so a
/// corrected entry immediately corrects every card that shows it.
class Books {
  Books({
    required this.monthId,
    required this.openingCash,
    required this.capital,
    required List<Txn> monthTxns,
    required List<Txn> unpaidTxns,
    this.withRider = 0,
    this.founderFloat = 0,
  }) : sales = _sum(monthTxns, TxnType.sale),
       purchases = _sum(monthTxns, TxnType.purchase),
       expenses = _sum(monthTxns, TxnType.expense),
       assetsBought = monthTxns
           .where((t) => t.isCapitalAsset)
           .fold<num>(0, (a, t) => a + t.amount),
       receipts = _sum(monthTxns, TxnType.receipt),
       loosePayments = monthTxns
           .where((t) => t.isLoosePayment)
           .fold<num>(0, (a, t) => a + t.amount),
       otherIncome = monthTxns
           .where((t) => t.isLooseReceipt)
           .fold<num>(0, (a, t) => a + t.amount),
       payments = _sum(monthTxns, TxnType.payment),
       paidSales = _sum(monthTxns, TxnType.sale, cashAtEntryOnly: true),
       paidPurchases = _sum(monthTxns, TxnType.purchase, cashAtEntryOnly: true),
       // Write-offs are deliberately not in here. An animal coming off the
       // books is a cost, but no rupee moves on the day it is written — the
       // money went when she was bought — so the cash must not see it.
       paidExpenses = monthTxns
           .where(
             (t) =>
                 t.type == TxnType.expense && t.paidOnCreate && !t.movedNoCash,
           )
           .fold<num>(0, (a, t) => a + t.amount),
       writeOffs = monthTxns
           .where((t) => t.isWriteOff)
           .fold<num>(0, (a, t) => a + t.amount),
       // What is still owed, not what was booked. An entry half settled is
       // half a receivable; counting the whole of it would have the farm
       // chasing money it has already taken.
       receivable = unpaidTxns
           .where((t) => t.isReceivable)
           .fold<num>(0, (a, t) => a + t.outstanding),
       payable = unpaidTxns
           .where((t) => t.isPayable)
           .fold<num>(0, (a, t) => a + t.outstanding);

  final String monthId;

  /// Operating cash carried in from the months already closed. Partner capital
  /// is deliberately not folded in here — it is added fresh from [capital], so
  /// a new investment shows up the moment it is entered.
  final num openingCash;

  /// Money the partners put into the farm from their own pockets. This is what
  /// the first cattle and the first feed are bought with, so it is part of the
  /// balance, not something separate from it.
  ///
  /// Only `invested` counts. Reinvested profit was earned by the farm and is
  /// already sitting in the cash it came from; counting it again would inflate
  /// the balance.
  final num capital;

  /// Cash a rider has taken at doors and not yet handed in.
  ///
  /// The sale is real and the money exists, but it is in somebody's pocket on
  /// a motorcycle, not in the farm's box. Counting it as the farm's own would
  /// say the farm can spend what it cannot reach, so it is held out of [cash]
  /// and shown on its own until a founder takes it in.
  final num withRider;

  /// Co-founders' own money the farm is holding and has to give back.
  ///
  /// A founder pays for a load of feed out of his own pocket. The feed is
  /// the farm's cost and the rupees left the farm's books — but they were
  /// never the farm's rupees, and without this the cash reads short by
  /// exactly what he laid out, every time any of them does it.
  ///
  /// So it goes in the cash, because it is in the box and can be spent, and
  /// it comes off what the farm is worth, because it is owed. The same two
  /// places a customer's security sits, for the same reason.
  final num founderFloat;

  /// Booked this month, paid or not.
  final num sales;
  final num purchases;
  final num expenses;

  /// Cattle and equipment bought this month. The cash for these is gone, but
  /// the farm owns them, so they are not part of [costs].
  final num assetsBought;

  /// Every receipt and payment this month, settlements included — these rows
  /// *are* the moment the money moved, which is exactly what cash wants.
  final num receipts;
  final num payments;

  /// Payments that settle nothing — rent or a bill paid without the cost ever
  /// having been booked. Real money out, so it belongs in [costs].
  final num loosePayments;

  /// Receipts that settle nothing — money in with no sale booked against it.
  ///
  /// The mirror of [loosePayments], and counted the same way round: real
  /// money in, so the profit has to see it. Not folded into [sales], because
  /// nothing was sold and the sales figure has to stay the sales figure.
  final num otherIncome;

  /// Animals that left the farm this period, at what they cost.
  ///
  /// A cost of the period they left in — a buffalo that dies is money the
  /// farm has genuinely lost, and one that is sold has to give up what she
  /// cost before the sale price counts as earnings. Not cash either way.
  final num writeOffs;

  /// Only the entries whose money moved as they were written. An entry booked
  /// on credit is left out here even once it is settled, because its cash is
  /// counted on the settlement row instead — possibly in a later month.
  final num paidSales;
  final num paidPurchases;
  final num paidExpenses;

  /// Cash actually paid out this month, for the balance card.
  num get paidOut => paidPurchases + paidExpenses + payments;

  /// Outstanding across every month, not just this one.
  final num receivable;
  final num payable;

  /// What it cost to run the farm this month — feed, salaries, bills, vet.
  /// Cattle and equipment are deliberately left out; see [assetsBought].
  num get costs => purchases + expenses - assetsBought + loosePayments;

  /// Profit for the open month, on an accrual basis. Neither the partners'
  /// capital nor the cattle they bought with it is income or cost, so neither
  /// touches this figure.
  num get profit => sales + otherIncome - costs;

  /// Everything the farm has trading with, including what the partners put in.
  num get cash => capital + founderFloat + operatingCash - withRider;

  /// Cash the farm can actually put its hand on, plus what a rider is still
  /// carrying. This is every rupee the sales have brought in.
  num get cashIncludingRiders => cash + withRider;

  /// The same figure with partner capital taken back out — what the farm has
  /// made or lost in cash terms, which is what carries into the next month.
  num get operatingCash =>
      openingCash +
      paidSales +
      receipts -
      paidPurchases -
      paidExpenses -
      payments;

  /// Bar width on the "Month to date" card.
  double get profitBar =>
      sales <= 0 ? 0 : (profit / sales).clamp(0, 1).toDouble();

  /// What a period close would share out.
  ///
  /// With [arIncluded] the profit is shared as it was earned: a sale made on
  /// credit belongs to the period it was made in, whether the money has
  /// arrived or not, and the receipt that settles it later is not income a
  /// second time.
  ///
  /// Without it, only cash is shared. That needs [carriedReceivable] — what
  /// the period before held back — added in, or the money is taken off on the
  /// way out and never put back on the way in, and a credit sale ends up
  /// shared by nobody, ever. With it the two cancel period by period and every
  /// rupee is shared exactly once.
  num profitToShare({required bool arIncluded, num carriedReceivable = 0}) =>
      arIncluded ? profit : profit - receivable + carriedReceivable;

  static num _sum(
    List<Txn> txns,
    TxnType type, {
    bool cashAtEntryOnly = false,
  }) => txns
      .where((t) => t.type == type && (!cashAtEntryOnly || t.paidOnCreate))
      .fold<num>(0, (a, t) => a + t.amount);

  static Books empty(String monthId) => Books(
    monthId: monthId,
    openingCash: 0,
    capital: 0,
    monthTxns: const [],
    unpaidTxns: const [],
  );
}

/// Rows where money actually came in, and rows where it actually went out —
/// every rupee exactly once.
///
/// The farm went looking at its own ledger for "what has come in" and found
/// the same money written twice: a sale on credit, and then the receipt that
/// settled it weeks later. Both rows are right and both have to stay — one
/// is the trade, the other is the day the money arrived — but a list that
/// counts both says the farm took twice what it took.
///
/// So these two pick the rows the cash moved on and nothing else. An entry
/// settled as it was written is counted on itself; one booked on credit is
/// counted on the settlement row instead, which may well be in a later
/// month. Add either list up and it comes to the same figure the balance
/// card shows — a test holds them to that.
///
/// A write-off is the one row that looks like money going out and is not.
/// The rupees left when the animal was bought; nothing moves on the day she
/// is written off.
bool movedCashIn(Txn t) =>
    t.type.isIncoming && t.paidOnCreate && !t.movedNoCash;

bool movedCashOut(Txn t) =>
    !t.type.isIncoming && t.paidOnCreate && !t.movedNoCash;

/// What one pair of hands has taken in, handed out, and is left holding.
class HandsOn {
  const HandsOn({
    required this.who,
    required this.received,
    required this.paid,
    required this.rows,
    this.onItsWay = 0,
    this.coming = 0,
  });

  /// The name as the farm writes it most often.
  final String who;

  final num received;
  final num paid;

  /// How many entries their name is on, so a figure can be looked into.
  final int rows;

  /// Handed to somebody else and not yet acknowledged by him.
  ///
  /// Out of this man's hands already — he has given it away — and not in
  /// anybody else's until the other man says he has it. It belongs to
  /// neither of them in between, which is the only honest place to put it.
  final num onItsWay;

  /// Sent to him and waiting on his own word. Shown beside his balance and
  /// deliberately not in it: a man is answerable for money when he says he
  /// has it, not when somebody says they sent it.
  final num coming;

  /// What they should have in their hand.
  ///
  /// Below nothing means the opposite and is just as useful: they have paid
  /// more of the farm's costs than they have taken in, out of their own
  /// pocket, and the farm owes them the difference.
  num get holding => received - paid - onItsWay;

  bool get outOfPocket => holding < 0;
}

/// Who is holding the farm's cash, read off the ledger.
///
/// Four friends run this place and none of them is an accountant. Money
/// comes in at the gate to whoever is standing there, feed gets paid for out
/// of whoever's pocket is nearest, and at the end of the week nobody can say
/// what is owed to whom without an argument. Every entry already carries the
/// name of the person who actually handled the money — it is asked for on
/// the form and has been from the start — so the answer was in the books the
/// whole time and was never once added up.
///
/// Only rows where cash really moved are counted, so a credit sale lands on
/// the person who collected it rather than the person who wrote it down, and
/// a debt given up on lands on nobody. Money passed from one of them to
/// another moves the holding and nothing else: it is a payment out of one
/// pair of hands and a receipt into the other, and the two cancel in every
/// figure except these.
///
/// Spellings are folded together — Jalbani and jalbani are one man — and the
/// name that comes back is whichever he is written as most often. Entries
/// with nobody's name on them are gathered under one heading rather than
/// dropped, because money that moved with no name against it is exactly what
/// a farm needs to be told about.
List<HandsOn> cashInHands(
  List<Txn> ledger, {
  String unnamed = 'Not recorded',

  /// Co-founders' own money coming in. Only the part that was handed to
  /// somebody counts here: money one of them spent straight on a load of
  /// feed never passed through the farm's hands, so no holding moves for
  /// it. Without this the card would read short by every rupee of capital
  /// that has been paid in, which is most of what the farm has.
  List<Contribution> putIn = const [],

  /// Cash handed over and not yet acknowledged. It comes off the sender's
  /// balance and does not go onto the receiver's — in between it is in
  /// neither pair of hands, which is where it actually is.
  List<CashTransfer> moving = const [],
}) {
  final received = <String, num>{};
  final paid = <String, num>{};
  final rows = <String, int>{};
  final spellings = <String, Map<String, int>>{};

  void note(String said, num amount, {required bool incoming}) {
    if (amount <= 0) return;
    final name = said.trim();
    final key = name.isEmpty ? '' : partyKey(name);
    (incoming ? received : paid).update(
      key,
      (v) => v + amount,
      ifAbsent: () => amount,
    );
    rows.update(key, (v) => v + 1, ifAbsent: () => 1);
    if (name.isNotEmpty) {
      spellings
          .putIfAbsent(key, () => <String, int>{})
          .update(name, (v) => v + 1, ifAbsent: () => 1);
    }
  }

  // Whose money paid for which entry, where the four of them clubbed
  // together on one.
  final split = <String, List<Contribution>>{};
  for (final c in putIn) {
    final id = c.txnId;
    if (c.isDeleted || id == null) continue;
    split.putIfAbsent(id, () => []).add(c);
  }

  for (final t in ledger) {
    if (t.isDeleted) continue;
    if (movedCashIn(t)) {
      note(t.handledBy, t.amount, incoming: true);
      continue;
    }
    if (!movedCashOut(t)) continue;

    // An entry carries one name as the payer, and three men can have paid
    // for it. Where the farm has written down who found the money, that is
    // who it comes out of — anything left over belongs to the one name on
    // the entry, which is the farm's own cash going out through his hands.
    var left = t.amount;
    for (final c in split[t.id] ?? const <Contribution>[]) {
      note(c.partnerName, c.amount, incoming: false);
      left -= c.amount;
    }
    note(t.handledBy, left, incoming: false);
  }
  for (final c in putIn) {
    if (c.isDeleted) continue;

    // A correction moves no money. The master putting a figure right is a
    // note about the books, not a rupee changing hands — counted here it
    // read as a man taking in minus ten lakh, which is not a thing.
    if (c.source == ContributionSource.correction) continue;
    if (c.amount <= 0) continue;

    // Money handed to somebody lands in that pair of hands.
    //
    // Money spent straight on something the farm bought lands in the
    // giver's own hands and goes out again on the purchase row, which
    // carries his name as the payer. Without this half of it his account
    // reads as though he had paid eighteen lakh of the farm's costs with
    // the farm's money, when it was his own and is already his capital.
    final who = c.wasHandedOver ? c.receivedBy : c.partnerName;
    if (who.trim().isEmpty) continue;

    final key = partyKey(who);
    received.update(key, (v) => v + c.amount, ifAbsent: () => c.amount);
    rows.update(key, (v) => v + 1, ifAbsent: () => 1);
    spellings
        .putIfAbsent(key, () => <String, int>{})
        .update(who, (v) => v + 1, ifAbsent: () => 1);
  }

  // Anybody with money on its way to or from him belongs on the list even
  // if he has never handled a rupee otherwise — that is exactly the man
  // the farm needs to be asked about.
  final waiting = <String, String>{};
  for (final t in moving) {
    if (!t.isWaiting) continue;
    waiting.putIfAbsent(partyKey(t.from), () => t.from);
    waiting.putIfAbsent(partyKey(t.to), () => t.to);
  }

  final out = [
    for (final key in {...received.keys, ...paid.keys, ...waiting.keys})
      HandsOn(
        who: key.isEmpty
            ? unnamed
            : _mostWritten(spellings[key]) ?? waiting[key] ?? key,
        received: received[key] ?? 0,
        paid: paid[key] ?? 0,
        rows: rows[key] ?? 0,
        onItsWay: sentWaitingBy(moving, waiting[key] ?? key),
        coming: comingTo(moving, waiting[key] ?? key),
      ),
  ];

  // Whoever is holding the most first, because that is the person the farm
  // is relying on. Anything unnamed goes last whatever it comes to.
  out.sort((a, b) {
    if ((a.who == unnamed) != (b.who == unnamed)) {
      return a.who == unnamed ? 1 : -1;
    }
    final byHeld = b.holding.compareTo(a.holding);
    return byHeld != 0 ? byHeld : a.who.compareTo(b.who);
  });
  return out;
}

String? _mostWritten(Map<String, int>? spellings) {
  if (spellings == null || spellings.isEmpty) return null;
  var best = spellings.keys.first;
  for (final e in spellings.entries) {
    if (e.value > (spellings[best] ?? 0)) best = e.key;
  }
  return best;
}

/// The order a ledger is read in: by the day it happened, newest first.
///
/// It is a diary before it is a book of accounts. Somebody reads down it
/// looking for what happened on the sixteenth, so an entry from the
/// sixteenth has to be where the sixteenth is — whatever period it was
/// booked into, and whenever it was typed.
///
/// Two entries on the same day keep the order they were written in, which
/// is the only other order anybody can check.
List<Txn> ledgerOrder(List<Txn> rows) => rows.toList()
  ..sort((a, b) {
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
  });

/// One period's worth of the farm, for the column chart on the dashboard.
class PeriodBar {
  const PeriodBar({
    required this.id,
    required this.label,
    required this.sales,
    required this.costs,
    required this.profit,
    required this.isOpen,
  });

  final String id;

  /// Short — `Sep` — because six of them share a phone's width.
  final String label;

  final num sales;
  final num costs;
  final num profit;

  /// The period still being written. Drawn faint, because it is not finished
  /// and reading a half month against five whole ones is how a farm talks
  /// itself into a bad decision.
  final bool isOpen;

  num get most => sales > costs ? sales : costs;
}

/// The last few periods, oldest first, for drawing.
///
/// The farm could see what this month has done and had no way of seeing what
/// the month before did, or the one before that. Four figures say where it
/// stands; six columns say which way it is going, which is the question
/// anybody actually asks at the gate.
///
/// A settled period is read from the figures frozen into it at the seal,
/// never worked out again — that is the whole point of freezing them. The
/// open one is read live.
List<PeriodBar> periodBars(
  List<FarmMonth> periods, {
  required FarmMonth open,
  required Books books,
  required String Function(String monthId) shortName,
  int last = 6,
}) {
  final done = periods.where((m) => m.isFrozen).toList()
    ..sort((a, b) => a.id.compareTo(b.id));

  final bars = [
    for (final m in done)
      PeriodBar(
        id: m.id,
        label: shortName(m.id),
        sales: (m.sales ?? 0) + (m.otherIncome ?? 0),
        costs: m.runningCosts,
        profit: m.profit ?? 0,
        isOpen: false,
      ),
    PeriodBar(
      id: open.id,
      label: shortName(open.id),
      sales: books.sales + books.otherIncome,
      costs: books.costs,
      profit: books.profit,
      isOpen: true,
    ),
  ];

  return bars.length <= last ? bars : bars.sublist(bars.length - last);
}

/// One line of an account: what happened, and which way the money went.
class AccountLine {
  const AccountLine({
    required this.date,
    required this.what,
    required this.detail,
    required this.amount,
  });

  final DateTime date;

  /// Who it was with, or what it was for — the first line on the row.
  final String what;

  final String detail;

  /// Into these hands when it is more than nothing, out of them when less.
  final num amount;
}

/// Everything that has passed through one pair of hands, newest first.
///
/// The farm asked for its accounts to read like a bank's, and this is what
/// a bank statement is: not a list of what the farm did, but a list of what
/// touched this account, in the order it touched it.
///
/// Four kinds of line reach it. Cash that came in through him and cash that
/// went out through him; his own money going in, which lands in his hands on
/// the way past; and his share of something the farm bought, which is the
/// other half of that — an entry carries one name as the payer and three men
/// can have paid for it, so where the farm has written down who found the
/// money, that is who it comes out of.
/// Wage money a man has already taken against a month, still to come off it.
///
/// He asks for five thousand on the 12th and says take it off my salary. The
/// farm has always said yes and then had to remember, so whether the
/// deduction happened depended on who was doing the paying at the end of the
/// month. The entries know, so they can do the remembering.
///
/// Dated inside the month being paid, because an advance belongs to the wage
/// it was taken against: one drawn in October comes off October's pay, and if
/// it was not deducted then it is not quietly taken out of November's.
num advanceTaken(
  List<Txn> ledger, {
  required String who,
  required DateTime from,
  required DateTime to,
}) {
  final key = partyKey(who);
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day, 23, 59, 59);

  return ledger
      .where(
        (t) =>
            !t.isDeleted &&
            t.category == salaryAdvanceCategory &&
            partyKey(t.party) == key &&
            !t.date.isBefore(start) &&
            !t.date.isAfter(end),
      )
      .fold<num>(0, (a, t) => a + t.amount);
}

/// Whether his wage for that month has already been paid.
///
/// Once it has, the advance has come off it and must not come off again —
/// the farm correcting an entry a week later should not watch five thousand
/// disappear twice.
bool wagePaidIn(
  List<Txn> ledger, {
  required String who,
  required DateTime from,
  required DateTime to,
}) {
  final key = partyKey(who);
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day, 23, 59, 59);

  return ledger.any(
    (t) =>
        !t.isDeleted &&
        t.category == salariesCategory &&
        partyKey(t.party) == key &&
        !t.date.isBefore(start) &&
        !t.date.isAfter(end),
  );
}

/// What a handover row should say on one man's own statement.
///
/// The categories on the rows are written for the books: "Handed to a
/// co-founder", "Taken from a co-founder". On the farm's own account that is
/// plainly wrong — the farm is not a co-founder — and on a man's page it
/// hides the one thing he wants to read, which is whether the money went
/// into the farm or to one of the others.
String handoverWords(Txn t, String forWhom) {
  final s = handoverSides(t);
  if (s == null) return t.category;

  final key = partyKey(forWhom);
  final gave = partyKey(s.from) == key;
  final farm = partyKey(gave ? s.to : s.from) == partyKey(farmAccountName);

  if (gave) return farm ? 'Put into the farm account' : 'Handed over';
  return farm ? 'Taken out of the farm account' : 'Taken in';
}

List<AccountLine> accountLines(
  List<Txn> ledger, {
  required String who,
  List<Contribution> putIn = const [],
}) {
  final key = partyKey(who);
  final out = <AccountLine>[];

  final split = <String, List<Contribution>>{};
  for (final c in putIn) {
    final id = c.txnId;
    if (c.isDeleted || id == null) continue;
    split.putIfAbsent(id, () => []).add(c);
  }

  for (final t in ledger) {
    if (t.isDeleted) continue;

    if (movedCashIn(t) && partyKey(t.handledBy) == key) {
      out.add(
        AccountLine(
          date: t.date,
          what: t.party.isEmpty ? t.category : t.party,
          detail: handoverWords(t, who),
          amount: t.amount,
        ),
      );
      continue;
    }
    if (!movedCashOut(t)) continue;

    var left = t.amount;
    for (final c in split[t.id] ?? const <Contribution>[]) {
      left -= c.amount;
      if (partyKey(c.partnerName) != key) continue;
      out.add(
        AccountLine(
          date: t.date,
          what: t.party.isEmpty ? t.category : t.party,
          detail: t.category,
          amount: -c.amount,
        ),
      );
    }
    if (left > 0 && partyKey(t.handledBy) == key) {
      out.add(
        AccountLine(
          date: t.date,
          what: t.party.isEmpty ? t.category : t.party,
          detail: handoverWords(t, who),
          amount: -left,
        ),
      );
    }
  }

  // His own money going in. Handed to somebody, it lands in that man's
  // hands; spent straight on a purchase, it lands in his own and goes out
  // again on the row above.
  for (final c in putIn) {
    if (c.isDeleted) continue;
    if (c.source == ContributionSource.correction || c.amount <= 0) continue;
    final landedOn = c.wasHandedOver ? c.receivedBy : c.partnerName;
    if (partyKey(landedOn) != key) continue;
    out.add(
      AccountLine(
        date: c.date,
        what: c.wasHandedOver
            ? '${c.partnerName} put money in'
            : '${c.partnerName} paid for something',
        detail: c.kind.label,
        amount: c.amount,
      ),
    );
  }

  out.sort((a, b) => b.date.compareTo(a.date));
  return out;
}

/// Which way round a handover went, read off either of its two rows.
///
/// The row that says "handed to" carries the receiver as its party and the
/// giver as its handler; the row that says "taken from" carries them the
/// other way about. Asking the row itself saves every screen from having to
/// remember which is which.
({String from, String to})? handoverSides(Txn t) {
  if (t.isHandoverOut) return (from: t.handledBy, to: t.party);
  if (t.isHandoverIn) return (from: t.party, to: t.handledBy);
  return null;
}

/// One handover's second row, so the pair can be read as the one thing it is.
///
/// Money moving from one of them to another reaches the books as two rows,
/// and it has to: one pair of hands goes down by it and another goes up, and
/// a single row cannot say both. But the farm reads a ledger, not a double
/// entry system, and two rows for one act is what it called "double entry,
/// meri samajh se bahar" — it handed 8,600 to the farm account once and the
/// page showed it twice, as money in and money out, of a farm whose total
/// had not changed by a rupee.
///
/// So the pair is matched back up and the page draws it once. Nothing is
/// taken out of the books: both rows stay, every balance is worked out from
/// both, and the one that is hidden is hidden from a list on a screen.
///
/// Matched on what the pair cannot differ in — the day, the amount, and the
/// two names the opposite way round — because the rows were written before
/// anything linked them and his farm's are already on the books.
Set<String> twinnedHandovers(List<Txn> ledger) {
  final outs = <String, List<Txn>>{};
  for (final t in ledger) {
    if (t.isDeleted || !t.isHandoverOut) continue;
    final s = handoverSides(t)!;
    outs.putIfAbsent(_twinKey(t.date, t.amount, s.from, s.to), () => []).add(t);
  }

  final hidden = <String>{};
  for (final t in ledger) {
    if (t.isDeleted || !t.isHandoverIn) continue;
    final s = handoverSides(t)!;
    final mates = outs[_twinKey(t.date, t.amount, s.from, s.to)];
    if (mates == null || mates.isEmpty) continue;

    // One for one. Two men handing the same amount to the same place on the
    // same day is two handovers, and both deserve their line.
    mates.removeLast();
    hidden.add(t.id);
  }
  return hidden;
}

String _twinKey(DateTime on, num amount, String from, String to) =>
    '${on.year}-${on.month}-${on.day}|$amount|'
    '${partyKey(from)}|${partyKey(to)}';

/// One entry sitting behind what a man is holding, or behind what he is out
/// of pocket.
///
/// [AccountLine] says how a figure was arrived at and is enough to read. This
/// carries the entry's id as well, because the farm wants to pick them: a
/// handover of 8,600 should be able to say it is *these four* Urooj receipts
/// rather than 8,600 of an indistinguishable pile.
class InHand {
  const InHand({
    required this.txnId,
    required this.date,
    required this.what,
    required this.detail,
    required this.amount,
    required this.incoming,
    this.handedOnTo = '',
  });

  final String txnId;
  final DateTime date;

  /// Who it was with, falling back to what it was for.
  final String what;
  final String detail;

  /// Always positive. [incoming] says which way it went.
  final num amount;

  /// Money that came into his hands, as against money that went out of them.
  final bool incoming;

  /// Named by a handover already, so it is spoken for.
  final String handedOnTo;

  bool get isSpokenFor => handedOnTo.isNotEmpty;
}

/// The entries behind one man's figure, latest first.
///
/// Latest first because the farm asked for it that way, and it is right: the
/// money he is most likely to be handing over this morning is the money that
/// came in last night.
///
/// [incoming] true gives what came into his hands — what he has to hand over.
/// False gives what went out of them, which on a co-founder's page is the
/// spending the farm has yet to settle with him.
List<InHand> inHand(
  List<Txn> ledger, {
  required String who,
  required bool incoming,
  List<Contribution> putIn = const [],
  List<CashTransfer> moving = const [],
}) {
  final key = partyKey(who);
  final spokenFor = <String, String>{};
  for (final t in moving) {
    if (t.state == TransferState.refused) continue;
    for (final id in t.txnIds) {
      spokenFor[id] = t.to;
    }
  }

  final split = <String, List<Contribution>>{};
  for (final c in putIn) {
    final id = c.txnId;
    if (c.isDeleted || id == null) continue;
    split.putIfAbsent(id, () => []).add(c);
  }

  InHand line(Txn t, num amount, bool incoming) => InHand(
    txnId: t.id,
    date: t.date,
    what: t.party.isEmpty ? t.category : t.party,
    detail: t.category,
    amount: amount,
    incoming: incoming,
    handedOnTo: spokenFor[t.id] ?? '',
  );

  final out = <InHand>[];
  for (final t in ledger) {
    if (t.isDeleted) continue;

    // A handover is not money he is holding — it is the act of passing it
    // on. Offering it back would let the same rupees be handed over twice.
    if (t.isHandoverOut || t.isHandoverIn) continue;

    if (movedCashIn(t)) {
      if (incoming && partyKey(t.handledBy) == key && t.amount > 0) {
        out.add(line(t, t.amount, true));
      }
      continue;
    }
    if (!movedCashOut(t)) continue;
    if (incoming) continue;

    // An entry carries one payer's name and three men can have paid for it.
    // Where the farm has written down who found the money, that is whose
    // row this is; the rest belongs to the name on the entry.
    var left = t.amount;
    for (final c in split[t.id] ?? const <Contribution>[]) {
      left -= c.amount;
      if (partyKey(c.partnerName) != key || c.amount <= 0) continue;
      out.add(line(t, c.amount, false));
    }
    if (left > 0 && partyKey(t.handledBy) == key) {
      out.add(line(t, left, false));
    }
  }

  out.sort((a, b) => b.date.compareTo(a.date));
  return out;
}

/// Capital that has never been written down as reaching anybody.
///
/// The farm's cash is its capital plus what it has earned less what it has
/// spent. The sum of what everybody is holding only counts money with a name
/// against it. The difference between the two is capital that went in without
/// a line saying where — a figure typed onto a card, with no day, no hands,
/// and nothing it paid for.
///
/// It is not an error and the books still balance with it there: the money is
/// real and the farm has it. What it means is that the per-person picture is
/// incomplete by exactly this much, and the fix is to write the lines — to
/// say who handed it over, or which purchase it paid for.
num capitalWithoutLines({
  required num capital,
  required List<Contribution> putIn,
}) {
  final written = putIn
      .where((c) => !c.isDeleted && c.isInvestment)
      .fold<num>(0, (a, c) => a + c.amount);
  final left = capital - written;
  return left > 0 ? left : 0;
}

/// Where every rupee the farm has ever handled currently sits.
///
/// The dashboard used to show only the closing figure, which left the farm
/// staring at a number with no way to check it. This lays out the whole route:
/// what the partners put in, what turned into cattle, what was spent running
/// the place, what came back from sales — and where that leaves the cash.
class MoneySummary {
  const MoneySummary({
    required this.capital,
    required this.assets,
    required this.runningCosts,
    required this.sales,
    required this.cash,
    required this.receivable,
    required this.payable,
    this.withRider = 0,
    this.paidOut = 0,
    this.otherIncome = 0,
    this.securitiesHeld = 0,
    this.loansOut = 0,
    this.securitiesOut = 0,
    this.profitHeld = 0,
    this.owedToFounders = 0,
  });

  /// Put in by the co-founders, all time.
  final num capital;

  /// Cattle and equipment the farm owns, all time.
  final num assets;

  /// Feed, salaries, rent and the rest, all time.
  final num runningCosts;

  /// Everything sold, all time, collected or not.
  final num sales;

  /// Money in with no sale booked against it, all time.
  final num otherIncome;

  /// Advances customers have left with the farm and not had back.
  ///
  /// In the cash, but not the farm's. It comes off what the farm is worth
  /// the same way an unpaid bill does — both are money the farm is holding
  /// and owes to somebody else.
  final num securitiesHeld;

  /// Co-founders' own money in the farm's box that the farm owes back.
  ///
  /// Counted exactly as a customer's security is, and for the same reason:
  /// it is money the farm is holding and not money the farm has. A founder
  /// who pays for the feed himself has lent the farm that much until the
  /// four of them either pay him back or agree it comes off his promise.
  final num owedToFounders;

  /// What the farm has lent its own co-founders and not had back.
  ///
  /// The mirror of an advance, and it belongs on the opposite side. An
  /// advance is money in the box that is not the farm's; a loan is money the
  /// farm owns that is not in the box. Both have to be said out loud or the
  /// waterfall and the holdings stop agreeing by exactly that much.
  final num loansOut;

  /// Advances the farm has handed out and not had back. The farm's own
  /// money, sitting in somebody else's pocket — so it counts towards what
  /// the farm is worth, exactly as a loan to a co-founder does, and for the
  /// same reason.
  final num securitiesOut;

  /// Profit the co-founders have earned and left in the farm.
  ///
  /// It is sitting in the cash, and it is not the farm's to spend freely —
  /// any of them can ask for it. Not taken off anything here, because it was
  /// never added: retaining profit moves no rupee, it only puts a name on
  /// cash that is already there. It is on the card so that fifty lakh in the
  /// box is not mistaken for fifty lakh to spend on buffaloes.
  final num profitHeld;

  /// Cash actually in hand right now.
  final num cash;

  /// Owed to the farm, and owed by it.
  final num receivable;
  final num payable;

  /// Taken at a door and not yet handed in. Owed to the farm by its own
  /// rider, which is why it sits beside [receivable] rather than in [cash].
  final num withRider;

  /// Profit the co-founders have taken out, all time.
  ///
  /// Not a running cost — the farm's earnings going to the people who own them
  /// is not the price of running the place — but the cash is gone, so the
  /// route the money took has to show it leaving. Leave it out and the
  /// waterfall reads high by exactly what was withdrawn, from the first close
  /// onwards.
  final num paidOut;

  /// What the farm is actually worth in money: cash, what a rider is carrying,
  /// and what is still to come in, less what it still owes.
  num get farmMoney =>
      cash +
      withRider +
      receivable -
      payable -
      securitiesHeld -
      owedToFounders +
      loansOut +
      securitiesOut;

  /// The same figure read down the waterfall — every rupee that came in, less
  /// every rupee that went out or turned into an animal. It should equal
  /// [farmMoney]; when it does not, an entry is missing or counted twice.
  num get expected =>
      capital - assets - runningCosts + sales + otherIncome - paidOut;

  bool get reconciles => (expected - farmMoney).abs() < 1;
}

/// Whole-rupee slices of a period, one per partner.
///
/// Takes the profit as it stands, which may be a loss. A loss is split the
/// same way a profit is and comes back negative — the four of them share what
/// the farm makes and they share what it loses, and a month that went badly
/// which left everybody's account untouched would be a month the books had
/// quietly paid for out of somebody's capital without saying whose.
///
/// Rounding each slice on its own would leave a rupee or two unaccounted for —
/// three partners on a profit of 100 would take 33 each. The odd rupee goes to
/// the largest slice, so the slices always add up to exactly what was made.
List<MonthShare> shareOut({
  required List<Partner> partners,
  required num profit,
}) {
  final ratios = ratiosOf(partners);
  final shares = [
    for (final p in partners)
      MonthShare(
        partnerId: p.id,
        name: p.name,
        ratio: ratios[p.id] ?? 0,
        share: (profit * (ratios[p.id] ?? 0)).round(),
      ),
  ];
  if (shares.isEmpty) return shares;

  final over =
      profit.round() - shares.fold<int>(0, (a, s) => a + s.share.round());
  if (over == 0) return shares;

  var biggest = 0;
  for (var i = 1; i < shares.length; i++) {
    if (shares[i].share.abs() > shares[biggest].share.abs()) biggest = i;
  }
  shares[biggest] = MonthShare(
    partnerId: shares[biggest].partnerId,
    name: shares[biggest].name,
    ratio: shares[biggest].ratio,
    share: shares[biggest].share + over,
  );
  return shares;
}

/// The same slices with a percentage of each handed over.
///
/// One percentage for all four, set by the master at the close. Nothing is
/// handed out of a loss: a negative slice stays whole and goes into that
/// partner's profit account, where it takes the balance down.
List<MonthShare> handOut(List<MonthShare> shares, int percent) {
  final pct = percent.clamp(0, 100);
  return [
    for (final s in shares)
      s.handing(s.share <= 0 ? 0 : (s.share * pct / 100).round()),
  ];
}

/// The milk trade on its own, split three ways: what the herd gave, what was
/// bought off another farm to sell on, and what the difference came to.
///
/// The farm took on a neighbouring farm's milk — a hundred litres at a
/// hundred and eighty, sold on at two hundred — and the books as they stood
/// could not answer the question that arrangement raises. Milk in and milk
/// out both ran through the same totals: sales went up by what the farm sold
/// and costs went up by what it paid, so the rupees came out right and the
/// month still looked like a month the buffaloes had had. They had not. Some
/// of it was somebody else's milk passing through.
///
/// So the two are counted apart. [ownLitres] is the herd's; [marginPk] is
/// what the trading itself earned, and it is the figure that says whether
/// buying milk in is worth doing at all.
class MilkBook {
  const MilkBook({
    required this.soldLitres,
    required this.soldPk,
    required this.boughtLitres,
    required this.boughtPk,
    required this.morningLitres,
    required this.eveningLitres,
    required this.unsaidLitres,
  });

  /// Litres the farm sold, whoever's buffalo they came out of.
  final num soldLitres;
  final num soldPk;

  /// Litres bought off another farm, and what was owed for them.
  final num boughtLitres;
  final num boughtPk;

  /// The day split, across sales. [unsaidLitres] is what was entered before
  /// the app asked which milking — shown rather than shared out, because
  /// putting it in either half would be inventing it.
  final num morningLitres;
  final num eveningLitres;
  final num unsaidLitres;

  /// What the herd itself gave, as far as the books can tell: everything
  /// sold that was not bought in first.
  ///
  /// Negative would mean more milk was bought in than went out — which is
  /// either milk still in the tank or an entry somebody got wrong, and
  /// either way it is shown as it falls rather than clamped to zero.
  num get ownLitres => soldLitres - boughtLitres;

  /// What the trading made. Only meaningful when milk was actually bought
  /// in; on a farm selling nothing but its own it is simply the milk income.
  num get marginPk => soldPk - boughtPk;

  /// What the farm paid on average for a bought-in litre, and what it got
  /// for a litre sold. Null when there were none, rather than zero — no
  /// trade is not the same as a rate of nothing.
  num? get boughtRate => boughtLitres == 0 ? null : boughtPk / boughtLitres;
  num? get soldRate => soldLitres == 0 ? null : soldPk / soldLitres;

  /// Whether any milk was bought in at all. The card only earns its place on
  /// the report when it did.
  bool get trades => boughtLitres > 0 || boughtPk > 0;

  bool get isEmpty => soldLitres == 0 && soldPk == 0 && !trades;

  /// Reads the milk out of a stretch of the ledger.
  ///
  /// Litres come off the entry's own quantity, and only when it was measured
  /// in litres — a bulk deal written as one total with no quantity has no
  /// litres to count, and guessing them from the rate would be making up a
  /// figure the farm never wrote down.
  factory MilkBook.from(List<Txn> rows) {
    num soldL = 0, soldPk = 0, boughtL = 0, boughtPk = 0;
    num morning = 0, evening = 0, unsaid = 0;

    for (final t in rows) {
      if (t.isDeleted) continue;
      final litres = t.unit == 'L' ? (t.qty ?? 0) : 0;

      if (t.isMilkSale) {
        soldL += litres;
        soldPk += t.amount;
        switch (t.shift) {
          case MilkShift.morning:
            morning += litres;
          case MilkShift.evening:
            evening += litres;
          case null:
            unsaid += litres;
        }
      } else if (t.isMilkBoughtIn) {
        boughtL += litres;
        boughtPk += t.amount;
      }
    }

    return MilkBook(
      soldLitres: soldL,
      soldPk: soldPk,
      boughtLitres: boughtL,
      boughtPk: boughtPk,
      morningLitres: morning,
      eveningLitres: evening,
      unsaidLitres: unsaid,
    );
  }
}

/// What the farm is holding for one person, and has not handed back.
///
/// Somebody else's money sitting in the farm's cash. It matters that this
/// can never go below nothing: a negative figure here reads as the farm
/// being owed by a man the farm owes, and it takes the balance check down
/// with it — so the entry form checks a return against this before saving,
/// and refuses anything larger.
///
/// Lives here rather than on the store so the rule the form enforces is the
/// same code a test can run, instead of a second copy of it that agrees
/// until the day it does not.
num securityHeldFromIn(List<Txn> rows, String party) => rows
    .where((t) => partyKey(t.party) == partyKey(party))
    .fold<num>(0, (a, t) => a + _heldBy(t));

/// The same across every customer.
num securitiesHeldIn(List<Txn> rows) =>
    rows.fold<num>(0, (a, t) => a + _heldBy(t));

/// What one person is holding of the farm own money as a security.
///
/// The mirror of [securityHeldFromIn]: that is somebody else money in the
/// farm box, this is the farm money in somebody else pocket — a deposit on
/// a rented yard. Never a cost, because the farm has not spent it, and
/// never below nothing, which is what the entry form checks a refund
/// against.
num securityOutWithIn(List<Txn> rows, String party) => rows
    .where((t) => partyKey(t.party) == partyKey(party))
    .fold<num>(0, (a, t) => a + _outWith(t));

/// The same across everybody.
num securitiesOutIn(List<Txn> rows) =>
    rows.fold<num>(0, (a, t) => a + _outWith(t));

/// What one row does to a security figure: adds to it, takes from it, or —
/// and this is the case that bit — leaves it entirely alone.
///
/// These were written as "is it the one that adds? then add, otherwise
/// subtract", which is right only while the list handed in holds nothing
/// but securities. The store passes exactly that, so it read correctly for
/// months. Hand one the whole ledger and every sale and every bag of feed
/// comes off the deposit: a shop with fifty thousand on deposit and a
/// seven-thousand-six-hundred milk bill showed forty-two thousand four
/// hundred of deposit, which is a figure from nowhere.
num _heldBy(Txn t) => t.isSecurityIn
    ? t.amount
    : t.isSecurityBack
    ? -t.amount
    : 0;

num _outWith(Txn t) => t.isSecurityOut
    ? t.amount
    : t.isSecurityRefund
    ? -t.amount
    : 0;
