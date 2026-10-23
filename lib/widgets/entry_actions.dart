import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/words.dart';
import '../models/models.dart';
import '../screens/shared/accounts_screen.dart';
import '../screens/shared/split_sheet.dart';
import '../services/accounting.dart';
import '../services/txn_repo.dart';
import '../state/farm_store.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../util/money.dart';
import 'ui.dart';

/// What a figure is made of, and how to open the entries behind it.
///
/// The farm's complaint, in its own words: a co-founder's card said the farm
/// owed him three thousand three hundred and fifty rupees, and tapping the
/// figure did nothing. In the ledger every row opens and tells you the whole
/// story of itself. A total that will not do the same is a number somebody has
/// to be *trusted* on, and trust is the one thing this app exists to make
/// unnecessary.
///
/// So every figure the app adds up can be opened, and what opens is the list
/// of entries it was added up from — one of them or forty. Tap one of those
/// and the ordinary entry sheet comes up, the same sheet with the same facts
/// and the same buttons as in the ledger, because there is only one of it.
///
/// That last part is why this file imports the accounts screen and the
/// accounts screen imports this one. The four things a person can do to an
/// entry — settle it, correct it, write it off, delete it — are written here
/// once and the ledger's rows call them, so an entry opened from a total
/// behaves exactly as it does when opened from its own row. Two copies of a
/// confirm box is how two screens end up disagreeing about what a button did.
class Behind {
  const Behind({
    required this.txnId,
    required this.date,
    required this.what,
    required this.detail,
    required this.amount,
    this.incoming,
    this.spokenFor = '',
  });

  /// One of the rows behind what a man is holding or is out of pocket.
  factory Behind.hand(InHand h) => Behind(
    txnId: h.txnId,
    date: h.date,
    what: h.what,
    detail: h.detail,
    amount: h.amount,
    incoming: h.incoming,
    spokenFor: h.handedOnTo,
  );

  /// A whole entry, where the figure counted all of it.
  factory Behind.txn(Txn t) => Behind(
    txnId: t.id,
    date: t.date,
    what: t.party.isEmpty ? t.category : t.party,
    detail: t.category,
    amount: t.amount,
    incoming: t.type.isIncoming,
  );

  final String txnId;
  final DateTime date;

  /// Who it was with, or what it was for.
  final String what;
  final String detail;

  /// Always positive. [incoming] says which way the money went, and null
  /// says the figure does not care which way — a bare total.
  final num amount;
  final bool? incoming;

  /// Named by a handover already, so this part of it is spoken for.
  final String spokenFor;
}

/// Everything behind one figure, in a sheet, latest first.
///
/// One entry opens straight into that entry: an extra list of one row is a
/// tap that tells the reader nothing. Nothing behind it at all opens nothing
/// — the caller is expected not to make the figure tappable, and [BehindTap]
/// does that for it.
Future<void> showBehind(
  BuildContext context, {
  required String title,
  String note = '',
  required List<Behind> rows,

  /// The figure that was tapped, when it is not simply the sum of the rows.
  ///
  /// A man's holding is what he took in less what he handed out, so a sheet
  /// showing both sides adds up to neither. The figure he pressed goes at
  /// the top and the arithmetic goes in [note], because the one thing this
  /// sheet must never do is show a different number from the card that
  /// opened it.
  ///
  /// The list then says what it comes to in its own right, under the
  /// figure. Both numbers are written down and neither is left to be worked
  /// out: a reader who adds the rows up and lands somewhere else is a
  /// reader who has just stopped believing the card.
  num? figure,
}) async {
  if (rows.isEmpty) return;

  final store = context.read<FarmStore>();
  final l = L.read(context);

  Txn? found(String id) =>
      store.ledger.where((t) => t.id == id && !t.isDeleted).firstOrNull;

  if (rows.length == 1) {
    final txn = found(rows.first.txnId);
    if (txn != null) return openEntry(context, txn);
  }

  final sorted = [...rows]..sort((a, b) => b.date.compareTo(a.date));
  final total = sorted.fold<num>(0, (a, r) => a + r.amount);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: T.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(T.radius)),
    ),
    builder: (sheet) => SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheet).size.height * 0.82,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(T.pad, 14, T.pad, T.pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: T.n400,
                    borderRadius: BorderRadius.circular(T.pill),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(title, style: T.screenTitle)),
                  const SizedBox(width: 10),
                  Text(rs(figure ?? total), style: T.num22),
                ],
              ),
              const SizedBox(height: 3),
              if (note.isNotEmpty) Text(note, style: T.meta),
              Text(
                l.t3('%s entries, %s between them', sorted.length, rs(total)),
                style: T.meta,
              ),
              const SizedBox(height: 12),
              for (final r in sorted) ...[
                _BehindRow(
                  row: r,
                  onTap: () {
                    final txn = found(r.txnId);
                    Navigator.pop(sheet);
                    if (txn != null) openEntry(context, txn);
                  },
                ),
                if (r != sorted.last) const Divider(height: 1),
              ],
              const SizedBox(height: 10),
              Text(
                l.t(
                  'Tap any one of them to read the whole entry — the same '
                  'sheet the ledger opens, with everything written on it.',
                ),
                style: T.meta,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BehindRow extends StatelessWidget {
  const _BehindRow({required this.row, required this.onTap});

  final Behind row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tone = row.incoming == null
        ? T.text
        : T.money(incoming: row.incoming!, settled: true);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: T.roundSm,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.what.isEmpty ? l.t(row.detail) : row.what,
                      style: T.bodyMid,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${fmtDate(row.date)} · ${l.t(row.detail)}',
                      style: T.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Already named by a handover, so it is not free money
                    // to be handed over a second time.
                    if (row.spokenFor.isNotEmpty)
                      Text(
                        l.t2('handed to %s', row.spokenFor),
                        style: T.meta.copyWith(color: T.moneyDue),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(rs(row.amount), style: T.bodyMid.copyWith(color: tone)),
              Icon(Icons.chevron_right, size: 16, color: T.n400),
            ],
          ),
        ),
      ),
    );
  }
}

