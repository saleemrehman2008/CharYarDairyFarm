import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers.dart';

enum TxnType {
  sale,
  purchase,
  expense,
  receipt,
  payment;

  static TxnType parse(Object? v) => switch (s(v)) {
    'purchase' => TxnType.purchase,
    'expense' => TxnType.expense,
    'receipt' => TxnType.receipt,
    'payment' => TxnType.payment,
    _ => TxnType.sale,
  };

  String get label => switch (this) {
    TxnType.sale => 'Sale',
    TxnType.purchase => 'Purchase',
    TxnType.expense => 'Expense',
    TxnType.receipt => 'Receipt',
    TxnType.payment => 'Payment',
  };

  /// Money coming in shows with a `+`, everything else with a `-`.
  bool get isIncoming => this == TxnType.sale || this == TxnType.receipt;

  /// Receipts and payments settle money that was already booked, so they carry
  /// no quantity or rate and are never "unpaid".
  bool get isSettlement => this == TxnType.receipt || this == TxnType.payment;

  /// Label for the "not settled yet" option on the entry form.
  String get unpaidLabel => switch (this) {
    TxnType.sale => 'Not received yet (khaata / AR)',
    _ => 'Not paid yet (AP)',
  };

  List<String> get categories => switch (this) {
    TxnType.sale => const [
      milkCategory,
      'Paneer',
      'Khoya',
      'Cattle sale',
      'Dung / manure',
      'Other sale',
    ],
    TxnType.purchase => const [
      'Fodder / feed',
      milkBoughtInCategory,
      'Cattle purchase',
      'Equipment',
      'Vet & medicine',
      'Food & kitchen',
      'Other purchase',
    ],
    TxnType.expense => const [
      'Salaries',
      'Rent',
      'Utilities (bijli, gas, pani)',
      'Food & kitchen',
      'Transport',
      'Vet & medicine',
      'Repairs',
      'Equipment',
      'Fodder / feed',
      'Other expense',
    ],
    // "Khaata receipt" is deliberately not offered. The app posts it itself
    // when an entry is settled, tied to the entry it settles — and one typed
    // by hand is tied to nothing, so the books read it as fresh income while
    // the original sale sits there still unpaid. The same eight thousand,
    // counted twice, with the balance check none the wiser because the cash
    // and the income both went up together.
    //
    // Money coming in against something already booked is taken in from the
    // ledger: pick the name, tick what they are paying for, take it in.
    // A loan instalment is offered here, unlike a khaata receipt, and the
    // difference is what happens if it is typed against the wrong name. A
    // khaata receipt tied to nothing reads as fresh income and the books
    // count the same rupee twice. A loan repayment is never income whatever
    // it is tied to — it only ever moves the cash and what is owed — so the
    // worst a mistake can do here is put a figure in the wrong person's row,
    // which is visible and correctable.
    TxnType.receipt => const [
      securityInCategory,
      loanRepaidCategory,
      'Other receipt',
    ],
    // Deliberately short. A payment settles something the books already
    // know about; it is not the place to record what the money was for. Rent,
    // salaries and bills used to be offered here as well as under Expense,
    // and picking the wrong one put the money out of the farm's cash without
    // ever counting it as a cost — so the profit never moved.
    TxnType.payment => const [
      'Supplier payment',
      securityBackCategory,
      'Other payment',
    ],
  };
}

/// Which way the money went.
///
/// This is the only thing a person actually knows standing at the gate with
/// notes in their hand, and so it is the only thing the entry form asks.
/// Before this it asked which of five kinds of entry it was, and the farm's
/// verdict on those five words was that they did not say what they did —
/// which is fair, because the difference between them is not a difference
/// between things that happen on a farm, it is a difference between what the
/// books do about it afterwards.
///
/// So the direction is picked and the heading decides the rest: [typeOf]
/// maps every heading on offer to the kind of entry the books need. Nobody
/// has to know that a customer's advance is a "receipt" while his milk bill
/// is a "sale". The form says in plain words what each choice will do
/// instead, which is the part that was actually missing.
///
/// What is deliberately *not* on these lists matters as much as what is.
/// A payment against a bill already in the books is not here: typed loose it
/// is counted as a cost all over again while the bill it was meant to settle
/// stays open. That has its own path — find the entry in the ledger and
/// settle it there — and leaving it off this list is what stops the same
/// rupee being spent twice.
enum MoneyFlow {
  incoming('Money in'),
  outgoing('Money out');

