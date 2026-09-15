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
                 t.type == TxnType.expense && t.paidOnCreate && !t.isWriteOff,
           )
           .fold<num>(0, (a, t) => a + t.amount),
       writeOffs = monthTxns
           .where((t) => t.isWriteOff)
           .fold<num>(0, (a, t) => a + t.amount),
       receivable = unpaidTxns
           .where((t) => t.isReceivable)
           .fold<num>(0, (a, t) => a + t.amount),
       payable = unpaidTxns
           .where((t) => t.isPayable)
           .fold<num>(0, (a, t) => a + t.amount);

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
  num get cash => capital + operatingCash - withRider;

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
  num get farmMoney => cash + withRider + receivable - payable;

  /// The same figure read down the waterfall — every rupee that came in, less
  /// every rupee that went out or turned into an animal. It should equal
  /// [farmMoney]; when it does not, an entry is missing or counted twice.
  num get expected =>
      capital - assets - runningCosts + sales + otherIncome - paidOut;

  bool get reconciles => (expected - farmMoney).abs() < 1;
}

/// Whole-rupee shares for a month close, one per partner.
///
/// Rounding each share on its own would leave a rupee or two unaccounted for —
/// three partners on a profit of 100 would take 33 each. The leftover goes to
/// the largest share, so the shares always add up to exactly what was shared.
List<MonthShare> shareOut({
  required List<Partner> partners,
  required num profitToShare,
  required Map<String, String> choices,
}) {
  final ratios = ratiosOf(partners);
  final shares = partners
      .map(
        (p) => MonthShare(
          partnerId: p.id,
          name: p.name,
          ratio: ratios[p.id] ?? 0,
          share: (profitToShare * (ratios[p.id] ?? 0)).round(),
          choice: choices[p.id] ?? 'withdraw',
        ),
      )
      .toList();

  if (shares.isEmpty) return shares;

  final remainder =
      profitToShare.round() -
      shares.fold<int>(0, (a, s) => a + s.share.round());
  if (remainder == 0) return shares;

  var biggest = 0;
  for (var i = 1; i < shares.length; i++) {
    if (shares[i].share > shares[biggest].share) biggest = i;
  }
  shares[biggest] = MonthShare(
    partnerId: shares[biggest].partnerId,
    name: shares[biggest].name,
    ratio: shares[biggest].ratio,
    share: shares[biggest].share + remainder,
    choice: shares[biggest].choice,
  );
  return shares;
}
