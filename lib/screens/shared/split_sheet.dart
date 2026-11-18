import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/contribution_repo.dart';
import '../../services/txn_repo.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/ui.dart';

/// Who found the money for this entry, and how much of it each of them found.
///
/// The farm bought four cows for seventeen lakh and three of the four paid
/// for them — five, five and seven. One sauda, one entry, three pockets. The
/// books had nowhere to put that: an entry carried one name, so either the
/// whole seventeen lakh sat against one man or the purchase had to be torn
/// into three, which it never was.
///
/// So the entry is left exactly as it is — seventeen lakh, one line, four
/// cows hanging off it — and the split is written beside it. In rupees, never
/// in percentages: the farm said so plainly, because five and five and seven
/// is what happened and 29.4% is not.
///
/// Each man's share of it goes straight onto what he has put into the farm,
/// carrying the entry's own date rather than today's. Nothing is handed to
/// anybody, so nobody's cash holding moves — the money went from three
/// pockets to the cattle market without passing through the farm's hands.
Future<void> showSplitSheet(BuildContext context, Txn entry) {
  final store = context.read<FarmStore>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: T.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(T.radius)),
    ),
    builder: (_) => ChangeNotifierProvider<FarmStore>.value(
      value: store,
      child: _SplitSheet(entry: entry),
    ),
  );
}

class _SplitSheet extends StatefulWidget {
  const _SplitSheet({required this.entry});

  final Txn entry;

  @override
  State<_SplitSheet> createState() => _SplitSheetState();
}

class _SplitSheetState extends State<_SplitSheet> {
  final _boxes = <String, TextEditingController>{};

  /// The farm's own share, which used to be whatever nobody claimed.
  ///
  /// The farm hit this on a 24,480 load of feed that one co-founder had put
  /// 8,000 of his own money into. The sheet handed the other 16,480 to the
  /// farm's account and said the farm had paid it — which it had not. The
  /// bill was still owed. So the farm's share is a figure like any other
  /// now, and what nobody claims is what nobody has paid.
  final _farm = TextEditingController();

  bool _busy = false;
  bool _filled = false;

  @override
  void dispose() {
    for (final c in _boxes.values) {
      c.dispose();
    }
    _farm.dispose();
    super.dispose();
  }

  TextEditingController _box(String partnerId) =>
      _boxes.putIfAbsent(partnerId, TextEditingController.new);

  /// What is already written against this entry, put into the boxes the
  /// first time the sheet is built — so opening it again shows what is
  /// there rather than an empty form over the top of it.
  void _fillFromWhatIsThere(List<Contribution> mine) {
    if (_filled) return;
    _filled = true;
    for (final c in mine) {
      _box(c.partnerId).text = '${c.amount.round()}';
    }
    // Opening the sheet changes nothing by itself. On an entry already
    // settled the farm's box starts where the old line stood — the
    // remainder — and on one still owed it starts at what has actually
    // been paid against it, less the men's own money.
    final claimed = mine.fold<num>(0, (a, c) => a + c.amount);
    final farm = widget.entry.paid
        ? widget.entry.amount - claimed
        : widget.entry.paidSoFar - claimed;
    if (farm > 0) _farm.text = '${farm.round()}';
  }

  num get _farmShare => num.tryParse(_farm.text.trim()) ?? 0;

  /// What this sheet says has been paid: the men's own money and the
  /// farm's own cash. Whatever is left over is what nobody has paid.
  num get _paidSoFar => _typed + _farmShare;

  num get _typed => _boxes.values.fold<num>(
    0,
    (a, c) => a + (num.tryParse(c.text.trim()) ?? 0),
  );

  void _shareEqually(List<Partner> partners) {
    if (partners.isEmpty) return;
    // The odd rupee goes to the first of them rather than being lost, so the
    // split still adds up to the entry to the last rupee.
    final each = (widget.entry.amount / partners.length).floor();
    final over = widget.entry.amount.round() - each * partners.length;
    for (final (i, p) in partners.indexed) {
      _box(p.id).text = '${each + (i == 0 ? over : 0)}';
    }
    setState(() {});
  }

  /// Whether this sheet may also say how much of the entry has been paid.
  ///
  /// Only when no receipt stands against it. A receipt is money that moved
  /// and is vouched for; this sheet records whose pocket it came from, and
  /// it may not quietly rewrite a figure a receipt is holding up.
  bool _canSettle(FarmStore store) =>
      !widget.entry.type.isSettlement &&
      !store.ledger.any(
        (t) => t.settlesTxnId == widget.entry.id && !t.isDeleted,
      );

