import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/month_repo.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';
import '../shared/share_decision_screen.dart';

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
    return sealed == null
        ? const _SealStep()
        : _DecisionsStep(period: sealed);
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
    final profitToShare = books.profitToShare(arIncluded: _arIncluded);
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
                      rs(((ratios[p.id] ?? 0) * profitToShare).round()),
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
                    l.t('Settling in the middle of the month'),
                    style: T.cardTitle.copyWith(color: T.moneyDue),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.t(
                      'Khaata carries on exactly as it is — customers are '
                      'billed at the end of their month, not now, and nobody '
                      'gets an extra bill because of this.',
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
            label: l.t('Send to co-founders'),
            icon: Icons.send_outlined,
            busy: _busy,
            onPressed: partners.isEmpty || profitToShare <= 0 ? null : _seal,
          ),
          const SizedBox(height: 10),
          Text(
            l.t(
              'The figures freeze the moment you send it. Everything sold or '
              'spent after this belongs to the next period, whatever the date '
              'says — so a co-founder answering in two days sees exactly what '
              'you are looking at now.',
            ),
            style: T.meta,
          ),
          if (profitToShare <= 0) ...[
            const SizedBox(height: 10),
            Text(
              profitToShare == 0
                  ? l.t('There is nothing to share, so there is nothing to '
                        'send. Settle once the period has made a profit.')
                  : l.t2(
                      'This period is at a loss of %s, so there is nothing to '
                      'share out. Check that every sale is entered — a big '
                      'one-off buy like cattle will show as a loss in the '
                      'period you pay for it.',
                      rs(profitToShare.abs()),
                    ),
              style: T.meta.copyWith(color: T.alert),
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
    final profitToShare = books.profitToShare(arIncluded: _arIncluded);

    final ok = await confirm(
      context,
      title: l.t2('Freeze %s?', periodLabel(store.month)),
      body: l.t3(
        '%s goes out to %s co-founders to decide on.\n\nFrom this moment the '
        "period's figures cannot change, and every new entry — even one dated "
        'today — belongs to the next period.',
        rs(profitToShare),
        store.partners.length,
      ),
      confirmLabel: l.t('Send'),
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

class _DecisionsStep extends StatefulWidget {
  const _DecisionsStep({required this.period});

  final FarmMonth period;

  @override
  State<_DecisionsStep> createState() => _DecisionsStepState();
}

class _DecisionsStepState extends State<_DecisionsStep> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<FarmStore>();
    final p = store.sealedPeriod ?? widget.period;
    final waiting = p.undecided.length;

    return FarmScaffold(
      title: l.t2('%s — decisions', periodLabel(p)),
      showBack: true,
      body: PageBody(
        children: [
          HeroCard(
            label: l.t('Profit to share'),
            value: rs(p.profitShared ?? 0),
            note: p.sealedAt == null
                ? null
                : l.t2('Frozen %s. It will not change.', fmtStamp(p.sealedAt!)),
            trailing: Tag(
              waiting == 0
                  ? l.t('All in')
                  : l.t2('%s waiting', waiting),
              tone: waiting == 0 ? TagTone.good : TagTone.warn,
            ),
          ),
          const SizedBox(height: T.gap),

          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: l.t('Taking out'),
                  value: rs(p.totalWithdraw),
                  tone: T.moneyOut,
                ),
              ),
              const SizedBox(width: T.gap),
              Expanded(
                child: StatTile(
                  label: l.t('Back into the farm'),
                  value: rs(p.totalReinvest),
                  tone: T.moneyIn,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          SectionTitle(l.t('What each of them wants')),
          const SizedBox(height: 8),
          for (final share in p.shares)
            _ShareRow(
              period: p,
              share: share,
              onEnter: () => _open(context, store, p, share),
            ),

          const SizedBox(height: 14),
          PrimaryButton(
            label: l.t('Approve all & close the period'),
            icon: Icons.lock_outline,
            busy: _busy,
            onPressed: p.allDecided ? () => _close(p) : null,
          ),
          const SizedBox(height: 10),
          Text(
            p.allDecided
                ? l.t(
                    'Every share is posted, the withdrawals are entered as '
                    'payments, and the investments go up. This cannot be '
                    'undone.',
                  )
                : l.t2(
                    'Waiting on %s. The decision is theirs — ring them, and if '
                    'they tell you what they want, enter it on their row. It '
                    'will be recorded as confirmed by phone.',
                    p.undecided.map((s) => s.name).join(', '),
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
              'Puts the figures back to being worked out, and clears every '
              'decision. Only for a period sealed by mistake — nothing has '
              'been paid yet at this stage.',
            ),
            style: T.meta,
          ),
        ],
      ),
    );
  }

  void _open(
    BuildContext context,
    FarmStore store,
    FarmMonth period,
    MonthShare share,
  ) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: store,
        child: ShareDecisionScreen(
          periodId: period.id,
          partnerId: share.partnerId,
          onBehalf: true,
        ),
      ),
    ),
  );

  Future<void> _close(FarmMonth p) async {
    final l = L.read(context);
    final ok = await confirm(
      context,
      title: l.t2('Close %s?', periodLabel(p)),
      body: l.t3(
        '%s goes out to the co-founders and %s stays in the farm as '
        'investment.\n\nThis cannot be undone from the app.',
        rs(p.totalWithdraw),
        rs(p.totalReinvest),
      ),
      confirmLabel: l.t('Close the period'),
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await MonthRepo.close(
        actor: context.read<Session>().actor,
        period: p,
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
        'The figures go back to being worked out and every decision so far is '
        'cleared. The co-founders will have to choose again.',
      ),
      confirmLabel: l.t('Reopen'),
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await MonthRepo.unseal(
        actor: context.read<Session>().actor,
        period: p,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, l.t2('Could not reopen it. %s', e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.period,
    required this.share,
    required this.onEnter,
  });

  final FarmMonth period;
  final MonthShare share;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: T.gap),
      child: RegCard(
        stripe: share.decided ? T.moneyIn : T.moneyDue,
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    share.name,
                    style: T.cardTitle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Tag(
                  share.decided ? l.t('Decided') : l.t('Waiting'),
                  tone: share.decided ? TagTone.good : TagTone.warn,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(l.t('Share'), style: T.body)),
                Text(rs(share.share), style: T.bodyMid),
              ],
            ),
            if (share.decided) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: Text(l.t('Taking out'), style: T.body)),
                  Money(share.withdraw, incoming: false, settled: true),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(l.t('Into investment'), style: T.body),
                  ),
                  Money(share.reinvest, incoming: true, settled: true),
                ],
              ),
              if (share.byPhone) ...[
                const SizedBox(height: 6),
                Text(
                  l.t('Confirmed by phone and entered by the master.'),
                  style: T.meta.copyWith(color: T.moneyDue),
                ),
              ],
            ] else ...[
              const SizedBox(height: 10),
              GhostButton(
                label: l.t('Enter after ringing them'),
                icon: Icons.call_outlined,
                compact: true,
                onPressed: onEnter,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    required this.tone,
  });

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
