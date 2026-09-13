import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../theme/tokens.dart';
import '../util/money.dart';

/// A white, rounded, softly lifted card — the single container every screen
/// is built from.
///
/// This used to be a transparent box with a hairline border and printer's
/// registration marks in the corners. On a phone in daylight that reads as one
/// flat grey sheet with nothing on it to grab, so the card now has its own
/// surface and sits slightly above the page.
class RegCard extends StatelessWidget {
  const RegCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(T.pad),
    this.onTap,
    this.dim = false,
    this.stripe,
    this.wash,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  /// Blocked users and inactive rows render at 55% opacity.
  final bool dim;

  /// A thick edge down the left, for a row whose state should read from
  /// across a courtyard: green for done, a soft red for still to go.
  final Color? stripe;

  /// A faint tint behind the card, to go with the stripe.
  final Color? wash;

  @override
  Widget build(BuildContext context) {
    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: wash ?? Colors.white,
        borderRadius: T.round,
        boxShadow: T.shadow,
      ),
      child: ClipRRect(
        borderRadius: T.round,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            splashColor: T.accent100,
            highlightColor: T.accent100.withValues(alpha: 0.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The stripe is the card's own edge, so it runs the full
                // height however tall the row grows.
                if (stripe != null) Container(width: 4, color: stripe),
                Expanded(
                  child: Padding(padding: padding, child: child),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (dim) card = Opacity(opacity: 0.55, child: card);
    return card;
  }
}

/// The headline figure on a page: white on the farm's navy-to-blue wash.
///
/// Only one of these belongs on a screen — it is the answer to "how are we
/// doing", and a page with three of them has no answer at all.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.label,
    required this.value,
    this.note,
    this.trailing,
    this.gradient,
    this.onTap,
  });

  final String label;
  final String value;
  final String? note;

  /// A chip on the same line as the label — "Open", "Sealed", a period name.
  final Widget? trailing;

  /// Overrides the navy wash, for a page that has taken a filter's colour.
  final LinearGradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: gradient ?? T.heroWash,
      borderRadius: T.round,
      boxShadow: T.shadowLift,
    ),
    child: ClipRRect(
      borderRadius: T.round,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label.toUpperCase(),
                        style: T.kicker.copyWith(color: T.accent200),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ?trailing,
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: T.num36.copyWith(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (note != null) ...[
                  const SizedBox(height: 4),
                  Text(note!, style: T.meta.copyWith(color: T.accent200)),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// A figure in a small card with a coloured top edge — the pair of tiles under
/// the hero. The edge carries the meaning, so the tiles read at a glance.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.tone,
    this.note,
    this.onTap,
  });

  final String label;
  final String value;
  final Color tone;
  final String? note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: T.round,
      boxShadow: T.shadow,
    ),
    child: ClipRRect(
      borderRadius: T.round,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 3, color: tone),
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: T.kicker,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value, style: T.num26.copyWith(color: tone)),
                    ),
                    if (note != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        note!,
                        style: T.meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// One square in the grid of things a person can go and do: icon in a tinted
/// rounded square, name underneath.
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.tone,
    this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final Color tone;
  final VoidCallback? onTap;
  final int badge;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: T.roundSm,
      boxShadow: T.shadow,
    ),
    child: ClipRRect(
      borderRadius: T.roundSm,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(T.radiusXs + 3),
                      ),
                      child: Icon(icon, size: 21, color: tone),
                    ),
                    if (badge > 0)
                      Positioned(
                        right: -5,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: T.pending,
                            borderRadius: BorderRadius.circular(T.pill),
                          ),
                          child: Text(
                            '$badge',
                            style: T.meta.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: T.meta.copyWith(
                    color: T.text,
                    fontSize: 11.5,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Three to a row on a phone, more on a tablet — sized by the tiles rather
/// than by a fixed count, so nothing stretches across a wide screen.
class ActionGrid extends StatelessWidget {
  const ActionGrid({super.key, required this.tiles});

  final List<ActionTile> tiles;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, c) {
      final columns = (c.maxWidth / 118).floor().clamp(3, 6);
      const gap = 9.0;
      final side = (c.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final t in tiles) SizedBox(width: side, child: t)],
      );
    },
  );
}

