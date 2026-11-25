import '../models/models.dart';
import '../util/money.dart';
import 'accounting.dart';

/// Checking the books against themselves.
///
/// Four friends' savings are in here and the surest way for them to fall out
/// over it is for one of them to doubt a figure and have no way to test it.
/// Every figure in the app is worked out from the entries, so the entries
/// are the only thing that can be wrong — and the ways they can be wrong are
/// few and all of them are findable.
///
/// This finds them. It changes nothing: it reads the ledger and says what
/// does not hold together, naming the entries so whoever is looking can open
/// each one and see for himself.
///
/// What it does not do is guess. Everything here is a thing that cannot be
/// true at the same time as something else in the same books — not a thing
/// that looks unusual. A page that cries wolf is a page nobody opens the
/// month something is actually wrong.

/// How much a finding matters.
enum AuditLevel {
  /// The books cannot be right while this stands.
  wrong,

  /// Nothing is provably broken; somebody should look.
  odd,
}

/// What was checked.
enum AuditCheck {
  /// More has been taken against an entry than the entry is for.
  paidPastAmount,

  /// It is marked settled and money is still owed on it.
  saidPaidStillOwing,

  /// A receipt or payment pointing at an entry that is no longer there.
  settlesNothing,

  /// The settlements against one entry come to more than the entry.
  overSettled,

  /// Half a handover: one pair of hands went down and none went up.
  halfHandover,

  /// More advance taken back off a man than was ever lent to him.
  advanceBackPastLent,

  /// The same, for a loan.
  loanBackPastLent,

  /// An entry with nobody and nothing on it.
  noName,

  /// Dated after today.
  future,

  /// The same name, day, amount and heading, twice.
  twiceOver,

  /// What the farm says it has does not match what it should have.
  cashDoesNotAdd,
}

/// One thing the audit found.
class AuditNote {
  const AuditNote({
    required this.check,
    required this.level,
    required this.about,
    this.amount = 0,
    this.ids = const [],
  });

  final AuditCheck check;
  final AuditLevel level;

  /// What it is about, in the farm's own words — a name, a day, a heading.
  final String about;

  /// The rupees in it, where that means anything.
  final num amount;

  /// The entries behind it, so the page can open them.
  final List<String> ids;
}

/// What the whole audit came to.
class AuditResult {
  const AuditResult({required this.notes, required this.checked});

  /// Worst first.
  final List<AuditNote> notes;

  /// How many entries were read.
  final int checked;

  Iterable<AuditNote> get wrong =>
      notes.where((n) => n.level == AuditLevel.wrong);

  Iterable<AuditNote> get odd => notes.where((n) => n.level == AuditLevel.odd);

  bool get clean => notes.isEmpty;
}

