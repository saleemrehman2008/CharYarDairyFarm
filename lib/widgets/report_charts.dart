import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../i18n/words.dart';
import '../models/models.dart';
import '../services/accounting.dart';
import '../services/verdict.dart';
import '../services/zones.dart';
import '../theme/tokens.dart';
import '../util/money.dart';
import 'day_chart.dart' show pct;
import 'investment_card.dart' show TotalRow;
import 'ui.dart';

/// The pictures the report draws beside the ring.
///
/// The page used to draw one donut, which says whether the farm made money
/// and nothing else. Everything here answers a question the four of them
/// actually ask: what was the money spent on, where did it come from, how
/// much milk, how does the month compare, where is the capital, and who
/// still owes whom. Each one is read from the ledger it is handed, so none
/// of them can drift from the figures above it.

/// One row of a ranked chart: a name, what it came to, and what is behind it.
class Slice {
  const Slice(this.label, this.amount, {this.count = 0, this.txns = const []});

  final String label;
  final num amount;
  final int count;
  final List<Txn> txns;
}

/// Every heading with something against it, longest bar first.
///
/// This is the answer to the farm's oldest complaint about the report: a
/// running cost of nearly three lakh was one dead figure, and the only way
/// to find out what it was made of was to read forty entries. Now the
/// headings are the chart, and each bar carries its own share of the whole.
class RankedBars extends StatelessWidget {
  const RankedBars({
    super.key,
    required this.title,
    required this.slices,
    required this.total,
    required this.tone,
    this.note,
    this.onTap,
    this.most = 7,
  });

  final String title;
  final List<Slice> slices;
  final num total;
  final Color tone;
  final String? note;
  final void Function(Slice)? onTap;

  /// How many bars before the rest are gathered into one.
  ///
  /// Twelve headings on a phone is a wall. The tail is real money and may
  /// not simply be dropped, so what does not fit is added up into a last
  /// bar that says how many it stands for.
  final int most;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final rows = [...slices.where((s) => s.amount > 0)]
      ..sort((a, b) => b.amount.compareTo(a.amount));
    if (rows.isEmpty) return const SizedBox.shrink();

    final shown = <Slice>[];
    if (rows.length <= most) {
      shown.addAll(rows);
    } else {
      shown.addAll(rows.take(most - 1));
      final rest = rows.skip(most - 1).toList();
      shown.add(
        Slice(
          l.t2('%s others', rest.length),
          rest.fold<num>(0, (a, s) => a + s.amount),
          count: rest.fold<int>(0, (a, s) => a + s.count),
        ),
      );
    }

