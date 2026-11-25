import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/audit.dart';
import '../../state/farm_store.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';
import 'accounts_screen.dart';

/// The books, checked against themselves, in front of everybody.
///
/// Four friends' savings are in here, and the surest way for them to fall
/// out over it is for one of them to doubt a figure and have no way to test
/// it. Every figure in the app comes off the entries, so the entries are the
/// only thing that can be wrong — and this page says which ones, by name,
/// with the way to open each of them.
///
/// It changes nothing. Nobody should have to trust a page that can also
/// quietly mend things.
class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<FarmStore>();
    final result = auditTheBooks(store.ledger, money: store.money);

    return FarmScaffold(
      title: l.t('Audit'),
      showBack: true,
      body: PageBody(
        children: [
          Text(l.t2('%s entries read.', '${result.checked}'), style: T.meta),
          const SizedBox(height: 12),

          if (result.clean)
            RegCard(
              wash: T.moneyIn.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Icon(Icons.verified_outlined, color: T.moneyIn, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.t(
                        'Nothing is out of place. Every entry adds up, every '
                        'settlement has something to settle, and the farm '
                        'holds what the books say it holds.',
                      ),
                      style: T.body,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if (result.wrong.isNotEmpty) ...[
              SectionTitle(l.t('This cannot be right')),
              const SizedBox(height: 6),
              for (final note in result.wrong) _Note(note: note, store: store),
              const SizedBox(height: 16),
            ],
            if (result.odd.isNotEmpty) ...[
              SectionTitle(l.t('Worth a look')),
              const SizedBox(height: 6),
              for (final note in result.odd) _Note(note: note, store: store),
            ],
          ],

          const SizedBox(height: 16),
          Text(
            l.t(
              'This page only reads. It never changes an entry — a check '
              'that can also mend things is a check nobody can trust. Open '
              'an entry to correct it yourself.',
            ),
            style: T.meta,
          ),
        ],
      ),
    );
  }
}

/// One finding, with the way to the entries behind it.
class _Note extends StatelessWidget {
  const _Note({required this.note, required this.store});

  final AuditNote note;
  final FarmStore store;

  /// What this check means, in the farm's own words.
  static String saidBy(L l, AuditNote n) => switch (n.check) {
    AuditCheck.paidPastAmount => l.t2(
      '%s more has been taken against this entry than the entry is for.',
      rs(n.amount),
    ),
    AuditCheck.saidPaidStillOwing => l.t2(
      'Marked settled, and %s is still owed on it.',
      rs(n.amount),
    ),
    AuditCheck.settlesNothing => l.t(
      'This money was taken against an entry that is no longer on the '
      'books, so nothing came down by it.',
    ),
    AuditCheck.overSettled => l.t2(
      '%s more has been settled against this entry than it was ever for.',
      rs(n.amount),
    ),
    AuditCheck.halfHandover => l.t(
      'Half a handover: one pair of hands went down and no other went up.',
    ),
    AuditCheck.advanceBackPastLent => l.t2(
      '%s more advance has come back off him than was ever handed to him.',
      rs(n.amount),
    ),
    AuditCheck.loanBackPastLent => l.t2(
      '%s more has come back off his loan than was ever lent to him.',
      rs(n.amount),
    ),
    AuditCheck.noName => l.t('An entry with nobody and nothing on it.'),
    AuditCheck.future => l.t('Dated after today.'),
    AuditCheck.twiceOver => l.t(
      'The same name, day, amount and heading more than once. It can be '
      'real — but this is the commonest way a figure goes wrong.',
    ),
    AuditCheck.cashDoesNotAdd => l.t2(
      'What the farm holds is out by %s against what it should hold. It '
      'is nearly always one entry typed twice or one never typed at all.',
      rs(n.amount),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final bad = note.level == AuditLevel.wrong;
    final tone = bad ? T.moneyOut : T.moneyDue;

    final rows = [
      for (final id in note.ids)
        ...store.ledger.where((t) => t.id == id && !t.isDeleted),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RegCard(
        stripe: tone,
        padding: const EdgeInsets.all(12),
        onTap: rows.isEmpty ? null : () => _open(context, rows.first),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  bad ? Icons.priority_high : Icons.error_outline,
                  size: 17,
                  color: tone,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    note.about.isEmpty ? l.t('The farm') : note.about,
                    style: T.bodyMid,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (note.amount > 0)
                  Text(rs(note.amount), style: T.bodyMid.copyWith(color: tone)),
              ],
            ),
            const SizedBox(height: 5),
            Text(saidBy(l, note), style: T.meta),
            if (rows.length > 1) ...[
              const SizedBox(height: 5),
              Text(
                l.t2('%s entries', '${rows.length}'),
                style: T.meta.copyWith(color: tone),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Opens the ledger at the name this is about, where the entry can be
  /// read in its own surroundings and corrected if it needs to be.
  void _open(BuildContext context, Txn txn) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider<FarmStore>.value(
        value: store,
        child: AccountsScreen(
          initialParty: txn.party.trim().isEmpty ? null : txn.party.trim(),
        ),
      ),
    ),
  );
}
