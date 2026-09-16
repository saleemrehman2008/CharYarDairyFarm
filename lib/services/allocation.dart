import '../models/models.dart';

/// How much of one payment lands on one entry.
class Landed {
  const Landed({required this.entry, required this.take});

  final Txn entry;

  /// The part of the money that went onto this entry. Never more than what
  /// was still owed on it.
  final num take;

  /// What the entry has taken in total once this lands.
  num get paidAfter => entry.paidSoFar + take;

  /// What is still owed on it afterwards.
  num get owingAfter => entry.amount - paidAfter;

  bool get finishes => owingAfter <= 0;
}

/// Where one lump of money goes across a stack of entries.
///
/// Oldest first. That is the only order that needs explaining to nobody: the
/// entry the money runs out on is then the oldest one still owing, so the next
/// payment picks up exactly where this one stopped, and a customer's account
/// works its way forward in the order the milk was delivered.
///
/// Nothing lands on an entry that is already settled, nothing takes more than
/// what is owed on it, and the parts always add back up to whatever was
/// handed over — capped at the total owed, because a slipped digit is a slip
/// and not a credit the farm is now holding.
///
/// Pure on purpose: this is the rule the whole ledger turns on, so it is
/// worked out somewhere a test can run it a thousand times without a database.
List<Landed> allocate(List<Txn> entries, num amount) {
  if (amount <= 0) return const [];

  final owing = entries.where((t) => t.outstanding > 0).toList()
    ..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
    });

  final out = <Landed>[];
  var purse = amount;
  for (final txn in owing) {
    if (purse <= 0) break;
    final take = purse < txn.outstanding ? purse : txn.outstanding;
    purse -= take;
    out.add(Landed(entry: txn, take: take));
  }
  return out;
}