    final peak = shown.first.amount;

    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Kicker(title)),
              Text(rs(total), style: T.num22.copyWith(color: tone)),
            ],
          ),
          const SizedBox(height: 12),
          for (final s in shown) ...[
            _Bar(
              slice: s,
              peak: peak,
              total: total,
              tone: tone,
              onTap: s.txns.isEmpty || onTap == null ? null : () => onTap!(s),
            ),
            const SizedBox(height: 9),
          ],
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(note!, style: T.meta),
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.slice,
    required this.peak,
    required this.total,
    required this.tone,
    this.onTap,
  });

  final Slice slice;
  final num peak;
  final num total;
  final Color tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final share = total <= 0 ? 0.0 : slice.amount / total;
    final width = peak <= 0 ? 0.0 : (slice.amount / peak).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.t(slice.label),
                  style: T.bodyMid,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                rs(slice.amount),
                style: T.bodyMid.copyWith(
                  fontWeight: FontWeight.w600,
                  color: tone,
                ),
              ),
              const SizedBox(width: 7),
              SizedBox(
                width: 36,
                child: Text(
                  pct(share.toDouble()),
                  textAlign: TextAlign.end,
                  style: T.meta,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // The track is the whole width and the fill is this bar's share
          // of the longest one, so the eye compares bars rather than
          // guessing at a figure.
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 8, color: T.n200),
                FractionallySizedBox(
                  widthFactor: width,
                  child: Container(height: 8, color: tone),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Morning against evening, and what the milk came to.
///
/// A buffalo is milked twice a day, and the two halves are drawn apart on
/// purpose: if one side drifts below the other for a week, something
/// happened at that milking and nobody would see it in one total.
class MilkSplit extends StatelessWidget {
  const MilkSplit({super.key, required this.book});

  final MilkBook book;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (book.isEmpty) return const SizedBox.shrink();

    final said = book.morningLitres + book.eveningLitres;
    final morning = said <= 0 ? 0.5 : book.morningLitres / said;

    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Kicker(l.t('Milk'))),
              Text(
                '${qty(book.soldLitres)} L',
                style: T.num22.copyWith(color: T.moneyIn),
              ),
            ],
          ),
          if (book.soldRate != null) ...[
            const SizedBox(height: 2),
            Text(
              l.t2('at Rs %s a litre on average', qty(book.soldRate!)),
              style: T.meta,
            ),
          ],
          if (said > 0) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: Kicker('${l.t('Morning')}  ${pct(morning)}')),
                Kicker('${pct(1 - morning)}  ${l.t('Evening')}'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  flex: (morning * 1000).round().clamp(1, 999),
                  child: _Half(
                    litres: book.morningLitres,
                    tone: T.moneyGet,
                    start: true,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  flex: ((1 - morning) * 1000).round().clamp(1, 999),
                  child: _Half(
                    litres: book.eveningLitres,
                    tone: T.accent600,
                    start: false,
                  ),
                ),
              ],
            ),
          ],
          if (book.unsaidLitres > 0) ...[
            const SizedBox(height: 10),
            Text(
              l.t2(
                '%s L was entered before the app asked which milking. Those '
                'litres are in the totals above but in neither half.',
                qty(book.unsaidLitres),
              ),
              style: T.meta,
            ),
          ],
        ],
      ),
    );
  }
}

class _Half extends StatelessWidget {
  const _Half({required this.litres, required this.tone, required this.start});

  final num litres;
  final Color tone;
  final bool start;

  @override
  Widget build(BuildContext context) => Container(
    height: 34,
    alignment: start
        ? AlignmentDirectional.centerStart
        : AlignmentDirectional.centerEnd,
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: tone, borderRadius: T.roundSm),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        '${qty(litres)} L',
        style: T.bodyMid.copyWith(
          fontWeight: FontWeight.w600,
          color: T.inkOn(tone),
        ),
      ),
    ),
  );
}

/// What the co-founders put in, against what it has cost to run the place.
///
/// The partners' own question, which no card on the app answered: we put in
/// thirty-five lakh — where is it? Nearly all of it is standing in the shed,
/// and that is why a month can read as a loss while the farm is worth more
/// than it was.
class CapitalVsSpend extends StatelessWidget {
  const CapitalVsSpend({
    super.key,
    required this.putIn,
    required this.assets,
    required this.spent,
  });

  final num putIn;
  final num assets;
  final num spent;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (putIn <= 0) return const SizedBox.shrink();

    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(l.t('Put in by the co-founders')),
          const SizedBox(height: 4),
          Text(rs(putIn), style: T.num26.copyWith(color: T.accent700)),
          const SizedBox(height: 10),
          _Track(
            value: assets,
            of: putIn,
            tone: const Color(0xFF6544B0),
            label: l.t('Cattle & equipment'),
          ),
          const SizedBox(height: 14),
          Kicker(l.t('Spent on running the farm')),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(rs(spent), style: T.num26.copyWith(color: T.moneyOut)),
              const SizedBox(width: 8),
              Text(
                l.t2('%s of it', pct(putIn <= 0 ? 0 : spent / putIn)),
                style: T.meta,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Track(value: spent, of: putIn, tone: T.moneyOut, label: null),
          const SizedBox(height: 10),
          Text(
            l.t(
              'Nearly all of what was put in is standing in the shed rather '
              'than spent. That is why a period can read as a loss while the '
              'farm is worth more than it was.',
            ),
            style: T.meta,
          ),
        ],
      ),
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({
    required this.value,
    required this.of,
    required this.tone,
    required this.label,
  });

  final num value;
  final num of;
  final Color tone;
  final String? label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          children: [
            Container(height: 12, color: T.n200),
            FractionallySizedBox(
              widthFactor: of <= 0 ? 0 : (value / of).clamp(0.0, 1.0),
              child: Container(height: 12, color: tone),
            ),
          ],
        ),
      ),
      if (label != null) ...[
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(child: Text(label!, style: T.meta)),
            Text(
              '${rs(value)}  ${pct(of <= 0 ? 0 : value / of)}',
              style: T.meta.copyWith(color: tone),
            ),
          ],
        ),
      ],
    ],
  );
}

