import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../state/farm_store.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/balance_check.dart';
import '../../widgets/day_chart.dart';
import '../../widgets/ui.dart';

/// Where the farm's money came from and where it went, over a stretch of time.
///
/// Two ways of reading it, because they answer different questions. The ring
/// answers "are we ahead?" in one glance. The list answers "on what?" — every
/// category, sorted biggest first, so the thing worth arguing about is at the
/// top.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

enum _Span {
  summary('Summary'),
  thisPeriod('This period'),
  lastThree('Last 3 months'),
  thisYear('This year'),
  everything('Everything');

  const _Span(this.label);

  final String label;

  /// The earliest date this span takes in. Null means no limit.
  DateTime? get from => switch (this) {
    _Span.summary => null,
    _Span.thisPeriod => null,
    _Span.lastThree => DateTime.now().subtract(const Duration(days: 92)),
    _Span.thisYear => DateTime(DateTime.now().year),
    _Span.everything => null,
  };
}

enum _View { ring, list }

class _ReportScreenState extends State<ReportScreen> {
  _Span _span = _Span.summary;
  _View _view = _View.ring;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<FarmStore>();

    return FarmScaffold(
      title: l.t('Report'),
      showBack: true,
      body: _span == _Span.summary
          ? PageBody(
              children: [
                _SinceDayOne(store: store),
                const SizedBox(height: 20),
                _SpanPicker(
                  span: _span,
                  onPick: (sp) => setState(() => _span = sp),
                ),
                const SizedBox(height: T.gap),
                _PeriodByPeriod(store: store),
                const SizedBox(height: 20),
                _InvestmentCard(partners: store.partners, ratios: store.ratios),
              ],
            )
          : _span == _Span.thisPeriod
          ? _body(context, l, store, store.monthTxns, periodLabel(store.month))
          : StreamBuilder<List<Txn>>(
              stream: Db.watchTxnsSince(_span.from),
              builder: (context, snap) {
                final txns = snap.data;
                if (txns == null) {
                  return PageBody(children: [EmptyNote(l.t('Loading…'))]);
                }
                return _body(context, l, store, txns, l.t(_span.label));
              },
            ),
    );
  }

  Widget _body(
    BuildContext context,
    L l,
    FarmStore store,
    List<Txn> txns,
    String spanLabel,
  ) {
    final live = txns.where((t) => !t.isDeleted).toList();
    final income = _byCategory(live, incoming: true);
    final spend = _byCategory(live, incoming: false);
    final assets = live
        .where((t) => t.isCapitalAsset)
        .fold<num>(0, (a, t) => a + t.amount);

    final totalIn = income.fold<num>(0, (a, e) => a + e.amount);
    // Cattle and equipment are not a running cost — the farm still owns them.
    final totalOut = spend.fold<num>(0, (a, e) => a + e.amount) - assets;
    final net = totalIn - totalOut;

    return PageBody(
      children: [
        HeroCard(
          label: l.t('Net'),
          value: rs(net),
          gradient: T.washOf(net < 0 ? T.moneyOut : T.moneyIn),
          note: l.t3('%s in, %s out', rs(totalIn), rs(totalOut)),
          trailing: Tag(spanLabel),
        ),
        const SizedBox(height: T.gap),

        _SpanPicker(span: _span, onPick: (s) => setState(() => _span = s)),
        const SizedBox(height: T.gap),

        Segmented<_View>(
          value: _view,
          options: [(_View.ring, l.t('Chart')), (_View.list, l.t('Detail'))],
          onChanged: (v) => setState(() => _view = v),
        ),
        const SizedBox(height: T.pad),

        if (_view == _View.ring) ...[
          RegCard(
            child: Column(
              children: [
                SizedBox(
                  height: 210,
                  child: _Ring(income: totalIn, spend: totalOut, net: net),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChartKey(colour: T.moneyIn, label: l.t('Money in')),
                    const SizedBox(width: 18),
                    ChartKey(colour: T.moneyOut, label: l.t('Money out')),
                  ],
                ),
                const Divider(height: 24),
                _Total(label: l.t('Money in'), value: totalIn, tone: T.moneyIn),
                _Total(
                  label: l.t('Money out'),
                  value: totalOut,
                  tone: T.moneyOut,
                ),
                const Divider(height: 16),
                _Total(
                  label: l.t('Net'),
                  value: net,
                  tone: net < 0 ? T.moneyOut : T.moneyIn,
                  strong: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: T.gap),
          DayChart(days: dayTotals(live)),
          if (assets > 0) ...[
            const SizedBox(height: T.gap),
            RegCard(
              wash: T.accent100,
              child: Text(
                l.t2(
                  '%s of cattle and equipment was bought in this stretch. It '
                  'is not counted as a cost above — the farm owns it.',
                  rs(assets),
                ),
                style: T.body,
              ),
            ),
          ],
        ] else ...[
          _Block(
            title: l.t('Money in'),
            tone: T.moneyIn,
            lines: income,
            total: totalIn,
          ),
          const SizedBox(height: T.gap),
          _Block(
            title: l.t('Money out'),
            tone: T.moneyOut,
            lines: spend,
            total: totalOut + assets,
          ),
          const SizedBox(height: T.gap),
          RegCard(
            child: Column(
              children: [
                if (assets > 0) ...[
                  _Total(
                    label: l.t('Less cattle & equipment'),
                    value: assets,
                    tone: T.accent700,
                  ),
                  const Divider(height: 16),
                ],
                _Total(
                  label: l.t('Net'),
                  value: net,
                  tone: net < 0 ? T.moneyOut : T.moneyIn,
                  strong: true,
                ),
                if (assets > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    l.t(
                      'Cattle and equipment are taken off the costs, because '
                      'the money bought something the farm still has.',
                    ),
                    style: T.meta,
                  ),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        _InvestmentCard(partners: store.partners, ratios: store.ratios),

        if (live.isEmpty) ...[
          const SizedBox(height: T.gap),
          EmptyNote(l.t('Nothing booked in this stretch yet.')),
        ],
      ],
    );
  }

  /// Every category with something in it, biggest first.
  List<_Line> _byCategory(List<Txn> txns, {required bool incoming}) {
    final totals = <String, num>{};
    final counts = <String, int>{};
    for (final t in txns) {
      if (t.type.isSettlement) continue; // the money is on its own entry
      if (t.type.isIncoming != incoming) continue;
      final key = t.category.isEmpty ? t.type.label : t.category;
      totals[key] = (totals[key] ?? 0) + t.amount;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final lines = [
      for (final e in totals.entries) _Line(e.key, e.value, counts[e.key] ?? 0),
    ]..sort((a, b) => b.amount.compareTo(a.amount));
    return lines;
  }
}

class _Line {
  const _Line(this.label, this.amount, this.count);

  final String label;
  final num amount;
  final int count;
}

class _Block extends StatelessWidget {
  const _Block({
    required this.title,
    required this.tone,
    required this.lines,
    required this.total,
  });

  final String title;
  final Color tone;
  final List<_Line> lines;
  final num total;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: T.kicker.copyWith(color: tone, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (lines.isEmpty)
            Text(l.t('Nothing here.'), style: T.meta)
          else
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.label,
                            style: T.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            l.t2('%s entries', line.count),
                            style: T.meta.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      rs(line.amount),
                      style: T.bodyMid.copyWith(color: tone),
                    ),
                  ],
                ),
              ),
          const Divider(height: 18),
          _Total(label: l.t('Total'), value: total, tone: tone, strong: true),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({
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
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label, style: strong ? T.cardTitle : T.body)),
        Text(
          rs(value),
          style: (strong ? T.num22 : T.bodyMid).copyWith(color: tone),
        ),
      ],
    ),
  );
}