  const MoneyFlow(this.label);

  final String label;

  /// Every heading on offer under this direction, in the order it is shown,
  /// and what the books record each one as.
  List<(String, TxnType)> get choices => switch (this) {
    MoneyFlow.incoming => const [
      (milkCategory, TxnType.sale),
      ('Paneer', TxnType.sale),
      ('Khoya', TxnType.sale),
      ('Cattle sale', TxnType.sale),
      ('Dung / manure', TxnType.sale),
      ('Other sale', TxnType.sale),
      // Money in that the farm has not earned. Both raise the cash and
      // leave the profit exactly where it was.
      (securityInCategory, TxnType.receipt),
      (securityRefundCategory, TxnType.receipt),
      (loanRepaidCategory, TxnType.receipt),
    ],
    MoneyFlow.outgoing => const [
      ('Fodder / feed', TxnType.purchase),
      (milkBoughtInCategory, TxnType.purchase),
      ('Vet & medicine', TxnType.purchase),
      ('Food & kitchen', TxnType.purchase),
      ('Salaries', TxnType.expense),
      ('Rent', TxnType.expense),
      ('Utilities (bijli, gas, pani)', TxnType.expense),
      ('Transport', TxnType.expense),
      ('Repairs', TxnType.expense),
      // Things the farm keeps. Money leaves and the profit does not move,
      // because the farm still has what it paid for.
      ('Cattle purchase', TxnType.purchase),
      ('Equipment', TxnType.purchase),
      // Handing back money that was never the farm's, and handing out money
      // that still is. Neither is a cost.
      (securityBackCategory, TxnType.payment),
      (securityOutCategory, TxnType.payment),
      ('Other purchase', TxnType.purchase),
    ],
  };

  List<String> get categories => [for (final c in choices) c.$1];

  /// What the books should record a heading as.
  ///
  /// A heading nobody listed — typed out at the counter — is taken at face
  /// value: money in was earned, money out was spent. That is the safe way
  /// round. The other way, a typed word would raise the cash without the
  /// profit ever noticing, and the books would stop adding up by that much.
  TxnType typeOf(String category) {
    final k = partyKey(category);
    for (final (name, type) in choices) {
      if (partyKey(name) == k) return type;
    }
    return this == MoneyFlow.incoming ? TxnType.sale : TxnType.purchase;
  }

  /// The kinds of entry this direction can produce, for reading the ledger's
  /// own headings back off it.
  List<TxnType> get types => this == MoneyFlow.incoming
      ? const [TxnType.sale, TxnType.receipt]
      : const [TxnType.purchase, TxnType.expense, TxnType.payment];
}

/// What an entry does to the books, in one word.
///
/// The farm asked for a mark beside every heading on the list, so that the
/// answer to "will this change the profit" is visible before anything is
/// picked rather than after. Four answers cover every heading there is.
enum EntryKind {
  /// The farm earned it. The profit goes up.
  earnings('Earnings'),

  /// The farm spent it. The profit goes down.
  cost('Cost'),

  /// The farm still has what it paid for — a buffalo, a machine. Cash out,
  /// profit untouched.
  owned('The farm keeps it'),

  /// Money moving with nothing earned and nothing spent: an advance either
  /// way, a loan instalment. Only the cash changes.
  neither('Only cash');

  const EntryKind(this.label);

  final String label;
}