/// Who still owes the farm, and whom the farm still owes.
///
/// Both lists come off the entries themselves, so neither can be out of
/// date — and they sit together because the question is always asked as a
/// pair: what is coming in, and what has to go out of it.
class TwoDebts extends StatelessWidget {
  const TwoDebts({super.key, required this.owedToUs, required this.owedByUs});

  /// Unpaid sales, and unpaid purchases and bills.
  final List<Txn> owedToUs;
  final List<Txn> owedByUs;

  static List<Slice> _byParty(List<Txn> rows) {
    final totals = <String, num>{};
    final counts = <String, int>{};
    for (final t in rows) {
      if (t.isDeleted) continue;
      final who = t.party.trim().isEmpty ? '—' : t.party.trim();
      totals[who] = (totals[who] ?? 0) + t.outstanding;
      counts[who] = (counts[who] ?? 0) + 1;
    }
    return [
      for (final e in totals.entries)
        if (e.value > 0) Slice(e.key, e.value, count: counts[e.key] ?? 0),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final us = _byParty(owedToUs);
    final them = _byParty(owedByUs);
    if (us.isEmpty && them.isEmpty) return const SizedBox.shrink();

    final inTotal = us.fold<num>(0, (a, s) => a + s.amount);
    final outTotal = them.fold<num>(0, (a, s) => a + s.amount);

    return Column(
      children: [
        if (us.isNotEmpty)
          RankedBars(
            title: l.t('Still to collect'),
            slices: us,
            total: inTotal,
            tone: T.moneyGet,
            most: 6,
          ),
        if (us.isNotEmpty && them.isNotEmpty) const SizedBox(height: T.gap),
        if (them.isNotEmpty)
          RankedBars(
            title: l.t('Still to pay'),
            slices: them,
            total: outTotal,
            tone: T.moneyDue,
            most: 6,
            note: l.t2(
              'The farm is owed %s more than it owes.',
              rs(inTotal - outTotal),
            ),
          ),
      ],
    );
  }
}

/// A month's wages, one line a man — the sheet the farm asked to keep.
///
/// Who was on the list that month, what each was due, what actually went
/// out and what is still owed. Built from the ledger every time it is
/// drawn, so a wage corrected afterwards corrects the sheet with it, and
/// nobody is ever reading a frozen copy of a figure that has since moved.
class WagesSheet extends StatelessWidget {
  const WagesSheet({super.key, required this.rows, required this.monthLabel});

  final List<WageLine> rows;
  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (rows.isEmpty) return const SizedBox.shrink();

    final due = rows.fold<num>(0, (a, r) => a + r.monthly);
    final paid = rows.fold<num>(0, (a, r) => a + r.paid);
    final owed = rows.fold<num>(0, (a, r) => a + r.left);

    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Kicker(l.t('Wages'))),
              Tag(monthLabel),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l.t3('%s of wages · %s still to pay', rs(due), rs(owed)),
            style: T.meta,
          ),
          const SizedBox(height: 12),
          for (final r in rows) ...[
            _WageRow(line: r),
            const SizedBox(height: 9),
          ],
          const Divider(height: 10),
          const SizedBox(height: 8),
          TotalRow(label: l.t('The month'), value: due, tone: T.accent700),
          TotalRow(label: l.t('Handed over'), value: paid, tone: T.moneyOut),
          TotalRow(
            label: l.t('Still to pay'),
            value: owed,
            tone: owed > 0 ? T.moneyDue : T.moneyIn,
            strong: true,
          ),
        ],
      ),
    );
  }
}

class _WageRow extends StatelessWidget {
  const _WageRow({required this.line});