class _SpanPicker extends StatelessWidget {
  const _SpanPicker({required this.span, required this.onPick});

  final _Span span;
  final ValueChanged<_Span> onPick;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in _Span.values)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => onPick(s),
                  borderRadius: BorderRadius.circular(T.pill),
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: s == span ? T.accent700 : Colors.white,
                      borderRadius: BorderRadius.circular(T.pill),
                      border: Border.all(
                        color: s == span ? T.accent700 : T.n300,
                        width: 1.3,
                      ),
                    ),
                    child: Text(
                      l.t(s.label),
                      style: T.meta.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: s == span ? Colors.white : T.n700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Money in against money out, as one ring with the net in the middle.
class _Ring extends StatelessWidget {
  const _Ring({required this.income, required this.spend, required this.net});

  final num income;
  final num spend;
  final num net;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _RingPainter(income: income, spend: spend),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(L.of(context).t('Net'), style: T.kicker),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              rs(net),
              style: T.num26.copyWith(color: net < 0 ? T.moneyOut : T.moneyIn),
            ),
          ),
        ],
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.income, required this.spend});

  final num income;
  final num spend;

  @override
  void paint(Canvas canvas, Size size) {
    final total = income + spend;
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 16;
    final rect = Rect.fromCircle(center: centre, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..color = T.n200;
    canvas.drawCircle(centre, radius, track);

    if (total <= 0) return;

    // Start at the top and go clockwise, which is how a pie is read.
    const start = -math.pi / 2;
    final inSweep = (income / total) * 2 * math.pi;

    final inPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.butt
      ..color = T.moneyIn;
    final outPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.butt
      ..color = T.moneyOut;

    canvas.drawArc(rect, start, inSweep, false, inPaint);
    canvas.drawArc(
      rect,
      start + inSweep,
      2 * math.pi - inSweep,
      false,
      outPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.income != income || old.spend != spend;
}

/// What the co-founders have put into the farm, and what that makes their
/// share. All time, not this stretch — capital does not belong to a period.
class _InvestmentCard extends StatelessWidget {
  const _InvestmentCard({required this.partners, required this.ratios});

  final List<Partner> partners;
  final Map<String, double> ratios;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final total = partners.fold<num>(0, (a, p) => a + p.capital);
    final out = partners.fold<num>(0, (a, p) => a + p.withdrawn);

    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(l.t('What the co-founders have in')),
          const SizedBox(height: 10),
          if (partners.isEmpty)
            Text(l.t('No co-founders yet.'), style: T.meta)
          else ...[
            for (final p in partners)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: T.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            p.reinvested > 0
                                ? l.t2(
                                    'incl. %s left in from profit',
                                    rs(p.reinvested),
                                  )
                                : l.t('put in from their own pocket'),
                            style: T.meta.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tag(
                      '${((ratios[p.id] ?? 0) * 100).toStringAsFixed(0)}%',
                      tone: TagTone.accent,
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 96,
                      child: Text(
                        rs(p.capital),
                        textAlign: TextAlign.right,
                        style: T.bodyMid,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 18),
            _Total(
              label: l.t('Total capital'),
              value: total,
              tone: T.accent700,
              strong: true,
            ),
            if (out > 0)
              _Total(
                label: l.t('Taken out so far'),
                value: out,
                tone: T.moneyOut,
              ),
          ],
        ],
      ),
    );
  }
}

