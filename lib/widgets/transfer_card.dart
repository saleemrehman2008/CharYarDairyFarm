import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/words.dart';
import '../models/models.dart';
import '../services/transfer_repo.dart';
import '../state/farm_store.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../util/money.dart';
import 'ui.dart';

/// Money somebody says he has handed to you.
///
/// There is no way to make a phone ring about this — the farm is on the free
/// plan and a push notification needs a card on a billing account — so it
/// waits at the top of the first screen he opens instead, and does not leave
/// until he has said one thing or the other. For a thing that happens a few
/// times a week between four friends who see each other daily, a card that
/// cannot be scrolled past is worth more than a notification anyway.
///
/// Two answers, and the second one matters more than the first. Saying it
/// arrived is the ordinary case and writes the pair of rows into the books.
/// Saying it did not is rare and is the entire reason the confirmation
/// exists: a disagreement about money between four friends is worth more
/// written down than settled quietly.
class TransferInbox extends StatelessWidget {
  const TransferInbox({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<Session>().user?.name ?? '';
    if (me.trim().isEmpty) return const SizedBox.shrink();

    final waiting = context.watch<FarmStore>().waitingOn(me);
    if (waiting.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final move in waiting)
          Padding(
            padding: const EdgeInsets.only(bottom: T.gap),
            child: _Card(move: move),
          ),
      ],
    );
  }
}

class _Card extends StatefulWidget {
  const _Card({required this.move});

  final CashTransfer move;

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  bool _busy = false;

  Future<void> _take() async {
    final l = L.read(context);
    setState(() => _busy = true);
    try {
      await TransferRepo.take(context.read<Session>().actor, widget.move);
      if (mounted) toast(context, l.t('Taken in'));
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refuse() async {
    final l = L.read(context);
    final why = await askForWords(
      context,
      title: l.t('You did not get this?'),
      hint: l.t('What happened'),
      note: l.t(
        'Nothing goes into the books and the money stays where it was. '
        'What you write here is kept on it, and both of you can see it.',
      ),
    );
    if (why == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await TransferRepo.refuse(
        context.read<Session>().actor,
        widget.move,
        because: why,
      );
      if (mounted) toast(context, l.t('Written down'));
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final m = widget.move;

    return RegCard(
      stripe: T.moneyDue,
      wash: T.moneyDueWash,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.south_west_rounded, size: 20, color: T.moneyDue),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.t2('%s has handed you money', m.from),
                      style: T.cardTitle,
                    ),
                    const SizedBox(height: 4),
                    Text(rs(m.amount), style: T.num26),
                    const SizedBox(height: 3),
                    Text(
                      [
                        l.t(m.payVia.label),
                        fmtStamp(m.sentAt),
                        if (m.note.trim().isNotEmpty) m.note,
                      ].join(' · '),
                      style: T.meta,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l.t(
              'Until you say so it is in nobody\'s hands — not his and not '
              'yours. Nothing has gone into the books yet.',
            ),
            style: T.meta,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: l.t('I have it'),
                  icon: Icons.check,
                  busy: _busy,
                  onPressed: _busy ? null : _take,
                ),
              ),
              const SizedBox(width: 8),
              GhostButton(
                label: l.t('I did not'),
                danger: true,
                onPressed: _busy ? null : _refuse,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