  final WageLine line;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final share = line.monthly <= 0
        ? 0.0
        : (line.paid / line.monthly).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                line.who,
                style: T.bodyMid,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              rs(line.monthly),
              style: T.bodyMid.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          // The allowance is named here because a man is told "twenty-four
          // and six for the milk", and the paper should say what he heard.
          line.allowance > 0 && line.allowanceFor.trim().isNotEmpty
              ? l.t4(
                  '%s paid · %s allowance for %s',
                  rs(line.paid),
                  rs(line.allowance),
                  line.allowanceFor.trim(),
                )
              : l.t2('%s paid', rs(line.paid)),
          style: T.meta,
        ),
        if (line.advanceOff > 0)
          Text(
            l.t3(
              '%s of it went to his advance, so %s reached his hand',
              rs(line.advanceOff),
              rs(line.inHand),
            ),
            style: T.meta.copyWith(color: T.moneyDue),
          ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  children: [
                    Container(height: 8, color: T.n200),
                    FractionallySizedBox(
                      widthFactor: share,
                      child: Container(
                        height: 8,
                        color: line.settled ? T.moneyIn : T.moneyDue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 9),
            SizedBox(
              width: 86,
              child: Text(
                line.settled
                    ? l.t('Paid in full')
                    : l.t2('%s left', rs(line.left)),
                textAlign: TextAlign.end,
                style: T.meta.copyWith(
                  color: line.settled ? T.moneyIn : T.moneyDue,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Where the money goes, zone by zone, against the band a dairy runs in.
///
/// The farm's question was not "what did we spend" — the ranked bars above
/// already answer that. It was "which of these are we overspending on", and
/// a list of rupees cannot answer it: five lakh of feed is normal and fifty
/// thousand of repairs is not, and nothing on the page said so.
///
/// So each zone is drawn as a share of what came in, with its usual band
/// marked on the same track. A bar inside the band is a bar nobody needs to
/// look at. A bar past the end of it carries what it is past by, in rupees,
/// because that is the figure worth acting on.
///
/// The bands are a yardstick and the page says so. The farm's own months
/// are the better one once there are a few of them.
class ZoneMeters extends StatelessWidget {
  const ZoneMeters({super.key, required this.zones});

  final SpendZones zones;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (zones.isEmpty) {
      return EmptyNote(l.t('Nothing booked here yet. Tap Add to start.'));
    }

    // One scale for every track, so the bars can be read against each
    // other and not just against their own bands. Wide enough to hold the
    // biggest bar and the widest band, with a little air past it.
    var scale = 0.0;
    for (final line in zones.lines) {
      if (line.share > scale) scale = line.share;
      if ((line.zone.most ?? 0) > scale) scale = line.zone.most!;
    }
    scale = scale <= 0 ? 1 : scale * 1.12;

    final focus = zones.focus;

    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(l.t('Where the money goes')),
          const SizedBox(height: 8),
          Text(
            l.t(
              'Each zone as a share of what came in. The bands are what a '
              'dairy usually runs at — a yardstick, not a rule.',
            ),
            style: T.meta,
          ),
          const SizedBox(height: 12),

          _Fig(label: l.t('Money in'), value: rs(zones.sales), tone: T.moneyIn),
          _Fig(
            label: l.t('Money out'),
            value: rs(zones.spent),
            // Above about four-fifths of what came in and there is nothing
            // left for the four of them to share.
            share: zones.spendShare > 0 ? pct(zones.spendShare) : null,
            tone: zones.spendShare > SpendZones.spendMost ? T.moneyOut : T.text,
          ),
          _Fig(
            label: l.t('Left over'),
            value: rs(zones.profit),
            // A loss has no share of anything. Drawn as a figure alone
            // rather than as a percentage nobody can read.
            share: zones.profitShare > 0 ? pct(zones.profitShare) : null,
            tone: zones.profit < 0
                ? T.moneyOut
                : zones.profitShare >= SpendZones.profitLeast
                ? T.moneyIn
                : T.moneyDue,
            strong: true,
          ),

          const SizedBox(height: 14),
          for (final line in zones.lines) _ZoneMeter(line: line, scale: scale),

          const SizedBox(height: 4),
          if (focus == null)
            _Verdict(
              icon: Icons.check_circle_outline,
              tone: T.moneyIn,
              title: l.t('Every zone is inside its band.'),
            )
          else
            _Verdict(
              icon: Icons.my_location,
              // Loud only when it is a lot of money — see [focusMatters].
              tone: zones.focusMatters ? T.moneyOut : T.moneyDue,
              title: l.t('Look here first'),
              note:
                  '${l.t(focus.zone.label)} — '
                  '${l.t2('Over by %s', rs(focus.over))}',
            ),
        ],
      ),
    );
  }
}

/// One zone's track.
class _ZoneMeter extends StatelessWidget {
  const _ZoneMeter({required this.line, required this.scale});

  final ZoneLine line;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final over = line.over > 0;
    final tone = over ? T.moneyOut : T.accent700;

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.t(line.zone.label),
                  style: T.bodyMid.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(rs(line.spent), style: T.meta),
              const SizedBox(width: 8),
              Text(
                pct(line.share),
                style: T.bodyMid.copyWith(fontSize: 13, color: tone),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // The band is drawn on the track itself rather than beside it,
          // because the only question being asked is whether the bar ends
          // inside it.
          LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              final bar = (line.share / scale).clamp(0.0, 1.0) * w;
              final from = ((line.zone.least ?? 0) / scale).clamp(0.0, 1.0) * w;
              final to = ((line.zone.most ?? 0) / scale).clamp(0.0, 1.0) * w;

              return SizedBox(
                height: 13,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Container(height: 13, width: w, color: T.n200),
                    ),
                    if (line.zone.hasBand)
                      PositionedDirectional(
                        start: from,
                        width: (to - from).clamp(1.0, w),
                        child: Container(
                          height: 13,
                          decoration: BoxDecoration(
                            color: T.moneyIn.withValues(alpha: 0.16),
                            border: Border.symmetric(
                              vertical: BorderSide(
                                color: T.moneyIn.withValues(alpha: 0.55),
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    PositionedDirectional(
                      start: 0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Container(height: 13, width: bar, color: tone),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  line.zone.hasBand
                      ? l.t2(
                          'Usually %s',
                          '${pct(line.zone.least!)}–${pct(line.zone.most!)}',
                        )
                      : l.t('Trading, not a farm cost — no band for it.'),
                  style: T.meta,
                ),
              ),
              if (over)
                Text(
                  l.t2('Over by %s', rs(line.over)),
                  style: T.meta.copyWith(color: T.moneyOut),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What the zones come to, said in one line.
class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.icon,
    required this.tone,
    required this.title,
    this.note,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: tone.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(T.radiusSm),
      border: Border.all(color: tone.withValues(alpha: 0.28)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: tone),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: T.bodyMid.copyWith(color: tone)),
              if (note != null) Text(note!, style: T.meta),
            ],
          ),
        ),
      ],
    ),
  );
}

/// One of the three figures at the head of the zones: what it is, what it
/// came to, and its share of what came in when that means anything.
class _Fig extends StatelessWidget {
  const _Fig({
    required this.label,
    required this.value,
    required this.tone,
    this.share,
    this.strong = false,
  });

  final String label;
  final String value;
  final Color tone;

  /// Null when a share would be a lie — nothing came in, or the month lost
  /// money and the share is below nothing.
  final String? share;

  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label, style: strong ? T.cardTitle : T.body)),
        if (share != null) ...[
          Text(share!, style: T.meta.copyWith(color: tone)),
          const SizedBox(width: 10),
        ],
        Text(
          value,
          style: (strong ? T.num22 : T.bodyMid).copyWith(color: tone),
        ),
      ],
    ),
  );
}