/// A figure that opens what it is made of.
///
/// Wraps whatever is already on the screen rather than replacing it, so a
/// total looks the same as it did and simply answers when it is pressed. A
/// figure with nothing behind it is left alone: a tap that opens an empty
/// sheet is worse than a figure that does not react.
class BehindTap extends StatelessWidget {
  const BehindTap({
    super.key,
    required this.child,
    required this.title,
    this.note = '',
    required this.rows,
    this.figure,
  });

  final Widget child;
  final String title;
  final String note;
  final List<Behind> rows;

  /// The figure on the card, where it is not simply the sum of [rows].
  final num? figure;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return child;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => showBehind(
          context,
          title: title,
          note: note,
          rows: rows,
          figure: figure,
        ),
        borderRadius: T.roundSm,
        child: child,
      ),
    );
  }
}

// ---- one entry, opened from wherever its figure was shown ----

/// The entry sheet, with everything a person can do to the entry.
///
/// Whatever it was opened from reads the same off the store — who paid for
/// it, which handover carried it, whether its period is still open — so an
/// entry reached from a total on the dashboard shows exactly what the same
/// entry shows in the ledger.
Future<void> openEntry(BuildContext context, Txn txn) {
  final store = context.read<FarmStore>();
  final session = context.read<Session>();
  return showEntryDetail(
    context,
    txn: txn,
    isMaster: session.role == Role.master,
    onMarkPaid: () => markEntryPaid(context, txn),
    onDelete: () => deleteEntry(context, txn),
    onEdit: () => editEntry(context, txn),
    onGiveUp: () => giveUpOnEntry(context, txn),
    onSplit: () => showSplitSheet(context, txn),
    paidBy: store.paidForEntry(txn.id),
    handedOn: store.handoverFor(txn.id),
    // A settled period's figures are what four people were paid out of, so
    // nothing in one can be corrected.
    canEdit:
        store.periods.where((p) => p.id == txn.monthId).firstOrNull?.isOpen ??
        true,
  );
}

/// Book the money against an entry that was entered on credit.
///
/// Asks how the money moved before booking it — a month later nobody will
/// remember whether it was cash or a transfer.
Future<void> markEntryPaid(BuildContext context, Txn txn) async {
  final settled = await askSettlement(
    context,
    incoming: txn.type.isIncoming,
    party: txn.party,
    amount: txn.amount,
  );
  if (settled == null || !context.mounted) return;

  try {
    await TxnRepo.markPaid(
      context.read<Session>().actor,
      txn,
      payVia: settled.payVia ?? PayVia.cash,
      handledBy: settled.handledBy,
    );
    if (context.mounted) toast(context, '${txn.party} marked paid');
  } catch (e) {
    if (context.mounted) toast(context, 'Could not mark it paid. $e');
  }
}

/// Open the correction sheet for one entry.
Future<void> editEntry(BuildContext context, Txn txn) {
  final store = context.read<FarmStore>();
  final isMaster = context.read<Session>().role == Role.master;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: T.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(T.radius)),
    ),
    // The sheet is built from the navigator context, which sits above the
    // provider the screen was pushed with, so the store is handed down.
    builder: (_) => ChangeNotifierProvider<FarmStore>.value(
      value: store,
      child: EditEntrySheet(txn: txn, isMaster: isMaster),
    ),
  );
}

/// Give up on what is still owed on one entry.
Future<void> giveUpOnEntry(BuildContext context, Txn txn) async {
  final l = L.read(context);
  final left = txn.outstanding;
  final ok = await confirm(
    context,
    title: l.t('Give up on this money?'),
    body: l.t3(
      '%s · %s\n\n'
      'The entry is marked settled and this becomes a cost of the open '
      'period, so the profit drops by it. No cash moves — it never came. '
      'It cannot be undone except by entering it again as a fresh sale.',
      txn.party,
      rs(left),
    ),
    confirmLabel: l.t('Give up on it'),
  );
  if (!ok || !context.mounted) return;

  try {
    await TxnRepo.giveUpOn(context.read<Session>().actor, txn);
    if (context.mounted) toast(context, l.t2('%s written off', rs(left)));
  } catch (e) {
    if (context.mounted) toast(context, l.t2('Could not write it off. %s', e));
  }
}

/// Take one entry off the books.
Future<void> deleteEntry(BuildContext context, Txn txn) async {
  final ok = await confirm(
    context,
    title: 'Delete this entry?',
    body:
        // What actually happens. The Sheet's tabs are rewritten whole on
        // every sync from the live books, and the live books leave deleted
        // entries out — so the row goes, it is not flagged.
        '${txn.type.label} · ${txn.party} · ${rs(txn.amount)}\n\n'
        'It goes from the app, and from the Google Sheet at the next '
        'sync a few seconds later. Every figure that counted it — the '
        'profit, the cash, this party\'s balance — is worked out again '
        'without it.',
    confirmLabel: 'Delete',
  );
  if (!ok || !context.mounted) return;

  try {
    await TxnRepo.softDelete(context.read<Session>().actor, txn);
    if (context.mounted) toast(context, 'Entry deleted');
  } catch (e) {
    if (context.mounted) toast(context, 'Could not delete it. $e');
  }
}
