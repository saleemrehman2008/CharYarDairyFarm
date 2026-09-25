import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/words.dart';
import '../models/models.dart';
import '../state/farm_store.dart';
import '../theme/tokens.dart';
import 'ui.dart';

/// What the entry is for — off the list, or written out.
///
/// The list is short on purpose and a real farm meets things nobody listed: a
/// tractor trolley, a tubewell repair, a wedding gift of milk. Those used to
/// go in as "Other", and a summary full of "Other" tells nobody anything. So
/// the last item on the list is a door.
///
/// Two things are checked on the way through that door, and only two, because
/// a form that argues with everything gets ignored.
///
/// The first is a word already in use somewhere else. "Rent" typed on the
/// Sale tab is not a new category, it is somebody on the wrong tab, and that
/// mistake does not just look untidy — it moves the profit. So it is named
/// and the tab it belongs on is named with it, and the person can still say
/// go on.
///
/// The second is only asked when the farm is spending: is this something the
/// farm keeps, or something it has spent. A listed category answers that by
/// being on a list. A typed one cannot, and getting it wrong takes a buffalo
/// out of that month's profit.
class CategoryField extends StatefulWidget {
  const CategoryField({
    super.key,
    required this.label,
    required this.type,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final TxnType type;
  final String value;

  /// The category, and what was said about it if it was typed. Null means it
  /// came off the list and [assetCategories] answers for it.
  final void Function(String category, bool? capital) onChanged;

  @override
  State<CategoryField> createState() => _CategoryFieldState();
}

/// The value the "write one out" row carries. Not a category anybody could
/// type: the leading space is folded away by [partyKey], so no typed word can
/// ever collide with it.
const _writeOne = ' write one out ';

class _CategoryFieldState extends State<CategoryField> {
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<FarmStore>();

    // The list, then whatever has been typed on this tab before — so a word
    // written once is a tap from then on and never gets spelled a second way.
    final listed = widget.type.categories;
    final seen = store.categoryBook[widget.type] ?? const <String>[];
    final extra =
        seen
            .where((c) => !listed.any((b) => partyKey(b) == partyKey(c)))
            .toList()
          ..sort();

    final options = [...listed, ...extra];
    // A category picked before this list was rebuilt — an old entry being
    // looked at — still has to have a row to sit on.
    if (!options.any((c) => partyKey(c) == partyKey(widget.value))) {
      options.add(widget.value);
    }

    return Picker<String>(
      label: widget.label,
      value: options.firstWhere(
        (c) => partyKey(c) == partyKey(widget.value),
        orElse: () => options.first,
      ),
      items: [
        for (final c in options) (c, l.t(c)),
        (_writeOne, l.t('Something else — write it out')),
      ],
      onChanged: (v) {
        if (v == _writeOne) {
          _writeOut(store);
        } else {
          widget.onChanged(v, null);
        }
      },
    );
  }

  Future<void> _writeOut(FarmStore store) async {
    final typed = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.radius)),
      ),
      // The store has to be handed down. A modal sheet is built from the
      // navigator's context, which sits above the provider this screen was
      // pushed with — so asking for it inside the sheet finds nothing and
      // the whole sheet comes up blank.
      builder: (_) => ChangeNotifierProvider<FarmStore>.value(
        value: store,
        child: _WriteOutSheet(type: widget.type),
      ),
    );
    if (!mounted || typed == null || typed.isEmpty) return;

    // Already on this tab, however it was spelled. Nothing to decide and
    // nothing to say: it is just that category.
    final here = [
      ...widget.type.categories,
      ...?store.categoryBook[widget.type],
    ];
    final same = here.where((c) => partyKey(c) == partyKey(typed));
    if (same.isNotEmpty) {
      widget.onChanged(same.first, null);
      return;
    }

    // On another tab. Worth stopping for, and worth saying which tab.
    final elsewhere = store
        .tabsUsing(typed)
        .where((t) => t != widget.type)
        .toList();
    if (elsewhere.isNotEmpty && mounted) {
      final goOn = await _alreadyThere(typed, elsewhere);
      if (!mounted || !goOn) return;
    }

    // Money going out under a word that is on no list. Which it is cannot be
    // looked up, so it is asked — once, here, and kept on the entry.
    bool? capital;
    if (widget.type == TxnType.purchase || widget.type == TxnType.expense) {
      capital = await _keepsOrSpent(typed);
      if (!mounted || capital == null) return;
    }
    widget.onChanged(typed, capital);
  }

  Future<bool> _alreadyThere(String typed, List<TxnType> tabs) async {
    final l = L.of(context);
    final where = tabs.map((t) => l.t(t.label)).join(', ');
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          l.t2('"%s" is already being used', typed),
          style: T.cardTitle,
        ),
        content: Text(
          l.t2(
            'It is on the %s tab. If that is where this belongs, go back and '
            'write it there — the summary keeps one word in one place. Make '
            'it here as well only if it is genuinely a different thing.',
            where,
          ),
          style: T.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.t('Cancel'), style: T.bodyMid),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l.t('Make it here anyway'),
              style: T.bodyMid.copyWith(color: T.accent700),
            ),
          ),
        ],
      ),
    );
    return yes ?? false;
  }

  /// Keeps it, or spent it. The whole of the difference between an investment
  /// and a cost, asked in one tap.
  Future<bool?> _keepsOrSpent(String typed) {
    final l = L.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          l.t2('Is "%s" something the farm keeps?', typed),
          style: T.cardTitle,
        ),
        content: Text(
          l.t(
            'A buffalo, a machine, a trolley — the farm still owns it '
            'afterwards, so the money moved but the profit did not. Feed, '
            'wages, bijli and repairs are spent and gone, and they do come '
            'off the profit.',
          ),
          style: T.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.t('Spent and gone'), style: T.bodyMid),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l.t('The farm keeps it'),
              style: T.bodyMid.copyWith(color: T.accent700),
            ),
          ),
        ],
      ),
    );
  }
}