  Future<void> _save(FarmStore store, List<Contribution> mine) async {
    final l = L.read(context);
    final partners = store.partners;
    final amounts = {
      for (final p in partners) p.id: num.tryParse(_box(p.id).text.trim()) ?? 0,
    };

    final actor = context.read<Session>().actor;
    setState(() => _busy = true);
    try {
      await ContributionRepo.setSplit(
        actor,
        entry: widget.entry,
        partners: partners,
        existing: mine,
        amounts: amounts,
      );
      // And what that means for the bill itself. A man's own money paying
      // part of it means the supplier has been paid that much; what
      // nobody has claimed is what nobody has paid. Said on the sheet
      // before saving, so this is the promise being kept rather than
      // something happening behind it.
      if (_canSettle(store)) {
        await TxnRepo.saySettledSoFar(
          actor,
          widget.entry,
          _paidSoFar,
          periodIsOpen: store.periodIsOpen(widget.entry.monthId),
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, l.t2('Split saved · %s', rs(_typed)));
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<FarmStore>();
    final partners = store.partners;
    final mine = store.paidForEntry(widget.entry.id);
    _fillFromWhatIsThere(mine);

    final typed = _typed;
    final left = widget.entry.amount - typed - _farmShare;
    final over = left < 0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            T.pad,
            14,
            T.pad,
            T.pad,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: T.n400,
                    borderRadius: BorderRadius.circular(T.pill),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(l.t('Who paid for this?'), style: T.screenTitle),
              const SizedBox(height: 4),
              Text(
                l.t3(
                  '%s · %s. The entry does not change and is never split — '
                  'what is written here is whose money paid it.',
                  widget.entry.party.isEmpty
                      ? widget.entry.category
                      : widget.entry.party,
                  rs(widget.entry.amount),
                ),
                style: T.meta,
              ),
              const SizedBox(height: T.pad),

              if (partners.isEmpty)
                EmptyNote(
                  l.t('No co-founders on the record yet. Add them first.'),
                )
              else ...[
                for (final p in partners) ...[
                  _Line(
                    partner: p,
                    box: _box(p.id),
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: T.gap),
                ],

                // Whatever the four of them have not claimed, against the
                // hands it actually goes out through.
                //
                // This line used to say "the farm's own cash" and name
                // nobody, which is true and is not the whole truth. The farm
                // read it as the farm's own account paying, split an entry
                // two ways, and found the remainder sitting on Rafeeq as
                // money out of his own pocket — because Rafeeq is the name
                // on the entry as having handled it, and that is where the
                // books put the rest of it. The sheet promised one thing and
                // the books did another.
                //
                // So it names him. The farm's cash goes out through whoever
                // handled the entry, and if it was the farm's own account
                // that paid, then the farm's own account is who handled it
                // — one field on the entry, and this line says so.
                //
                // No box, because its figure is not a separate fact: it is
                // the entry less what the men have claimed. Type against a
                // man above and this comes down by it, in front of you.
                _FarmLine(
                  box: _farm,
                  left: over ? 0 : left,
                  short: over,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: T.gap),

                // What is typed against what the entry is for. The farm
                // asked for rupees and not percentages, so the only
                // arithmetic on the page is the one that has to add up.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (over
                                ? T.moneyOut
                                : left == 0
                                ? T.moneyIn
                                : T.moneyDue)
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(T.radiusXs),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(l.t('Put against it'), style: T.meta),
                          ),
                          Text(rs(typed), style: T.bodyMid),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        over
                            ? l.t2(
                                '%s more than the entry. Take it down before '
                                'saving.',
                                rs(-left),
                              )
                            : left == 0
                            ? l.t('Adds up to the entry exactly.')
                            : l.t2(
                                '%s of it has not been paid by anybody yet. '
                                'It stands in what the farm still owes.',
                                rs(left),
                              ),
                        style: T.meta.copyWith(
                          color: over
                              ? T.moneyOut
                              : left == 0
                              ? T.moneyIn
                              : T.moneyDue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                GhostButton(
                  label: l.t('Share it equally'),
                  icon: Icons.balance_outlined,
                  compact: true,
                  onPressed: _busy ? null : () => _shareEqually(partners),
                ),

                // What the farm's own rule does with each share, said
                // rather than asked. While a man still owes on what he
                // promised, his money pays that off; once he has paid it
                // in full, the next rupee is the farm's to give back.
                const SizedBox(height: T.pad),
                Kicker(l.t('What this does')),
                const SizedBox(height: 6),
                if (!over && _farmShare > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      l.t3(
                        '%s — %s came out of the farm\'s own cash, so '
                        'nobody\'s investment moves.',
                        l.t(farmAccountName),
                        rs(_farmShare),
                      ),
                      style: T.meta.copyWith(color: T.accent700),
                    ),
                  ),
                // What the entry itself will say afterwards. The sheet
                // promises it here so that saving holds no surprise.
                if (!over && _canSettle(store))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      left > 0
                          ? l.t3(
                              'The entry — %s of it paid, %s still owed.',
                              rs(_paidSoFar),
                              rs(left),
                            )
                          : l.t('The entry — paid in full, nothing owed.'),
                      style: T.meta.copyWith(color: T.moneyDue),
                    ),
                  ),
                for (final p in partners)
                  Builder(
                    builder: (context) {
                      final typed = num.tryParse(_box(p.id).text.trim()) ?? 0;
                      if (typed <= 0) return const SizedBox.shrink();
                      final cut = splitByPledge(
                        amount: typed,
                        pledged: p.pledged,
                        alreadyIn: p.invested,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(
                          cut.refundable <= 0
                              ? l.t3(
                                  '%s — %s goes onto his investment.',
                                  p.name,
                                  rs(cut.investment),
                                )
                              : cut.investment <= 0
                              ? l.t3(
                                  '%s — his promise is already paid, so the '
                                  'farm owes him %s back.',
                                  p.name,
                                  rs(cut.refundable),
                                )
                              : l.t4(
                                  '%s — %s finishes his promise, %s the farm '
                                  'owes him back.',
                                  p.name,
                                  rs(cut.investment),
                                  rs(cut.refundable),
                                ),
                          style: T.meta.copyWith(
                            color: cut.refundable > 0
                                ? T.moneyDue
                                : T.accent700,
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: T.pad),
                PrimaryButton(
                  label: l.t('Save who paid'),
                  icon: Icons.check,
                  busy: _busy,
                  onPressed: _busy || over ? null : () => _save(store, mine),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The farm's own account, carrying whatever the men have not claimed.
///
/// It takes no typing, because its figure is not a separate fact: an entry
/// is paid for by the men who claim part of it and by the farm, and whatever
/// none of them claims is the farm's by arithmetic. Given a box of its own
/// it could be made to disagree with the men above it, and a sheet that can
/// show two answers to one purchase is the thing these books exist to stop.
///
/// For one release this line carried the name of whoever handled the entry
/// instead, because that is where the books were putting the money. That was
/// the wrong half to change. Writing a split is the farm saying this much
/// was these men's own — so the rest, by its own account, was not anybody's
/// own, and it now comes off the farm's account where it always said it did.
/// It also put Rafeeq on the list twice, once as a man with a box and once
/// as this line, which is how a thing that is wrong usually announces itself.
/// The farm's own share, and what nobody has paid.
///
/// This used to be a grey box reading 'whatever is left' — the entry less
/// what the men had claimed, asserted as the farm's own cash. On a bill
/// nobody had paid yet that was simply untrue, and it was the farm that
/// found it: 8,000 of a 24,480 load of feed came out of one co-founder's
/// pocket and the sheet handed the other 16,480 to the farm's account,
/// while the bill sat in 'still to pay' all along.
///
/// So the farm types its own figure like anybody else, and what is left
/// after all of them is money nobody has paid.
class _FarmLine extends StatelessWidget {
  const _FarmLine({
    required this.box,
    required this.left,
    required this.short,
    required this.onChanged,
  });

  final TextEditingController box;

  /// What nobody has claimed once the farm has had its say.
  final num left;

  /// More has been typed than the entry comes to.
  final bool short;

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tone = short
        ? T.moneyOut
        : left > 0
        ? T.moneyDue
        : T.accent700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Field(
          label: l.t(farmAccountName),
          controller: box,
          keyboardType: TextInputType.number,
          hint: '0',
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 4),
        Text(
          short
              ? l.t(
                  'More has been put against the farm and the men above '
                  'than the entry comes to.',
                )
              : left > 0
              ? l.t2(
                  '%s of this entry is still paid by nobody. Leave it, and '
                  'that much stays owed.',
                  rs(left),
                )
              : l.t(
                  'Every rupee of this entry is accounted for — the farm '
                  'and the men above have it between them.',
                ),
          style: T.meta.copyWith(color: tone),
        ),
      ],
    );
  }
}

/// One co-founder's box, with what this would do to his total under it.
class _Line extends StatelessWidget {
  const _Line({
    required this.partner,
    required this.box,
    required this.onChanged,
  });

  final Partner partner;
  final TextEditingController box;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final typed = num.tryParse(box.text.trim()) ?? 0;
    // Only the part that counts towards his promise moves his total;
    // the rest is money the farm will hand back.
    final after =
        partner.invested +
        splitByPledge(
          amount: typed,
          pledged: partner.pledged,
          alreadyIn: partner.invested,
        ).investment;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Field(
          label: partner.name,
          controller: box,
          keyboardType: TextInputType.number,
          hint: '0',
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 4),
        // What his figure is about to become. The farm has been keeping
        // these by hand, so somebody opening this sheet needs to see
        // whether the money is about to be counted twice.
        Text(
          typed <= 0
              ? l.t2('Put in so far: %s', rs(partner.invested))
              : l.t3('Put in: %s → %s', rs(partner.invested), rs(after)),
          style: T.meta.copyWith(color: typed > 0 ? T.accent700 : T.n500),
        ),
      ],
    );
  }
}
