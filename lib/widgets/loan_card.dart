import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/words.dart';
import '../models/models.dart';
import '../services/loan_repo.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../util/money.dart';
import 'ui.dart';

/// Money the farm has lent one of its own, and how far along it is.
///
/// Shown to the person who owes it and to the master who handed it over. A
/// loan between four friends does not need chasing so much as it needs to be
/// somewhere both of them can see it without asking each other.
class LoanCard extends StatefulWidget {
  const LoanCard({super.key, required this.loan, required this.canDecide});

  final FounderLoan loan;

  /// The master, who hands it over or says no, and who can take a payment in
  /// over the counter.
  final bool canDecide;

  @override
  State<LoanCard> createState() => _LoanCardState();
}

class _LoanCardState extends State<LoanCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final loan = widget.loan;
    final asked = loan.state == LoanState.asked;
    // What it is, rather than what was last written down about it.
    final standing = loan.standing;

    return Padding(
      padding: const EdgeInsets.only(bottom: T.gap),
      child: RegCard(
        stripe: switch (standing) {
          LoanState.asked => T.moneyDue,
          LoanState.given => T.moneyGet,
          LoanState.cleared => T.moneyIn,
          LoanState.refused => T.n300,
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    loan.name,
                    style: T.cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Tag(
                  l.t(standing.label),
                  tone: switch (standing) {
                    LoanState.asked => TagTone.warn,
                    LoanState.given => TagTone.accent,
                    LoanState.cleared => TagTone.good,
                    LoanState.refused => TagTone.neutral,
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(rs(loan.amount), style: T.num22),
            Text(
              l.t3(
                'over %s months · %s a month',
                '${loan.months}',
                rs(loan.instalment),
              ),
              style: T.meta,
            ),

            if (standing == LoanState.cleared) ...[
              const SizedBox(height: 12),
              RatioBar(fraction: 1, color: T.moneyIn),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, color: T.moneyIn, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.t2('Paid back in full — %s.', rs(loan.amount)),
                      style: T.bodyMid,
                    ),
                  ),
                ],
              ),
            ],

            if (standing == LoanState.given) ...[
              const SizedBox(height: 12),
              RatioBar(fraction: loan.done, color: T.moneyIn),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text(l.t('Paid back'), style: T.body)),
                  Text(
                    rs(loan.repaid),
                    style: T.bodyMid.copyWith(color: T.moneyIn),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(child: Text(l.t('Still owed'), style: T.body)),
                  Text(
                    rs(loan.left),
                    style: T.bodyMid.copyWith(color: T.moneyGet),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l.t(
                  'The instalment comes off what they are handed when a '
                  'period is settled. In a month where nothing goes out '
                  'there is nothing to take it from, so it waits — and they '
                  'can pay it in themselves any time.',
                ),
                style: T.meta,
              ),
              if (widget.canDecide) ...[
                const SizedBox(height: 10),
                GhostButton(
                  label: l.t('They paid some in'),
                  icon: Icons.south_west,
                  compact: true,
                  onPressed: _busy ? null : () => _takeIn(loan),
                ),
              ],
            ],

            if (asked && widget.canDecide) ...[
              const SizedBox(height: 12),
              Text(
                l.t(
                  'The cash leaves the farm when you hand it over. It is not '
                  'a cost and it does not touch anybody\'s profit — it is '
                  'the farm\'s money, in their pocket, until it comes back.',
                ),
                style: T.meta,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: l.t('Hand it over'),
                      icon: Icons.north_east,
                      busy: _busy,
                      onPressed: _busy ? null : () => _give(loan),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GhostButton(
                    label: l.t('Not now'),
                    compact: true,
                    onPressed: _busy ? null : () => _refuse(loan),
                  ),
                ],
              ),
            ],

            if (asked && !widget.canDecide) ...[
              const SizedBox(height: 10),
              Text(
                l.t('Waiting for the master to hand it over.'),
                style: T.meta,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _give(FounderLoan loan) async {
    final l = L.read(context);
    final ok = await confirm(
      context,
      title: l.t2('Hand %s over?', rs(loan.amount)),
      body: l.t3(
        '%s leaves the farm now and comes back at %s a month out of what '
        'they are handed when a period is settled.\n\nIt is not a cost and '
        'nobody\'s profit changes.',
        rs(loan.amount),
        rs(loan.instalment),
      ),
      confirmLabel: l.t('Hand it over'),
    );
    if (!ok || !mounted) return;
    await _run(
      () => LoanRepo.give(
        actor: context.read<Session>().actor,
        loan: loan,
        handledBy: context.read<Session>().actor.name,
      ),
      l.t('Handed over.'),
    );
  }

  Future<void> _refuse(FounderLoan loan) async {
    final l = L.read(context);
    await _run(
      () => LoanRepo.refuse(actor: context.read<Session>().actor, loan: loan),
      l.t('Noted.'),
    );
  }

  Future<void> _takeIn(FounderLoan loan) async {
    final l = L.read(context);
    final amount = await askForMoney(
      context,
      title: l.t('How much did they pay in?'),
      hint: rs(loan.left),
    );
    if (amount == null || amount <= 0 || !mounted) return;
    await _run(
      () => LoanRepo.repay(
        actor: context.read<Session>().actor,
        loan: loan,
        amount: amount,
        handledBy: context.read<Session>().actor.name,
      ),
      l.t('Taken in.'),
    );
  }

  Future<void> _run(Future<void> Function() job, String said) async {
    final l = L.read(context);
    setState(() => _busy = true);
    try {
      await job();
      if (mounted) toast(context, said);
    } catch (e) {
      if (mounted) toast(context, l.t2('Could not do it. %s', e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// A co-founder asking the farm for a loan.
class AskForLoanCard extends StatefulWidget {
  const AskForLoanCard({super.key, required this.partner});

  final Partner partner;

  @override
  State<AskForLoanCard> createState() => _AskForLoanCardState();
}

class _AskForLoanCardState extends State<AskForLoanCard> {
  final _amount = TextEditingController();
  int _months = 12;
  bool _open = false;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final amount = num.tryParse(_amount.text.trim()) ?? 0;

    if (!_open) {
      return Padding(
        padding: const EdgeInsets.only(bottom: T.gap),
        child: GhostButton(
          label: l.t('Ask the farm for a loan'),
          icon: Icons.account_balance_wallet_outlined,
          onPressed: () => setState(() => _open = true),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: T.gap),
      child: RegCard(
        stripe: T.moneyDue,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Kicker(l.t('Ask the farm for a loan')),
            const SizedBox(height: 10),
            Field(
              label: l.t('How much'),
              controller: _amount,
              hint: '100000',
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Text(l.t('Over how many months'), style: T.kicker),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in [3, 6, 12, 18, 24])
                  ChoiceChip(
                    label: Text('$m'),
                    selected: _months == m,
                    showCheckmark: false,
                    labelStyle: T.bodyMid.copyWith(
                      color: _months == m ? T.onFill : T.n700,
                    ),
                    selectedColor: T.accent,
                    backgroundColor: T.surface,
                    side: BorderSide(color: _months == m ? T.accent : T.n300),
                    onSelected: (_) => setState(() => _months = m),
                  ),
              ],
            ),
            if (amount > 0) ...[
              const SizedBox(height: 12),
              Text(
                l.t2('%s a month', rs((amount / _months).round())),
                style: T.bodyMid,
              ),
              const SizedBox(height: 4),
              Text(
                l.t(
                  'Taken off your share when a period is settled. No '
                  'interest — it is the farm\'s money and you pay back what '
                  'you took, nothing more.',
                ),
                style: T.meta,
              ),
            ],
            const SizedBox(height: 12),
            PrimaryButton(
              label: l.t('Ask'),
              icon: Icons.send_outlined,
              busy: _busy,
              onPressed: amount <= 0 || _busy ? null : () => _ask(amount),
            ),
            const SizedBox(height: 6),
            GhostButton(
              label: l.t('Cancel'),
              onPressed: () => setState(() => _open = false),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ask(num amount) async {
    final l = L.read(context);
    setState(() => _busy = true);
    try {
      await LoanRepo.ask(
        actor: context.read<Session>().actor,
        partner: widget.partner,
        amount: amount,
        months: _months,
      );
      if (!mounted) return;
      setState(() => _open = false);
      toast(context, l.t('Asked. The master will see it.'));
    } catch (e) {
      if (mounted) toast(context, l.t2('Could not ask. %s', e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
