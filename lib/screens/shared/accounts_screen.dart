import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/accounting.dart';
import '../../services/allocation.dart';
import '../../services/db.dart';
import '../../services/statement.dart';
import '../../services/txn_repo.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/category_field.dart';
import '../../widgets/party_field.dart';
import '../../widgets/pick_sheet.dart';
import '../../widgets/ui.dart';
import 'new_entry_screen.dart';

/// The five ways of looking at the ledger, each with its own colour.
///
/// The colour is the point. Five identically blue chips meant that once the
/// page had scrolled you could no longer tell which one you had pressed, so
/// the chosen filter now paints the figure at the top of the page as well as
/// its own chip. The colours are the money colours, not new ones: what has
/// come in is green, what has gone out is red, what is still owed either way
/// is pale.
enum AccountsFilter {
  all('All'),

  /// The two cash views: rows where the money actually moved.
  ///
  /// These are the answer to the farm's own complaint about this page. A milk
  /// sale on credit and the receipt that settles it three weeks later are two
  /// rows, and on the "All" list they sit there looking like two sales. They
  /// have to both be there — one is the trade, the other is the day the money
  /// came — but a person counting what has come in should not have to know
  /// which of them to skip. So these two lists carry one row per rupee: an
  /// entry settled on the spot, or the settlement of one that was not.
  received('Received'),
  paidOut('Paid'),

  receivable('To receive'),
  payable('To pay'),
  sales('Sales'),
  expenses('Expenses');

  const AccountsFilter(this.label);

  final String label;

  /// Read fresh every time, because the money colours differ between the
  /// three skins — a red that reads on paper is a bruise on a black page.
  Color get tone => switch (this) {
    AccountsFilter.all => T.accent600,
    AccountsFilter.sales || AccountsFilter.received => T.moneyIn,
    AccountsFilter.expenses || AccountsFilter.paidOut => T.moneyOut,
    AccountsFilter.receivable => T.moneyGet,
    AccountsFilter.payable => T.moneyDue,
  };

  /// The one figure this view is about.
  num totalFrom(Books books) => switch (this) {
    AccountsFilter.all => books.cash,
    AccountsFilter.sales => books.sales,
    AccountsFilter.expenses => books.costs,
    AccountsFilter.received => books.paidSales + books.receipts,
    AccountsFilter.paidOut => books.paidOut,
    AccountsFilter.receivable => books.receivable,
    AccountsFilter.payable => books.payable,
  };

  String get heading => switch (this) {
    AccountsFilter.all => 'Cash in hand',
    AccountsFilter.sales => 'Sales this period',
    AccountsFilter.expenses => 'Running costs',
    AccountsFilter.received => 'Money received',
    AccountsFilter.paidOut => 'Money paid out',
    AccountsFilter.receivable => 'Still to collect',
    AccountsFilter.payable => 'Still to pay',
  };

  /// True on the two lists that carry one row per rupee, where a figure at
  /// the top of the page is a total of money and not of entries.
  bool get isCashView =>
      this == AccountsFilter.received || this == AccountsFilter.paidOut;
}

