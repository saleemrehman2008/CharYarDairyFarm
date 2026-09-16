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
      'Milk',
      'Dahi',
      'Butter',
      'Ghee',
      'Lassi',
      'Paneer',
      'Cream',
      'Khoya',
      'Cattle sale',
      'Dung / manure',
      'Other sale',
    ],
    TxnType.purchase => const [
      'Fodder / feed',
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
    TxnType.receipt => const [advanceCategory, 'Other receipt'],
    // Deliberately short. A payment settles something the books already
    // know about; it is not the place to record what the money was for. Rent,
    // salaries and bills used to be offered here as well as under Expense,
    // and picking the wrong one put the money out of the farm's cash without
    // ever counting it as a cost — so the profit never moved.
    TxnType.payment => const [
      'Supplier payment',
      advanceReturnCategory,
      'Other payment',
    ],
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

/// Money a customer leaves with the farm to hold, against a standing
/// order.
///
/// Not a payment for anything, and never the farm's earnings. A contract
/// for 80 litres a day starts with the customer handing over an advance;
/// a fortnight later they pay that fortnight's milk bill on top, and the
/// advance is untouched. It sits there until one side ends the contract
/// and the farm hands it back.
///
/// So it raises the cash and nothing else: not the sales, not the profit,
/// and not one rupee of what the co-founders share out. The farm is
/// holding somebody else's money.
const advanceCategory = 'Advance';

/// What the app books money in against an entry as.
///
/// Posted by the app alone, never typed: a collection is always against
/// something, and one that names nothing is money the books would read as
/// earned all over again.
const khaataReceiptCategory = 'Khaata receipt';

/// Handing that money back when the contract ends.
const advanceReturnCategory = 'Advance returned';

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
      assetCategories.contains(category);

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
      !isAdvanceOut;

  /// An advance taken in against a standing order. Cash in, and nothing
  /// else: the farm is holding this money, not earning it.
  bool get isAdvanceIn =>
      type == TxnType.receipt && category == advanceCategory;

  /// That advance handed back when the contract ends. Cash out, and
  /// nothing else: it was never the farm's to spend.
  bool get isAdvanceOut =>
      type == TxnType.payment && category == advanceReturnCategory;

  /// A receipt that settles nothing — the other side of [isLoosePayment].
  ///
  /// Money came in and no sale anywhere accounts for it, so this row is the
  /// only record that the farm earned it. Counted as income, for the same
  /// reason its opposite is counted as a cost: otherwise the rupees land in
  /// the cash and the profit never notices, and the books stop adding up by
  /// exactly that much.
  bool get isLooseReceipt =>
      type == TxnType.receipt && !settlesAnotherEntry && !isAdvanceIn;

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
