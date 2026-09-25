import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/accounting.dart';
import '../../services/month_repo.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';

/// Master only. Settling up at the end of a stretch of trading, in two steps.
///
/// Step one works out the profit and freezes it. Step two waits for every
/// co-founder to say how much of their share they are taking out, then posts
/// the lot. The two are separate because the money is theirs to decide about,
/// and because their answers can take days — during which the farm keeps
/// selling milk, and none of that milk may change the figures they were sent.
class CloseMonthScreen extends StatelessWidget {
  const CloseMonthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final sealed = store.sealedPeriod;
    return sealed == null ? const _SealStep() : _HandOutStep(period: sealed);
  }
}

// ---------------------------------------------------------------- step one

class _SealStep extends StatefulWidget {
  const _SealStep();

  @override
  State<_SealStep> createState() => _SealStepState();
}

class _SealStepState extends State<_SealStep> {
  bool _arIncluded = true;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final l = L.of(context);
    final books = store.books;
    final partners = store.partners;
    final ratios = store.ratios;
    final profitToShare = books.profitToShare(
      arIncluded: _arIncluded,
      carriedReceivable: store.carriedReceivable,
    );
    final today = DateTime.now();
    final midMonth = !isLastDayOfMonth(today);

    return FarmScaffold(
      title: l.t2('Settle %s', periodLabel(store.month)),
      showBack: true,
      body: PageBody(
        children: [
          RegCard(
            child: Column(
              children: [
                _Line(
                  label: l.t('Sales'),
                  value: rs(books.sales),
                  tone: T.moneyIn,
                ),
                _Line(
                  label: '− ${l.t('Running costs')}',
                  value: rs(books.costs),
                  tone: T.moneyOut,
                ),
                _Line(
                  label: _arIncluded
                      ? '+ ${l.t('Receivables kept')}'
                      : '− ${l.t('Receivables')}',
                  value: rs(books.receivable),
                  tone: T.moneyGet,
                ),
                if (books.assetsBought > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      l.t2(
                        '%s of cattle & equipment was bought. It is not a cost '
                        '— the farm owns it — so it is not taken off the '
                        'profit.',
                        rs(books.assetsBought),
                      ),
                      style: T.meta,
                    ),
                  ),
                const Divider(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Kicker(l.t('Profit to share')),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    rs(profitToShare),
                    style: T.num26.copyWith(
                      color: profitToShare < 0 ? T.moneyOut : T.moneyIn,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: T.pad),

          RegCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(
                  '${l.t('Uncollected receivables')} · ${rs(books.receivable)}',
                ),
                const SizedBox(height: 8),
                _Radio(
                  label: l.t("Count as this period's income (share on paper)"),
                  selected: _arIncluded,
                  onTap: () => setState(() => _arIncluded = true),
                ),
                _Radio(
                  label: l.t('Roll into the next period (share cash only)'),
                  selected: !_arIncluded,
                  onTap: () => setState(() => _arIncluded = false),
                ),
                if (!_arIncluded && store.carriedReceivable > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      l.t2(
                        '%s rolled from last time is back in this figure — it '
                        'was held back then, so it is shared now.',
                        rs(store.carriedReceivable),
                      ),
                      style: T.meta,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: T.pad),

          SectionTitle(l.t("Each co-founder's share")),
          const SizedBox(height: 8),
          for (final p in partners)
            Padding(
              padding: const EdgeInsets.only(bottom: T.gap),
              child: RegCard(
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.name,
                        style: T.cardTitle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Tag(
                      '${((ratios[p.id] ?? 0) * 100).toStringAsFixed(0)}%',
                      tone: TagTone.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      rs(
                        profitToShare > 0
                            ? ((ratios[p.id] ?? 0) * profitToShare).round()
                            : 0,
                      ),
                      style: T.num22,
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 10),
          if (midMonth)
            RegCard(
              wash: T.moneyDueWash,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.t('Settling before the month ends'),
                    style: T.cardTitle.copyWith(color: T.moneyDue),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.t(
                      'You can settle up on any day you like — the period '
                      'simply ends here and the next one starts. Khaata is '
                      'not touched: customers are still billed at the end of '
                      'their own month, and nobody gets an extra bill because '
                      'of this.',
                    ),
                    style: T.body,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.t(
                      'Khaata milk counts as income the day the customer pays '
                      'for it, so this period holds what has been collected. '
                      'The rest arrives in the period it is collected in. '
                      'Nothing is lost; it moves along.',
                    ),
                    style: T.meta,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),

          PrimaryButton(
            label: profitToShare > 0
                ? l.t('Freeze the figures')
                : l.t('End this period'),
            icon: profitToShare > 0 ? Icons.send_outlined : Icons.lock_outline,
            busy: _busy,
            onPressed: partners.isEmpty ? null : _seal,
          ),
          const SizedBox(height: 10),
          Text(
            l.t(
              'The figures freeze here. Everything sold or spent after this '
              'belongs to the next period, whatever the date says. Nothing is '
              'handed out yet — that is the next step, where you say how much '
              'of it goes out and how much stays in the farm.',
            ),
            style: T.meta,
          ),
          if (profitToShare <= 0) ...[
            const SizedBox(height: 10),
            Text(
              profitToShare == 0
                  ? l.t(
                      'Nothing to share this time. The period still ends here '
                      'and the next one opens.',
                    )
                  : l.t2(
                      'This period is %s down, so there is nothing to share '
                      'out — and nothing comes off anybody\'s capital either. '
                      'The shortfall is already in the cash the next period '
                      'starts with.\n\nBefore you end it, check every sale is '
                      'entered. A big one-off buy like cattle shows as a loss '
                      'in the period you pay for it, even though the farm '
                      'still has the animal.',
                      rs(profitToShare.abs()),
                    ),
              style: T.meta.copyWith(color: T.moneyDue),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _seal() async {
    final store = context.read<FarmStore>();
    final l = L.read(context);
    final books = store.books;
    final profitToShare = books.profitToShare(
      arIncluded: _arIncluded,
      carriedReceivable: store.carriedReceivable,
    );

    final ok = await confirm(
      context,
      title: l.t2('Freeze %s?', periodLabel(store.month)),
      body: profitToShare > 0
          ? l.t3(
              '%s is cut into %s shares and held there.\n\nFrom this moment '
              'the figures cannot change, and every new entry — even one '
              'dated today — belongs to the next period. Nothing is paid out '
              'until you close it.',
              rs(profitToShare),
              store.partners.length,
            )
          : l.t(
              'There is nothing to share this time.\n\nFrom this moment the '
              'figures cannot change, and every new entry — even one dated '
              'today — belongs to the next period.',
            ),
      confirmLabel: profitToShare > 0 ? l.t('Send') : l.t('End it'),
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await MonthRepo.seal(
        actor: context.read<Session>().actor,
        period: store.month,
        books: books,
        partners: store.partners,
        arIncluded: _arIncluded,
        carriedReceivable: store.carriedReceivable,
      );
      if (!mounted) return;
      toast(context, l.t('Sent. Waiting on the co-founders.'));
    } catch (e) {
      if (mounted) toast(context, l.t2('Could not send it. %s', e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ---------------------------------------------------------------- step two

/// How much of it goes out, and how much stays in the farm.
///
/// Version 1 asked each co-founder what they wanted doing with their share
/// and would not close until all four had answered. That is a fine rule and a
/// hard one to live under when the answer is the same every month for a year:
/// the four of them have agreed to keep the lot in and buy more buffaloes
/// with it, and the close sat there waiting for four taps that never came.
///
/// So the master sets one percentage for all of them. That is not a shortcut
/// either — it is what keeps the share ratio honest. Everybody holds back the
/// same proportion, so nobody ends up with more of their own money working in
/// the farm than their slice of it reflects.
class _HandOutStep extends StatefulWidget {
  const _HandOutStep({required this.period});

  final FarmMonth period;

  @override
  State<_HandOutStep> createState() => _HandOutStepState();
}

class _HandOutStepState extends State<_HandOutStep> {
  /// Nothing out, to begin with. It is what they have agreed for the first
  /// year, and it is the answer that cannot cost anybody anything by being
  /// the one already filled in.
  int _percent = 0;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<FarmStore>();
    final p = store.sealedPeriod ?? widget.period;
    final handed = handOut(p.shares, _percent);
    final out = handed.fold<num>(0, (a, s) => a + s.taken);
    final held = handed.fold<num>(0, (a, s) => a + s.held);

    return FarmScaffold(
      title: l.t2('%s — settling up', periodLabel(p)),
      showBack: true,
      body: PageBody(
        children: [
          HeroCard(
            label: p.isLoss ? l.t('Lost this period') : l.t('Profit to share'),
            value: rs((p.profitShared ?? 0).abs()),
            gradient: T.washOf(p.isLoss ? T.moneyOut : T.moneyIn),
            note: p.sealedAt == null
                ? null
                : l.t2('Frozen %s. It will not change.', fmtStamp(p.sealedAt!)),
            trailing: Tag(
              p.isLoss ? l.t('A loss') : l.t('Frozen'),
              tone: p.isLoss ? TagTone.warn : TagTone.good,
            ),
          ),
          const SizedBox(height: 20),

          if (p.isLoss)
            RegCard(
              wash: T.moneyDueWash,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.t('Nothing to hand out'),
                    style: T.cardTitle.copyWith(color: T.moneyDue),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.t(
                      'This period lost money, so there is nothing going out. '
                      'The loss is split the same way a profit would be and '
                      'comes off what each of them has kept in the farm — a '
                      'bad month belongs to all four, the same as a good one.',
                    ),
                    style: T.body,
                  ),
                ],
              ),
            )
          else ...[
            SectionTitle(l.t('How much goes out?')),
            const SizedBox(height: 4),
            Text(
              l.t(
                'The same for all four. Whatever is left stays in the farm, '
                'in each of their names — it buys the next buffalo, and it is '
                'still theirs.',
              ),
              style: T.meta,
            ),
            const SizedBox(height: 10),
            _PercentPicker(
              value: _percent,
              onPick: (v) => setState(() => _percent = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: l.t('Going out'),
                    value: rs(out),
                    tone: T.moneyOut,
                  ),
                ),
                const SizedBox(width: T.gap),
                Expanded(
                  child: StatTile(
                    label: l.t('Staying in the farm'),
                    value: rs(held),
                    tone: T.moneyIn,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),

          SectionTitle(l.t('What each of them gets')),
          const SizedBox(height: 8),
          for (final share in handed) _ShareRow(share: share),

          const SizedBox(height: 14),
          PrimaryButton(
            label: l.t('Close the period'),
            icon: Icons.lock_outline,
            busy: _busy,
            onPressed: _busy ? null : () => _close(p, handed),
          ),
          const SizedBox(height: 10),
          Text(
            p.isLoss
                ? l.t(
                    'The loss is posted to all four accounts and the period '
                    'is filed. This cannot be undone.',
                  )
                : l.t(
                    'What goes out is entered as a payment, what stays in '
                    'goes to each of their profit accounts, and the other '
                    'three are shown the figures. This cannot be undone.',
                  ),
            style: T.meta,
          ),
          const SizedBox(height: 20),

          GhostButton(
            label: l.t('Reopen this period'),
            icon: Icons.undo,
            danger: true,
            onPressed: _busy ? null : () => _unseal(p),
          ),
          const SizedBox(height: 8),
          Text(
            l.t(
              'Puts the figures back to being worked out. Only for a period '
              'sealed by mistake — nothing has been paid yet at this stage.',
            ),
            style: T.meta,
          ),
        ],
      ),
    );
  }

  Future<void> _close(FarmMonth p, List<MonthShare> handed) async {
    final l = L.read(context);
    final out = handed.fold<num>(0, (a, s) => a + s.taken);
    final held = handed.fold<num>(0, (a, s) => a + s.held);
    final ok = await confirm(
      context,
      title: l.t2('Close %s?', periodLabel(p)),
      body: p.isLoss
          ? l.t2(
              'The loss of %s goes onto all four accounts, split the way a '
              'profit would be.\n\nThis cannot be undone from the app.',
              rs(held.abs()),
            )
          : l.t3(
              '%s goes out to the co-founders and %s stays in the farm in '
              'their names.\n\nThis cannot be undone from the app.',
              rs(out),
              rs(held),
            ),
      confirmLabel: l.t('Close the period'),
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await MonthRepo.close(
        actor: context.read<Session>().actor,
        period: p,
        percent: _percent,
        loans: context.read<FarmStore>().loans,
      );
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, l.t2('%s closed.', periodLabel(p)));
    } catch (e) {
      if (mounted) toast(context, l.t2('Could not close it. %s', e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unseal(FarmMonth p) async {
    final l = L.read(context);
    final ok = await confirm(
      context,
      title: l.t('Reopen it?'),
      body: l.t(
        'The figures go back to being worked out. Nothing has been paid yet, '
        'so nothing is taken back.',
      ),
      confirmLabel: l.t('Reopen it'),
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await MonthRepo.unseal(actor: context.read<Session>().actor, period: p);
      if (!mounted) return;
      toast(context, l.t2('%s is open again.', periodLabel(p)));
    } catch (e) {
      if (mounted) toast(context, l.t2('Could not reopen it. %s', e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// The one figure the master sets, in the steps anybody actually asks for.
///
/// Typed as well as tapped, because 35% is a perfectly reasonable answer and
/// a row of round buttons that cannot say it is a row of round buttons that
/// gets worked around.
class _PercentPicker extends StatelessWidget {
  const _PercentPicker({required this.value, required this.onPick});

  final int value;
  final ValueChanged<int> onPick;

  static const _steps = [0, 25, 50, 75, 100];

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final step in _steps)
              ChoiceChip(
                label: Text(step == 0 ? l.t('Nothing out') : '$step%'),
                selected: value == step,
                showCheckmark: false,
                labelStyle: T.bodyMid.copyWith(
                  color: value == step ? Colors.white : T.n700,
                ),
                selectedColor: T.accent,
                backgroundColor: Colors.white,
                side: BorderSide(color: value == step ? T.accent : T.n300),
                onSelected: (_) => onPick(step),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Slider(
          value: value.toDouble(),
          max: 100,
          divisions: 20,
          label: '$value%',
          activeColor: T.accent,
          onChanged: (v) => onPick(v.round()),
        ),
      ],
    );
  }
}

/// One co-founder's line: their slice, what they are handed, what stays in.
class _ShareRow extends StatelessWidget {
  const _ShareRow({required this.share});

  final MonthShare share;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: T.gap),
      child: RegCard(
        stripe: share.isLoss ? T.moneyOut : T.moneyIn,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    share.name,
                    style: T.cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Tag('${(share.ratio * 100).toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: 8),
            _Line(
              label: share.isLoss
                  ? l.t('Their share of the loss')
                  : l.t('Share'),
              value: rs(share.share.abs()),
              tone: share.isLoss ? T.moneyOut : T.moneyIn,
            ),
            if (!share.isLoss) ...[
              _Line(
                label: l.t('Taking out'),
                value: rs(share.taken),
                tone: T.moneyOut,
              ),
              _Line(
                label: l.t('Staying in the farm'),
                value: rs(share.held),
                tone: T.moneyIn,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, required this.tone});

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label, style: T.body)),
        Text(value, style: T.bodyMid.copyWith(color: tone)),
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
