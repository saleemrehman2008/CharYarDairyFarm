import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../services/log_service.dart';
import '../../services/txn_repo.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/entry_actions.dart';
import '../../widgets/ui.dart';

/// Which of the two lists is on screen.
enum _Shown {
  everything('Everything'),

  /// Entries changed or taken out after they were written.
  ///
  /// Its own list because it answers its own question, and because the
  /// question is the one four friends with their savings in a farm will
  /// actually ask: who has been back over the books. Mixed in with logins and
  /// new entries it is there but it is not readable, which for a record of
  /// this kind is nearly the same as not being kept.
  changes('Changes to entries');

  const _Shown(this.label);

  final String label;
}

/// Everything anybody has done on the farm, newest first, loading more as
/// the list is pulled down.
///
/// Open to every co-founder, not just the master. Four friends are putting
/// their savings in together, and a record only one of them can see is not a
/// record — it is that one person's word. Append-only: not even the master
/// can change a line once it is written.
class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  static const _page = 60;

  /// The changes list reaches further back before it filters.
  ///
  /// Corrections are rare next to logins and new entries — which is the point
  /// of them — so sixty lines of everything can easily hold two of these. The
  /// filtering is done here rather than in the query on purpose: asking
  /// Firestore for one kind of line in date order needs an index built by
  /// hand in the console, and the farm should not have to go and do that for
  /// a list this size.
  static const _deepPage = 400;

  int _limit = _page;
  _Shown _shown = _Shown.everything;

  void _show(_Shown shown) => setState(() {
    _shown = shown;
    _limit = shown == _Shown.changes ? _deepPage : _page;
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return FarmScaffold(
      title: l.t('Activity log'),
      showBack: true,
      body: StreamBuilder<List<LogEntry>>(
        stream: Db.watchLogs(limit: _limit),
        builder: (context, snap) {
          final all = snap.data ?? const <LogEntry>[];
          if (snap.connectionState == ConnectionState.waiting && all.isEmpty) {
            return const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          final onlyChanges = _shown == _Shown.changes;
          final entries = onlyChanges
              ? all.where((e) => e.kind.changedAnEntry).toList()
              : all;
          final hasMore = all.length >= _limit;

          return NotificationListener<ScrollEndNotification>(
            onNotification: (n) {
              if (hasMore && n.metrics.extentAfter < 200) {
                setState(() => _limit += _page);
              }
              return false;
            },
            child: PageBody(
              children: [
                Row(
                  children: [
                    for (final s in _Shown.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: _Chip(
                          label: l.t(s.label),
                          selected: s == _shown,
                          onTap: () => _show(s),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Who has been back over the books, and how many times. At
                // the head of the list rather than worked out by scrolling
                // it, because the count is the answer and the lines under it
                // are the working.
                if (onlyChanges) ...[
                  _Tally(lines: all),
                  const SizedBox(height: 14),
                ],

                if (entries.isEmpty)
                  EmptyNote(
                    l.t(
                      onlyChanges
                          ? 'Nothing has been changed after it was written.'
                          : 'Nothing logged yet.',
                    ),
                  )
                else
                  for (final e in entries) _LogRow(entry: e),

                if (hasMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// How many entries each person has changed or removed, busiest first.
class _Tally extends StatelessWidget {
  const _Tally({required this.lines});

  final List<LogEntry> lines;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tally = correctionTally(lines);
    final total = tally.fold<int>(0, (a, t) => a + t.times);

    if (tally.isEmpty) {
      return RegCard(
        stripe: T.moneyIn,
        child: Text(
          l.t(
            'Nobody has gone back over an entry. Everything on the books is '
            'as it was first written.',
          ),
          style: T.body,
        ),
      );
    }

    return RegCard(
      stripe: T.accent600,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l.t('Who has changed what'), style: T.cardTitle),
              ),
              Tag(l.t2('%s in all', total)),
            ],
          ),
          const SizedBox(height: 10),
          for (final person in tally)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(child: Text(person.who, style: T.body)),
                  Text(
                    l.t2('%s times', person.times),
                    style: T.bodyMid.copyWith(color: T.accent700),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(
            l.t(
              'Counted out of the lines below. Every one of them says which '
              'entry it was and what moved.',
            ),
            style: T.meta,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(T.pill),
      child: Container(
        height: 34,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? T.fill : T.surface,
          borderRadius: BorderRadius.circular(T.pill),
          border: Border.all(color: selected ? T.fill : T.n300, width: 1.3),
        ),
        child: Text(
          label,
          style: T.bodyMid.copyWith(
            fontSize: 12.5,
            color: selected ? T.onFill : T.n700,
          ),
        ),
      ),
    ),
  );
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: T.divider, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 92,
                child: Text(fmtStamp(entry.at), style: T.meta),
              ),
              Expanded(
                child: Text('${entry.who} ${entry.what}', style: T.body),
              ),
              const SizedBox(width: 8),
              Tag(
                l.t(entry.kind.label),
                tone: entry.kind.changedAnEntry
                    ? TagTone.warn
                    : TagTone.neutral,
              ),
            ],
          ),
          // The way back from a deletion, and the way in to the entry
          // itself.
          //
          // The farm deleted six real sales in one minute, hunting a figure
          // that was wrong for a reason none of them was. Nothing in these
          // books is ever truly thrown away, so every one of those lines
          // could be walked back — there was simply nothing to press.
          //
          // Once it is back the button goes and the line says so. A button
          // that stays put after it has worked is a button somebody presses
          // twice, wondering whether the first one took.
          if (entry.touchedAnEntry) ...[
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.only(left: 92),
              child: _LogActions(entry: entry),
            ),
          ],
        ],
      ),
    );
  }
}

/// What can be done from one line of the log.
///
/// Opening the entry it names, which the farm asked for in as many words —
/// a log that says a figure moved and will not show you the figure is a
/// log you have to go and look something up from. And, on a deletion,
/// putting it back.
class _LogActions extends StatelessWidget {
  const _LogActions({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final id = entry.refId ?? '';
    // Deleted rows are not in the ledger this phone carries, so a row that
    // is there is a row that is back.
    final live = context
        .watch<FarmStore>()
        .ledger
        .where((t) => t.id == id)
        .firstOrNull;

    return Row(
      children: [
        if (live != null)
          GhostButton(
            label: l.t('Open the entry'),
            icon: Icons.open_in_new,
            compact: true,
            onPressed: () => openEntry(context, live),
          ),
        if (live != null && entry.undoable) const SizedBox(width: 8),
        if (entry.undoable)
          live == null
              ? _UndoButton(entry: entry)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, size: 14, color: T.done),
                    const SizedBox(width: 5),
                    Text(
                      l.t('Back on the books'),
                      style: T.meta.copyWith(color: T.done),
                    ),
                  ],
                ),
      ],
    );
  }
}