/// Which of the four a heading is.
///
/// The single fact the mark on the list, the sentence under the heading and
/// the books are all built from — so a heading cannot carry one mark on
/// screen and do something else in the ledger. A test walks every heading on
/// both lists and checks a period holding one entry agrees with this.
EntryKind entryKindOf({
  required TxnType type,
  required String category,
  required bool isAsset,
}) {
  if (type == TxnType.sale) return EntryKind.earnings;
  if (type == TxnType.receipt) {
    return category == securityInCategory ||
            category == securityRefundCategory ||
            category == loanRepaidCategory
        ? EntryKind.neither
        : EntryKind.earnings;
  }
  if (isAsset) return EntryKind.owned;
  if (type == TxnType.payment) {
    return category == securityBackCategory ||
            category == securityOutCategory ||
            category == profitShareCategory
        ? EntryKind.neither
        : EntryKind.cost;
  }
  return EntryKind.cost;
}

/// Whether an entry under this heading moves the profit at all.
bool entryMovesProfit({
  required TxnType type,
  required String category,
  required bool isAsset,
}) {
  final kind = entryKindOf(type: type, category: category, isAsset: isAsset);
  return kind == EntryKind.earnings || kind == EntryKind.cost;
}

/// What an entry about to be saved will do to the books, in one line.
///
/// Shown under the heading on the form. The whole trouble with the old
/// five-button form was that nothing on screen ever said this out loud, so
/// the only way to know whether an entry moved the profit was to know
/// already.
String entryEffect({
  required TxnType type,
  required String category,
  required bool isAsset,
}) {
  if (type == TxnType.sale) {
    return 'This counts as the farm earning money. It raises the profit.';
  }
  if (type == TxnType.receipt) {
    if (category == securityRefundCategory) {
      return 'Not earnings — the farm is getting back an advance it handed '
          'out. The cash goes up and the profit does not move.';
    }
    if (category == securityInCategory) {
      return 'Not earnings — the farm is only holding this money and owes it '
          'back. The cash goes up and the profit does not move.';
    }
    if (category == loanRepaidCategory) {
      return 'Not earnings — the farm is getting its own money back. The cash '
          'goes up and the profit does not move.';
    }
    return 'Nothing already in the books accounts for this, so it counts as '
        'the farm earning it.';
  }
  if (isAsset) {
    return 'Not a cost — the farm owns what it paid for. Only the cash goes '
        'down; the profit does not move.';
  }
  if (type == TxnType.payment) {
    if (category == securityOutCategory) {
      return 'Not a cost — the farm expects this back, so it goes onto their '
          'account. The cash goes down and the profit does not move.';
    }
    if (category == securityBackCategory) {
      return 'Handing back money the farm was holding. Not a cost — the cash '
          'goes down and the profit does not move.';
    }
    return 'Nothing already in the books accounts for this, so it counts as '
        'money the farm spent.';
  }
  return 'This counts as money the farm spent. It takes the profit down.';
}

/// Milk the farm produced itself and sold.
const milkCategory = 'Milk';

/// Milk the farm bought from another farm to sell on.
///
/// Kept apart from feed and everything else the farm buys, because it is the
/// only purchase that is really the cost of a sale. The neighbouring farm
/// hands over a hundred litres at a hundred and eighty; the farm sells a
/// hundred and eighty litres at two hundred. Booked as an ordinary purchase
/// the two disappear into one another and the month says the herd is doing
/// better than it is — the rupees are right either way, but the question
/// "how much of this did our own buffaloes make" has no answer.
///
/// The supplying farm is a party like any other, so what is owed to them
/// reads off their own statement without anything new being built for it.
const milkBoughtInCategory = 'Milk bought in';

/// Which milking a litre came from.
///
/// A buffalo is milked twice a day and the two are not the same trade: the
/// morning is the bigger one and goes out early, the evening is smaller and
/// often sold nearer the gate. Written into the note until now, which means
/// it could not be counted. [Txn.needsShift] says when it must be filled in.
enum MilkShift {
  morning('Morning'),
  evening('Evening');

  const MilkShift(this.label);

  final String label;

  static MilkShift? parse(Object? v) => switch (s(v)) {
    'morning' => MilkShift.morning,
    'evening' => MilkShift.evening,
    _ => null,
  };
}

/// The category a profit share is booked under when a period closes.
///
/// Named rather than typed out, because the books have to be able to tell it
/// from an ordinary payment: it is the one payment that is not a cost.
const profitShareCategory = 'Profit share';

