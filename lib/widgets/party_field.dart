import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/words.dart';
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
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

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

  /// Case and stray spaces are not differences worth keeping people apart on.
  static String _key(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

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
    final needle = _key(typed);
    final known = context.watch<FarmStore>().partyBook;

    final hits = needle.isEmpty
        ? const <PartySummary>[]
        : known
              .where(
                (p) =>
                    _key(p.name).startsWith(needle) ||
                    _key(p.name).contains(' $needle'),
              )
              .toList();
    final exact = known.any((p) => _key(p.name) == needle);

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
        if (_show && needle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
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
                for (final p in hits)
                  _Option(party: p, onTap: () => _pick(p.name)),
                if (!exact)
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
          const Icon(Icons.add, size: 17, color: T.accent700),
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
