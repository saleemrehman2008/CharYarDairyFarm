import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/accounting.dart';
import '../../services/month_repo.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';

/// Master only. Works out each partner's share and posts it.
class CloseMonthScreen extends StatefulWidget {
  const CloseMonthScreen({super.key});

  @override
  State<CloseMonthScreen> createState() => _CloseMonthScreenState();
}

class _CloseMonthScreenState extends State<CloseMonthScreen> {
  bool _arIncluded = true;
  bool _busy = false;

  /// partnerId -> 'withdraw' | 'reinvest'
  final Map<String, String> _choices = {};

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final books = store.books;
    final partners = store.partners;
    final ratios = store.ratios;
    final profitToShare = books.profitToShare(arIncluded: _arIncluded);

    return FarmScaffold(
      title: 'Close ${monthName(store.month.id)}',
      showBack: true,
      body: PageBody(
        children: [
          RegCard(
            child: Column(
              children: [
                _Line(label: 'Sales', value: rs(books.sales)),
                _Line(label: '− Running costs', value: rs(books.costs)),
                _Line(
                  label: _arIncluded ? '+ Receivables kept' : '− Receivables',
                  value: rs(books.receivable),
                ),
                if (books.assetsBought > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${rs(books.assetsBought)} of cattle & equipment was '
                      'bought this month. It is not a cost — the farm owns it '
                      '— so it is not taken off the profit.',
                      style: T.meta,
                    ),
                  ),
                const Divider(height: 18),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Kicker('Profit to share'),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(rs(profitToShare), style: T.num26),
                ),
              ],
            ),
          ),
          const SizedBox(height: T.pad),

          RegCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker('Uncollected receivables · ${rs(books.receivable)}'),
                const SizedBox(height: 8),
                _Radio(
                  label: 'Count as this month\'s income (share on paper)',
                  selected: _arIncluded,
                  onTap: () => setState(() => _arIncluded = true),
                ),
                _Radio(
                  label: 'Roll into next month (share cash only)',
                  selected: !_arIncluded,
                  onTap: () => setState(() => _arIncluded = false),
                ),
              ],
            ),
          ),
          const SizedBox(height: T.pad),

          const SectionTitle('Each co-founder\'s share'),
          for (final p in partners)
            _ShareRow(
              name: p.name,
              ratio: ratios[p.id] ?? 0,
              share: ((ratios[p.id] ?? 0) * profitToShare).round(),
              choice: _choices[p.id] ?? 'withdraw',
              onChoice: (v) => setState(() => _choices[p.id] = v),
            ),

          const SizedBox(height: 22),
          PrimaryButton(
            label: 'Close month & post shares',
            busy: _busy,
            onPressed: partners.isEmpty || profitToShare <= 0 ? null : _close,
          ),
          if (profitToShare <= 0) ...[
            const SizedBox(height: 10),
            Text(
              profitToShare == 0
                  ? 'There is nothing to share this month, so there is nothing '
                        'to post. Close it once the month has made a profit.'
                  : 'This month is at a loss of ${rs(profitToShare.abs())}, so '
                        'there is nothing to share out. Check that every sale '
                        'is entered — a big one-off buy like cattle will show '
                        'as a loss in the month you pay for it.',
              style: T.meta.copyWith(color: const Color(0xFF8C2F20)),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Shares are posted to each co-founder, the month is written to the '
            'Sheet and the activity log, every co-founder is notified, and '
            '${monthShort(nextMonthId(store.month.id))} opens. Unpaid entries '
            'carry forward.',
            style: T.meta,
          ),
        ],
      ),
    );
  }

  Future<void> _close() async {
    final store = context.read<FarmStore>();
    final books = store.books;
    final profitToShare = books.profitToShare(arIncluded: _arIncluded);
    final shares = shareOut(
      partners: store.partners,
      profitToShare: profitToShare,
      choices: _choices,
    );
    final withdrawing = shares.where((s) => !s.isReinvested).length;

    final ok = await confirm(
      context,
      title: 'Close ${monthName(store.month.id)}?',
      body:
          '${rs(profitToShare)} is shared between ${shares.length} co-founders.'
          '\n$withdrawing withdrawing, ${shares.length - withdrawing} '
          'reinvesting.\n\nThis cannot be undone from the app.',
      confirmLabel: 'Close month',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await MonthRepo.close(
        actor: context.read<Session>().actor,
        month: store.month,
        books: books,
        partners: store.partners,
        arIncluded: _arIncluded,
        choices: _choices,
        unpaidTxns: store.unpaidTxns,
      );
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, 'Month closed · ${rs(profitToShare)} shared');
    } catch (e) {
      if (mounted) toast(context, 'Could not close the month. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label, style: T.body)),
        Text(value, style: T.bodyMid),
      ],
    ),
  );
}

class _Radio extends StatelessWidget {
  const _Radio({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 18,
            color: selected ? T.accent : T.n500,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: T.body)),
        ],
      ),
    ),
  );
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.name,
    required this.ratio,
    required this.share,
    required this.choice,
    required this.onChoice,
  });

  final String name;
  final double ratio;
  final num share;
  final String choice;
  final ValueChanged<String> onChoice;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: T.gap),
    child: RegCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: T.cardTitle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Tag('${(ratio * 100).toStringAsFixed(0)}%', tone: TagTone.accent),
              const SizedBox(width: 8),
              Text(rs(share), style: T.num22),
            ],
          ),
          const SizedBox(height: 10),
          Segmented<String>(
            value: choice,
            compact: true,
            options: const [
              ('withdraw', 'Withdraw'),
              ('reinvest', 'Add to investment'),
            ],
            onChanged: onChoice,
          ),
        ],
      ),
    ),
  );
}
