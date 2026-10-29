import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/contribution_repo.dart';
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
  bool _busy = false;
  bool _filled = false;

  @override
  void dispose() {
    for (final c in _boxes.values) {
      c.dispose();
    }
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
  }

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

  Future<void> _save(FarmStore store, List<Contribution> mine) async {
    final l = L.read(context);
    final partners = store.partners;
    final amounts = {
      for (final p in partners) p.id: num.tryParse(_box(p.id).text.trim()) ?? 0,
    };

    setState(() => _busy = true);
    try {
      await ContributionRepo.setSplit(
        context.read<Session>().actor,
        entry: widget.entry,
        partners: partners,
        existing: mine,
        amounts: amounts,
      );
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
    final left = widget.entry.amount - typed;
    final over = left < 0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(T.pad, 14, T.pad, T.pad),
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

                // The farm's own account, which was missing from this list
                // and should never have been.
                //
                // The farm buys things with its own cash now, not only out
                // of four pockets, and this sheet asked whose money paid
                // while offering no way to answer "the farm's". It was there
                // all along as the leftover at the bottom — "that part came
                // out of the farm's own cash" — which is a true sentence
                // nobody reads as a name on the list.
                //
                // So it is a line like the others and it has no box: its
                // figure is whatever the four of them have not claimed. A
                // box would be a second place to say the same thing, and
                // two places to write one figure is how they come to
                // disagree. Type against a man and the farm's share comes
                // down by it, in front of you.
                _FarmLine(amount: over ? 0 : left, short: over),
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
                                '%s of it is left — that part came out of the '
                                'farm\'s own cash.',
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
                if (!over && left > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      l.t3(
                        '%s — %s came out of the farm\'s own cash, so '
                        'nobody\'s investment moves.',
                        l.t(farmAccountName),
                        rs(left),
                      ),
                      style: T.meta.copyWith(color: T.accent700),
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

/// The farm's own account on the list, carrying whatever is left.
///
/// It looks like the others and takes no typing, because its figure is not a
/// separate fact: an entry is paid for by the four of them and by the farm,
/// and whatever none of the four claims is the farm's by arithmetic. Given a
/// box of its own it could be made to disagree with the men above it, and a
/// sheet that can show two answers to one purchase is the thing these books
/// exist to stop.
class _FarmLine extends StatelessWidget {
  const _FarmLine({required this.amount, required this.short});

  final num amount;

  /// More has been typed than the entry comes to, so there is nothing left
  /// for the farm and a figure above has to come down first.
  final bool short;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tone = short
        ? T.moneyOut
        : amount > 0
        ? T.accent700
        : T.n500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Kicker(l.t(farmAccountName)),
        const SizedBox(height: 5),
        Container(
          height: T.tap,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: T.n100,
            borderRadius: T.roundSm,
            border: Border.all(color: T.divider),
          ),
          child: Row(
            children: [
              Icon(Icons.account_balance_outlined, size: 16, color: tone),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rs(short ? 0 : amount),
                  style: T.body.copyWith(color: tone),
                ),
              ),
              Text(l.t('whatever is left'), style: T.meta),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          short
              ? l.t(
                  'Nothing left for the farm — more has been put against '
                  'the men above than the entry comes to.',
                )
              : amount > 0
              ? l.t(
                  'The farm\'s own cash paid this part. Type against a man '
                  'above and this comes down by it.',
                )
              : l.t('The four of them paid all of it between them.'),
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
