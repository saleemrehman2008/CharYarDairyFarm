import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/accounting.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import 'accounts_screen.dart';
import 'founder_money.dart';
import '../../widgets/ui.dart';
import 'cash_hands.dart';

/// Every account the farm's money can sit in, picked from a strip of names.
///
/// The farm asked for this in its own words: a row of names across the top,
/// the farm's own account among them, and each one opening its whole account
/// underneath. It is how a bank with several accounts works, and it carries a
/// fact that matters more than the convenience — **the farm's account and a
/// co-founder's are the same kind of thing**. Both are a pair of hands the
/// money can be in. One of them simply belongs to nobody.
///
/// Whoever opens it gets his own account first, because that is the one he is
/// answerable for. The master gets the farm's, because his job is the whole
/// of it.
class AccountStrip extends StatefulWidget {
  const AccountStrip({super.key});

  @override
  State<AccountStrip> createState() => _AccountStripState();
}

class _AccountStripState extends State<AccountStrip> {
  /// Null until somebody picks, so the first build can choose for him.
  String? _chosen;

  String _openOn(FarmStore store, String me) {
    final picked = _chosen;
    if (picked != null) return picked;

    // A man working as the farm's account opens on the farm's account. He
    // has said which of the two he is being, and this page asking him again
    // every time he opens it is the app not listening.
    final session = context.read<Session>();
    if (session.asFarm) return farmAccountName;

    // His own, if he is one of them. The master's job is the whole farm, so
    // his own name is one tap away rather than the one in front of him.
    final isMaster = session.role == Role.master;
    if (!isMaster && me.trim().isNotEmpty) {
      for (final name in store.moneyHolders) {
        if (partyKey(name) == partyKey(me)) return name;
      }
    }
    return farmAccountName;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<FarmStore>();
    final me = context.watch<Session>().user?.name ?? '';
    final names = store.moneyHolders;
    final chosen = _openOn(store, me);
    final isFarm = partyKey(chosen) == partyKey(farmAccountName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final name in names)
                Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: _Name(
                    label: partyKey(name) == partyKey(me)
                        ? l.t2('%s (you)', name)
                        : name,
                    farm: partyKey(name) == partyKey(farmAccountName),
                    selected: partyKey(name) == partyKey(chosen),
                    onTap: () => setState(() => _chosen = name),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Account(name: chosen, isFarm: isFarm),
      ],
    );
  }
}

/// One account: what is in it, and everything that has gone through it.
class _Account extends StatelessWidget {
  const _Account({required this.name, required this.isFarm});

  final String name;
  final bool isFarm;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<FarmStore>();
    final hands = store.handsOf(name);
    final held = hands?.holding ?? 0;
    final partner = store.partners
        .where((p) => partyKey(p.name) == partyKey(name))
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // What is in it. Two figures on a co-founder's, because he has two
        // quite separate kinds of money with the farm: what he is holding of
        // its cash, and what he owns of the farm itself.
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: isFarm
                    ? l.t('In the farm\'s own keeping')
                    : held < 0
                    ? l.t('Out of his own pocket')
                    : l.t('Farm\'s cash on him'),
                value: rs(held.abs()),
                tone: held < 0 ? T.moneyDue : T.moneyIn,
                onTap: () => _open(context, name, AccountsFilter.all),
                note: hands == null
                    ? l.t('Nothing has gone through it yet')
                    : l.t3(
                        '%s in · %s out',
                        rs(hands.received),
                        rs(hands.paid),
                      ),
              ),
            ),
            if (partner != null) ...[
              const SizedBox(width: T.gap),
              Expanded(
                child: StatTile(
                  label: l.t('His own, in the farm'),
                  value: rs(partner.inTheFarm),
                  tone: T.accent700,
                  onTap: () => showMoneyLines(context, partner),
                  note: partner.stillToPayIn > 0
                      ? l.t2('%s still to come', rs(partner.stillToPayIn))
                      : l.t2('%s promised', rs(partner.pledged)),
                ),
              ),
            ],
            // The farm's own account has two figures as well, and the farm
            // was right to want them apart: what is actually in its keeping
            // is one thing, and what it owes the four of them is another.
            // Three of them are still paying their promise out of their own
            // pockets, so the cash the farm itself holds is small and the
            // debt behind it is not.
            if (isFarm) ...[
              const SizedBox(width: T.gap),
              Expanded(
                child: StatTile(
                  label: l.t('Owed to the co-founders'),
                  value: rs(_owedToThem(store)),
                  tone: T.moneyDue,
                  note: l.t('Their own money, in the farm'),
                ),
              ),
            ],
          ],
        ),

        // What is left of it once the co-founders have been paid back.
        //
        // The two figures above can be the same money seen twice: the farm
        // holds 8,600 and owes 8,600, because the 8,600 it holds is what
        // one of them paid in out of his own pocket. Saying so is the whole
        // point of this page — it is the figure a month is closed on, and
        // reading it off two tiles in your head is how it gets read wrong.
        if (isFarm && (held > 0 || _owedToThem(store) > 0)) ...[
          const SizedBox(height: T.gap),
          Builder(
            builder: (context) {
              final free = held - _owedToThem(store);
              return RegCard(
                stripe: free < 0 ? T.moneyDue : T.moneyIn,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.t('The farm\'s own, free and clear'),
                            style: T.bodyMid,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            free < 0
                                ? l.t(
                                    'It owes them more than it is holding. '
                                    'Nothing in this account is the farm\'s '
                                    'until that is paid back.',
                                  )
                                : free == 0
                                ? l.t(
                                    'Every rupee in the account is owed back '
                                    'to one of them.',
                                  )
                                : l.t('After paying them back'),
                            style: T.meta,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      rs(free),
                      style: T.num22.copyWith(
                        color: free < 0 ? T.moneyDue : T.moneyIn,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],

        // Still to come in, and still to go out. Neither is money the farm
        // has — one is owed to it and the other by it — so neither belongs
        // in the figure above, and both belong on the page.
        if (isFarm) ...[
          const SizedBox(height: T.gap),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: l.t('Still to come in'),
                  value: rs(store.money.receivable),
                  tone: T.moneyIn,
                  note: l.t('Sold and not yet paid for'),
                  onTap: () => _open(context, null, AccountsFilter.receivable),
                ),
              ),
              const SizedBox(width: T.gap),
              Expanded(
                child: StatTile(
                  label: l.t('Still to go out'),
                  value: rs(store.money.payable),
                  tone: T.moneyOut,
                  note: l.t('Bought and not yet paid for'),
                  onTap: () => _open(context, null, AccountsFilter.payable),
                ),
              ),
            ],
          ),
        ],

        // What is on its way to or from him, which is in nobody's hands.
        if ((hands?.onItsWay ?? 0) > 0 || (hands?.coming ?? 0) > 0) ...[
          const SizedBox(height: T.gap),
          RegCard(
            stripe: T.moneyDue,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((hands?.onItsWay ?? 0) > 0)
                  Text(
                    l.t2(
                      '%s on its way out, waiting on the other man',
                      rs(hands!.onItsWay),
                    ),
                    style: T.meta.copyWith(color: T.moneyDue),
                  ),
                if ((hands?.coming ?? 0) > 0)
                  Text(
                    l.t2(
                      '%s sent to him and not yet acknowledged',
                      rs(hands!.coming),
                    ),
                    style: T.meta.copyWith(color: T.moneyDue),
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: T.gap),
        IfCanWrite(
          child: GhostButton(
            label: l.t('Hand cash to somebody'),
            icon: Icons.swap_horiz,
            onPressed: () => showHandover(context),
          ),
        ),

        const SizedBox(height: 18),
        SectionTitle(l.t('What has gone through it')),
        const SizedBox(height: 6),
        _Statement(name: name),
      ],
    );
  }
}