/// Puts one deleted entry back, and everything it had done with it.
class _UndoButton extends StatefulWidget {
  const _UndoButton({required this.entry});

  final LogEntry entry;

  @override
  State<_UndoButton> createState() => _UndoButtonState();
}

class _UndoButtonState extends State<_UndoButton> {
  bool _busy = false;

  Future<void> _undo() async {
    final l = L.read(context);
    // Read before the register is, so nothing asks this widget's context
    // for anything after the first await.
    final actor = context.read<Session>().actor;
    final id = widget.entry.refId;
    if (id == null || id.isEmpty) return;

    setState(() => _busy = true);
    try {
      // Read straight from the register rather than from this phone's
      // ledger, which leaves deleted rows out — the whole point here is a
      // row this phone is not carrying.
      final doc = await Db.transactions.doc(id).get();
      if (!doc.exists) {
        if (mounted) toast(context, l.t('That entry is no longer there.'));
        return;
      }
      final txn = Txn.fromDoc(doc);
      if (!txn.isDeleted) {
        if (mounted) toast(context, l.t('That entry is already back.'));
        return;
      }

      await TxnRepo.restore(actor, txn);
      if (mounted) {
        toast(context, l.t2('%s is back on the books', txn.party));
      }
    } catch (e) {
      if (mounted) toast(context, l.t2('Could not bring it back. %s', e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => GhostButton(
    label: L.of(context).t('Bring it back'),
    icon: Icons.undo,
    compact: true,
    onPressed: _busy ? null : _undo,
  );
}