/// The door itself: a box to write in, with whatever the books already carry
/// coming up underneath as it is typed.
class _WriteOutSheet extends StatefulWidget {
  const _WriteOutSheet({required this.type});

  final TxnType type;

  @override
  State<_WriteOutSheet> createState() => _WriteOutSheetState();
}

class _WriteOutSheetState extends State<_WriteOutSheet> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<FarmStore>();
    final typed = _field.text.trim();
    final needle = partyKey(typed);

    // Every word the books carry, on any tab, because the point of showing
    // them is to stop a second spelling of one that already exists.
    final all = <String>{
      for (final type in TxnType.values) ...type.categories,
      for (final list in store.categoryBook.values) ...list,
    }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final hits = needle.isEmpty
        ? const <String>[]
        : all
              .where(
                (c) =>
                    partyKey(c).startsWith(needle) ||
                    partyKey(c).contains(' $needle'),
              )
              .take(6)
              .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: T.pad,
        right: T.pad,
        top: T.pad,
        bottom: MediaQuery.of(context).viewInsets.bottom + T.pad,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.t('What is it for?'), style: T.cardTitle),
          const SizedBox(height: 4),
          Text(
            l.t2('It will be filed under %s.', l.t(widget.type.label)),
            style: T.meta,
          ),
          const SizedBox(height: 14),
          Field(
            label: l.t('Write it out'),
            controller: _field,
            hint: l.t('Tubewell repair, trolley, mazdoori…'),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          for (final c in hits) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => Navigator.pop(context, c),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    const Icon(
                      Icons.subdirectory_arrow_right,
                      size: 16,
                      color: T.n500,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l.t(c), style: T.bodyMid)),
                    Text(l.t('already there'), style: T.meta),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          PrimaryButton(
            label: l.t('Use this'),
            onPressed: typed.isEmpty
                ? null
                : () => Navigator.pop(context, typed),
          ),
          const SizedBox(height: 6),
          GhostButton(
            label: l.t('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