/// One coloured stretch of a dial's arc.
class GaugeBand {
  const GaugeBand(this.upTo, this.colour);

  /// Where this band ends, 0 at the left end of the arc and 1 at the right.
  final double upTo;
  final Color colour;
}

/// A dial: a needle on a coloured arc, with the figure written under it.
///
/// The farm asked for the report to read like the dashboards it sees at
/// work, and it was right to: a share of something is a position on a
/// scale, and a number on its own makes you do that work in your head
/// every time. Red, amber, green and a needle does it for you.
///
/// Drawn rather than animated. A dial that sweeps up from zero looks
/// expensive and is read wrong for the second it is moving, and this page
/// is read in a hurry.
class Gauge extends StatelessWidget {
  const Gauge({
    super.key,
    required this.label,
    required this.value,
    required this.at,
    required this.bands,
    this.least = '',
    this.most = '',
    this.note,
    this.tone,
  });

  /// What the dial is of: "Munafa", "Kul kharch".
  final String label;

  /// The figure in the middle, already written out.
  final String value;

  /// Where the needle stands, 0 at the left end and 1 at the right.
  final double at;

  /// The arc's colours, in order, each saying where it ends.
  final List<GaugeBand> bands;

  /// The two ends of the scale, written small under the arc.
  final String least;
  final String most;