/// A rupee figure written in the colour of its state: deep when the money has
/// moved, pale when it is still only owed.
class Money extends StatelessWidget {
  const Money(
    this.amount, {
    super.key,
    required this.incoming,
    required this.settled,
    this.style,
  });

  final num amount;
  final bool incoming;
  final bool settled;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(
    rs(amount),
    style: (style ?? T.bodyMid).copyWith(
      color: T.money(incoming: incoming, settled: settled),
      fontWeight: T.moneyWeight(settled),
    ),
  );
}

/// The one action a screen is really for: the logo's blue, rounded, lifted.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.busy = false,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [T.accent700, T.accent600],
                )
              : null,
          color: enabled ? null : T.n300,
          borderRadius: T.roundSm,
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: Color(0x4D2277AF),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: T.roundSm,
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: T.accent100,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 18, color: T.accent100),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: T.bodyMid.copyWith(color: T.accent100),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hairline-outlined button for secondary actions (Approve, Mark paid, Add).
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.danger = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fg = onPressed == null
        ? T.n500
        : danger
        ? T.alert
        : T.accent700;
    return SizedBox(
      height: compact ? 34 : T.tap,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          backgroundColor: Colors.white,
          side: BorderSide(
            color: onPressed == null ? T.n300 : fg.withValues(alpha: 0.45),
            width: 1.4,
          ),
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(T.radiusSm)),
          ),
          textStyle: T.bodyMid,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            Text(label, style: T.bodyMid.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}

enum TagTone { neutral, accent, good, warn, bad }

/// The farm's logo, on the navy it was drawn for.
///
/// The lockup is silver and white on a dark ground — put it straight onto the
/// app's pale pages and half of it disappears. So it keeps its own ground
/// wherever it is shown, which is also what a logo is supposed to have.
class FarmLogo extends StatelessWidget {
  const FarmLogo({super.key, this.width = 180, this.mark = false});

  final double width;

  /// The roundel alone. At 36 points the whole lockup is a smudge; one mark
  /// is still recognisable.
  final bool mark;

  @override
  Widget build(BuildContext context) {
    // Decode at the size it will be drawn at, times the screen's own scale.
    // Without this the whole picture is decoded at full size into memory for
    // a 36-point badge, which is most of what the app was doing while it
    // looked like it was still loading.
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 3;
    final cache = (width * ratio).round();

    if (mark) {
      // The mark is drawn on its ground already.
      return ClipRRect(
        borderRadius: BorderRadius.circular(T.radiusXs),
        child: Image.asset(
          'assets/mark.png',
          width: width,
          height: width,
          cacheWidth: cache,
        ),
      );
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: width * 0.07,
        vertical: width * 0.06,
      ),
      decoration: BoxDecoration(color: T.accent900, borderRadius: T.roundSm),
      child: Image.asset('assets/logo.png', width: width, cacheWidth: cache),
    );
  }
}

/// Small status chip: "Open", "Pending", "unpaid", "Sheets synced".
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.tone = TagTone.neutral});

  final String label;
  final TagTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      TagTone.neutral => (T.n200, T.n700),
      TagTone.accent => (T.accent100, T.accent700),
      TagTone.good => (T.moneyInWash, T.moneyIn),
      TagTone.warn => (T.moneyDueWash, T.moneyDue),
      TagTone.bad => (T.pendingWash, T.pending),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(T.pill),
      ),
      child: Text(
        label,
        style: T.meta.copyWith(
          color: fg,
          fontWeight: FontWeight.w500,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Uppercase 11 px label above a number or section.
class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: T.kicker);
}

