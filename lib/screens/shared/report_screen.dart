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
  thisPeriod('This period'),
  lastThree('Last 3 months'),
  thisYear('This year'),
  everything('Everything');

  const _Span(this.label);

  final String label;

  /// The earliest date this span takes in. Null means no limit.
  DateTime? get from => switch (this) {
    _Span.thisPeriod => null,
    _Span.lastThree => DateTime.now().subtract(const Duration(days: 92)),
    _Span.thisYear => DateTime(DateTime.now().year),
    _Span.everything => null,
  };
}

enum _View { ring, list }

class _ReportScreenState extends State<ReportScreen> {
  _Span _span = _Span.thisPeriod;
  _View _view = _View.ring;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<FarmStore>();

    return FarmScaffold(
      title: l.t('Report'),
      showBack: true,
      body: _span == _Span.thisPeriod
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
                    _Key(colour: T.moneyIn, label: l.t('Money in')),
                    const SizedBox(width: 18),
                    _Key(colour: T.moneyOut, label: l.t('Money out')),
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

class _Key extends StatelessWidget {
  const _Key({required this.colour, required this.label});

  final Color colour;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: colour,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 7),
      Text(label, style: T.meta.copyWith(fontSize: 12.5)),
    ],
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