/// The farm from the day it started: what went in, what it sold, what it
/// spent, what is left.
///
/// Six figures, in the order the question is usually asked. Every one of them
/// counts every period — including a period that is sealed and still waiting
/// on the co-founders, whose trading happened whatever is being decided about
/// the profit.
class _SinceDayOne extends StatelessWidget {
  const _SinceDayOne({required this.store});

  final FarmStore store;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final money = store.money;
    final profit = store.lifetimeProfit;

    return Column(
      children: [
        HeroCard(
          label: l.t('Made since day one'),
          value: rs(profit),
          gradient: T.washOf(profit < 0 ? T.moneyOut : T.moneyIn),
          note: l.t3(
            '%s sold, %s spent on running the farm',
            rs(store.lifetimeSales),
            rs(store.lifetimeRunningCosts),
          ),
          trailing: Tag(l.t('All time')),
        ),
        const SizedBox(height: T.gap),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: l.t('Put in'),
                value: rs(money.capital),
                tone: T.accent700,
                note: l.t('by the co-founders'),
              ),
            ),
            const SizedBox(width: T.gap),
            Expanded(
              child: StatTile(
                label: l.t('Sold'),
                value: rs(store.lifetimeSales),
                tone: T.moneyIn,
              ),
            ),
          ],
        ),
        const SizedBox(height: T.gap),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: l.t('Spent'),
                value: rs(store.lifetimeRunningCosts),
                tone: T.moneyOut,
                note: l.t('feed, salaries, bills'),
              ),
            ),
            const SizedBox(width: T.gap),
            Expanded(
              child: StatTile(
                label: l.t('Owns'),
                value: rs(money.assets),
                tone: const Color(0xFF6544B0),
                note: l.t('cattle & equipment'),
              ),
            ),
          ],
        ),
        const SizedBox(height: T.gap),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: l.t('Cash now'),
                value: rs(money.cash),
                tone: T.moneyIn,
              ),
            ),
            const SizedBox(width: T.gap),
            Expanded(
              child: StatTile(
                label: l.t('To receive'),
                value: rs(money.receivable),
                tone: T.moneyGet,
              ),
            ),
          ],
        ),
        const SizedBox(height: T.gap),
        // Put where every co-founder can reach it, not only the master.
        BalanceCheck(money: money),
      ],
    );
  }
}

