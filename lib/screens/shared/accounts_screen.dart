import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/accounting.dart';
import '../../services/db.dart';
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

  /// Settling a week of milk in one go.
  ///
  /// The round sells on credit twice a day, so a customer who pays on Friday
  /// is paying off a dozen entries at once. Ticking them off one at a time,
  /// each with its own "how did the money come" sheet, is not something
  /// anybody would do twice — so the whole lot is picked first and asked
  /// about once. Which ones are settled is still recorded one by one, because
  /// he may hand over enough for nine of them and not the other three.
  final _picked = <String>{};
  bool _settling = false;

  /// How much the customer is actually handing over, once it is not simply
  /// all of it. Empty until somebody types in the box.
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
        // The names and kinds actually in the books, rather than a fixed
        // list: a customer who has never traded is not worth offering.
        final parties = _distinct(everything, (t) => t.party);
        final categories = _distinct(everything, (t) => t.category);

        return PageBody(
          children: [
            HeroCard(
              label: l.t(_filter.heading),
              value: rs(_total(books, rows)),
              gradient: T.washOf(_filter.tone),
              note: loading ? l.t('Loading…') : l.t2('%s entries', rows.length),
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
            const SizedBox(height: 12),

            Text(
              l.t(
                'All farm money in one place: milk & product sales, '
                'cattle, feed, bills, rent, food, salaries. Anything sold '
                'or bought on credit stays unpaid until you mark it paid.',
              ),
              style: T.meta,
            ),
            const SizedBox(height: 14),

            if (loading && everything.isEmpty)
              EmptyNote(l.t('Loading…'))
            else if (rows.isEmpty)
              EmptyNote(l.t('Nothing booked here yet. Tap Add to start.'))
            else ...[
              ..._withDividers(rows, periods, l, isMaster),
              const SizedBox(height: 4),
              _TotalStrip(
                count: rows.length,
                // On the two tabs about what is owed, the total is what
                // is still owed — an entry half settled counts half.
                total: rows.fold<num>(
                  0,
                  (a, t) => a + (_owedTab ? t.outstanding : t.amount),
                ),
                tone: _filter.tone,
              ),
              // What has been ticked, and the one button that settles it.
              // Below the list, because that is where you are standing
              // when you have finished reading it.
              if (_ticked(rows).isNotEmpty) ...[
                const SizedBox(height: 12),
                _SettleBar(
                  picked: _ticked(rows),
                  taking: _taking,
                  busy: _settling,
                  onAll: () => _pickAll(rows),
                  allPicked: _allPicked(rows),
                  onClear: _clearPicked,
                  onSettle: () => _settleMany(rows),
                  onAmountChanged: () => setState(() {}),
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  /// The tab's rows, narrowed to one name, one kind, or both.
  List<Txn> _narrow(List<Txn> rows) => rows
      .where((t) => _party == null || t.party == _party)
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
          selecting: _canTick,
          selected: _picked.contains(txn.id),
          onToggle: _canPick(txn) ? () => _toggle(txn) : null,
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

  /// Anything still outstanding can be ticked, part settled included. What is
  /// finished stays on screen, faded, because the week has to read as the week.
  bool _canPick(Txn txn) => _canTick && txn.outstanding > 0;

  List<Txn> _ticked(List<Txn> rows) =>
      rows.where((t) => _picked.contains(t.id) && t.outstanding > 0).toList();

  bool _allPicked(List<Txn> rows) {
    final owing = rows.where((t) => t.outstanding > 0).toList();
    return owing.isNotEmpty && owing.every((t) => _picked.contains(t.id));
  }

  void _toggle(Txn txn) => setState(() {
    if (!_picked.remove(txn.id)) _picked.add(txn.id);
    _taking.clear();
  });

  void _pickAll(List<Txn> rows) => setState(() {
    final owing = rows.where((t) => t.outstanding > 0).toList();
    final all = _allPicked(rows);
    _picked.clear();
    if (!all) _picked.addAll(owing.map((t) => t.id));
    _taking.clear();
  });

  void _clearPicked() => setState(() {
    _picked.clear();
    _taking.clear();
  });

  /// Take one lump of money against everything that is ticked.
  Future<void> _settleMany(List<Txn> rows) async {
    final chosen = _ticked(rows);
    if (chosen.isEmpty) return;
    final l = L.read(context);

    // One direction at a time, so "who took the money" is asked of the right
    // people. In practice a week of milk is all one way; this only bites when
    // somebody ticks a bill and a sale together.
    final incoming = chosen.where((t) => t.type.isIncoming).toList();
    final outgoing = chosen.where((t) => !t.type.isIncoming).toList();
    if (incoming.isNotEmpty && outgoing.isNotEmpty) {
      toast(
        context,
        l.t('Money coming in and money going out have to be settled apart.'),
      );
      return;
    }

    final owed = chosen.fold<num>(0, (a, t) => a + t.outstanding);
    final typed = num.tryParse(_taking.text.trim());
    // Empty box means all of it, which is what usually happens. A figure
    // larger than what is owed is a slip, not an overpayment to hold.
    final taking = typed == null ? owed : typed.clamp(0, owed);
    if (taking <= 0) return;

    final settled = await askSettlement(
      context,
      incoming: chosen.first.type.isIncoming,
      party: chosen.first.party,
      amount: taking,
    );
    if (settled == null || !mounted) return;

    setState(() => _settling = true);
    try {
      final finished = await TxnRepo.settle(
        context.read<Session>().actor,
        chosen,
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
          _picked.clear();
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

/// What has been ticked, and the one button that takes the money in.
///
/// Three figures, because three is what somebody standing in a yard with a
/// handful of notes actually needs: how many days, how much milk, how much
/// money — and the money written out as well as in digits, the way it would be
/// said out loud while it is counted.
///
/// The amount box starts empty, meaning all of it, which is what usually
/// happens. Type a smaller figure and the bar says what will still be owed
/// afterwards, before anything is settled.
class _SettleBar extends StatelessWidget {
  const _SettleBar({
    required this.picked,
    required this.taking,
    required this.busy,
    required this.allPicked,
    required this.onAll,
    required this.onClear,
    required this.onSettle,
    required this.onAmountChanged,
  });

  final List<Txn> picked;
  final TextEditingController taking;
  final bool busy;
  final bool allPicked;
  final VoidCallback onAll;
  final VoidCallback onClear;
  final VoidCallback onSettle;
  final VoidCallback onAmountChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final owed = picked.fold<num>(0, (a, t) => a + t.outstanding);

    // Only where litres mean something. Rent and vet bills have no litres, and
    // a "0 L" under them would be a figure pretending to be information.
    final litres = picked
        .where((t) => t.unit == 'L' && t.qty != null)
        .fold<num>(0, (a, t) => a + t.qty!);

    final typed = num.tryParse(taking.text.trim());
    final amount = typed == null ? owed : typed.clamp(0, owed);
    final over = owed - amount;

    return RegCard(
      stripe: T.moneyIn,
      padding: const EdgeInsets.fromLTRB(14, 13, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    _Figure(
                      value: '${picked.length}',
                      label: l.t('ticked'),
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
                      label: l.t('owed'),
                      tone: T.moneyIn,
                    ),
                  ],
                ),
              ),
              GhostButton(
                label: allPicked ? l.t('Clear') : l.t('All of them'),
                compact: true,
                onPressed: busy ? null : (allPicked ? onClear : onAll),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
              rsInWords(owed),
              style: T.bodyMid.copyWith(fontSize: 12.5, color: T.n700),
            ),
          ),

          const Divider(height: 20),
          Field(
            label: l.t('How much is being handed over'),
            controller: taking,
            hint: l.t2('Leave it empty for all of it — %s', rs(owed)),
            keyboardType: TextInputType.number,
            onChanged: (_) => onAmountChanged(),
          ),
          if (over > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: T.moneyDueWash,
                borderRadius: BorderRadius.circular(T.radiusXs),
                border: Border.all(color: T.moneyDue.withValues(alpha: 0.5)),
              ),
              child: Text(
                l.t2(
                  '%s will still be owed. The oldest entries are settled '
                  'first; whatever is left over stops part way through one, '
                  'and that is the one the next payment fills.',
                  rs(over),
                ),
                style: T.meta.copyWith(color: T.moneyDue),
              ),
            ),
          ],
          const SizedBox(height: 12),
          PrimaryButton(
            label: busy ? l.t('Taking it in…') : l.t2('Take in %s', rs(amount)),
            onPressed: busy || amount <= 0 ? null : onSettle,
          ),
        ],
      ),
    );
  }
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
    final mine = ledger.where((t) => t.party == party).toList();

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
    this.selecting = false,
    this.selected = false,
    this.onToggle,
  });

  final Txn txn;
  final bool isMaster;
  final bool busy;
  final VoidCallback onMarkPaid;
  final VoidCallback onDelete;

  /// Picking several entries to settle in one go.
  final bool selecting;
  final bool selected;

  /// Null when this entry cannot join the selection — it is already settled,
  /// or the money runs the other way from what is already picked.
  final VoidCallback? onToggle;

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
          if (selecting)
            SizedBox(
              width: 34,
              child: Checkbox(
                value: selected,
                // A settled entry, or one running the other way, is shown
                // greyed rather than hidden: the week's account reads as the
                // week's account, and only what can be settled can be ticked.
                onChanged: onToggle == null ? null : (_) => onToggle!(),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                      // While entries are being ticked, the one-at-a-time
                      // button would be a second way of doing the same
                      // thing, half a second before the other one.
                      if (!selecting) ...[
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
              if (isMaster && !selecting)
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      // The whole card is the tick box while several are being picked. Ticking
      // fourteen days of milk one small square at a time, on a phone, in a
      // yard, is not something anybody would do twice.
      child: selecting && onToggle != null
          ? InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(T.radius),
              child: card,
            )
          : card,
    );
  }
}
