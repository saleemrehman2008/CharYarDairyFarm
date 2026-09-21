import '../models/models.dart';

/// Every category the books already carry, and which tab each one sits on.
///
/// Read off the ledger rather than kept as a list of its own, for the same
/// reason the names are: a second list is a second thing to fall out of step.
/// A word exists the moment somebody uses it and can never be missing.
///
/// Folded the way names are folded, so `mazdoori` and `Mazdoori` are one
/// heading and not two rows in the summary — and the spelling that comes back
/// is whichever one the farm has written most.
Map<TxnType, List<String>> categoriesUsed(List<Txn> ledger) {
  final byType = <TxnType, Map<String, _Tally>>{};
  for (final t in ledger) {
    final name = t.category.trim();
    if (name.isEmpty) continue;
    final seen = byType.putIfAbsent(t.type, () => <String, _Tally>{});
    seen.putIfAbsent(partyKey(name), _Tally.new).saw(name);
  }
  return {
    for (final e in byType.entries)
      e.key: [for (final t in e.value.values) t.commonest]
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
  };
}

/// Which tabs a word is already being used on — listed there, or written
/// there by somebody.
///
/// Asked before a typed category is accepted. A word that already lives on
/// another tab is almost always somebody in the wrong place, and that is the
/// one thing worth stopping them for: "Rent" on the Sale tab does not just
/// look odd, it turns a cost into income and moves the profit twice over.
List<TxnType> tabsUsingCategory(List<Txn> ledger, String category) {
  final k = partyKey(category);
  if (k.isEmpty) return const [];
  return [
    for (final type in TxnType.values)
      if (type.categories.any((c) => partyKey(c) == k) ||
          ledger.any((t) => t.type == type && partyKey(t.category) == k))
        type,
  ];
}

class _Tally {
  final Map<String, int> spellings = {};

  void saw(String spelling) =>
      spellings[spelling] = (spellings[spelling] ?? 0) + 1;

  String get commonest =>
      spellings.entries.reduce((a, b) => b.value > a.value ? b : a).key;
}