/// What an animal that has left the farm is taken off the books at.
///
/// Posted by the app when a buffalo is sold, dies or is slaughtered, never
/// typed by hand — which is why it is not in the Expense list. The amount is
/// what she cost, because that is what the farm is giving up.
///
/// No money moves on this row. The rupees left the box the day she was
/// bought; this is the farm admitting it no longer has what it bought.
const writeOffCategory = 'Cattle write-off';

/// A security a customer leaves with the farm against a contract.
///
/// Urooj Dairy signs for a year of milk and leaves a deposit first. The
/// milk then goes out and is billed every week or ten days, and those
/// bills are paid on their own; the deposit is not touched by any of it.
/// It sits where it is until one side ends the contract and the farm
/// hands it back.
///
/// So it raises the cash and nothing else: not the sales, not the profit,
/// not one rupee of what the co-founders share out, and — this is the part
/// that is easy to get wrong — not what the shop owes for its milk either.
/// Fold it into his balance and the statement says he owes less for milk
/// than he does. It is reported on its own line instead.
const securityInCategory = 'Security taken';

/// What the app books money in against an entry as.
///
/// Posted by the app alone, never typed: a collection is always against
/// something, and one that names nothing is money the books would read as
/// earned all over again.
const khaataReceiptCategory = 'Khaata receipt';

/// Handing that security back when the contract ends.
const securityBackCategory = 'Security given back';

/// A security the farm leaves with somebody else, and expects back.
///
/// The yard is rented and the landlord wants a deposit before the keys; it
/// comes back when the lease ends. The exact mirror of
/// [securityInCategory], and the farm asked for the two to behave alike.
///
/// Cash leaves the box and that is all that happens: not a cost, because
/// the farm has not spent it — it is owed it. Booked as a purchase, which
/// is how the farm first had to enter one, the month profit drops by the
/// whole deposit and climbs again when it comes back, so two months
/// running say something untrue about how the farm is doing.
///
/// Like the one it is holding, it stays off what that party owes for
/// goods, and is reported on its own line.
const securityOutCategory = 'Security paid';

/// That deposit coming back when the lease or the arrangement ends.
///
/// Cash in and nothing else: the farm is not earning this, it is getting
/// its own money back.
const securityRefundCategory = 'Security got back';

/// Money the farm lends one of its own co-founders.
///
/// The mirror of an advance, and it has to be read the same way round. Cash
/// leaves the box, and that is all that happens: it is not a cost and it must
/// never touch the profit, because it is coming back. Book it as a purchase
/// or an expense — which was the first idea, and an understandable one — and
/// that month's profit drops by the whole loan, so all four co-founders lose
/// their share of money that one of them is going to repay.
///
/// No interest. It is a loan between friends and they have said so.
const founderLoanCategory = 'Founder loan';

/// An instalment coming back, or the founder paying it in himself.
///
/// Cash in and nothing else, for the same reason: the farm is not earning
/// this, it is getting its own money back. Counted as income and the profit
/// would climb by the whole loan over the term, and all four would be handed
/// a share of a rupee that was never made.
const loanRepaidCategory = 'Loan repayment';

/// Categories the app posts for itself, and nobody types by hand.
///
/// Each of these is written as one half of something the books already
/// understand: a collection against an entry, a founder's slice at a close, an
/// animal coming off the register, money lent through the loan it belongs to.
/// Typed loose, each one is the same money counted a second time or a figure
/// with no arrangement behind it.
///
/// Keeping them off the fixed lists was never enough. The entry form also
/// offers back every heading the books already carry, so that a word written
/// once is a tap from then on — and that read them straight out of the ledger
/// and handed them back, which is how "Profit share" turned up as something to
/// pick on the payment form.
///
/// An advance and a loan instalment are deliberately absent from this set:
/// both are ordinary things a person does at a counter, and both are safe to
/// type because neither can ever be read as income or as a cost.
const appPostedCategories = {
  khaataReceiptCategory,
  profitShareCategory,
  writeOffCategory,
  founderLoanCategory,
};

