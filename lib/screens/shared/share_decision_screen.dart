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

/// What a co-founder was handed for a closed period, and their word that they
/// have seen it.
///
/// This screen used to ask them what they wanted doing with their share, and
/// the master could not close until all four had answered. The four of them
/// have since agreed to leave the lot in the farm for a year and buy more
/// buffaloes with it, so the question had the same answer every month and the
/// close sat waiting on four taps nobody was going to make.
///
/// What was worth keeping out of that is not the veto. It is the record: four
/// friends in business need it written down that every one of them was shown
/// what the month came to, and when. So the figures are laid out in full and
/// there is one button, and pressing it changes nothing about the money.
class ShareDecisionScreen extends StatefulWidget {
  const ShareDecisionScreen({
    super.key,
    required this.periodId,
    required this.partnerId,
  });

  final String periodId;
  final String partnerId;

  @override
  State<ShareDecisionScreen> createState() => _ShareDecisionScreenState();
}

class _ShareDecisionScreenState extends State<ShareDecisionScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<FarmStore>();

    FarmMonth? period;
    for (final m in store.periods) {
      if (m.id == widget.periodId) period = m;
    }
    final share = period?.shareFor(widget.partnerId);

    if (period == null || share == null) {
      return FarmScaffold(
        title: l.t('Your share'),
        showBack: true,
        body: PageBody(
          children: [EmptyNote(l.t('That period is no longer here.'))],
        ),
      );
    }

    final seen = period.seenBy(widget.partnerId);
    final loss = share.isLoss;

    return FarmScaffold(
      title: l.t2('%s — your share', periodLabel(period)),
      showBack: true,
      body: PageBody(
        children: [
          HeroCard(
            label: loss ? l.t('Your share of the loss') : l.t('Your share'),
            value: rs(share.share.abs()),
            gradient: T.washOf(loss ? T.moneyOut : T.moneyIn),
            note: l.t2(
              'Your %s of what the farm made this period.',
              '${(share.ratio * 100).toStringAsFixed(1)}%',
            ),
            trailing: Tag(
              seen ? l.t('Seen') : l.t('New'),
              tone: seen ? TagTone.good : TagTone.warn,
            ),
          ),
          const SizedBox(height: 20),

          RegCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(l.t('The period')),
                const SizedBox(height: 10),
                _Row(
                  label: loss
                      ? l.t('What the farm lost')
                      : l.t('What the farm made'),
                  value: rs((period.profitShared ?? 0).abs()),
                  tone: loss ? T.moneyOut : T.moneyIn,
                ),
                _Row(
                  label: l.t('Your share of the farm'),
                  value: '${(share.ratio * 100).toStringAsFixed(1)}%',
                  tone: T.accent700,
                ),
                if (period.sharedPercent != null)
                  _Row(
                    label: l.t('Handed out this period'),
                    value: '${period.sharedPercent}%',
                    tone: T.n700,
                  ),
                const Divider(height: 20),
                if (loss)
                  _Row(
                    label: l.t('Taken off what you had kept'),
                    value: rs(share.held.abs()),
                    tone: T.moneyOut,
                    strong: true,
                  )
                else ...[
                  _Row(
                    label: l.t('Paid out to you'),
                    value: rs(share.taken),
                    tone: T.moneyOut,
                    strong: true,
                  ),
                  _Row(
                    label: l.t('Kept in the farm, in your name'),
                    value: rs(share.held),
                    tone: T.moneyIn,
                    strong: true,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: T.gap),

          Text(
            loss
                ? l.t(
                    'A month that loses money is shared the same way a month '
                    'that makes it — your part of it comes off what you have '
                    'kept in the farm. Nothing is hidden and nothing is '
                    'carried quietly.',
                  )
                : l.t(
                    'Whatever is kept in stays yours. It does not change '
                    'your share of the farm — that comes from what you have '
                    'put in out of your own pocket, and only moves when you '
                    'put in more.',
                  ),
            style: T.meta,
          ),
          const SizedBox(height: 20),

          if (seen)
            RegCard(
              wash: T.moneyInWash,
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: T.moneyIn, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.t2(
                        'You saw this on %s.',
                        fmtStamp(period.seen[widget.partnerId]!),
                      ),
                      style: T.body,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            PrimaryButton(
              label: l.t('I have seen this'),
              icon: Icons.check,
              busy: _busy,
              onPressed: _busy ? null : () => _seen(period!),
            ),
            const SizedBox(height: 10),
            Text(
              l.t(
                'It changes nothing about the money. It puts your name and '
                'the date against these figures, so nobody has to remember '
                'later who was told what.',
              ),
              style: T.meta,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _seen(FarmMonth period) async {
    final l = L.read(context);
    setState(() => _busy = true);
    try {
      await MonthRepo.markSeen(
        actor: context.read<Session>().actor,
        period: period,
        partnerId: widget.partnerId,
      );
      if (mounted) toast(context, l.t('Noted — thank you.'));
    } catch (e) {
      if (mounted) toast(context, l.t2('Could not save it. %s', e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.tone,
    this.strong = false,
  });

  final String label;
  final String value;
  final Color tone;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label, style: strong ? T.bodyMid : T.body)),
        Text(
          value,
          style: (strong ? T.num22 : T.bodyMid).copyWith(color: tone),
        ),
      ],
    ),
  );
}