/// Every period the farm has settled, one line each — the month-by-month
/// answer to "how did we do".
class _PeriodByPeriod extends StatelessWidget {
  const _PeriodByPeriod({required this.store});

  final FarmStore store;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final settled = store.settledPeriods;
    final open = store.month;
    final books = store.books;

    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(l.t('Period by period')),
          const SizedBox(height: 4),
          Text(
            l.t('Newest first. The open one is still running.'),
            style: T.meta,
          ),
          const SizedBox(height: 12),

          _PeriodLine(
            label: periodLabel(open),
            state: l.t('open'),
            sales: books.sales,
            costs: books.costs,
            profit: books.profit,
            shared: null,
          ),

          for (final p in settled) ...[
            const Divider(height: 18),
            _PeriodLine(
              label: periodLabel(p),
              state: p.isSealed ? l.t('waiting') : l.t('closed'),
              sales: p.sales ?? 0,
              costs: (p.purchases ?? 0) + (p.expenses ?? 0) - (p.assets ?? 0),
              profit: p.profit ?? 0,
              shared: p.isClosed ? (p.profitShared ?? 0) : null,
            ),
          ],

          if (settled.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              l.t('No period has been settled yet — this is the first one.'),
              style: T.meta,
            ),
          ],
        ],
      ),
    );
  }
}

class _PeriodLine extends StatelessWidget {
  const _PeriodLine({
    required this.label,
    required this.state,
    required this.sales,
    required this.costs,
    required this.profit,
    required this.shared,
  });

  final String label;
  final String state;
  final num sales;
  final num costs;
  final num profit;

  /// What was actually handed to the co-founders. Null while the period is
  /// still running or still being decided.
  final num? shared;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: T.cardTitle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Tag(
              state,
              tone: state == l.t('closed') ? TagTone.good : TagTone.warn,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _Cell(label: l.t('Sold'), value: sales, tone: T.moneyIn),
            _Cell(label: l.t('Spent'), value: costs, tone: T.moneyOut),
            _Cell(
              label: l.t('Profit'),
              value: profit,
              tone: profit < 0 ? T.moneyOut : T.moneyIn,
            ),
          ],
        ),
        if (shared != null && shared! > 0) ...[
          const SizedBox(height: 4),
          Text(l.t2('%s went to the co-founders', rs(shared!)), style: T.meta),
        ],
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value, required this.tone});

  final String label;
  final num value;
  final Color tone;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: T.kicker.copyWith(fontSize: 10)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(rs(value), style: T.bodyMid.copyWith(color: tone)),
        ),
      ],
    ),
  );
}