/// Units offered on the new-entry form.
const txnUnits = ['L', 'kg', 'maund', 'bag', 'pc', 'head', 'month'];

/// How the money actually changed hands.
///
/// A farm's books are settled in person — someone hands over notes, someone
/// else gets a JazzCash message — and a month later the only way to check a
/// figure is to remember which. Recording it at the time is what makes that
/// possible.
enum PayVia {
  cash,
  bank,
  jazzcash,
  other;

  static PayVia parse(Object? v) => switch (s(v)) {
    'bank' => PayVia.bank,
    'jazzcash' => PayVia.jazzcash,
    'other' => PayVia.other,
    _ => PayVia.cash,
  };

  String get label => switch (this) {
    PayVia.cash => 'Cash',
    PayVia.bank => 'Bank',
    PayVia.jazzcash => 'JazzCash',
    PayVia.other => 'Other',
  };
}

/// Buying a buffalo is not a cost the way a bag of feed is. The cash leaves
/// either way, but the farm still owns the animal — it changed shape, it was
/// not spent. Counting it as a monthly cost would show a huge loss in the month
/// it was bought and flattering profits ever after, so these categories are
/// held out of the profit and reported as what the farm owns.
const assetCategories = {'Cattle purchase', 'Equipment'};

class Txn {
  Txn({
    required this.id,
    required this.date,
    required this.monthId,
    required this.type,
    required this.party,
    this.customerId,
    required this.category,
    this.qty,
    this.unit,
    this.rate,
    required this.amount,
    required this.paid,
    num? paidSoFar,
    this.paidAt,
    required this.note,
    this.orderId,
    this.settlesTxnId,
    this.capital,
    this.shift,
    this.paidOnCreate = false,
    this.payVia = PayVia.cash,
    this.handledBy = '',
    required this.createdBy,
    this.createdByName = '',
    required this.createdAt,
    this.deletedAt,
    // An entry written before part payments were kept says only whether it
    // was settled, so read it that way: all of it, or none of it.
  }) : paidSoFar = paidSoFar ?? (paid ? amount : 0);

  final String id;
  final DateTime date;
  final String monthId;
  final TxnType type;
  final String party;
  final String? customerId;
  final String category;
  final num? qty;
  final String? unit;
  final num? rate;
  final num amount;
  final bool paid;

  /// Whether this bought something the farm now owns, when the category is
  /// one somebody typed rather than one off the list.
  ///
  /// Null on every entry written under a listed category, and on every entry
  /// written before this existed — those are read off [assetCategories] as
  /// they always were. A typed word is not on that list and never will be, so
  /// the answer is asked once and kept on the entry itself. On the entry, and
  /// not in a settings list, because a list can be edited afterwards and would
  /// quietly rewrite what last year's profit was.
  final bool? capital;

  /// Which milking this milk came from, or null on an entry written before
  /// the app asked. Null is "nobody said", never a guess — a litre put in
  /// the wrong half of the day is worse than one that admits it is unknown.
  final MilkShift? shift;

  /// How much of [amount] has actually been taken against this entry.
  ///
  /// A milk round sells on credit twice a day and gets paid in one lump on a
  /// Friday, and the lump rarely lands on an entry boundary: a customer hands
  /// over 100,000 against 120,000 of milk, and one entry ends up half settled.
  /// Before this, an entry was paid or it was not, so the odd 20,000 had
  /// nowhere to live and the farm carried it in its head.
  ///
  /// Entries written before this is read back from the old flag: settled means
  /// all of it, unsettled means none.
  final num paidSoFar;

  /// What is still owed on this entry. Zero once it is fully settled.
  num get outstanding {
    final left = amount - paidSoFar;
    return left > 0 ? left : 0;
  }

  /// Something has been taken against it, but not all of it.
  bool get partlyPaid => paidSoFar > 0 && outstanding > 0;

  final DateTime? paidAt;
  final String note;
  final String? orderId;

