import 'package:flutter/material.dart';

import '../i18n/words.dart';
import '../theme/tokens.dart';
import 'ui.dart';

/// Pick one name off a list, or clear the one already picked.
///
/// A dropdown would do for five customers and be unusable at fifty, which is
/// where a milk round ends up. So this is a sheet with a search box: type two
/// letters of a name and it is there. Returning null means "all of them"; the
/// caller cannot tell that apart from a cancel, so the sheet hands back a
/// [Picked] saying which happened.
Future<Picked?> pickOne(
  BuildContext context, {
  required String title,
  required List<String> options,
  required String allLabel,
  String? current,
}) => showModalBottomSheet<Picked>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(T.radius)),
  ),
  builder: (_) => _PickSheet(
    title: title,
    options: options,
    allLabel: allLabel,
    current: current,
  ),
);

/// What the sheet came back with. [value] null means every one of them.
class Picked {
  const Picked(this.value);

  final String? value;
}

class _PickSheet extends StatefulWidget {
  const _PickSheet({
    required this.title,
    required this.options,
    required this.allLabel,
    required this.current,
  });

  final String title;
  final List<String> options;
  final String allLabel;
  final String? current;

  @override
  State<_PickSheet> createState() => _PickSheetState();
}

class _PickSheetState extends State<_PickSheet> {
  final _search = TextEditingController();
  String _needle = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final needle = _needle.trim().toLowerCase();
    final shown = needle.isEmpty
        ? widget.options
        : widget.options
              .where((o) => o.toLowerCase().contains(needle))
              .toList();

    // Never taller than two thirds of the screen, and never so short that one
    // result sits alone in a tall empty sheet.
    final maxHeight = MediaQuery.of(context).size.height * 0.7;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: T.n300,
                borderRadius: BorderRadius.circular(T.pill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(T.pad, 14, T.pad, 10),
              child: Row(
                children: [
                  Expanded(child: SectionTitle(widget.title)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            if (widget.options.length > 8)
              Padding(
                padding: const EdgeInsets.fromLTRB(T.pad, 0, T.pad, 8),
                child: TextField(
                  controller: _search,
                  autofocus: true,
                  onChanged: (v) => setState(() => _needle = v),
                  decoration: InputDecoration(
                    hintText: l.t('Search'),
                    prefixIcon: const Icon(Icons.search, size: 19),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(T.radiusSm),
                    ),
                  ),
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(T.pad, 0, T.pad, T.pad),
                children: [
                  _Option(
                    label: widget.allLabel,
                    selected: widget.current == null,
                    onTap: () => Navigator.pop(context, const Picked(null)),
                  ),
                  if (shown.isEmpty)
                    EmptyNote(l.t('Nothing by that name.'))
                  else
                    for (final o in shown)
                      _Option(
                        label: o,
                        selected: o == widget.current,
                        onTap: () => Navigator.pop(context, Picked(o)),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(T.radiusXs),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: selected ? T.bodyMid : T.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selected) const Icon(Icons.check, size: 18, color: T.accent600),
          ],
        ),
      ),
    ),
  );
}

/// The button that opens one of those sheets.
///
/// Reads as a sentence when nothing is chosen — "Anyone", "Anything" — and as
/// the choice itself once one is, with a cross to undo it. Coloured only when
/// it is doing something, so a page with no filter on it looks quiet.
class PickPill extends StatelessWidget {
  const PickPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.onClear,
    this.chosen = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final bool chosen;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(T.pill),
      child: Container(
        height: 38,
        padding: EdgeInsets.only(left: 12, right: chosen ? 4 : 12),
        decoration: BoxDecoration(
          color: chosen ? T.accent100 : Colors.white,
          borderRadius: BorderRadius.circular(T.pill),
          border: Border.all(color: chosen ? T.accent600 : T.n300, width: 1.3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: chosen ? T.accent700 : T.n600),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                style: T.bodyMid.copyWith(
                  fontSize: 12.5,
                  color: chosen ? T.accent700 : T.n700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (chosen)
              IconButton(
                icon: const Icon(Icons.close, size: 15),
                color: T.accent700,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(7),
                onPressed: onClear,
              ),
          ],
        ),
      ),
    ),
  );
}
