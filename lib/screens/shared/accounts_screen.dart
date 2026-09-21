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
  all('All', T.accent600),
  sales('Sales', T.moneyIn),
  expenses('Expenses', T.moneyOut),
  receivable('To receive', T.moneyGet),
  payable('To pay', T.moneyDue);

  const AccountsFilter(this.label, this.tone);

  final String label;
  final Color tone;

  /// The one figure this view is about.
  num totalFrom(Books books) => switch (this) {
    AccountsFilter.all => books.cash,
    AccountsFilter.sales => books.sales,
    AccountsFilter.expenses => books.costs,
    AccountsFilter.receivable => books.receivable,
    AccountsFilter.payable => books.payable,
  };

  String get heading => switch (this) {
    AccountsFilter.all => 'Cash in hand',
    AccountsFilter.sales => 'Sales this period',
    AccountsFilter.expenses => 'Running costs',
    AccountsFilter.receivable => 'Still to collect',
    AccountsFilter.payable => 'Still to pay',
  };
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
        final rows = _narrow(_rows(everything, store));
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
                advanceHeld: store.advanceHeldFor(_party!),
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
                advanceHeld: store.advanceHeldFor(_party!),
              ),
              const SizedBox(height: 12),
            ],

            GhostButton(
              label: l.t('Add an entry'),
              icon: Icons.add,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: store,
                    child: const NewEntryScreen(),
                  ),
                ),
              ),
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
    AccountsFilter.receivable => store.receivablesDue,
    AccountsFilter.payable => store.payablesDue,
  };

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

  Future<void> _delete(Txn txn) async {
    final ok = await confirm(
      context,
      title: 'Delete this entry?',
      body:
          '${txn.type.label} · ${txn.party} · ${rs(txn.amount)}\n\n'
          'It disappears from the app and is marked deleted in the Sheet.',
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
          color: selected ? tone : Colors.white,
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
            color: selected ? Colors.white : T.n700,
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
              _Figure(
                value: rs(owed),
                label: incoming ? l.t('owed') : l.t('to pay'),
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
      color: done ? tone : Colors.white,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: done || part ? tone : T.n300, width: 2),
    ),
    child: done
        ? const Icon(Icons.check, size: 13, color: Colors.white)
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
    required this.advanceHeld,
    required this.tone,
  });

  final String party;
  final String heading;
  final String shown;
  final int count;
  final num balance;
  final num advanceHeld;
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
                        style: T.kicker.copyWith(color: T.accent200),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          shown,
                          style: T.num30.copyWith(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l.t2('%s entries', count),
                        style: T.meta.copyWith(color: T.accent200),
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
                      style: T.kicker.copyWith(color: T.accent200),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rs(balance.abs()),
                      style: T.num22.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
            if (advanceHeld > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(T.radiusXs),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 15,
                      color: T.accent200,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.t('Advance'),
                        style: T.meta.copyWith(color: T.accent200),
                      ),
                    ),
                    Text(
                      rs(advanceHeld),
                      style: T.bodyMid.copyWith(color: Colors.white),
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
    required this.advanceHeld,
  });

  final String party;
  final List<Txn> ledger;

  /// What this person has left with the farm and not had back.
  final num advanceHeld;

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
    final owesUs = sum((t) => t.isReceivable);
    final weOwe = sum((t) => t.isPayable);

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
          if (advanceHeld > 0) ...[
            const Divider(height: 18),
            _PartyLine(
              label: l.t('Advance the farm is holding'),
              value: advanceHeld,
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
    this.showMark = false,
    this.reached = 0,
  });

  final Txn txn;
  final bool isMaster;
  final bool busy;
  final VoidCallback onMarkPaid;
  final VoidCallback onDelete;

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

    final card = RegCard(
      stripe: tone,
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
                    if (txn.handOverLine.isNotEmpty) txn.handOverLine,
                  ].join(' · '),
                  style: T.meta,
                  maxLines: 2,
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
                    icon: const Icon(Icons.close, size: 15, color: T.n400),
                    padding: EdgeInsets.zero,
                    tooltip: l.t('Delete entry'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    return Padding(padding: const EdgeInsets.only(bottom: 9), child: card);
  }
}