/// The farm ledger: everything bought and sold, and what is still outstanding.
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key, this.initialFilter = AccountsFilter.all});

  final AccountsFilter initialFilter;

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  late AccountsFilter _filter = widget.initialFilter;

  /// Narrowed to one name, or one kind of entry, or both. Null is everybody
  /// and everything.
  ///
  /// Kept apart from the tab and applied on top of it, because together they
  /// answer the question the farm actually asks: pick Kashif on the "To
  /// receive" tab and you have what Kashif still owes. Picking a name does not
  /// move you off the tab you were reading.
  String? _party;
  String? _category;

  String? _busyId;

  bool _settling = false;

  /// How much is being handed over. Empty means all of it.
  ///
  /// This one figure is the whole of the interaction. The round sells on
  /// credit twice a day, so a customer paying on Friday is paying off a dozen
  /// entries — and ticking twelve boxes to say so is twelve taps to tell the
  /// app something it can work out from one number. Type what is in your hand
  /// and the entries it reaches tick themselves, oldest first, with the one it
  /// stops part way through showing how far it got.
  final _taking = TextEditingController();

  @override
  void dispose() {
    _taking.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AccountsScreen old) {
    super.didUpdateWidget(old);
    // A tile on Home can jump straight to a preset filter.
    if (old.initialFilter != widget.initialFilter) {
      setState(() => _filter = widget.initialFilter);
    }
  }

  /// The whole ledger as one running account, newest first.
  ///
  /// It used to be shown a period at a time, behind a row of month chips.
  /// That was wrong in the way that matters: the moment a period was settled
  /// its entire ledger left the screen — and a period that was sealed but not
  /// yet closed had no chip at all, so it could not be reached from anywhere.
  /// The farm's books are read as one account. Where a period ended is drawn
  /// as a line through the list.
  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final isMaster = context.watch<Session>().role == Role.master;
    final l = L.of(context);
    final books = store.books;

    // One ledger, held by the store and read by everything that wants it.
    // Opening a second listener on the same query here only meant the same
    // rows arriving twice.
    return StreamBuilder<List<FarmMonth>>(
      stream: Db.watchPeriods(),
      builder: (context, periodSnap) {
        final periods = periodSnap.data ?? const <FarmMonth>[];
        final everything = store.ledger;
        final loading = !store.ready;
        final rows = _ordered(_narrow(_rows(everything, store)));
        // Split where the work is. Anything still owing goes above the
        // settle bar; anything finished with goes below it.
        final open = rows.where((t) => t.outstanding > 0).toList();
        final done = rows.where((t) => t.outstanding <= 0).toList();
        // The names and kinds actually in the books, rather than a fixed
        // list: a customer who has never traded is not worth offering.
        // One row per person, under the spelling the farm uses most — not
        // one row per way anybody has ever typed it.
        final parties = [for (final p in store.partyBook) p.name];
        final categories = _distinct(everything, (t) => t.category);

        return PageBody(
          children: [
            // Narrowed to one person, the figure on the left is only half the
            // answer: it says what this tab is about, not where the account
            // stands. So the balance goes beside it, worked out the same way
            // the statement works it out — and the advance under both,
            // subtracted from neither, because it is their money and not a
            // payment against any of this.
            if (_party != null)
              _PartyHead(
                party: _party!,
                heading: l.t(_filter.heading),
                shown: rs(_total(books, rows)),
                count: rows.length,
                balance: buildStatement(
                  rows: everything,
                  party: _party,
                ).closing,
                securityHeld: store.securityHeldFrom(_party!),
                tone: _filter.tone,
              )
            else
              HeroCard(
                label: l.t(_filter.heading),
                value: rs(_total(books, rows)),
                gradient: T.washOf(_filter.tone),
                note: loading
                    ? l.t('Loading…')
                    : l.t2('%s entries', rows.length),
                trailing: Tag(periodLabel(store.month, short: true)),
              ),
            const SizedBox(height: T.pad),

            _FilterBar(
              filter: _filter,
              onPick: (f) => setState(() => _filter = f),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Flexible(
                  child: PickPill(
                    icon: Icons.person_outline,
                    label: _party ?? l.t('Anyone'),
                    chosen: _party != null,
                    onClear: () => setState(() => _party = null),
                    onTap: () => _pick(
                      title: l.t('Whose entries?'),
                      options: parties,
                      allLabel: l.t('Everybody'),
                      current: _party,
                      onPicked: (v) => setState(() => _party = v),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: PickPill(
                    icon: Icons.sell_outlined,
                    label: _category ?? l.t('Anything'),
                    chosen: _category != null,
                    onClear: () => setState(() => _category = null),
                    onTap: () => _pick(
                      title: l.t('Which kind of entry?'),
                      options: categories,
                      allLabel: l.t('Everything'),
                      current: _category,
                      onPicked: (v) => setState(() => _category = v),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // One customer's whole account, the moment a name is picked.
            if (_party != null) ...[
              _PartyCard(
                party: _party!,
                ledger: everything,
                securityHeld: store.securityHeldFrom(_party!),
              ),
              const SizedBox(height: 12),
            ],

            // The same two doors as on Home, in the same two colours.
            Row(
              children: [
                Expanded(
                  child: _EntryButton(
                    flow: MoneyFlow.incoming,
                    label: l.t('Money in'),
                    store: store,
                  ),
                ),
                const SizedBox(width: T.gap),
                Expanded(
                  child: _EntryButton(
                    flow: MoneyFlow.outgoing,
                    label: l.t('Money out'),
                    store: store,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (loading && everything.isEmpty)
              EmptyNote(l.t('Loading…'))
            else if (rows.isEmpty)
              EmptyNote(l.t('Nothing booked here yet. Tap Add to start.'))
            else ...[
              // What is still outstanding, and the button that settles it,
              // before any of the history.
              //
              // The other way round is how it was, and it does not survive
              // contact with a farm: six months in, the thing you came here
              // to do is a thousand rows below the thing you already know.
              // What is settled is a record — it is read occasionally and
              // acted on never — so it goes underneath, however long it gets.
              if (open.isNotEmpty) ...[
                SectionTitle(
                  _owedTab ? l.t(_filter.heading) : l.t('Still open'),
                ),
                const SizedBox(height: 6),
                ..._withDividers(open, periods, l, isMaster, _reach(rows)),
                const SizedBox(height: 4),
                _TotalStrip(
                  count: open.length,
                  total: open.fold<num>(0, (a, t) => a + t.outstanding),
                  tone: _filter.tone,
                ),
                if (_canTick) ...[
                  const SizedBox(height: 12),
                  _SettleBar(
                    owing: _owing(rows),
                    reach: _reach(rows),
                    taking: _taken(rows),
                    incoming: open.first.type.isIncoming,
                    field: _taking,
                    busy: _settling,
                    onSettle: () => _settleMany(rows),
                    onAmountChanged: () => setState(() {}),
                  ),
                ],
                const SizedBox(height: 20),
              ],

              if (done.isNotEmpty) ...[
                SectionTitle(
                  open.isEmpty ? l.t('Everything here') : l.t('Done with'),
                ),
                const SizedBox(height: 6),
                ..._withDividers(done, periods, l, isMaster, const {}),
                const SizedBox(height: 4),
                _TotalStrip(
                  count: done.length,
                  total: done.fold<num>(0, (a, t) => a + t.amount),
                  tone: T.n600,
                ),
              ],
            ],

            const SizedBox(height: 16),
            Text(
              l.t(
                'All farm money in one place: milk & product sales, '
                'cattle, feed, bills, rent, food, salaries. Anything sold '
                'or bought on credit stays unpaid until you mark it paid.',
              ),
              style: T.meta,
            ),
          ],
        );
      },
    );
  }

  /// The tab's rows, narrowed to one name, one kind, or both.
  List<Txn> _narrow(List<Txn> rows) => rows
      .where((t) => _party == null || partyKey(t.party) == partyKey(_party!))
      .where((t) => _category == null || t.category == _category)
      .toList();

  /// Every distinct value in the ledger, alphabetically, blanks left out — an
  /// entry with no name against it offers nothing to pick.
  static List<String> _distinct(List<Txn> rows, String Function(Txn) of) {
    final seen = <String>{};
    for (final t in rows) {
      final v = of(t).trim();
      if (v.isNotEmpty) seen.add(v);
    }
    return seen.toList()..sort();
  }

  Future<void> _pick({
    required String title,
    required List<String> options,
    required String allLabel,
    required String? current,
    required ValueChanged<String?> onPicked,
  }) async {
    final picked = await pickOne(
      context,
      title: title,
      options: options,
      allLabel: allLabel,
      current: current,
    );
    // A null is a cancel. A Picked carrying null is "all of them".
    if (picked != null) onPicked(picked.value);
  }

  /// The rows, with a line drawn wherever the period changes.
  ///
  /// Grouped by the period each entry was booked into rather than by its date,
  /// because those two part company on purpose: an entry made the evening a
  /// period was sealed carries that evening's date and belongs to the period
  /// that opened, and the line has to fall where the books say it does.
  List<Widget> _withDividers(
    List<Txn> rows,
    List<FarmMonth> periods,
    L l,
    bool isMaster,
    Map<String, num> reach,
  ) {
    final out = <Widget>[];
    String? current;

    for (final txn in rows) {
      if (txn.monthId != current) {
        current = txn.monthId;
        final period = periods.where((p) => p.id == current).firstOrNull;
        out.add(_divider(period, current, l));
      }
      out.add(
        _LedgerRow(
          txn: txn,
          isMaster: isMaster,
          busy: _busyId == txn.id,
          onMarkPaid: () => _markPaid(txn),
          onDelete: () => _delete(txn),
          onEdit: () => _edit(txn),
          onGiveUp: () => _giveUp(txn),
          // A settled period's figures are what four people were paid out
          // of, so nothing in one can be corrected.
          canEdit:
              periods.where((p) => p.id == txn.monthId).firstOrNull?.isOpen ??
              true,
          // Marked by the money, not by a finger.
          showMark: _canTick && txn.outstanding > 0,
          reached: reach[txn.id] ?? 0,
        ),
      );
    }
    return out;
  }

  Widget _divider(FarmMonth? period, String id, L l) {
    if (period == null) {
      // A period document the farm never wrote, from before periods were
      // recorded. Name it from the id and say nothing else about it.
      return PeriodDivider(
        label: monthName(id),
        state: l.t('earlier'),
        tone: T.n600,
      );
    }

    // The days it covered, written out. "September 2026" does not say whether
    // that was to the 30th or to the 14th.
    final dates = periodDates(period);

    if (period.isOpen) {
      return PeriodDivider(
        label: periodLabel(period),
        state: l.t('open now'),
        tone: T.moneyIn,
        note: dates.isEmpty ? null : l.t2('Started %s', dates),
      );
    }

    final shared = period.profitShared ?? 0;
    final money = shared > 0
        ? l.t2('%s shared between the co-founders', rs(shared))
        : l.t('Nothing was shared out of this one.');

    return PeriodDivider(
      label: periodLabel(period),
      state: period.isSealed
          ? l.t('sealed — waiting on the co-founders')
          : l.t('closed here'),
      tone: period.isSealed ? T.moneyDue : T.accent700,
      note: dates.isEmpty ? money : '$dates\n$money',
    );
  }

  /// The one figure above the list, matching whatever the filter is showing.
  num _total(Books books, List<Txn> rows) {
    // Narrowed to one name or one kind, the farm's own balances answer
    // nothing — what is on screen does. Only the unnarrowed view shows the
    // balance the rest of the app shows.
    if (_party != null || _category != null) {
      return rows.fold<num>(0, (a, t) => a + t.amount);
    }
    return switch (_filter) {
      // Balances, which belong to the farm rather than to a period.
      AccountsFilter.all => books.cash,
      AccountsFilter.receivable => books.receivable,
      AccountsFilter.payable => books.payable,
      // Totals of what is actually on screen.
      _ => rows.fold<num>(0, (a, t) => a + t.amount),
    };
  }

  List<Txn> _rows(List<Txn> monthTxns, FarmStore store) => switch (_filter) {
    AccountsFilter.all => monthTxns,
    // Loose receipts are in here for the same reason loose payments are in
    // the list below: money came in and nothing else on the books says so.
    AccountsFilter.sales =>
      monthTxns
          .where((t) => t.type == TxnType.sale || t.isLooseReceipt)
          .toList(),
    // Loose payments are in here too: money that went out with no cost
    // booked against it anywhere else is a cost, and hiding it from this
    // list is how the farm lost track of a rent payment.
    AccountsFilter.expenses =>
      monthTxns
          .where(
            (t) =>
                t.type == TxnType.purchase ||
                t.type == TxnType.expense ||
                t.isLoosePayment,
          )
          .toList(),
    // One row per rupee. See [AccountsFilter.received].
    AccountsFilter.received => monthTxns.where(movedCashIn).toList(),
    AccountsFilter.paidOut => monthTxns.where(movedCashOut).toList(),
    AccountsFilter.receivable => store.receivablesDue,
    AccountsFilter.payable => store.payablesDue,
  };

  /// The order the ledger is read in: period by period, newest first, and
  /// inside a period by day.
  ///
  /// By date alone was enough while every entry was written on the day it
  /// happened. It is not now that an entry can be dated back: one written in
  /// October for a day in September sorts in among September's rows while the
  /// books still hold it in October, so the line that marks where a period
  /// ended would be drawn twice and in the wrong place. The period is what
  /// the figures are built on, so the period leads.
  static List<Txn> _ordered(List<Txn> rows) => rows.toList()
    ..sort((a, b) {
      final byPeriod = b.monthId.compareTo(a.monthId);
      if (byPeriod != 0) return byPeriod;
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
    });

  // ---- settling a stack of credit entries together ----

  /// Ticking is only offered once a name is picked.
  ///
  /// One customer's money cannot be spread across another customer's entries,
  /// and a list of everybody at once would invite exactly that. Pick Kashif
  /// and the tick boxes appear on what Kashif still owes.
  bool get _canTick => _party != null;

  /// The two tabs that are about what is still owed rather than what was
  /// booked.
  bool get _owedTab =>
      _filter == AccountsFilter.receivable || _filter == AccountsFilter.payable;

  /// Everything still owing in the current view, oldest first — which is the
  /// order the money will land in, so it is the order to show them in.
  List<Txn> _owing(List<Txn> rows) =>
      rows.where((t) => t.outstanding > 0).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  /// What is being handed over. An empty box means all of it, which is what
  /// usually happens; a figure larger than what is owed is a slip of the
  /// thumb, not an overpayment for the farm to hold.
  num _taken(List<Txn> rows) {
    final owed = _owing(rows).fold<num>(0, (a, t) => a + t.outstanding);
    final typed = num.tryParse(_taking.text.trim());
    return typed == null ? owed : typed.clamp(0, owed);
  }

  /// How far that money gets into each entry, by entry id.
  ///
  /// The app's own allocation, so what is ticked on screen is exactly what
  /// will be written when the button is pressed — not a second guess at it.
  Map<String, num> _reach(List<Txn> rows) => {
    for (final landing in allocate(_owing(rows), _taken(rows)))
      landing.entry.id: landing.take,
  };

  /// Take the money in, against everything it reaches.
  Future<void> _settleMany(List<Txn> rows) async {
    final owing = _owing(rows);
    final taking = _taken(rows);
    if (owing.isEmpty || taking <= 0) return;
    final l = L.read(context);

    // One direction at a time, so "who took the money" is asked of the right
    // people. In practice a name's outstanding is all one way; this only
    // bites where somebody both buys from the farm and sells to it.
    final incoming = owing.where((t) => t.type.isIncoming).toList();
    final outgoing = owing.where((t) => !t.type.isIncoming).toList();
    if (incoming.isNotEmpty && outgoing.isNotEmpty) {
      toast(
        context,
        l.t('Money coming in and money going out have to be settled apart.'),
      );
      return;
    }

    final owed = owing.fold<num>(0, (a, t) => a + t.outstanding);
    final settled = await askSettlement(
      context,
      incoming: owing.first.type.isIncoming,
      party: owing.first.party,
      amount: taking,
    );
    if (settled == null || !mounted) return;

    setState(() => _settling = true);
    try {
      final finished = await TxnRepo.settle(
        context.read<Session>().actor,
        owing,
        amount: taking,
        payVia: settled.payVia ?? PayVia.cash,
        handledBy: settled.handledBy,
      );
      if (!mounted) return;
      final over = owed - taking;
      toast(
        context,
        over > 0
            ? l.t3('%s settled, %s still owed', finished, rs(over))
            : l.t3('%s settled · %s', finished, rs(taking)),
      );
    } catch (e) {
      if (mounted) toast(context, l.t2('Could not take it in. %s', e));
    } finally {
      if (mounted) {
        setState(() {
          _settling = false;
          _taking.clear();
        });
      }
    }
  }

  Future<void> _markPaid(Txn txn) async {
    // Ask how the money moved before booking it — a month later nobody will
    // remember whether it was cash or a transfer.
    final settled = await askSettlement(
      context,
      incoming: txn.type.isIncoming,
      party: txn.party,
      amount: txn.amount,
    );
    if (settled == null || !mounted) return;

    setState(() => _busyId = txn.id);
    try {
      await TxnRepo.markPaid(
        context.read<Session>().actor,
        txn,
        payVia: settled.payVia ?? PayVia.cash,
        handledBy: settled.handledBy,
      );
      if (mounted) toast(context, '${txn.party} marked paid');
    } catch (e) {
      if (mounted) toast(context, 'Could not mark it paid. $e');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// Open the correction sheet for one entry.
  Future<void> _edit(Txn txn) async {
    final store = context.read<FarmStore>();
    final isMaster = context.read<Session>().role == Role.master;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: T.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.radius)),
      ),
      // The sheet is built from the navigator context, which sits above the
      // provider this screen was pushed with, so the store is handed down.
      builder: (_) => ChangeNotifierProvider<FarmStore>.value(
        value: store,
        child: EditEntrySheet(txn: txn, isMaster: isMaster),
      ),
    );
  }

  /// Give up on what is still owed on one entry.
  Future<void> _giveUp(Txn txn) async {
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
    if (!ok || !mounted) return;

    setState(() => _busyId = txn.id);
    try {
      await TxnRepo.giveUpOn(context.read<Session>().actor, txn);
      if (mounted) toast(context, l.t2('%s written off', rs(left)));
    } catch (e) {
      if (mounted) toast(context, l.t2('Could not write it off. %s', e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(Txn txn) async {
    final ok = await confirm(
      context,
      title: 'Delete this entry?',
      body:
          // What actually happens, which is not what this used to say. The
          // Sheet's tabs are rewritten whole on every sync from the live
          // books, and the live books leave deleted entries out — so the
          // row goes, it is not flagged.
          '${txn.type.label} · ${txn.party} · ${rs(txn.amount)}\n\n'
          'It goes from the app, and from the Google Sheet at the next '
          'sync a few seconds later. Every figure that counted it — the '
          'profit, the cash, this party\'s balance — is worked out again '
          'without it.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;

    setState(() => _busyId = txn.id);
    try {
      await TxnRepo.softDelete(context.read<Session>().actor, txn);
      if (mounted) toast(context, 'Entry deleted');
    } catch (e) {
      if (mounted) toast(context, 'Could not delete it. $e');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }
}

/// The row of filters. Each chip wears its own colour when chosen, and the
/// figure above the list wears it too.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter, required this.onPick});

  final AccountsFilter filter;
  final ValueChanged<AccountsFilter> onPick;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in AccountsFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: _FilterChip(
                label: l.t(f.label),
                tone: f.tone,
                selected: f == filter,
                onTap: () => onPick(f),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.tone,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color tone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(T.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 36,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: selected ? tone : T.surface,
          borderRadius: BorderRadius.circular(T.pill),
          border: Border.all(color: selected ? tone : T.n300, width: 1.3),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: tone.withValues(alpha: 0.32),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: T.bodyMid.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? T.inkOn(tone) : T.n700,
          ),
        ),
      ),
    ),
  );
}

/// One figure in, and everything else follows.
///
/// The old version of this asked for the entries first and the amount second,
/// which is the wrong way round: the farm knows what is in its hand before it
/// knows which days that covers. So the amount is the only thing to fill in,
/// and the rows above tick themselves as it is typed — the same allocation
/// that will be written when the button is pressed, shown before it is.
///
/// Leave it empty for all of it, which is what usually happens.
class _SettleBar extends StatelessWidget {
  const _SettleBar({
    required this.owing,
    required this.reach,
    required this.taking,
    required this.incoming,
    required this.field,
    required this.busy,
    required this.onSettle,
    required this.onAmountChanged,
  });

  final List<Txn> owing;

  /// How far the money gets into each entry, by id.
  final Map<String, num> reach;

  /// What is actually being handed over.
  final num taking;

  /// Money coming in, or money going out. The same splitting either way — a
  /// supplier paid half his bill is the mirror of a customer who paid half of
  /// his — but the words have to follow the direction or half of them are a
  /// lie.
  final bool incoming;

  final TextEditingController field;
  final bool busy;
  final VoidCallback onSettle;
  final VoidCallback onAmountChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final owed = owing.fold<num>(0, (a, t) => a + t.outstanding);
    final left = owed - taking;

    // Only where litres mean something. Rent and vet bills have no litres,
    // and a "0 L" under them would be a figure pretending to be information.
    final litres = owing
        .where((t) => t.unit == 'L' && t.qty != null && (reach[t.id] ?? 0) > 0)
        .fold<num>(0, (a, t) => a + t.qty!);

    final covered = reach.values.where((v) => v > 0).length;
    final whole = owing
        .where((t) => (reach[t.id] ?? 0) >= t.outstanding)
        .length;

    return RegCard(
      stripe: incoming ? T.moneyIn : T.moneyOut,
      padding: const EdgeInsets.fromLTRB(14, 13, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Field(
            label: incoming
                ? l.t('How much is being handed over')
                : l.t('How much is being paid'),
            controller: field,
            hint: l.t2('Leave it empty for all of it — %s', rs(owed)),
            keyboardType: TextInputType.number,
            onChanged: (_) => onAmountChanged(),
          ),
          const SizedBox(height: 9),

          // The figure said out loud, which is how it is checked against the
          // notes in somebody's hand.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: T.n100,
              borderRadius: BorderRadius.circular(T.radiusXs),
            ),
            child: Text(
              rsInWords(taking),
              style: T.bodyMid.copyWith(fontSize: 12.5, color: T.n700),
            ),
          ),
          const SizedBox(height: 11),

          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Figure(
                value: whole == covered ? '$whole' : '$whole + ½',
                label: l.t('entries'),
                tone: T.accent700,
              ),
              if (litres > 0)
                _Figure(
                  value: '${qty(litres)} L',
                  label: l.t('milk'),
                  tone: T.accent700,
                ),
              // "owed" on its own was read as a word about ownership rather
              // than about a balance. It is the same figure the card at the
              // top of the page calls a balance, so it says balance too.
              _Figure(
                value: rs(owed),
                label: incoming ? l.t('balance owed') : l.t('balance to pay'),
                tone: incoming ? T.moneyIn : T.moneyOut,
              ),
            ],
          ),

          if (left > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: T.moneyDueWash,
                borderRadius: BorderRadius.circular(T.radiusXs),
                border: Border.all(color: T.moneyDue.withValues(alpha: 0.5)),
              ),
              child: Text(
                l.t2(
                  incoming
                      ? '%s will still be owed. The oldest entries are '
                            'settled first; whatever is left over stops part '
                            'way through one, and that is the one the next '
                            'payment fills.'
                      : '%s will still be owing to them. The oldest bills are '
                            'paid first; whatever is left over stops part way '
                            'through one, and that is the one the next payment '
                            'finishes.',
                  rs(left),
                ),
                style: T.meta.copyWith(color: T.moneyDue),
              ),
            ),
          ],
          const SizedBox(height: 12),
          PrimaryButton(
            label: busy
                ? (incoming ? l.t('Taking it in…') : l.t('Paying…'))
                : (incoming
                      ? l.t2('Take in %s', rs(taking))
                      : l.t2('Pay %s', rs(taking))),
            onPressed: busy || taking <= 0 ? null : onSettle,
          ),
        ],
      ),
    );
  }
}