/// Opening the entries behind a figure.
///
/// The store goes with it: this panel lives under a provider the navigator
/// does not sit beneath, and a page pushed without it reads an empty farm.
void _open(BuildContext context, String? who, AccountsFilter filter) {
  final store = context.read<FarmStore>();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider<FarmStore>.value(
        value: store,
        child: AccountsScreen(initialFilter: filter, initialParty: who),
      ),
    ),
  );
}

/// What the farm owes the four of them out of their own pockets.
///
/// Their own money that the farm has had the use of and has not been told
/// to count as investment — see the button on the holding card. Shown on
/// the farm's own account because that is where somebody reading "Rs 8,600
/// in the farm's keeping" needs to see it: the farm is not short of money
/// by accident, it is running on theirs.
num _owedToThem(FarmStore store) {
  var owed = store.owedToFounders;
  for (final p in store.partners) {
    final held = store.handsOf(p.name)?.holding ?? 0;
    if (held < 0) owed += -held;
  }
  return owed;
}

/// Every line that has touched one account, newest first, with what the
/// account stood at after each.
///
/// A running balance rather than a list of figures, because the question
/// anybody actually asks of an account is not "what happened" but "how did it
/// get to this".
class _Statement extends StatelessWidget {
  const _Statement({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<FarmStore>();
    final lines = accountLines(
      store.ledger,
      who: name,
      putIn: store.contributions,
    );

    if (lines.isEmpty) {
      return EmptyNote(
        l.t(
          'Nothing has gone through this account yet. Every entry with this '
          'name against it appears here.',
        ),
      );
    }

    // The running balance is read downwards from what is in the account now,
    // because the newest line is at the top.
    var running = lines.fold<num>(0, (a, line) => a + line.amount);

    return Column(
      children: [
        for (final line in lines)
          Builder(
            builder: (context) {
              final after = running;
              running -= line.amount;
              return _Line(line: line, after: after);
            },
          ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.line, required this.after});

  final AccountLine line;
  final num after;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final inward = line.amount >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: T.divider, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 46, child: Text(fmtDate(line.date), style: T.meta)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.what, style: T.bodyMid, maxLines: 2),
                if (line.detail.isNotEmpty)
                  Text(line.detail, style: T.meta, maxLines: 2),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                signedRs(line.amount.abs(), incoming: inward),
                style: T.bodyMid.copyWith(
                  color: inward ? T.moneyIn : T.moneyOut,
                ),
              ),
              Text(l.t2('%s after', rs(after)), style: T.meta),
            ],
          ),
        ],
      ),
    );
  }
}

class _Name extends StatelessWidget {
  const _Name({
    required this.label,
    required this.farm,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool farm;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(T.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 36,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? T.fill : T.surface,
          borderRadius: BorderRadius.circular(T.pill),
          border: Border.all(color: selected ? T.fill : T.n300, width: 1.3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (farm) ...[
              Icon(
                Icons.account_balance_outlined,
                size: 15,
                color: selected ? T.onFill : T.n700,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: T.bodyMid.copyWith(
                fontSize: 12.5,
                color: selected ? T.onFill : T.n700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