  /// One short line under the figure.
  final String? note;

  /// The colour of the figure itself. Taken from the band the needle is in
  /// when it is not given, which is almost always what is wanted.
  final Color? tone;

  Color get _atTone {
    for (final band in bands) {
      if (at <= band.upTo) return band.colour;
    }
    return bands.isEmpty ? T.n500 : bands.last.colour;
  }

  @override
  Widget build(BuildContext context) {
    final colour = tone ?? _atTone;
    return RegCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(label),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 2.05,
            child: CustomPaint(
              painter: _GaugeFace(at: at.clamp(0.0, 1.0), bands: bands),
              child: const SizedBox.expand(),
            ),
          ),
          Row(
            children: [
              Text(least, style: T.meta.copyWith(fontSize: 9.5)),
              const Spacer(),
              Text(most, style: T.meta.copyWith(fontSize: 9.5)),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(value, style: T.num22.copyWith(color: colour)),
          ),
          if (note != null) ...[
            const SizedBox(height: 2),
            Center(
              child: Text(
                note!,
                style: T.meta.copyWith(fontSize: 10.5),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The arc and the needle.
class _GaugeFace extends CustomPainter {
  _GaugeFace({required this.at, required this.bands});

  final double at;
  final List<GaugeBand> bands;

  /// The arc is the top half of a circle, drawn left to right.
  static const _start = math.pi;
  static const _sweep = math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final thick = size.height * 0.20;
    final r = math.min(size.width / 2, size.height) - thick / 2;
    final centre = Offset(size.width / 2, size.height);
    final box = Rect.fromCircle(center: centre, radius: r);

    // The dial's own ground, so a short band does not leave a gap.
    canvas.drawArc(
      box,
      _start,
      _sweep,
      false,
      Paint()
        ..color = T.n200
        ..strokeWidth = thick
        ..strokeCap = StrokeCap.butt
        ..style = PaintingStyle.stroke,
    );

    var from = 0.0;
    for (final band in bands) {
      final to = band.upTo.clamp(0.0, 1.0);
      if (to <= from) continue;
      canvas.drawArc(
        box,
        _start + _sweep * from,
        _sweep * (to - from),
        false,
        Paint()
          ..color = band.colour
          ..strokeWidth = thick
          ..strokeCap = StrokeCap.butt
          ..style = PaintingStyle.stroke,
      );
      from = to;
    }

    // The needle, from the middle of the foot out to just inside the arc.
    final angle = _start + _sweep * at;
    final tip = Offset(
      centre.dx + math.cos(angle) * (r - thick * 0.75),
      centre.dy + math.sin(angle) * (r - thick * 0.75),
    );
    canvas.drawLine(
      centre,
      tip,
      Paint()
        ..color = T.text
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(centre, 4.2, Paint()..color = T.text);
    canvas.drawCircle(centre, 2.0, Paint()..color = T.surface);
  }

  @override
  bool shouldRepaint(_GaugeFace old) => old.at != at || old.bands != bands;
}

/// The whole stretch on four dials, and what they add up to in words.
///
/// This is the farm's own question, asked in the farm's own words: are we
/// all right at this speed, and which zone is losing money. Four figures
/// answer it between them — what was made, what it cost to run, what the
/// feed took, and whether that is better or worse than last time — and
/// each is a share, which is a position on a scale and not a number to
/// hold in your head.
///
/// Underneath, the same findings written out, worst first. Nothing here is
/// guessed: every line is arithmetic on the entries, and the card says so,
/// because a verdict four partners cannot check is worth nothing to them.
class HealthCard extends StatelessWidget {
  const HealthCard({super.key, required this.read, required this.spanLabel});

  final MonthRead read;

  /// What stretch this is of — "November 2026", "Last 3 months".
  final String spanLabel;

  static Color _tone(Tone t) => switch (t) {
    Tone.good => T.moneyIn,
    Tone.watch => T.moneyDue,
    Tone.bad => T.moneyOut,
  };

  static IconData _icon(Tone t) => switch (t) {
    Tone.good => Icons.check_circle_outline,
    Tone.watch => Icons.error_outline,
    Tone.bad => Icons.priority_high,
  };

  /// A share drawn onto a dial that runs from [from] to [to].
  static double _at(double share, double from, double to) =>
      ((share - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (read.isEmpty) {
      return RegCard(
        child: EmptyNote(l.t('Nothing booked here yet. Tap Add to start.')),
      );
    }

    final z = read.zones;
    final feed = z.lines.where((x) => x.zone == Zone.feed).firstOrNull;

    // Every dial runs left to right from worst to best or best to worst,
    // whichever way the figure itself runs. The bands are the same ones
    // the zones card uses, so two cards cannot disagree about what is good.
    final dials = <Widget>[
      // What was made, as a share of what came in. A loss parks the needle
      // at the far left and says so in the figure.
      Gauge(
        label: l.t('Profit'),
        value: z.sales > 0 ? pct(z.profitShare) : rs(z.profit),
        at: _at(z.profitShare, 0, 0.30),
        least: '0%',
        most: '30%',
        note: rs(z.profit),
        tone: z.profit < 0 ? T.moneyOut : null,
        bands: [
          GaugeBand(_at(SpendZones.profitLeast, 0, 0.30), T.moneyOut),
          GaugeBand(_at(SpendZones.profitGood, 0, 0.30), T.moneyDue),
          GaugeBand(1, T.moneyIn),
        ],
      ),

      // What it cost to run. This one runs the other way: low is good.
      Gauge(
        label: l.t('Running cost'),
        value: z.sales > 0 ? pct(z.spendShare) : rs(z.spent),
        at: _at(z.spendShare, 0.50, 1.00),
        least: '50%',
        most: '100%',
        note: rs(z.spent),
        bands: [
          GaugeBand(_at(0.70, 0.50, 1.00), T.moneyIn),
          GaugeBand(_at(SpendZones.spendMost, 0.50, 1.00), T.moneyDue),
          GaugeBand(1, T.moneyOut),
        ],
      ),

      // The feed, because it is the one that decides the year.
      Gauge(
        label: l.t('Fodder / feed'),
        value: feed == null ? rs(0) : pct(feed.share),
        at: _at(feed?.share ?? 0, 0.30, 0.90),
        least: '30%',
        most: '90%',
        note: rs(feed?.spent ?? 0),
        bands: [
          GaugeBand(_at(Zone.feed.most!, 0.30, 0.90), T.moneyIn),
          GaugeBand(_at(0.75, 0.30, 0.90), T.moneyDue),
          GaugeBand(1, T.moneyOut),
        ],
      ),

      // And the speed: this stretch against the one before it.
      Gauge(
        label: l.t('Pace'),
        value: read.hasBefore
            ? '${read.pace >= 0 ? '+' : '−'}${pct(read.pace.abs())}'
            : '—',
        at: read.hasBefore ? _at(read.pace, -0.50, 0.50) : 0.5,
        least: '−50%',
        most: '+50%',
        note: read.hasBefore
            ? l.t('vs the stretch before')
            : l.t('Nothing before this to compare with'),
        tone: read.hasBefore ? null : T.n500,
        bands: read.hasBefore
            ? [
                GaugeBand(_at(-0.10, -0.50, 0.50), T.moneyOut),
                GaugeBand(_at(0.10, -0.50, 0.50), T.moneyDue),
                GaugeBand(1, T.moneyIn),
              ]
            : const [GaugeBand(1, Color(0x00000000))],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l.t('How the farm is doing')),
        Text(spanLabel, style: T.meta),
        // What every share below is a share of. The dials read 23% and
        // 77% and 47% and the page never said of what — and a figure
        // nobody can work back to is a figure nobody trusts.
        if (z.sales > 0)
          Text(
            l.t2('%s came in. Every share below is of that.', rs(z.sales)),
            style: T.meta.copyWith(color: T.accent700),
          ),
        const SizedBox(height: 10),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: dials[0]),
            const SizedBox(width: 10),
            Expanded(child: dials[1]),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: dials[2]),
            const SizedBox(width: 10),
            Expanded(child: dials[3]),
          ],
        ),

        // What is outside the farm. A stretch can look fine on four dials
        // and have four lakh sitting in other people's pockets.
        const SizedBox(height: 10),
        RegCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: _Side(
                  label: l.t('To receive'),
                  value: rs(read.toCome),
                  tone: T.moneyGet,
                ),
              ),
              Container(width: 1, height: 30, color: T.n200),
              Expanded(
                child: _Side(
                  label: l.t('To pay'),
                  value: rs(read.toPay),
                  tone: T.moneyDue,
                  end: true,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),
        for (final f in read.findings) ...[
          _Said(finding: f),
          const SizedBox(height: 7),
        ],

        Text(
          l.t(
            'Read off your own entries, not guessed. Every line here can '
            'be checked against the ledger.',
          ),
          style: T.meta,
        ),
      ],
    );
  }
}

/// One half of the two-figure strip under the dials.
class _Side extends StatelessWidget {
  const _Side({
    required this.label,
    required this.value,
    required this.tone,
    this.end = false,
  });