/// Rounded segmented control used for filters and either/or choices.
class Segmented<V> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.compact = false,
    this.tone,
  });

  final V value;
  final List<(V, String)> options;
  final ValueChanged<V> onChanged;
  final bool compact;

  /// The colour the chosen segment takes. Defaults to the app's blue; a
  /// filtered page passes its own so the control matches the page.
  final Color? tone;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: T.n200,
      borderRadius: BorderRadius.circular(T.radiusSm),
    ),
    child: Row(
      children: [
        for (final option in options)
          Expanded(
            child: _Seg(
              label: option.$2,
              selected: option.$1 == value,
              compact: compact,
              tone: tone ?? T.accent,
              onTap: () => onChanged(option.$1),
            ),
          ),
      ],
    ),
  );
}

class _Seg extends StatelessWidget {
  const _Seg({
    required this.label,
    required this.selected,
    required this.compact,
    required this.tone,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool compact;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(T.radiusXs),
      child: Container(
        height: compact ? 32 : 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? tone : Colors.transparent,
          borderRadius: BorderRadius.circular(T.radiusXs),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: tone.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: T.bodyMid.copyWith(
              fontSize: compact ? 12 : 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? Colors.white : T.n700,
            ),
          ),
        ),
      ),
    ),
  );
}

/// The 4-segment order progress bar, and the thin profit bar on Home.
class StepBar extends StatelessWidget {
  const StepBar({super.key, required this.step, this.steps = 4});

  final int step;
  final int steps;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 1; i <= steps; i++) ...[
        if (i > 1) const SizedBox(width: 3),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              // Each segment carries its own depth, so a finished bar is dark
              // all the way and a new one is barely there.
              color: i <= step ? T.stage(i, steps: steps) : T.n300,
              borderRadius: BorderRadius.circular(T.pill),
            ),
          ),
        ),
      ],
    ],
  );
}

/// Single filled bar — profit over sales.
class RatioBar extends StatelessWidget {
  const RatioBar({super.key, required this.fraction, this.color = T.accent});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(T.pill),
    child: SizedBox(
      height: 7,
      child: LayoutBuilder(
        builder: (_, c) => Stack(
          children: [
            Container(color: T.n300),
            Container(width: c.maxWidth * fraction.clamp(0, 1), color: color),
          ],
        ),
      ),
    ),
  );
}

/// Labelled form field, 44 px tall, square corners.
class Field extends StatelessWidget {
  const Field({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.prefix,
    this.onChanged,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? prefix;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Kicker(label),
      const SizedBox(height: 5),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        minLines: maxLines,
        onChanged: onChanged,
        textCapitalization: textCapitalization,
        inputFormatters: keyboardType == TextInputType.number
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
            : null,
        style: T.body,
        decoration: InputDecoration(
          hintText: hint,
          prefixText: prefix,
          prefixStyle: T.body.copyWith(color: T.n600),
        ),
      ),
    ],
  );
}

/// Square-cornered dropdown matching the fields.
class Picker<V> extends StatelessWidget {
  const Picker({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final V value;
  final List<(V, String)> items;
  final ValueChanged<V> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Kicker(label),
      const SizedBox(height: 5),
      DropdownButtonFormField<V>(
        initialValue: value,
        isExpanded: true,
        style: T.body,
        dropdownColor: T.bg,
        borderRadius: BorderRadius.circular(T.radius),
        icon: const Icon(Icons.expand_more, size: 18),
        items: [
          for (final (v, label) in items)
            DropdownMenuItem(
              value: v,
              child: Text(label, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    ],
  );
}

/// Section heading above a list.
/// A setting you turn on or off, with room to say what it does.
///
/// [why] is shown when the row cannot be used — a switch that is greyed out
/// with no explanation is just a broken control.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.note,
    this.why,
    this.enabled = true,
  });

  final String title;
  final String? note;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? why;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final live = enabled && onChanged != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: live ? 1 : 0.45,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: T.cardTitle),
                    if (note != null)
                      Text(note!, style: T.meta.copyWith(fontSize: 11.5)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Switch(
                value: value,
                onChanged: live ? onChanged : null,
                activeThumbColor: Colors.white,
                activeTrackColor: T.moneyIn,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: T.n300,
                trackOutlineColor: const WidgetStatePropertyAll(
                  Colors.transparent,
                ),
              ),
            ],
          ),
        ),
        if (!live && why != null) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: T.moneyDueWash,
              borderRadius: BorderRadius.circular(T.radiusXs),
            ),
            child: Text(
              why!,
              style: T.meta.copyWith(color: T.moneyDue, fontSize: 11.5),
            ),
          ),
        ],
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(child: Text(text, style: T.cardTitle)),
        ?trailing,
      ],
    ),
  );
}

