import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/statement.dart';
import '../../services/statement_paper.dart';
import '../../state/farm_store.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/pick_sheet.dart';
import '../../widgets/ui.dart';

/// The books as a statement — the shape everybody already knows how to read.
///
/// A dairy is asked one question more than any other: what do I owe you. The
/// answer to that is not a dashboard, it is a page of days with a running
/// figure down the right, and it has to be something the customer can be sent.
///
/// Which statement this is follows the name at the top. Pick somebody and it
/// is their account; leave it on everybody and it is the farm's cash book. The
/// difference is real and not cosmetic — see [buildStatement].
class StatementScreen extends StatefulWidget {
  const StatementScreen({super.key});

  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  String? _party;
  DateTimeRange? _range;

  /// One kind of entry, or all of them. Sale, purchase, expense, receipt,
  /// payment — the whole ledger is on this page unless somebody narrows it.
  TxnType? _type;

  /// One heading off the books — milk, feed, salaries, or a word somebody
  /// typed themselves.
  String? _category;

  /// Everything the farm has done, whether the money has moved or not.
  ///
  /// Off by default, because the page asked for most often is the cash book
  /// and its last column has to be the money in the box. On, it is a listing
  /// of the lot: feed bought on credit, a buffalo that died, milk still owed
  /// for — the things a cash book is right to leave out and a summary is
  /// wrong to.
  bool _everything = false;

  /// Which of a co-founder's accounts is on the page.
  ///
  /// They have two with the farm and they are not the same thing: what the
  /// farm has earned in their name, and what they have borrowed off it. Put
  /// on one page the running column would be neither.
  bool _theirLoan = false;

  /// Shut to begin with. The whole account is what is wanted nine times out of
  /// ten, and a date box open on arrival is a question nobody asked.
  bool _datesOpen = false;

  /// What the picture is painted from, so what gets sent is what was on the
  /// screen rather than a second drawing of it.
  final _paper = GlobalKey();
  bool _busy = false;

  /// The co-founder whose name is picked, if it is one of theirs.
  Partner? _founder(FarmStore store) {
    if (_party == null) return null;
    for (final p in store.partners) {
      if (partyKey(p.name) == partyKey(_party!)) return p;
    }
    return null;
  }

