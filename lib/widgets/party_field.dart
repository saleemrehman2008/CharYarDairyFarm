import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/words.dart';
import '../models/models.dart';
import '../state/farm_store.dart';
import '../theme/tokens.dart';
import '../util/money.dart';
import 'ui.dart';

/// Whose entry this is, taken off the farm's own books as it is typed.
///
/// One customer written two ways is two customers as far as the books are
/// concerned: Kashif on Monday and kashif on Tuesday splits a man's account in
/// half, and neither half ever adds up to what he owes. So the names already
/// in the ledger come up from the first letter, and picking one is a tap.
///
/// No warnings, no second-guessing. The list opens on the first letter, so
/// nobody is typing out a whole name for the app to have an opinion about —
/// and case is not a difference at all: type `kashif` and the entry is filed
/// under `Kashif`, because that is the spelling the books already carry.
class PartyField extends StatefulWidget {
  const PartyField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.offer = const [],
    this.offerNote = '',
    this.onlyOffered = false,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  /// Names worth offering before a letter has been typed.
  ///
  /// The farm's own people, where the heading already says who this will
  /// be: pick Salaries and the men on the wage list belong under the box
  /// at once. The ordinary list cannot do that — it is built from whoever
  /// the farm has traded with, so a man taken on last week and not yet
  /// paid is not in it, and tapping the box showed nothing at all.
  final List<String> offer;

  /// One line saying what these names are.
  final String offerNote;

  /// Nobody but the offered names will do.
  ///
  /// A wage goes to somebody on the wage list or it goes nowhere: an
  /// advance paid to a name typed into the box, with the man put on the
  /// list afterwards, is two records of one man and a wage that cannot find
  /// the advance to take it off.
  final bool onlyOffered;

  @override
  State<PartyField> createState() => _PartyFieldState();
}

class _PartyFieldState extends State<PartyField> {
  final _focus = FocusNode();
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!mounted) return;
      setState(() => _show = _focus.hasFocus);
    });
    widget.controller.addListener(_redraw);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_redraw);
    _focus.dispose();
    super.dispose();
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  void _pick(String name) {
    widget.controller
      ..text = name
      ..selection = TextSelection.collapsed(offset: name.length);
    widget.onChanged?.call(name);
    _focus.unfocus();
    setState(() => _show = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final typed = widget.controller.text;
    final needle = partyKey(typed);
    final known = context.watch<FarmStore>().partyBook;

    bool matches(String name) =>
        partyKey(name).startsWith(needle) ||
        partyKey(name).contains(' $needle');

    final hits = needle.isEmpty || widget.onlyOffered
        ? const <PartySummary>[]
        : known.where((p) => matches(p.name)).toList();

    // The offered names, minus any the ordinary list already carries, so
    // one man never appears twice under his own box.
    final mine = [
      for (final name in widget.offer)
        if (needle.isEmpty || matches(name))
          if (!hits.any((p) => partyKey(p.name) == partyKey(name))) name,
    ];

    final exact =
        known.any((p) => partyKey(p.name) == needle) ||
        widget.offer.any((n) => partyKey(n) == needle);

    final open = _show && (needle.isNotEmpty || mine.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Field(
          label: widget.label,
          controller: widget.controller,
          hint: widget.hint,
          focusNode: _focus,
          textCapitalization: TextCapitalization.words,
          onChanged: widget.onChanged,
        ),
        if (open) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: T.surface,
              borderRadius: BorderRadius.circular(T.radiusSm),
              border: Border.all(color: T.n200),
              boxShadow: T.shadow,
            ),
            // Tall enough for five, and scrolls past that. Bounded, because a
            // list with no ceiling inside a page has no height to lay out in.
            constraints: const BoxConstraints(maxHeight: 248),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                if (mine.isNotEmpty) ...[
                  if (widget.offerNote.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                      child: Text(widget.offerNote, style: T.meta),
                    ),
                  for (final name in mine)
                    _NewOption(
                      label: name,
                      note: l.t('On the wage list'),
                      onTap: () => _pick(name),
                    ),
                ],
                for (final p in hits)
                  _Option(party: p, onTap: () => _pick(p.name)),
                if (widget.onlyOffered && mine.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                    child: Text(
                      needle.isEmpty
                          ? l.t(
                              'Nobody is on the wage list yet. '
                              'More → Wages puts them on it.',
                            )
                          : l.t(
                              'Nobody of that name is on the wage list. '
                              'Put him on it first, under More → Wages.',
                            ),
                      style: T.meta.copyWith(color: T.moneyDue),
                    ),
                  ),
                if (!widget.onlyOffered && !exact && needle.isNotEmpty)
                  _NewOption(
                    label: l.t2('New name — "%s"', typed.trim()),
                    note: l.t('Not written down before'),
                    onTap: () => _pick(typed.trim()),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.party, required this.onTap});

  final PartySummary party;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    party.name,
                    style: T.bodyMid,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(l.t2('%s entries', party.entries), style: T.meta),
                ],
              ),
            ),
            // What they still owe, which is how two men with similar names are
            // told apart at a glance.
            if (party.owed > 0)
              Text(
                l.t2('%s owed', rs(party.owed)),
                style: T.meta.copyWith(
                  color: T.moneyGet,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NewOption extends StatelessWidget {
  const _NewOption({
    required this.label,
    required this.note,
    required this.onTap,
  });

  final String label;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        children: [
          Icon(Icons.add, size: 17, color: T.accent700),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: T.bodyMid.copyWith(color: T.accent700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(note, style: T.meta),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
