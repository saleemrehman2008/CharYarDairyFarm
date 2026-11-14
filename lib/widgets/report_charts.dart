import 'package:flutter/material.dart';

import '../i18n/words.dart';
import '../models/models.dart';
import '../services/accounting.dart';
import '../theme/tokens.dart';
import '../util/money.dart';
import 'day_chart.dart' show pct;
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