/// Quiet placeholder for an empty list.
class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Text(text, style: T.meta),
  );
}

/// Dark bar above the tab bar, 2.4 s.
void toast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 2400),
        margin: const EdgeInsets.fromLTRB(T.pad, 0, T.pad, 8),
      ),
    );
}

/// What the person settling an entry said happened to the money.
class Settlement {
  const Settlement({required this.payVia, required this.handledBy});

  /// Null when nothing was collected — the entry stays owed.
  final PayVia? payVia;
  final String handledBy;

  bool get collected => payVia != null;
}

/// Asks how the money moved and who handled it, before settling an entry.
///
/// Returns null if the sheet is dismissed, so the caller can leave the entry
/// alone rather than settling it on a guess. With [allowUnpaid] the sheet also
/// offers "nothing taken", which is how a delivery made on trust is recorded.
Future<Settlement?> askSettlement(
  BuildContext context, {
  required bool incoming,
  required String party,
  required num amount,
  bool allowUnpaid = false,
}) {
  var via = PayVia.cash;
  final who = TextEditingController();
  // Money that moved without a name against it is money nobody can be asked
  // about later, so the sheet will not close until there is one.
  var named = false;

  return showModalBottomSheet<Settlement>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        left: T.pad,
        right: T.pad,
        top: T.pad,
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom + T.pad,
      ),
      child: StatefulBuilder(
        builder: (context, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              incoming ? 'Money received' : 'Money paid',
              style: T.screenTitle,
            ),
            const SizedBox(height: 4),
            Text('$party · ${rs(amount)}', style: T.meta),
            const SizedBox(height: T.pad),
            const Kicker('How'),
            const SizedBox(height: 6),
            Segmented<PayVia>(
              value: via,
              compact: true,
              options: [for (final v in PayVia.values) (v, v.label)],
              onChanged: (v) => setSheetState(() => via = v),
            ),
            const SizedBox(height: T.gap),
            Field(
              label: incoming ? 'Received by' : 'Paid by',
              controller: who,
              hint: incoming ? 'Who took the money' : 'Who handed it over',
              onChanged: (v) =>
                  setSheetState(() => named = v.trim().isNotEmpty),
            ),
            const SizedBox(height: 6),
            Text(
              named
                  ? ' '
                  : incoming
                  ? 'Who took the money? Needed before this can be saved.'
                  : 'Who handed it over? Needed before this can be saved.',
              style: T.meta.copyWith(color: named ? T.n600 : T.alert),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Save',
              onPressed: named
                  ? () => Navigator.pop(
                      sheetContext,
                      Settlement(payVia: via, handledBy: who.text.trim()),
                    )
                  : null,
            ),
            if (allowUnpaid) ...[
              const SizedBox(height: 10),
              GhostButton(
                label: 'Nothing taken — they still owe it',
                onPressed: named
                    ? () => Navigator.pop(
                        sheetContext,
                        Settlement(payVia: null, handledBy: who.text.trim()),
                      )
                    : null,
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  ).whenComplete(who.dispose);
}

/// Square-cornered confirm dialog; returns true only on the primary action.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String body,
  String confirmLabel = 'Confirm',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: T.screenTitle),
      content: Text(body, style: T.body),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      actions: [
        GhostButton(
          label: 'Cancel',
          onPressed: () => Navigator.pop(ctx, false),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 150,
          child: PrimaryButton(
            label: confirmLabel,
            height: T.tap,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}
