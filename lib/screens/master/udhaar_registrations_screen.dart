import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/udhaar_repo.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';

/// Customers asking for monthly credit, and the limit each one gets.
class UdhaarRegistrationsScreen extends StatelessWidget {
  const UdhaarRegistrationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<FarmStore>().udhaarAccounts;

    return FarmScaffold(
      title: 'Khaata registrations',
      showBack: true,
      body: PageBody(
        children: [
          Text(
            'A khaata customer takes milk through the month and is billed at '
            'month end. The rate is theirs alone; the limit caps how much they '
            'can owe before the farm stops delivering.',
            style: T.meta,
          ),
          const SizedBox(height: 14),
          if (accounts.isEmpty)
            const EmptyNote('No khaata registrations yet.')
          else
            for (final a in accounts)
              _UdhaarCard(key: ValueKey(a.uid), account: a),
        ],
      ),
    );
  }
}

class _UdhaarCard extends StatefulWidget {
  const _UdhaarCard({super.key, required this.account});

  final UdhaarAccount account;

  @override
  State<_UdhaarCard> createState() => _UdhaarCardState();
}

class _UdhaarCardState extends State<_UdhaarCard> {
  late final _limit = TextEditingController(
    text: widget.account.limit.round().toString(),
  );
  late final _rate = TextEditingController(
    text: widget.account.rate.round().toString(),
  );
  bool _busy = false;

  @override
  void dispose() {
    _limit.dispose();
    _rate.dispose();
    super.dispose();
  }

  num? get _typedLimit => num.tryParse(_limit.text.trim());
  num? get _typedRate => num.tryParse(_rate.text.trim());

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) toast(context, done);
    } catch (e) {
      if (mounted) toast(context, 'Could not do that. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    final actor = context.read<Session>().actor;

    return Padding(
      padding: const EdgeInsets.only(bottom: T.gap),
      child: RegCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    a.name,
                    style: T.cardTitle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Tag(a.status.label, tone: _tone(a.status)),
              ],
            ),
            const SizedBox(height: 6),
            Text(a.address, style: T.body),
            const SizedBox(height: 4),
            Text(
              '${a.mobile} · ${a.slotLabel} · ${qty(a.litresPerDay)} L/day',
              style: T.meta,
            ),
            const SizedBox(height: 4),
            Text(
              a.isApproved
                  ? 'Owes ${rs(a.balance)} of ${rs(a.limit)}'
                  : 'Suggested limit ${rs(a.limit)}',
              style: T.meta,
            ),
            const SizedBox(height: 8),
            Text(
              a.approvedByName == null
                  ? 'Awaiting approval · all co-founders notified'
                  : 'Approved by ${a.approvedByName}',
              style: T.meta.copyWith(
                color: a.approvedByName == null ? T.accent700 : T.n600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Field(
                    label: 'Rate / litre',
                    controller: _rate,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Field(
                    label: 'Limit (Rs)',
                    controller: _limit,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'This customer pays their own rate — a regular can be given a '
              'little off the shop price.',
              style: T.meta,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (a.status == UdhaarStatus.pending)
                  GhostButton(
                    label: 'Approve khaata',
                    icon: Icons.check,
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => UdhaarRepo.approve(
                              actor,
                              a,
                              limit: _typedLimit,
                              rate: _typedRate,
                            ),
                            '${a.name} now has a khaata',
                          ),
                  )
                else
                  GhostButton(
                    label: 'Save rate & limit',
                    onPressed: _busy || _typedLimit == null
                        ? null
                        : () => _run(
                            () => UdhaarRepo.setTerms(
                              actor,
                              a,
                              limit: _typedLimit!,
                              rate: _typedRate,
                            ),
                            'Saved',
                          ),
                  ),
              ],
            ),
            if (a.status == UdhaarStatus.pending) ...[
              const SizedBox(height: 8),
              GhostButton(
                label: 'Do not approve',
                compact: true,
                danger: true,
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => UdhaarRepo.reject(actor, a),
                        'Registration declined',
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static TagTone _tone(UdhaarStatus s) => switch (s) {
    UdhaarStatus.approved => TagTone.good,
    UdhaarStatus.pending => TagTone.warn,
    UdhaarStatus.rejected => TagTone.bad,
    UdhaarStatus.none => TagTone.neutral,
  };
}