/// A tick, a half-filled circle, or an empty box.
///
/// Three states and three shapes, because the one in the middle is the one
/// that matters and it has no word short enough to fit on a row. Half filled
/// reads as half done from across a yard.
class _Mark extends StatelessWidget {
  const _Mark({required this.done, required this.part, required this.tone});

  final bool done;
  final bool part;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
    width: 21,
    height: 21,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: done ? tone : T.surface,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: done || part ? tone : T.n300, width: 2),
    ),
    child: done
        ? Icon(Icons.check, size: 13, color: T.inkOn(tone))
        : part
        ? Icon(Icons.contrast, size: 13, color: tone)
        : null,
  );
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label, required this.tone});

  final String value;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(value, style: T.num22.copyWith(color: tone)),
      Text(label, style: T.meta),
    ],
  );
}

/// The figure this tab is about, and where the account actually stands.
///
/// Two numbers, because they answer two questions and neither answers the
/// other. "To receive · Rs 3,26,000" is what this tab is showing; the balance
/// is where the person stands once both sides are counted — and on a supplier
/// it runs the other way and reads as what the farm owes them.
///
/// The advance sits under both and is taken off neither. It is a security
/// against a standing order, not a payment against any of this, and it goes
/// back whole when the contract ends. It appears only when there is one.
class _PartyHead extends StatelessWidget {
  const _PartyHead({
    required this.party,
    required this.heading,
    required this.shown,
    required this.count,
    required this.balance,
    required this.securityHeld,
    required this.tone,
  });

