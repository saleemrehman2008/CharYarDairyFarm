import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'reg_marks.dart';

/// A transparent hairline-bordered card with registration marks — the single
/// container every screen is built from.
class RegCard extends StatelessWidget {
  const RegCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(T.pad),
    this.onTap,
    this.dim = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  /// Blocked users and inactive rows render at 55% opacity.
  final bool dim;

  @override
  Widget build(BuildContext context) {
    Widget card = RegMarks(
      child: DecoratedBox(
        decoration: BoxDecoration(border: T.hair),
        child: Padding(padding: padding, child: child),
      ),
    );

    if (dim) card = Opacity(opacity: 0.55, child: card);
    if (onTap == null) return card;

    return InkWell(
      onTap: onTap,
      splashColor: T.accent100,
      highlightColor: T.accent100.withValues(alpha: 0.5),
      child: card,
    );
  }
}

/// Solid bronze, light text, 48 px tall, registration marks in the corners.
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
      child: RegMarks(
        color: enabled ? T.accent200 : T.n400,
        child: Material(
          color: enabled ? T.accent : T.n400,
          borderRadius: BorderRadius.circular(T.radius),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(T.radius),
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
        ? const Color(0xFF8C2F20)
        : T.accent700;
    return SizedBox(
      height: compact ? 34 : T.tap,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: BorderSide(color: onPressed == null ? T.n300 : T.divider),
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(T.radius)),
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
      TagTone.good => (const Color(0xFFE6EFE2), const Color(0xFF3D5A33)),
      TagTone.warn => (T.accent200, T.accent800),
      TagTone.bad => (const Color(0xFFF3E0DC), const Color(0xFF8C2F20)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(T.radius),
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

/// Square-cornered segmented control used for filters and either/or choices.
class Segmented<V> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.compact = false,
  });

  final V value;
  final List<(V, String)> options;
  final ValueChanged<V> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(border: T.hair),
    child: Row(
      children: [
        for (final (i, option) in options.indexed)
          Expanded(
            child: _Seg(
              label: option.$2,
              selected: option.$1 == value,
              first: i == 0,
              compact: compact,
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
    required this.first,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool first;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: compact ? 36 : T.tap,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? T.accent : Colors.transparent,
        border: first
            ? null
            : const Border(left: BorderSide(color: T.divider, width: 1)),
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
            color: selected ? T.accent100 : T.n700,
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
          child: Container(height: 6, color: i <= step ? T.accent : T.n300),
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
  Widget build(BuildContext context) => SizedBox(
    height: 6,
    child: LayoutBuilder(
      builder: (_, c) => Stack(
        children: [
          Container(color: T.n300),
          Container(width: c.maxWidth * fraction.clamp(0, 1), color: color),
        ],
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
        if (trailing != null) trailing!,
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