  /// Set on the receipt or payment that "Mark paid" posts against an entry.
  ///
  /// The cash it moves is already captured by that entry flipping to paid, so
  /// the balance must not count this row a second time. It exists so the ledger
  /// and the Google Sheet still show when the money actually changed hands.
  final String? settlesTxnId;

  /// Named apart from `type.isSettlement`, which asks a different question:
  /// whether this is a receipt or payment at all.
  bool get settlesAnotherEntry => settlesTxnId != null;

  /// True when the money changed hands as this entry was written — "Paid now"
  /// on the form.
  ///
  /// An entry booked on credit is false forever, even after it is settled: the
  /// cash for it moves on the receipt or payment row that "Mark paid" posts,
  /// which may well be in a later month. Keeping the two apart is what lets a
  /// balance stay right across a month close.
  final bool paidOnCreate;

  /// Cash, bank or JazzCash — only meaningful once the money has moved.
  final PayVia payVia;

  /// The person who handed the money over or took it in. Not the person who
  /// typed the entry: the worker who went to the mandi may not be the
  /// co-founder who recorded it that evening.
  final String handledBy;

  /// "Received by" for money coming in, "Paid by" for money going out.
  String get handledLabel => type.isIncoming ? 'Received by' : 'Paid by';

  /// "Cash · Riaz" for the ledger row, empty when nothing was recorded.
  String get handOverLine {
    if (!paid) return '';
    final who = handledBy.trim();
    return who.isEmpty ? payVia.label : '${payVia.label} · $who';
  }

  final String createdBy;

  /// Who typed this in.
  ///
  /// Not the same person as [handledBy], and the difference is the point: the
  /// rider takes the money at the door and a co-founder enters it that
  /// evening. A month later, an entry nobody can be asked about is an entry
  /// nobody can check.
  ///
  /// Empty on anything written before the name was kept.
  final String createdByName;

  final DateTime createdAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  /// Cattle and equipment the farm now owns, rather than money it spent.
  bool get isCapitalAsset =>
      (type == TxnType.purchase || type == TxnType.expense) &&
      (capital ?? assetCategories.contains(category));

  /// Milk the farm produced and sold.
  bool get isMilkSale => type == TxnType.sale && category == milkCategory;

  /// Milk bought off another farm to sell on. A cost of the sale, not a cost
  /// of running the place — see [milkBoughtInCategory].
  bool get isMilkBoughtIn =>
      type == TxnType.purchase && category == milkBoughtInCategory;

  /// Whether this entry has to say which milking it was.
  ///
  /// Only milk, and only the two rows that carry litres. A payment against a
  /// milk bill is not a milking, so it is not asked.
  bool get needsShift => isMilkSale || isMilkBoughtIn;

  /// A co-founder's share of the profit, paid out when a period closed.
  ///
  /// Money leaving the farm, but not a cost of running it — it is the farm's
  /// earnings going to the people who own them.
  bool get isProfitShare => category == profitShareCategory;

  /// An animal taken off the books — sold, died or slaughtered.
  ///
  /// A cost, because the farm has given up something it owned, and the profit
  /// has to know. Not cash: nothing moves on the day it is written.
  bool get isWriteOff =>
      type == TxnType.expense && category == writeOffCategory;

  /// A payment that settles nothing.
  ///
  /// Money went out and no purchase or expense anywhere accounts for it, so
  /// this row is the only record that the farm spent it. Counted as a cost —
  /// otherwise the rupees leave the cash and the profit never notices.
  bool get isLoosePayment =>
      type == TxnType.payment &&
      !settlesAnotherEntry &&
      !isProfitShare &&
      !isSecurityBack &&
      !isSecurityOut &&
      !isLoanOut;

  /// An advance taken in against a standing order. Cash in, and nothing
  /// else: the farm is holding this money, not earning it.
  bool get isSecurityIn =>
      type == TxnType.receipt && category == securityInCategory;

  /// That advance handed back when the contract ends. Cash out, and
  /// nothing else: it was never the farm's to spend.
  bool get isSecurityBack =>
      type == TxnType.payment && category == securityBackCategory;