  final String party;
  final String heading;
  final String shown;
  final int count;
  final num balance;
  final num securityHeld;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final owesUs = balance >= 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: T.washOf(tone),
        borderRadius: T.round,
        boxShadow: T.shadowLift,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$party — $heading'.toUpperCase(),
                        style: T.kicker.copyWith(color: T.onHeroQuiet),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          shown,
                          style: T.num30.copyWith(color: T.onHero),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l.t2('%s entries', count),
                        style: T.meta.copyWith(color: T.onHeroQuiet),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      l.t(owesUs ? 'Balance' : 'The farm owes').toUpperCase(),
                      style: T.kicker.copyWith(color: T.onHeroQuiet),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rs(balance.abs()),
                      style: T.num22.copyWith(color: T.onHero),
                    ),
                  ],
                ),
              ],
            ),
            if (securityHeld > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: T.onHero.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(T.radiusXs),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, size: 15, color: T.onHeroQuiet),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.t('Security we are holding'),
                        style: T.meta.copyWith(color: T.onHeroQuiet),
                      ),
                    ),
                    Text(
                      rs(securityHeld),
                      style: T.bodyMid.copyWith(color: T.onHero),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One person's whole account with the farm, on one card.
///
/// The question a dairy gets asked at the door is never "what were the sales
/// this month" — it is "what does Kashif owe me". So picking a name answers
/// exactly that, out of the whole ledger rather than the open period: what the
/// farm sold him since the day he started, what he has handed over, and what
/// is left between them. An advance he left is shown apart from all of it,
/// because it settles nothing — it is his money, being kept.
class _PartyCard extends StatelessWidget {
  const _PartyCard({
    required this.party,
    required this.ledger,
    required this.securityHeld,
  });

  final String party;
  final List<Txn> ledger;

  /// What this person has left with the farm and not had back.
  final num securityHeld;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    // Every spelling of the name, because Ali and ali are one man and his
    // account has to add up to what he actually owes.
    final mine = ledger
        .where((t) => partyKey(t.party) == partyKey(party))
        .toList();

    num sum(bool Function(Txn) test) =>
        mine.where(test).fold<num>(0, (a, t) => a + t.amount);

    final sold = sum((t) => t.type == TxnType.sale);
    // What was bought off them, not what was handed over. The payment that
    // settles a bill is the same money as the bill, and counting both would
    // say the farm bought twice as much off them as it did.
    final bought = sum(
      (t) => t.type == TxnType.purchase || t.type == TxnType.expense,
    );
    // What is still owed, not what was booked — the one figure on this screen
    // somebody is going to be asked for by name, so it comes from the same
    // place the statement's balance does rather than being worked out again
    // here and drifting.
    final (owesUs: owesUs, weOwe: weOwe) = partyOwing(ledger, party);

    return RegCard(
      stripe: owesUs > 0 ? T.moneyGet : T.accent600,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  party,
                  style: T.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Tag(l.t2('%s entries', mine.length)),
            ],
          ),
          const SizedBox(height: 10),
          if (sold > 0)
            _PartyLine(
              label: l.t('Sold to them, all time'),
              value: sold,
              tone: T.moneyIn,
            ),
          if (bought > 0)
            _PartyLine(
              label: l.t('Bought from them, all time'),
              value: bought,
              tone: T.moneyOut,
            ),
          if (owesUs > 0)
            _PartyLine(
              label: l.t('They still owe'),
              value: owesUs,
              tone: T.moneyGet,
              strong: true,
            ),
          if (weOwe > 0)
            _PartyLine(
              label: l.t('The farm still owes them'),
              value: weOwe,
              tone: T.moneyDue,
              strong: true,
            ),
          if (owesUs == 0 && weOwe == 0)
            Text(l.t('Nothing outstanding either way.'), style: T.meta),
          if (securityHeld > 0) ...[
            const Divider(height: 18),
            _PartyLine(
              label: l.t('Security the farm is holding'),
              value: securityHeld,
              tone: T.moneyDue,
              strong: true,
            ),
            Text(
              l.t(
                'It belongs to them, not the farm. It goes back when they '
                'stop.',
              ),
              style: T.meta,
            ),
          ],
        ],
      ),
    );
  }
}

