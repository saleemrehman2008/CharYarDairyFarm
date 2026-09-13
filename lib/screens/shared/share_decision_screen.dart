import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// One co-founder decides how much of their share to take out.
///
/// The two figures move as the amount is typed, because that is the whole
/// question: what goes in your pocket, and what stays in the farm. Whatever is
/// not taken out is added to that co-founder's investment, which raises their
/// share of the next period.
///
/// The master reaches the same screen with [onBehalf] set, to enter what a
/// co-founder told them on the phone. It is recorded as second hand.
class ShareDecisionScreen extends StatefulWidget {
  const ShareDecisionScreen({
    super.key,
    required this.periodId,
    required this.partnerId,
    this.onBehalf = false,
  });

  final String periodId;
  final String partnerId;

  /// The master entering it for somebody else, after speaking to them.
  final bool onBehalf;

  @override
  State<ShareDecisionScreen> createState() => _ShareDecisionScreenState();
}

class _ShareDecisionScreenState extends State<ShareDecisionScreen> {
  final _amount = TextEditingController();
  bool _busy = false;
  bool _started = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  num get _withdraw => num.tryParse(_amount.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<FarmStore>();
    final period = store.sealedPeriod;
    final share = period?.shareFor(widget.partnerId);

    if (period == null || share == null) {
      return FarmScaffold(
        title: l.t('Your share'),
        showBack: true,
        body: PageBody(
          children: [
            EmptyNote(
              l.t(
                'There is nothing to decide right now. The master will send '
                'the figures when the period is settled.',
              ),
            ),
          ],
        ),
      );
    }

    // Start on what they already chose, or on nothing if they have not.
    if (!_started) {
      _started = true;
      if (share.decided && share.withdraw > 0) {
        _amount.text = share.withdraw.round().toString();
      }
    }

    final over = _withdraw > share.share;
    final take = over ? share.share : _withdraw;
    final keep = share.share - take;

    return FarmScaffold(
      title: widget.onBehalf ? share.name : l.t('Your share'),
      showBack: true,
      body: PageBody(
        children: [
          HeroCard(
            label: l.t2('%s share', periodLabel(period, short: true)),
            value: rs(share.share),
            note: period.sealedAt == null
                ? null
                : l.t2(
                    'Frozen %s. This figure will not change.',
                    fmtStamp(period.sealedAt!),
                  ),
            trailing: Tag(
              '${(share.ratio * 100).toStringAsFixed(0)}%',
              tone: TagTone.accent,
            ),
          ),
          const SizedBox(height: T.gap),

          // The two columns the farm asked for: what is left of the share,
          // and what that leaves in the farm. Both move as you type.
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: l.t('You take out'),
                  value: rs(take),
                  tone: T.moneyOut,
                ),
              ),
              const SizedBox(width: T.gap),
              Expanded(
                child: StatTile(
                  label: l.t('Stays as investment'),
                  value: rs(keep),
                  tone: T.moneyIn,
                ),
              ),
            ],
          ),
          const SizedBox(height: T.gap),

          RegCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(l.t('How much do you want to take out?')),
                const SizedBox(height: 8),
                TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                  ],
                  onChanged: (_) => setState(() {}),
                  style: T.num22,
                  decoration: InputDecoration(
                    prefixText: 'Rs ',
                    prefixStyle: T.num22.copyWith(color: T.n600),
                    hintText: '0',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: GhostButton(
                        label: l.t('Take nothing'),
                        compact: true,
                        onPressed: () => setState(() => _amount.text = '0'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GhostButton(
                        label: l.t('Take all of it'),
                        compact: true,
                        onPressed: () => setState(
                          () => _amount.text = share.share.round().toString(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  over
                      ? l.t2(
                          'Your share is only %s — you cannot take more than '
                          'that.',
                          rs(share.share),
                        )
                      : keep == 0
                      ? l.t('Taking the whole share. Nothing goes to '
                            'investment.')
                      : l.t2(
                          '%s is added to your investment, so your share of '
                          'the next period goes up.',
                          rs(keep),
                        ),
                  style: T.meta.copyWith(color: over ? T.alert : T.n700),
                ),
              ],
            ),
          ),
          const SizedBox(height: T.pad),

          if (widget.onBehalf)
            Padding(
              padding: const EdgeInsets.only(bottom: T.pad),
              child: RegCard(
                wash: T.moneyDueWash,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.t('Entering this for someone else'),
                      style: T.cardTitle.copyWith(color: T.moneyDue),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.t2(
                        'Only do this after speaking to %s. It will be saved '
                        'as confirmed by phone, with your name on it, and they '
                        'will be told what was entered.',
                        share.name,
                      ),
                      style: T.body,
                    ),
                  ],
                ),
              ),
            ),

          PrimaryButton(
            label: widget.onBehalf
                ? l.t('Save what they told you')
                : l.t('Confirm my decision'),
            icon: Icons.check,
            busy: _busy,
            onPressed: _amount.text.trim().isEmpty || over
                ? null
                : () => _save(period, share, take),
          ),
          const SizedBox(height: 10),
          Text(
            l.t(
              'You can change this until the master closes the period. After '
              'that it is final.',
            ),
            style: T.meta,
          ),
        ],
      ),
    );
  }

  Future<void> _save(FarmMonth period, MonthShare share, num take) async {
    final l = L.read(context);
    final ok = await confirm(
      context,
      title: widget.onBehalf
          ? l.t2('Save for %s?', share.name)
          : l.t('Confirm?'),
      body: l.t3(
        '%s out, %s into investment.',
        rs(take),
        rs(share.share - take),
      ),
      confirmLabel: l.t('Confirm'),
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await MonthRepo.decide(
        actor: context.read<Session>().actor,
        period: period,
        partnerId: widget.partnerId,
        withdraw: take,
        byPhone: widget.onBehalf,
      );
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, l.t('Saved.'));
    } catch (e) {
      if (mounted) toast(context, l.t2('Could not save it. %s', e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