  /// An advance the farm handed out and expects back. Cash out, and
  /// nothing else — the farm has not spent it, it is owed it.
  bool get isSecurityOut =>
      type == TxnType.payment && category == securityOutCategory;

  /// That advance coming back. Cash in, and nothing else.
  bool get isSecurityRefund =>
      type == TxnType.receipt && category == securityRefundCategory;

  /// A receipt that settles nothing — the other side of [isLoosePayment].
  ///
  /// Money came in and no sale anywhere accounts for it, so this row is the
  /// only record that the farm earned it. Counted as income, for the same
  /// reason its opposite is counted as a cost: otherwise the rupees land in
  /// the cash and the profit never notices, and the books stop adding up by
  /// exactly that much.
  bool get isLooseReceipt =>
      type == TxnType.receipt &&
      !settlesAnotherEntry &&
      !isSecurityIn &&
      !isSecurityRefund &&
      !isLoanBack;

  /// Money lent to a co-founder. Cash out, and nothing else.
  bool get isLoanOut =>
      type == TxnType.payment && category == founderLoanCategory;

  /// An instalment of it coming back. Cash in, and nothing else.
  bool get isLoanBack =>
      type == TxnType.receipt && category == loanRepaidCategory;

  /// Feed, salaries, bills — the cost of running the farm this month.
  bool get isRunningCost =>
      ((type == TxnType.purchase || type == TxnType.expense) &&
          !isCapitalAsset) ||
      isLoosePayment;

  /// Unpaid sales are receivables; unpaid purchases and expenses are payables.
  bool get isReceivable => !paid && type == TxnType.sale;
  bool get isPayable =>
      !paid && (type == TxnType.purchase || type == TxnType.expense);

  /// Reads back as "240 L x Rs 200" when the entry was measured.
  String? get qtyLine {
    final q = qty, r = rate;
    if (q == null || r == null || q == 0) return null;
    final qs = q % 1 == 0 ? q.toInt().toString() : q.toString();
    return '$qs ${unit ?? ''} × Rs ${r.round()}';
  }

  /// Entries written before the app recorded [paidOnCreate] are read back from
  /// their timestamps: money that moved as the row was created has a `paidAt`
  /// alongside its `createdAt`, while "Mark paid" stamps one much later.
  static bool _wasPaidOnCreate(bool paid, DateTime? paidAt, DateTime created) {
    if (!paid) return false;
    if (paidAt == null) return true;
    return paidAt.difference(created).abs() < const Duration(minutes: 2);
  }

  factory Txn.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    final date = dtOr(m['date']);
    final paid = b(m['paid']);
    final paidAt = dt(m['paidAt']);
    final createdAt = dtOr(m['createdAt'], date);
    return Txn(
      id: doc.id,
      date: date,
      monthId: s(m['monthId']).isEmpty ? monthIdOf(date) : s(m['monthId']),
      type: TxnType.parse(m['type']),
      party: s(m['party']),
      customerId: m['customerId'] == null ? null : s(m['customerId']),
      category: s(m['category']),
      qty: m['qty'] == null ? null : n(m['qty']),
      unit: m['unit'] == null ? null : s(m['unit']),
      rate: m['rate'] == null ? null : n(m['rate']),
      amount: n(m['amount']),
      paid: paid,
      paidSoFar: m['paidSoFar'] == null ? null : n(m['paidSoFar']),
      paidAt: paidAt,
      note: s(m['note']),
      orderId: m['orderId'] == null ? null : s(m['orderId']),
      settlesTxnId: m['settlesTxnId'] == null ? null : s(m['settlesTxnId']),
      capital: m['capital'] == null ? null : b(m['capital']),
      shift: MilkShift.parse(m['shift']),
      paidOnCreate: m['paidOnCreate'] == null
          ? _wasPaidOnCreate(paid, paidAt, createdAt)
          : b(m['paidOnCreate']),
      payVia: PayVia.parse(m['payVia']),
      handledBy: s(m['handledBy']),
      createdBy: s(m['createdBy']),
      createdByName: s(m['createdByName']),
      createdAt: createdAt,
      deletedAt: dt(m['deletedAt']),
    );
  }
}