class _PartyLine extends StatelessWidget {
  const _PartyLine({
    required this.label,
    required this.value,
    required this.tone,
    this.strong = false,
  });

  final String label;
  final num value;
  final Color tone;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, style: strong ? T.bodyMid : T.body)),
        Text(
          rs(value),
          style: (strong ? T.num22 : T.bodyMid).copyWith(color: tone),
        ),
      ],
    ),
  );
}

/// How many entries are on screen and what they come to.
///
/// At the foot of the list rather than only at the head of it, because that is
/// where you are when you have finished reading it — and because a total you
/// have to scroll back up for is a total you will add up yourself instead.
class _TotalStrip extends StatelessWidget {
  const _TotalStrip({
    required this.count,
    required this.total,
    required this.tone,
  });

  final int count;
  final num total;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(T.radiusSm),
        border: Border.all(color: tone.withValues(alpha: 0.28), width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l.t2('%s entries', count),
              style: T.bodyMid.copyWith(color: tone),
            ),
          ),
          Text(rs(total), style: T.num22.copyWith(color: tone)),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.txn,
    required this.isMaster,
    required this.busy,
    required this.onMarkPaid,
    required this.onDelete,
    required this.onEdit,
    required this.onGiveUp,
    required this.canEdit,
    this.showMark = false,
    this.reached = 0,
  });

  final Txn txn;
  final bool isMaster;
  final bool busy;
  final VoidCallback onMarkPaid;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  /// Giving up on what is still owed — the master's, and only while
  /// something is still owed.
  final VoidCallback onGiveUp;

  /// False once this entry's period has been settled.
  final bool canEdit;

  /// Whether this row shows a mark at all — only while a name is picked and
  /// there is something left to settle on it.
  final bool showMark;

  /// How much of the money being handed over lands on this entry. Nothing,
  /// part of what it is worth, or the whole of it — three states, three marks.
  final num reached;

  bool get _done => reached >= txn.outstanding && reached > 0;
  bool get _part => reached > 0 && !_done;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final qtyLine = txn.qtyLine;
    // The day the money came, on an entry that was booked on credit. Null
    // when it was paid as it was written — there is nothing extra to say
    // then, the one date on the left is both.
    final settledLater = txn.paid && !txn.paidOnCreate ? txn.paidAt : null;
    // Every entry wears the colour of what it is and whether the money has
    // actually moved, down its own edge — so a page of them can be read down
    // the left margin without reading a word of it.
    // Part settled gets its own colour, because it is a third state and
    // reading it as either of the other two would be wrong: some of that
    // money has come and some of it has not.
    final tone = txn.partlyPaid
        ? T.moneyDue
        : T.money(incoming: txn.type.isIncoming, settled: txn.paid);

    // Money paid against an entry written earlier — the second of the two
    // rows the farm was reading as two sales. It is set in from the margin
    // and wears the farm's own blue rather than a money colour, so a page of
    // the ledger can be read down the left edge: the rows flush with the
    // margin are the trades, the ones stepped in are the money arriving
    // afterwards. The figure on it keeps its money colour, because that part
    // is real.
    final settling = txn.settlesAnotherEntry;

    final card = RegCard(
      stripe: settling ? T.accent600 : tone,
      wash: settling ? T.accent100 : null,
      padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Three states, three marks. A tick for an entry the money covers
          // in full; a half-filled circle for the one it stops part way
          // through, which is the single shape that says "some of this"
          // without a word; and an empty box for the rest, because nothing is
          // happening to them.
          if (showMark)
            Padding(
              padding: const EdgeInsets.only(right: 10, top: 1),
              child: _Mark(
                done: _done,
                part: _part,
                tone: _done ? T.moneyIn : T.moneyDue,
              ),
            ),
          SizedBox(width: 46, child: Text(fmtDate(txn.date), style: T.meta)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (settling)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: [
                        Icon(
                          Icons.subdirectory_arrow_right,
                          size: 14,
                          color: T.accent600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            l.t('Money against an entry written earlier'),
                            style: T.meta.copyWith(color: T.accent600),
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  txn.party.isEmpty ? txn.category : txn.party,
                  style: T.bodyMid,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  [
                    txn.type.label,
                    txn.category,
                    ?qtyLine,
                    ?txn.shift?.label,
                    if (txn.handOverLine.isNotEmpty) txn.handOverLine,
                  ].join(' · '),
                  style: T.meta,
                  maxLines: 2,
                ),
                // An entry for a day gone by, written later. Said on the row
                // itself rather than only inside it, because the farm reads
                // this list down a day at a time and an entry that was not
                // there yesterday has to explain itself.
                if (txn.wasDatedBack)
                  Text(
                    l.t2('For this day · written %s', fmtDate(txn.createdAt)),
                    style: T.meta.copyWith(
                      color: T.moneyDue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                // When the money actually moved, on an entry that was
                // booked on credit and settled later. One entry, two dates:
                // the row is not written twice, it is the same row with the
                // day it was paid added to it.
                if (settledLater != null)
                  Text(
                    txn.type.isIncoming
                        ? l.t2('Received %s', fmtDate(settledLater))
                        : l.t2('Paid %s', fmtDate(settledLater)),
                    style: T.meta.copyWith(
                      color: T.money(
                        incoming: txn.type.isIncoming,
                        settled: true,
                      ),
                    ),
                  ),
                // Who typed it in, which is not always who handled the
                // money.
                if (txn.createdByName.isNotEmpty)
                  Text(
                    l.t2('Entered by %s', txn.createdByName),
                    style: T.meta.copyWith(color: T.n500),
                  ),
                if (txn.note.isNotEmpty)
                  Text(
                    txn.note,
                    style: T.meta.copyWith(color: T.n500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (txn.isCapitalAsset) ...[
                  const SizedBox(height: 6),
                  Tag(l.t('farm asset · not a cost'), tone: TagTone.accent),
                ],
                // Part of it has come and the rest has not. Both figures on
                // the row, so nobody has to work out the difference.
                if (txn.partlyPaid)
                  Text(
                    l.t3(
                      '%s in, %s still to come',
                      rs(txn.paidSoFar),
                      rs(txn.outstanding),
                    ),
                    style: T.meta.copyWith(
                      color: T.moneyDue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (!txn.paid) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Tag(
                        l.t(
                          txn.partlyPaid
                              ? 'part paid'
                              : txn.type.isIncoming
                              ? 'not received'
                              : 'not paid',
                        ),
                        tone: txn.partlyPaid || !txn.type.isIncoming
                            ? TagTone.warn
                            : TagTone.neutral,
                      ),
                      // While the money is doing the marking, this would be
                      // a second way of doing the same thing, half a second
                      // before the other one.
                      if (!showMark) ...[
                        const SizedBox(width: 8),
                        GhostButton(
                          label: l.t('Mark paid'),
                          compact: true,
                          onPressed: busy ? null : onMarkPaid,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Deep when the money has moved, pale when it is still owed.
              Text(
                signedRs(txn.amount, incoming: txn.type.isIncoming),
                style: T.bodyMid.copyWith(
                  color: T.money(
                    incoming: txn.type.isIncoming,
                    settled: txn.paid,
                  ),
                  fontWeight: T.moneyWeight(txn.paid),
                ),
              ),
              if (isMaster && !showMark)
                SizedBox(
                  height: 30,
                  child: IconButton(
                    onPressed: busy ? null : onDelete,
                    icon: Icon(Icons.close, size: 15, color: T.n400),
                    padding: EdgeInsets.zero,
                    tooltip: l.t('Delete entry'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    return Padding(
      // Stepped in from the margin when it is money against an earlier
      // entry, so the two are not read as two trades.
      padding: EdgeInsets.only(left: settling ? 22 : 0, bottom: 9),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => showEntryDetail(
            context,
            txn: txn,
            isMaster: isMaster,
            onMarkPaid: onMarkPaid,
            onDelete: onDelete,
            onEdit: onEdit,
            onGiveUp: onGiveUp,
            canEdit: canEdit,
          ),
          borderRadius: T.round,
          child: card,
        ),
      ),
    );
  }
}

/// One of the two doors into the entry form, in its direction's colour.
///
/// Money coming in is green and money going out is red, the same as every
/// figure in the app — so the button a person is about to press already
/// tells them which way the books are going to move.
class _EntryButton extends StatelessWidget {
  const _EntryButton({
    required this.flow,
    required this.label,
    required this.store,
  });

  final MoneyFlow flow;
  final String label;
  final FarmStore store;

  @override
  Widget build(BuildContext context) {
    final coming = flow == MoneyFlow.incoming;
    final tone = coming ? T.moneyIn : T.moneyOut;
    return Pressable(
      height: T.tap + 4,
      face: tone,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: store,
            child: NewEntryScreen(flow: flow),
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            coming ? Icons.south_west_rounded : Icons.north_east_rounded,
            size: 17,
            color: T.inkOn(tone),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: T.bodyMid.copyWith(
              color: T.inkOn(tone),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Everything about one entry, opened by tapping it.
///
/// The list can only carry a line and a half — a name, what it was for, the
/// figure — and the farm went looking for the rest of it and found that
/// tapping did nothing at all. The rest is: what the books did with it,
/// how much of the money has actually come, who handled it, who wrote it
/// down and when, and whatever was typed in the note. All of it was already
/// stored; none of it was ever shown.
Future<void> showEntryDetail(
  BuildContext context, {
  required Txn txn,
  required bool isMaster,
  required VoidCallback onMarkPaid,
  required VoidCallback onDelete,
  required VoidCallback onEdit,

  /// Giving up on what is still owed on it. The master's.
  required VoidCallback onGiveUp,

  /// False once the entry's period has been settled. The figures of a
  /// closed month were what four people were paid out of, so nothing in
  /// it is correctable — the correction goes in the open period instead.
  required bool canEdit,
}) {
  final l = L.read(context);
  final kind = entryKindOf(
    type: txn.type,
    category: txn.category,
    isAsset: txn.isCapitalAsset,
  );
  final (markIcon, markTone) = switch (kind) {
    EntryKind.earnings => (Icons.trending_up, T.moneyIn),
    EntryKind.cost => (Icons.trending_down, T.moneyOut),
    EntryKind.owned => (Icons.inventory_2_outlined, T.accent700),
    EntryKind.neither => (Icons.swap_horiz, T.moneyDue),
  };

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: T.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(T.radius)),
    ),
    builder: (sheet) => SafeArea(
      top: false,
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

            // The figure, and what the books did with it. Together, because
            // one without the other is the thing that was missing.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        txn.party.isEmpty ? l.t(txn.category) : txn.party,
                        style: T.screenTitle,
                      ),
                      Text(l.t(txn.category), style: T.meta),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  signedRs(txn.amount, incoming: txn.type.isIncoming),
                  style: T.num26.copyWith(
                    color: T.money(
                      incoming: txn.type.isIncoming,
                      settled: txn.paid,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
              decoration: BoxDecoration(
                color: markTone.withValues(alpha: T.isDark ? 0.16 : 0.09),
                borderRadius: T.roundSm,
                border: Border.all(color: markTone.withValues(alpha: 0.32)),
              ),
              child: Row(
                children: [
                  Icon(markIcon, size: 17, color: markTone),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.t(kind.label),
                          style: T.bodyMid.copyWith(color: markTone),
                        ),
                        Text(
                          l.t(
                            entryEffect(
                              type: txn.type,
                              category: txn.category,
                              isAsset: txn.isCapitalAsset,
                            ),
                          ),
                          style: T.meta,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: T.gap),

            _DetailFact(label: l.t('Date'), value: fmtDateFull(txn.date)),
            // The two dates, where they differ, and which of them the books
            // use. Both are kept on every entry; only here are both shown.
            if (txn.wasDatedBack)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  l.t2(
                    'Written in later, on %s. Every figure reads the day '
                    'above — this is only the day somebody typed it.',
                    fmtDateFull(txn.createdAt),
                  ),
                  style: T.meta.copyWith(color: T.moneyDue),
                ),
              ),
            _DetailFact(label: l.t('Period'), value: monthName(txn.monthId)),
            if (txn.qtyLine != null)
              _DetailFact(label: l.t('Quantity'), value: txn.qtyLine!),
            if (txn.shift != null)
              _DetailFact(
                label: l.t('Which milking?'),
                value: l.t(txn.shift!.label),
              ),

            const Divider(height: 20),

            // What has actually come, which is not the same as what was
            // booked — the whole reason a ledger exists.
            _DetailFact(
              label: l.t('Settled'),
              value: txn.paid
                  ? l.t('Yes, in full')
                  : txn.partlyPaid
                  ? l.t2('%s so far', rs(txn.paidSoFar))
                  : l.t('Not yet'),
              tone: txn.paid
                  ? T.moneyIn
                  : txn.partlyPaid
                  ? T.moneyDue
                  : T.moneyGet,
            ),
            if (!txn.paid && txn.outstanding > 0)
              _DetailFact(
                label: txn.type.isIncoming
                    ? l.t('Still to receive')
                    : l.t('Still to pay'),
                value: rs(txn.outstanding),
                tone: txn.type.isIncoming ? T.moneyGet : T.moneyDue,
              ),
            if (txn.paid) ...[
              _DetailFact(label: l.t('How'), value: txn.payVia.label),
              if (txn.handledBy.trim().isNotEmpty)
                _DetailFact(
                  label: txn.type.isIncoming
                      ? l.t('Received by')
                      : l.t('Paid by'),
                  value: txn.handledBy,
                ),
              if (txn.paidAt != null && !txn.paidOnCreate)
                _DetailFact(
                  label: l.t('Money moved on'),
                  value: fmtDateFull(txn.paidAt!),
                ),
            ],

            const Divider(height: 20),

            _DetailFact(
              label: l.t('Entered by'),
              value: txn.createdByName.isEmpty
                  ? l.t('Someone')
                  : txn.createdByName,
            ),
            _DetailFact(
              label: l.t('Written on'),
              value: fmtStamp(txn.createdAt),
            ),
            if (txn.note.trim().isNotEmpty)
              _DetailFact(label: l.t('Note'), value: txn.note),

            // Every correction ever made to it, oldest first, in the words
            // it was shown as at the time. The farm asked for this before
            // the edit button was built: a figure that can be changed
            // without a trace is worth less than one that cannot be
            // changed at all.
            if (txn.edits.isNotEmpty) ...[
              const Divider(height: 20),
              Kicker(l.t('Corrections')),
              const SizedBox(height: 8),
              for (final e in txn.edits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${fmtStamp(e.at)} · ${e.byName}',
                        style: T.meta.copyWith(color: T.accent700),
                      ),
                      for (final c in e.changes)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text.rich(
                            TextSpan(
                              style: T.body.copyWith(fontSize: 13),
                              children: [
                                TextSpan(text: '${l.t(c.field)}: '),
                                TextSpan(
                                  text: c.from,
                                  style: TextStyle(
                                    color: T.n600,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const TextSpan(text: '  →  '),
                                TextSpan(
                                  text: c.to,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],

            const SizedBox(height: T.pad),

            // Correcting it, and the reason when it cannot be.
            if (!canEdit)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  l.t2(
                    'This entry belongs to %s, which is already settled. '
                    'Nothing in a settled period can be corrected — the '
                    'profit was worked out from it and shared. Put the '
                    'correction in the open period as a new entry.',
                    monthName(txn.monthId),
                  ),
                  style: T.meta.copyWith(color: T.moneyDue),
                ),
              ),
            Row(
              children: [
                if (canEdit)
                  Expanded(
                    child: GhostButton(
                      label: l.t('Edit'),
                      icon: Icons.edit_outlined,
                      onPressed: () {
                        Navigator.pop(sheet);
                        onEdit();
                      },
                    ),
                  ),
                if (canEdit && !txn.paid && !txn.type.isSettlement)
                  const SizedBox(width: 8),
                if (!txn.paid && !txn.type.isSettlement)
                  Expanded(
                    child: GhostButton(
                      label: l.t('Mark paid'),
                      icon: Icons.check,
                      onPressed: () {
                        Navigator.pop(sheet);
                        onMarkPaid();
                      },
                    ),
                  ),
                if (!txn.paid && !txn.type.isSettlement && isMaster)
                  const SizedBox(width: 8),
                if (isMaster)
                  Expanded(
                    child: GhostButton(
                      label: l.t('Delete'),
                      icon: Icons.delete_outline,
                      danger: true,
                      onPressed: () {
                        Navigator.pop(sheet);
                        onDelete();
                      },
                    ),
                  ),
              ],
            ),

            // Money that is owed and is not coming. Left on the books it
            // says it is owed for ever, and the next co-founder to read the
            // account goes and asks for it.
            if (isMaster && txn.outstanding > 0 && !txn.type.isSettlement) ...[
              const SizedBox(height: 8),
              GhostButton(
                label: l.t2('Give up on %s', rs(txn.outstanding)),
                icon: Icons.money_off_csred_outlined,
                danger: true,
                onPressed: () {
                  Navigator.pop(sheet);
                  onGiveUp();
                },
              ),
              const SizedBox(height: 5),
              Text(
                l.t(
                  'For money nobody is going to pay. The entry is settled '
                  'and what is left of it becomes a cost — the profit drops '
                  'by it, and no cash moves.',
                ),
                style: T.meta,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// One label and its figure, down the sheet.
class _DetailFact extends StatelessWidget {
  const _DetailFact({required this.label, required this.value, this.tone});

  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 118, child: Text(label, style: T.meta)),
        Expanded(
          child: Text(value, style: T.bodyMid.copyWith(color: tone ?? T.text)),
        ),
      ],
    ),
  );
}

/// Correcting an entry that was written wrong.
///
/// Opened from the entry's own page. Anybody who keeps the books may fix
/// what was typed — a name, a heading, a quantity, a rate, the figure, the
/// note — and may move the date anywhere inside the period that is open,
/// back or forward, as far as today. Taking it out of that period is the
/// master's alone, because an earlier period has already been read, agreed
/// and printed on somebody's statement.
///
/// The whole thing is shut once the entry's period has been settled. Those
/// months were closed on figures the four of them were paid out of, and a
/// correction afterwards would leave the ledger saying one thing and the
/// period another with nothing to notice it. That correction goes in as a
/// fresh entry in the period that is open.
class EditEntrySheet extends StatefulWidget {
  const EditEntrySheet({super.key, required this.txn, required this.isMaster});

  final Txn txn;
  final bool isMaster;

  @override
  State<EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends State<EditEntrySheet> {
  late final _party = TextEditingController(text: widget.txn.party);
  late final _qty = TextEditingController(
    text: widget.txn.qty == null ? '' : qty(widget.txn.qty!),
  );
  late final _rate = TextEditingController(
    text: widget.txn.rate == null ? '' : qty(widget.txn.rate!),
  );
  late final _total = TextEditingController(
    text: '${widget.txn.amount.round()}',
  );
  late final _note = TextEditingController(text: widget.txn.note);
  late final _handledBy = TextEditingController(text: widget.txn.handledBy);

  late String _category = widget.txn.category;
  bool? _capital;
  late MilkShift? _shift = widget.txn.shift;
  late DateTime _date = widget.txn.date;
  bool _busy = false;

  /// Which way the money went, so the heading list offers the right side.
  /// It is not changeable here: a sale that should have been a purchase is
  /// not a typing slip, it is the wrong entry, and the honest fix is to
  /// delete it and write the right one.
  MoneyFlow get _flow =>
      widget.txn.type.isIncoming ? MoneyFlow.incoming : MoneyFlow.outgoing;

  bool get _measured => !widget.txn.type.isSettlement;

  @override
  void dispose() {
    _party.dispose();
    _qty.dispose();
    _rate.dispose();
    _total.dispose();
    _note.dispose();
    _handledBy.dispose();
    super.dispose();
  }

  /// The period this entry sits in, which is the one still open — nothing in
  /// a settled period reaches this sheet at all.
  FarmMonth _period(FarmStore store) {
    for (final p in store.periods) {
      if (p.id == widget.txn.monthId) return p;
    }
    return store.month;
  }

  /// The earliest day this person may move the entry to.
  ///
  /// A founder may move it anywhere inside the period that is open — back a
  /// few days or forward, as far as today. That covers what actually goes
  /// wrong: a day typed as the 8th that was the 6th, or the other way about.
  /// What it does not cover is the day before the period began, because that
  /// day belongs to figures four people have already agreed. The master can
  /// reach further back, because somebody has to be able to.
  DateTime _floor(FarmStore store) {
    final floor = widget.isMaster
        ? DateTime(widget.txn.date.year - 2, widget.txn.date.month)
        : periodFirstDay(_period(store));
    // An entry already dated before that floor — one the master moved back,
    // or one from before any of this — keeps its own date reachable, so
    // opening the picker on it cannot throw.
    return floor.isAfter(widget.txn.date)
        ? DateTime(
            widget.txn.date.year,
            widget.txn.date.month,
            widget.txn.date.day,
          )
        : floor;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    // An entry already dated later than today — there should be none, but a
    // ledger outlives the rules it was written under — cannot be made worse
    // by this picker, and it must not crash on it either.
    final last = _date.isAfter(now) ? _date : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _floor(context.read<FarmStore>()),
      lastDate: last,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final l = L.read(context);
    final store = context.read<FarmStore>();
    final amount = num.tryParse(_total.text.trim()) ?? 0;
    if (_party.text.trim().isEmpty) {
      toast(context, l.t('Who is this entry for? Add a party name.'));
      return;
    }
    if (amount <= 0) {
      toast(context, l.t('Add the total amount.'));
      return;
    }

    setState(() => _busy = true);
    try {
      await TxnRepo.edit(
        actor: context.read<Session>().actor,
        txn: widget.txn,
        isMaster: widget.isMaster,
        periodIsOpen: store.periodIsOpen(widget.txn.monthId),
        party: _party.text,
        category: _category,
        capital: _capital,
        shift: _shift,
        qty: num.tryParse(_qty.text.trim()),
        rate: num.tryParse(_rate.text.trim()),
        amount: amount,
        note: _note.text,
        handledBy: _handledBy.text,
        // Sent whoever is editing. How far it may move is the repo's rule
        // and the server's, not this sheet's — see [TxnRepo.edit].
        date: _date,
        earliest: periodFirstDay(_period(store)),
      );
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, l.t('Entry corrected'));
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final t = widget.txn;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
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
              Text(l.t('Correct this entry'), style: T.screenTitle),
              const SizedBox(height: 4),
              Text(
                l.t(
                  'What was written down, not what happened. Everything you '
                  'change is kept on the entry with your name against it.',
                ),
                style: T.meta,
              ),
              const SizedBox(height: T.pad),

              PartyField(
                label: l.t(
                  t.type.isIncoming ? 'Who it came from' : 'Who it went to',
                ),
                controller: _party,
                hint: l.t(
                  t.type.isIncoming
                      ? 'Who paid, or who bought it'
                      : 'Who you paid',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: T.gap),

              CategoryField(
                label: l.t('What for'),
                flow: _flow,
                value: _category,
                onChanged: (c, capital) => setState(() {
                  _category = c;
                  _capital = capital;
                }),
              ),
              const SizedBox(height: 7),
              Text(
                l.t(
                  entryEffect(
                    type: _flow.typeOf(_category),
                    category: _category,
                    isAsset: _capital ?? assetCategories.contains(_category),
                  ),
                ),
                style: T.meta,
              ),

              if (_shift != null || _needsShift) ...[
                const SizedBox(height: T.pad),
                Kicker(l.t('Which milking?')),
                const SizedBox(height: 6),
                Segmented<MilkShift?>(
                  value: _shift,
                  options: [
                    for (final s in MilkShift.values) (s, l.t(s.label)),
                  ],
                  onChanged: (v) => setState(() => _shift = v),
                ),
              ],

              if (_measured) ...[
                const SizedBox(height: T.gap),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Field(
                        label: l.t('Qty'),
                        controller: _qty,
                        keyboardType: TextInputType.number,
                        hint: '0',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Field(
                        label: l.t('Rate / unit'),
                        controller: _rate,
                        keyboardType: TextInputType.number,
                        hint: '0',
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: T.gap),
              Field(
                label: l.t('Total amount (Rs)'),
                controller: _total,
                keyboardType: TextInputType.number,
                hint: '0',
              ),

              const SizedBox(height: T.gap),
              Field(
                label: t.type.isIncoming ? l.t('Received by') : l.t('Paid by'),
                controller: _handledBy,
              ),

              const SizedBox(height: T.gap),
              Field(label: l.t('Note'), controller: _note, maxLines: 2),

              // The date. It is the one field that moves the entry rather
              // than correcting it, so what each person may do with it is
              // said on the page before they try.
              const SizedBox(height: T.pad),
              Kicker(l.t('Date')),
              const SizedBox(height: 6),
              GhostButton(
                label: fmtDateFull(_date),
                icon: Icons.event_outlined,
                onPressed: _busy ? null : _pickDate,
              ),
              const SizedBox(height: 5),
              Text(
                widget.isMaster
                    ? l.t(
                        'Any day up to today, back or forward. Where it ends '
                        'up is kept on the entry with the day it came from.',
                      )
                    : l.t2(
                        'Anywhere inside this period — %s to today, back or '
                        'forward. Both days are kept on the entry.',
                        fmtDateFull(_floor(context.watch<FarmStore>())),
                      ),
                style: T.meta,
              ),

              const SizedBox(height: T.pad),
              PrimaryButton(
                label: l.t('Save the correction'),
                icon: Icons.check,
                busy: _busy,
                onPressed: _busy ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Milk wants its milking said, the same as a new entry does.
  bool get _needsShift =>
      _category == milkCategory || _category == milkBoughtInCategory;
}