/// A day, with the time thrown away.
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Read the books and say what does not hold together.
///
/// [money] is the farm's own balance, when the page has it. Handed in rather
/// than worked out here so the audit and the card above it can never disagree
/// about the farm's cash.
AuditResult auditTheBooks(
  List<Txn> ledger, {
  MoneySummary? money,
  DateTime? today,
}) {
  final live = ledger.where((t) => !t.isDeleted).toList();
  final notes = <AuditNote>[];
  final now = _day(today ?? DateTime.now());

  final byId = {for (final t in live) t.id: t};

  // ---- one entry at a time ----
  for (final t in live) {
    if (t.paidSoFar > t.amount + 0.5) {
      notes.add(
        AuditNote(
          check: AuditCheck.paidPastAmount,
          level: AuditLevel.wrong,
          about: _says(t),
          amount: t.paidSoFar - t.amount,
          ids: [t.id],
        ),
      );
    }

    if (t.paid && t.outstanding > 0.5) {
      notes.add(
        AuditNote(
          check: AuditCheck.saidPaidStillOwing,
          level: AuditLevel.wrong,
          about: _says(t),
          amount: t.outstanding,
          ids: [t.id],
        ),
      );
    }

    if (t.party.trim().isEmpty && t.category.trim().isEmpty) {
      notes.add(
        AuditNote(
          check: AuditCheck.noName,
          level: AuditLevel.odd,
          about: fmtDate(t.date),
          amount: t.amount,
          ids: [t.id],
        ),
      );
    }

    if (_day(t.date).isAfter(now)) {
      notes.add(
        AuditNote(
          check: AuditCheck.future,
          level: AuditLevel.odd,
          about: _says(t),
          amount: t.amount,
          ids: [t.id],
        ),
      );
    }

    // A settlement whose entry is gone is money settling nothing — the
    // cash moved and no balance came down by it.
    final points = t.settlesTxnId;
    if (points != null && points.isNotEmpty && !byId.containsKey(points)) {
      notes.add(
        AuditNote(
          check: AuditCheck.settlesNothing,
          level: AuditLevel.wrong,
          about: _says(t),
          amount: t.amount,
          ids: [t.id],
        ),
      );
    }
  }

  // ---- what has been taken against each entry ----
  //
  // The advance and the loan coming back off a wage point at that wage so
  // they can be found again — they do not settle it. Counting them here
  // would call every wage over-settled.
  final against = <String, num>{};
  for (final t in live) {
    final points = t.settlesTxnId;
    if (points == null || points.isEmpty) continue;
    if (t.isWageAdvanceBack || t.isStaffLoanBack) continue;
    against[points] = (against[points] ?? 0) + t.amount;
  }
  for (final e in against.entries) {
    final parent = byId[e.key];
    if (parent == null) continue;
    if (e.value > parent.amount + 0.5) {
      notes.add(
        AuditNote(
          check: AuditCheck.overSettled,
          level: AuditLevel.wrong,
          about: _says(parent),
          amount: e.value - parent.amount,
          ids: [parent.id],
        ),
      );
    }
  }

  // ---- handovers come in pairs ----
  final pairs = <String, List<Txn>>{};
  for (final t in live) {
    if (!t.hasPair) continue;
    pairs.putIfAbsent(t.pairId!, () => []).add(t);
  }
  for (final e in pairs.entries) {
    if (e.value.length == 2) continue;
    notes.add(
      AuditNote(
        check: AuditCheck.halfHandover,
        level: AuditLevel.wrong,
        about: _says(e.value.first),
        amount: e.value.first.amount,
        ids: [for (final t in e.value) t.id],
      ),
    );
  }

  // ---- a man cannot give back more than he was given ----
  notes.addAll(
    _backPastLent(
      live,
      out: (t) => t.isWageAdvance,
      back: (t) => t.isWageAdvanceBack,
      check: AuditCheck.advanceBackPastLent,
    ),
  );
  notes.addAll(
    _backPastLent(
      live,
      out: (t) => t.isStaffLoan,
      back: (t) => t.isStaffLoanBack,
      check: AuditCheck.loanBackPastLent,
    ),
  );

  // ---- the same entry, typed twice ----
  //
  // Not proof of anything: a farm really can buy two identical loads of
  // wanda on one day. It is the commonest way a figure goes wrong though,
  // and five seconds of looking settles it either way.
  final seen = <String, List<Txn>>{};
  for (final t in live) {
    if (t.isPartOfATake || t.hasPair) continue;
    final key =
        '${partyKey(t.party)}|${partyKey(t.category)}|'
        '${_day(t.date).millisecondsSinceEpoch}|${t.amount}|${t.type.name}';
    seen.putIfAbsent(key, () => []).add(t);
  }
  for (final e in seen.entries) {
    if (e.value.length < 2) continue;
    final t = e.value.first;
    notes.add(
      AuditNote(
        check: AuditCheck.twiceOver,
        level: AuditLevel.odd,
        about: '${_says(t)} · ${fmtDate(t.date)}',
        amount: t.amount * (e.value.length - 1),
        ids: [for (final x in e.value) x.id],
      ),
    );
  }

  // ---- and the farm's own balance ----
  if (money != null && !money.reconciles) {
    notes.add(
      AuditNote(
        check: AuditCheck.cashDoesNotAdd,
        level: AuditLevel.wrong,
        about: '',
        amount: (money.expected - money.farmMoney).abs(),
      ),
    );
  }

  notes.sort((a, b) {
    final by = a.level.index.compareTo(b.level.index);
    return by != 0 ? by : b.amount.compareTo(a.amount);
  });

  return AuditResult(notes: notes, checked: live.length);
}

/// Who has had more back off him than was ever handed to him.
List<AuditNote> _backPastLent(
  List<Txn> live, {
  required bool Function(Txn) out,
  required bool Function(Txn) back,
  required AuditCheck check,
}) {
  final lent = <String, num>{};
  final returned = <String, num>{};
  final names = <String, String>{};
  for (final t in live) {
    final key = partyKey(t.party);
    if (key.isEmpty) continue;
    if (out(t)) {
      lent[key] = (lent[key] ?? 0) + t.amount;
      names[key] = t.party.trim();
    } else if (back(t)) {
      returned[key] = (returned[key] ?? 0) + t.amount;
      names[key] = t.party.trim();
    }
  }

  final notes = <AuditNote>[];
  for (final key in {...lent.keys, ...returned.keys}) {
    final over = (returned[key] ?? 0) - (lent[key] ?? 0);
    if (over <= 0.5) continue;
    notes.add(
      AuditNote(
        check: check,
        level: AuditLevel.wrong,
        about: names[key] ?? key,
        amount: over,
        ids: [
          for (final t in live)
            if (partyKey(t.party) == key && (out(t) || back(t))) t.id,
        ],
      ),
    );
  }
  return notes;
}

/// What an entry says it is, for naming it on a finding.
String _says(Txn t) {
  final who = t.party.trim();
  final what = t.category.trim();
  if (who.isEmpty) return what.isEmpty ? '—' : what;
  if (what.isEmpty) return who;
  return '$who · $what';
}