  /// A co-founder's account is every period the farm has settled and cannot
  /// be cut to a window of days — the money arrives in one lump at a close,
  /// not on the days in between — so the page says so rather than showing
  /// dates it has not honoured.
  String _periodLine(L l) {
    if (_founder(context.read<FarmStore>()) != null) {
      return _theirLoan
          ? l.t('The whole loan, from the day it was handed over')
          : l.t('Every period settled so far');
    }
    return _range == null
        ? l.t('Everything, from the start')
        : '${fmtDateFull(_range!.start)} — ${fmtDateFull(_range!.end)}';
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
      helpText: L.read(context).t('Which days'),
    );
    if (picked != null && mounted) setState(() => _range = picked);
  }

  void _lastDays(int days) {
    final now = DateTime.now();
    setState(() {
      _range = DateTimeRange(
        start: now.subtract(Duration(days: days)),
        end: now,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final l = L.of(context);

    final founder = _founder(store);
    // Only worth offering the second account to somebody who has one.
    final hasLoan =
        founder != null &&
        store.ledger.any(
          (t) =>
              (t.isLoanOut || t.isLoanBack) &&
              partyKey(t.party) == partyKey(founder.name),
        );
    final onLoan = founder != null && _theirLoan && hasLoan;

    final statement = founder != null
        ? onLoan
              ? loanAccount(partner: founder, rows: store.ledger)
              : profitAccount(
                  partner: founder,
                  periods: store.settledPeriods,
                  label: (m) => periodLabel(m, short: true),
                )
        : buildStatement(
            rows: store.ledger,
            party: _party,
            from: _range?.start,
            to: _range?.end,
            capital: store.capitalIn,
            types: _type == null ? null : {_type!},
            category: _category,
            everything: _everything,
          );
    final advance = _party == null || founder != null
        ? 0
        : store.advanceHeldFor(_party!);

    return FarmScaffold(
      title: l.t('Statement'),
      showBack: true,
      body: PageBody(
        children: [
          // Everything that goes on the page, in one box — which is also the
          // thing the camera points at when a picture is asked for.
          RepaintBoundary(
            key: _paper,
            child: StatementSheet(
              statement: statement,
              farmName: l.t('Char Yar Dairy Farm'),
              forWhom: _party ?? l.t('The whole farm'),
              period: _periodLine(l),
              advanceHeld: advance,
            ),
          ),
          const SizedBox(height: T.pad),

          Row(
            children: [
              Flexible(
                child: PickPill(
                  icon: Icons.person_outline,
                  label: _party ?? l.t('Everybody'),
                  chosen: _party != null,
                  onClear: () => setState(() => _party = null),
                  onTap: _pickParty,
                ),
              ),
              if (founder == null) const SizedBox(width: 8),
              if (founder == null)
                Flexible(
                  child: PickPill(
                    icon: Icons.swap_vert,
                    label: _type == null
                        ? l.t('Everything')
                        : l.t(_type!.label),
                    chosen: _type != null,
                    onClear: () => setState(() => _type = null),
                    onTap: _pickType,
                  ),
                ),
            ],
          ),
          // One person's own page carries everything of theirs already, so
          // this is only worth offering on the farm's own.
          // Two accounts, two pages. A co-founder who has never borrowed
          // sees neither this nor the question.
          if (hasLoan) ...[
            const SizedBox(height: 8),
            Segmented<bool>(
              value: _theirLoan,
              options: [(false, l.t('Profit')), (true, l.t('Loan'))],
              onChanged: (v) => setState(() => _theirLoan = v),
            ),
          ],
          if (founder == null && _party == null) ...[
            const SizedBox(height: 8),
            SwitchRow(
              title: l.t('Show everything, paid or not'),
              note: l.t(
                'Feed bought on credit, a buffalo that died, milk still owed '
                'for. The running total stops being the cash in the box and '
                'becomes the total of what is on the page.',
              ),
              value: _everything,
              onChanged: (v) => setState(() => _everything = v),
            ),
          ],
          if (founder == null) const SizedBox(height: 8),
          if (founder == null)
            Row(
              children: [
                Flexible(
                  child: PickPill(
                    icon: Icons.sell_outlined,
                    label: _category ?? l.t('Anything'),
                    chosen: _category != null,
                    onClear: () => setState(() => _category = null),
                    onTap: _pickCategory,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: PickPill(
                    icon: Icons.calendar_today_outlined,
                    label: _range == null
                        ? l.t('All dates')
                        : l.t2('%s days', _range!.duration.inDays + 1),
                    chosen: _range != null,
                    onClear: () => setState(() {
                      _range = null;
                      _datesOpen = false;
                    }),
                    onTap: () => setState(() => _datesOpen = !_datesOpen),
                  ),
                ),
              ],
            ),

          if (_datesOpen && founder == null) ...[
            const SizedBox(height: 10),
            RegCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker(l.t('Which days')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _Quick(
                        label: l.t('Last 30 days'),
                        onTap: () => _lastDays(30),
                      ),
                      _Quick(
                        label: l.t('3 months'),
                        onTap: () => _lastDays(90),
                      ),
                      _Quick(label: l.t('A year'), onTap: () => _lastDays(365)),
                      _Quick(
                        label: l.t('Pick the days'),
                        icon: Icons.date_range,
                        onTap: _pickDates,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: l.t('Send as PDF'),
                  icon: Icons.picture_as_pdf_outlined,
                  busy: _busy,
                  onPressed: statement.isEmpty ? null : _sendPdf,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: GhostButton(
                  label: l.t('Send as picture'),
                  icon: Icons.image_outlined,
                  onPressed: _busy || statement.isEmpty ? null : _sendImage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            statement.forOneParty
                ? l.t(
                    'One person’s account. Milk they took puts the '
                    'balance up whether it is paid for or not; money they '
                    'hand over brings it down.',
                  )
                : l.t(
                    'The farm’s cash book. Only what actually moved '
                    'money is in it, so it opens at what the co-founders put '
                    'in and closes at what is in the box today.',
                  ),
            style: T.meta,
          ),
        ],
      ),
    );
  }

  Future<void> _pickType() async {
    final l = L.read(context);
    final picked = await pickOne(
      context,
      title: l.t('Which kind of entry?'),
      options: [for (final t in TxnType.values) l.t(t.label)],
      allLabel: l.t('Everything'),
      current: _type == null ? null : l.t(_type!.label),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final v = picked.value;
      _type = v == null
          ? null
          : TxnType.values.firstWhere(
              (t) => l.t(t.label) == v,
              orElse: () => TxnType.sale,
            );
    });
  }

  Future<void> _pickCategory() async {
    final store = context.read<FarmStore>();
    final l = L.read(context);
    // Every heading the books carry, on every tab, because the question
    // "what has the feed cost" does not care which tab it was written on.
    final all = <String>{
      for (final list in store.categoryBook.values) ...list,
    }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final picked = await pickOne(
      context,
      title: l.t('Which kind of entry?'),
      options: all,
      allLabel: l.t('Anything'),
      current: _category,
    );
    if (picked != null && mounted) setState(() => _category = picked.value);
  }

  Future<void> _pickParty() async {
    final store = context.read<FarmStore>();
    final l = L.read(context);
    final picked = await pickOne(
      context,
      title: l.t('Whose statement?'),
      // The four of them first. A co-founder's page is a different document
      // from a customer's — capital never went through the ledger — and the
      // way to ask for it is to pick their name like anybody else's.
      options: [
        for (final p in store.partners) p.name,
        for (final p in store.partyBook)
          if (!store.partners.any((f) => partyKey(f.name) == partyKey(p.name)))
            p.name,
      ],
      allLabel: l.t('The whole farm'),
      current: _party,
    );
    if (picked != null && mounted) setState(() => _party = picked.value);
  }

  Future<void> _sendPdf() async {
    final store = context.read<FarmStore>();
    final l = L.read(context);
    setState(() => _busy = true);
    try {
      await StatementPaper.sharePdf(
        // Whatever is on the screen is what goes on the paper. Working it
        // out a second time here is how the two drift apart.
        statement: _founder(store) != null
            ? (_theirLoan
                  ? loanAccount(partner: _founder(store)!, rows: store.ledger)
                  : profitAccount(
                      partner: _founder(store)!,
                      periods: store.settledPeriods,
                      label: (m) => periodLabel(m, short: true),
                    ))
            : buildStatement(
                rows: store.ledger,
                party: _party,
                from: _range?.start,
                to: _range?.end,
                capital: store.capitalIn,
                types: _type == null ? null : {_type!},
                category: _category,
                everything: _everything,
              ),
        farmName: l.t('Char Yar Dairy Farm'),
        forWhom: _party ?? l.t('The whole farm'),
        period: _periodLine(l),
        advanceHeld: _party == null ? 0 : store.advanceHeldFor(_party!),
      );
    } catch (e) {
      if (mounted) toast(context, l.t2('Could not make the PDF. %s', e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendImage() async {
    final l = L.read(context);
    setState(() => _busy = true);
    try {
      await StatementPaper.shareImage(
        boundary: _paper,
        farmName: l.t('Char Yar Dairy Farm'),
        forWhom: _party ?? l.t('The whole farm'),
        period: _periodLine(l),
      );
    } catch (e) {
      if (mounted) toast(context, l.t2('Could not make the picture. %s', e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// The page itself — head, the days, and the figures at the foot.
///
/// Public so a test can pump it on a 360-wide phone and check that nothing
/// has fallen off the right-hand edge. It has done, twice.
class StatementSheet extends StatelessWidget {
  const StatementSheet({
    super.key,
    required this.statement,
    required this.farmName,
    required this.forWhom,
    required this.period,
    required this.advanceHeld,
  });

  final Statement statement;
  final String farmName;
  final String forWhom;
  final String period;
  final num advanceHeld;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    // Paper, not a screen: this sheet is shared out of the app and read by
    // somebody who never chose a skin. Everything below is laid out in this
    // one pass, which is why the parts are functions.
    return T.onPaper(
      () => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: T.round,
          boxShadow: T.shadow,
        ),
        child: ClipRRect(
          borderRadius: T.round,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Head
              Container(
                color: T.accent800,
                padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(T.radiusXs),
                      child: Image.asset(
                        'assets/mark.png',
                        width: 38,
                        height: 38,
                        fit: BoxFit.cover,
                        // The farm's mark is going to be swapped one day, and
                        // a statement is not the place to find out the file has
                        // moved. Without this the whole page throws and draws
                        // nothing at all over a missing picture.
                        errorBuilder: (_, _, _) =>
                            const SizedBox(width: 38, height: 38),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            farmName,
                            style: T.cardTitle.copyWith(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            l.t(statement.kind.title),
                            style: T.meta.copyWith(color: T.accent300),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          l.t('Issued').toUpperCase(),
                          style: T.kicker.copyWith(color: T.accent300),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fmtDateFull(DateTime.now()),
                          style: T.bodyMid.copyWith(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Who, when, and where the balance started
              Container(
                color: T.n100,
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 11,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _fact(label: l.t('Account'), value: forWhom),
                    ),
                    Expanded(
                      flex: 2,
                      child: _fact(label: l.t('Period'), value: period),
                    ),
                    _fact(
                      label: statement.showing.isEmpty
                          ? l.t('Opening')
                          : l.t('Showing'),
                      value: statement.showing.isEmpty
                          ? rs(statement.opening)
                          : statement.showing,
                      right: true,
                    ),
                  ],
                ),
              ),

              if (statement.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: EmptyNote(l.t('Nothing in these days.')),
                )
              else
                _table(context, statement),

              // The foot
              Container(
                color: T.accent100,
                padding: const EdgeInsets.fromLTRB(15, 12, 15, 13),
                child: Column(
                  children: [
                    _footLine(
                      label: l.t('Total debit'),
                      value: rs(statement.debits),
                      tone: T.moneyOut,
                    ),
                    _footLine(
                      label: l.t('Total credit'),
                      value: rs(statement.credits),
                      tone: T.moneyIn,
                    ),
                    Divider(height: 14, color: T.accent300),
                    _footLine(
                      label: l.t(statement.kind.footLabel),
                      value: rs(statement.closing),
                      tone: T.accent800,
                      big: true,
                    ),
                    if (advanceHeld > 0)
                      _footLine(
                        label: l.t('Advance'),
                        value: rs(advanceHeld),
                        tone: T.moneyDue,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The seven columns, on a phone.
///
/// They were laid out as a grid five hundred and eighty pixels wide inside a
/// sideways scroll, which is fine on paper and not fine on a phone: the last
/// three columns sat off the right-hand edge, so the page never showed the
/// credit or the balance — and a picture of it was cut off at the same place,
/// because a photograph of a scrolling box only catches what is on screen.
/// The whole point of the page is the figure down the right.
///
/// So nothing scrolls sideways any more. The date and the three money
/// columns keep their own width, and everything wordy — who it was, what it
/// was, who wrote it — shares what is left and wraps. The A4 version keeps
/// the true grid, because a sheet of paper is wide enough for it.
/// Wide enough for a lakh with its commas, and not a pixel more.
const _money = 56.0;
const _balance = 64.0;
const _date = 42.0;

Widget _table(BuildContext context, Statement statement) {
  final l = L.of(context);
  return Column(
    children: [
      Container(
        color: T.n100,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            SizedBox(width: _date, child: _h('Date')),
            Expanded(child: _h(l.t('Particulars'))),
            SizedBox(width: _money, child: _h(l.t('Debit'), right: true)),
            SizedBox(width: _money, child: _h(l.t('Credit'), right: true)),
            SizedBox(width: _balance, child: _h(l.t('Balance'), right: true)),
          ],
        ),
      ),
      for (final line in statement.lines)
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: T.n200)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _date,
                child: Text(
                  fmtDate(line.date),
                  style: T.body.copyWith(fontSize: 11),
                ),
              ),
              // Who, what, and whose hand wrote it — one under the other,
              // because on a phone these are the three that can afford to
              // wrap and the money is the one that cannot.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.party, style: T.bodyMid.copyWith(fontSize: 12)),
                    Text(line.detail, style: T.meta.copyWith(fontSize: 10.5)),
                    if (line.enteredBy.isNotEmpty)
                      Text(
                        line.enteredBy,
                        style: T.meta.copyWith(fontSize: 10, color: T.n500),
                      ),
                  ],
                ),
              ),
              _moneyCell(line.debit, _money, T.moneyOut),
              _moneyCell(line.credit, _money, T.moneyIn),
              SizedBox(
                width: _balance,
                child: Text(
                  groupPk(line.balance),
                  textAlign: TextAlign.right,
                  style: T.bodyMid.copyWith(
                    fontSize: 11.5,
                    color: line.balance < 0 ? T.moneyDue : T.accent800,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

Widget _moneyCell(num value, double width, Color tone) => SizedBox(
  width: width,
  child: Text(
    value > 0 ? groupPk(value) : '',
    textAlign: TextAlign.right,
    style: T.body.copyWith(fontSize: 11.5, color: tone),
  ),
);

Widget _h(String text, {bool right = false}) => Text(
  text.toUpperCase(),
  textAlign: right ? TextAlign.right : TextAlign.left,
  style: T.kicker,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
);

Widget _fact({
  required String label,
  required String value,
  bool right = false,
}) => Column(
  crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
  children: [
    Text(label.toUpperCase(), style: T.kicker),
    const SizedBox(height: 2),
    Text(value, style: T.bodyMid.copyWith(fontSize: 12.5), maxLines: 2),
  ],
);

Widget _footLine({
  required String label,
  required String value,
  required Color tone,
  bool big = false,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 2),
  child: Row(
    children: [
      Expanded(child: Text(label, style: big ? T.bodyMid : T.body)),
      Text(value, style: (big ? T.num22 : T.bodyMid).copyWith(color: tone)),
    ],
  ),
);

class _Quick extends StatelessWidget {
  const _Quick({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) =>
      GhostButton(label: label, icon: icon, compact: true, onPressed: onTap);
}