  final String label;
  final String value;
  final Color tone;
  final bool end;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: T.kicker),
      const SizedBox(height: 3),
      Text(value, style: T.num22.copyWith(fontSize: 19, color: tone)),
    ],
  );
}

/// One finding, written out.
class _Said extends StatelessWidget {
  const _Said({required this.finding});

  final Finding finding;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tone = HealthCard._tone(finding.tone);
    final said = switch (finding.note) {
      Note.losing => l.t2(
        'This stretch lost %s — more went out than came in.',
        rs(finding.amount),
      ),
      Note.thin => l.t3(
        'It earned %s, which is %s of everything that came in. Under a '
        'sixth is a stretch that ran rather than one that earned.',
        rs(finding.amount),
        pct(finding.share),
      ),
      Note.healthy => l.t3(
        'It earned %s — %s of everything that came in. That is a stretch '
        'that earned.',
        rs(finding.amount),
        pct(finding.share),
      ),
      Note.spendHigh => l.t2(
        'Running cost ate %s of what came in. Past four fifths there is '
        'nothing left to share.',
        pct(finding.share),
      ),
      Note.zoneOver => l.t3(
        '%s is %s past the share a dairy usually keeps it inside. That is '
        'the money to go after.',
        l.t(finding.zone?.label ?? ''),
        rs(finding.amount),
      ),
      Note.faster => l.t2(
        '%s better than the stretch before it.',
        rs(finding.amount),
      ),
      Note.slower => l.t2(
        '%s worse than the stretch before it.',
        rs(finding.amount),
      ),
      Note.steady => l.t('Much the same as the stretch before it.'),
      Note.toCome => l.t2('%s is still to come in.', rs(finding.amount)),
      Note.toPay => l.t2('%s is still to go out.', rs(finding.amount)),
      Note.owingMore => l.t2(
        '%s is still to go out — more than is coming in.',
        rs(finding.amount),
      ),
    };

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(T.radiusSm),
        border: Border.all(color: tone.withValues(alpha: 0.26)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(HealthCard._icon(finding.tone), size: 16, color: tone),
          const SizedBox(width: 8),
          Expanded(child: Text(said, style: T.body.copyWith(fontSize: 13))),
        ],
      ),
    );
  }
}
