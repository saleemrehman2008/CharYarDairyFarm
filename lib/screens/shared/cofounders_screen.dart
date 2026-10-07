import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/db.dart';
import '../../services/partner_repo.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/loan_card.dart';
import '../../widgets/ui.dart';

/// Capital, share ratios and the record of closed months.
class CofoundersScreen extends StatelessWidget {
  const CofoundersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final session = context.watch<Session>();
    final isMaster = session.role == Role.master;
    final partners = store.partners;
    final ratios = store.ratios;

    return PageBody(
      children: [
        RegCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Kicker('Total capital · ${partners.length} co-founders'),
              const SizedBox(height: 8),
              Text(rs(store.totalCapital), style: T.num30),
              const SizedBox(height: 12),
              _StackedRatioBar(partners: partners, ratios: ratios),
              const SizedBox(height: 10),
              Text(
                'The share ratio follows what each of them has put in out of '
                'their own pocket. Profit kept in the farm is theirs and is '
                'listed on their own card — it does not move the ratio.',
                style: T.meta,
              ),
            ],
          ),
        ),
        const SizedBox(height: T.pad),

        if (isMaster) ...[
          const _AddPartnerCard(),
          const SizedBox(height: T.pad),
        ],

        if (partners.isEmpty)
          const EmptyNote(
            'No co-founders yet. Add one above — they do not have to have '
            'signed in.',
          )
        else
          for (final (i, p) in partners.indexed)
            _PartnerCard(
              partner: p,
              color: T.partnerColors[i % T.partnerColors.length],
              ratio: ratios[p.id] ?? 0,
              isYou: p.userId == session.user?.uid,
              canAddInvestment: isMaster,
              canRemove: isMaster,
            ),

        // Money the farm has lent its own. Asked for by them, handed over by
        // the master, and paid back out of what they are handed at a close.
        if (store.loans.any((l) => l.state != LoanState.refused)) ...[
          const SizedBox(height: 12),
          const SectionTitle('Loans'),
          const SizedBox(height: 8),
          for (final loan in store.loans)
            if (loan.state != LoanState.refused)
              LoanCard(loan: loan, canDecide: isMaster),
        ],
        for (final me in partners)
          if (me.userId == session.user?.uid &&
              store.runningLoanFor(me.id) == null &&
              !store.loansAsked.any((l) => l.partnerId == me.id))
            AskForLoanCard(partner: me),

        const SizedBox(height: 12),
        const SectionTitle('Closed months'),
        StreamBuilder<List<FarmMonth>>(
          stream: Db.watchClosedMonths(),
          builder: (context, snap) {
            final months = snap.data ?? const <FarmMonth>[];
            if (months.isEmpty) {
              return const EmptyNote('No month has been closed yet.');
            }
            return Column(
              children: [
                for (final m in months)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: T.divider, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(monthName(m.id), style: T.bodyMid),
                        ),
                        Tag(m.arLabel),
                        const SizedBox(width: 8),
                        Text(rs(m.profit ?? 0), style: T.bodyMid),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// One bar split by each partner's share of the capital.
class _StackedRatioBar extends StatelessWidget {
  const _StackedRatioBar({required this.partners, required this.ratios});

  final List<Partner> partners;
  final Map<String, double> ratios;

  @override
  Widget build(BuildContext context) {
    if (partners.isEmpty) return Container(height: 6, color: T.n300);
    return SizedBox(
      height: 6,
      child: Row(
        children: [
          for (final (i, p) in partners.indexed)
            Expanded(
              flex: (((ratios[p.id] ?? 0) * 1000).round()).clamp(1, 1000),
              child: Container(
                color: T.partnerColors[i % T.partnerColors.length],
              ),
            ),
        ],
      ),
    );
  }
}

class _PartnerCard extends StatefulWidget {
  const _PartnerCard({
    required this.partner,
    required this.color,
    required this.ratio,
    required this.isYou,
    required this.canAddInvestment,
    required this.canRemove,
  });

  final Partner partner;
  final Color color;
  final double ratio;
  final bool isYou;
  final bool canAddInvestment;

  /// The master may clear away a record with nothing in it.
  final bool canRemove;

  @override
  State<_PartnerCard> createState() => _PartnerCardState();
}

class _PartnerCardState extends State<_PartnerCard> {
  final _amount = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final amount = num.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0) {
      toast(context, 'Enter how much was invested.');
      return;
    }
    setState(() => _busy = true);
    try {
      await PartnerRepo.addInvestment(
        context.read<Session>().actor,
        widget.partner,
        amount,
      );
      _amount.clear();
      if (mounted) {
        toast(context, '${rs(amount)} added for ${widget.partner.name}');
      }
    } catch (e) {
      if (mounted) toast(context, 'Could not add it. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.partner;
    return Padding(
      padding: const EdgeInsets.only(bottom: T.gap),
      child: RegCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 10, height: 10, color: widget.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: T.cardTitle,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // One person can hold two accounts on the farm and both
                      // carry the same name from Google. The email is the only
                      // thing here that tells them apart.
                      if (p.email.isNotEmpty)
                        Text(
                          p.email,
                          style: T.meta.copyWith(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (widget.isYou) ...[
                  const Tag('You'),
                  const SizedBox(width: 6),
                ],
                Tag(
                  '${(widget.ratio * 100).toStringAsFixed(0)}%',
                  tone: TagTone.accent,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(label: 'Invested', value: rs(p.invested)),
                _Stat(label: 'Reinvested', value: rs(p.profitHeld)),
                _Stat(label: 'Withdrawn', value: rs(p.withdrawn)),
              ],
            ),
            if (widget.canAddInvestment) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Field(
                      label: 'Add investment (Rs)',
                      controller: _amount,
                      keyboardType: TextInputType.number,
                      hint: '0',
                    ),
                  ),
                  const SizedBox(width: 8),
                  GhostButton(
                    label: 'Add',
                    icon: Icons.add,
                    onPressed: _busy ? null : _add,
                  ),
                ],
              ),
            ],

            // Correcting a figure that went in wrong, and taking a record
            // away. Both are the master's, both are written into the log
            // with what changed, and neither is a quiet button: capital is
            // what every share ratio is worked out from, so one of these
            // moves all four slices.
            if (widget.canRemove) ...[
              const SizedBox(height: 10),
              if (p.isEmpty)
                Text(
                  'Nothing has ever gone through this record.',
                  style: T.meta,
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  GhostButton(
                    label: 'Name',
                    icon: Icons.badge_outlined,
                    compact: true,
                    onPressed: _busy ? null : _editWho,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GhostButton(
                      label: 'Capital',
                      icon: Icons.edit_outlined,
                      compact: true,
                      onPressed: _busy ? null : _correct,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GhostButton(
                    label: 'Remove',
                    icon: Icons.delete_outline,
                    compact: true,
                    danger: true,
                    onPressed: _busy ? null : _remove,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Correct the name or the email on this record.
  Future<void> _editWho() async {
    final p = widget.partner;
    final name = TextEditingController(text: p.name);
    final mail = TextEditingController(text: p.email);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: T.surface,
        title: Text('Who this record is', style: T.cardTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Field(label: 'Name', controller: name),
            const SizedBox(height: T.gap),
            Field(
              label: 'Email',
              controller: mail,
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
              hint: 'The one they sign in with',
            ),
            const SizedBox(height: 10),
            Text(
              'The email is what lets this person claim this record when '
              'they first sign in — with its capital on it. Wrong, and the '
              'app opens them an empty one instead.',
              style: T.meta,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: T.bodyMid),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Save', style: T.bodyMid.copyWith(color: T.accent700)),
          ),
        ],
      ),
    );

    final to = name.text.trim();
    final toMail = mail.text.trim();
    name.dispose();
    mail.dispose();
    if (ok != true || !mounted) return;
    if (to.isEmpty) {
      toast(context, 'A record needs a name.');
      return;
    }

    setState(() => _busy = true);
    try {
      await PartnerRepo.rename(
        context.read<Session>().actor,
        p,
        name: to,
        email: toMail,
      );
      if (mounted) toast(context, 'Saved');
    } catch (e) {
      if (mounted) toast(context, 'Could not save it. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Set the capital to a figure, rather than add to it.
  ///
  /// The box opens on what it is now, because this is a correction and the
  /// person doing it should be looking at the figure they are about to
  /// change rather than recalling it.
  Future<void> _correct() async {
    final p = widget.partner;
    final said = await askForMoney(
      context,
      title: 'Capital for ${p.name}',
      hint: '0',
      starting: p.invested,
      note:
          'This replaces the figure rather than adding to it. Share ratios '
          'are worked out from capital, so changing this changes what all '
          'four of them get from every month closed after today. Months '
          'already closed keep what they were closed with. It goes in the '
          'log either way, with what it was before.',
    );
    if (said == null || !mounted || said == p.invested) return;
    if (said < 0) {
      toast(context, 'Capital cannot be less than nothing.');
      return;
    }

    final ok = await confirm(
      context,
      title: 'Change the capital?',
      body:
          '${p.name}\n\n'
          '${rs(p.invested)}  →  ${rs(said)}\n\n'
          'Every co-founder\'s share of future months moves with this.',
      confirmLabel: 'Change it',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await PartnerRepo.setInvested(context.read<Session>().actor, p, said);
      if (mounted) toast(context, '${p.name} capital is now ${rs(said)}');
    } catch (e) {
      if (mounted) toast(context, 'Could not change it. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final p = widget.partner;
    final empty = p.isEmpty;

    // An empty record is housekeeping — a duplicate left behind by a second
    // account — and reads as such. One with money in it is a different act
    // altogether, so it names every figure that goes with it rather than
    // asking "are you sure" over a number nobody can see.
    final ok = await confirm(
      context,
      title: empty
          ? 'Remove this record?'
          : 'Remove a record with money in it?',
      body: empty
          ? '${p.name}${p.email.isEmpty ? '' : '\n${p.email}'}\n\n'
                'No capital, nothing reinvested, nothing withdrawn — so there '
                'is nothing to lose. The share ratios are worked out again '
                'without it.'
          : '${p.name}${p.email.isEmpty ? '' : '\n${p.email}'}\n\n'
                'Capital: ${rs(p.invested)}\n'
                'Kept in the farm: ${rs(p.profitHeld)}\n'
                'Taken out: ${rs(p.withdrawn)}\n\n'
                'All of it goes. The other co-founders\' share ratios are '
                'worked out again without this record, so every one of their '
                'slices changes. Months already closed keep what they were '
                'closed with.\n\n'
                'The figures above are written into the activity log, and so '
                'is your name. This cannot be undone.',
      confirmLabel: 'Remove',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await PartnerRepo.remove(context.read<Session>().actor, p, force: !empty);
      if (mounted) toast(context, '${p.name} removed');
    } catch (e) {
      if (mounted) toast(context, 'Could not remove it. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Kicker(label),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: T.bodyMid),
        ),
      ],
    ),
  );
}

/// Opens a capital record for somebody who has not signed in yet.
///
/// A co-founder can put money into the farm months before they ever open the
/// app — and until now there was no way to say so, because a record only came
/// into being when its owner signed in. Give it their email and their own
/// sign-in will claim this record rather than starting a second one beside it.
class _AddPartnerCard extends StatefulWidget {
  const _AddPartnerCard();

  @override
  State<_AddPartnerCard> createState() => _AddPartnerCardState();
}

class _AddPartnerCardState extends State<_AddPartnerCard> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _amount = TextEditingController();
  bool _busy = false;
  bool _open = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, 'What is their name?');
      return;
    }
    final email = _email.text.trim();
    if (email.isNotEmpty && !email.contains('@')) {
      toast(context, 'That email does not look right.');
      return;
    }

    final invested = num.tryParse(_amount.text.trim()) ?? 0;
    setState(() => _busy = true);
    try {
      await PartnerRepo.create(
        context.read<Session>().actor,
        name: name,
        email: email,
        invested: invested,
      );
      if (!mounted) return;
      _name.clear();
      _email.clear();
      _amount.clear();
      setState(() => _open = false);
      toast(context, '$name added');
    } catch (e) {
      if (mounted) toast(context, 'Could not add them. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return GhostButton(
        label: 'Add a co-founder',
        icon: Icons.person_add_alt,
        onPressed: () => setState(() => _open = true),
      );
    }

    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add a co-founder', style: T.cardTitle),
          const SizedBox(height: 4),
          Text(
            'They do not have to have signed in. Put their email on it and '
            'their first sign-in will pick up this record — name, capital and '
            'share all intact.',
            style: T.meta,
          ),
          const SizedBox(height: T.gap),
          Field(label: 'Name', controller: _name, hint: 'As everyone says it'),
          const SizedBox(height: T.gap),
          Field(
            label: 'Email (the one they will sign in with)',
            controller: _email,
            hint: 'someone@gmail.com',
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
          ),
          const SizedBox(height: T.gap),
          Field(
            label: 'Capital they have put in (Rs)',
            controller: _amount,
            keyboardType: TextInputType.number,
            hint: '0',
          ),
          const SizedBox(height: T.pad),
          Row(
            children: [
              Expanded(
                child: GhostButton(
                  label: 'Cancel',
                  onPressed: _busy ? null : () => setState(() => _open = false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label: 'Add',
                  busy: _busy,
                  onPressed: _add,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
