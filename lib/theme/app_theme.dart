import 'package:flutter/material.dart';
import 'tokens.dart';

/// The Material theme for the skin that is on right now.
///
/// Nothing here picks a colour — every one comes from [T], so switching the
/// skin and rebuilding is the whole of it. Called again on every change.
ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: T.accent,
        brightness: T.isDark ? Brightness.dark : Brightness.light,
      ).copyWith(
        surface: T.bg,
        primary: T.accent,
        onPrimary: T.isDark ? T.accent100 : Colors.white,
        secondary: T.accent2,
        onSurface: T.text,
        outline: T.divider,
      );

  return ThemeData(
    useMaterial3: true,
    brightness: T.isDark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: T.bg,
    fontFamily: T.fontBody,
    splashFactory: InkSparkle.splashFactory,
    dividerColor: T.divider,
    dividerTheme: DividerThemeData(
      color: T.divider,
      thickness: T.hairline,
      space: 0,
    ),
    textTheme: TextTheme(
      displayLarge: T.title,
      headlineMedium: T.screenTitle,
      titleMedium: T.cardTitle,
      bodyMedium: T.body,
      labelSmall: T.meta,
    ).apply(fontFamily: T.fontBody),
    iconTheme: IconThemeData(color: T.text, size: 20, weight: 300),
    appBarTheme: AppBarTheme(
      backgroundColor: T.bg,
      foregroundColor: T.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      // On a dark skin a white field is a hole in the page; the field takes
      // the raised surface instead, same as a card sitting on a card.
      fillColor: T.isDark ? T.raised : Colors.white,
      hintStyle: T.body.copyWith(color: T.n500),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      border: _inputBorder(T.divider),
      enabledBorder: _inputBorder(T.divider),
      focusedBorder: _inputBorder(T.accent),
      errorBorder: _inputBorder(T.alert),
      focusedErrorBorder: _inputBorder(T.alert),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: T.isDark ? T.raised : T.accent900,
      contentTextStyle: T.body.copyWith(color: T.isDark ? T.text : T.accent100),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(T.radius)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: T.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(T.radius)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: T.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(T.radius)),
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? T.accent : T.n500,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: T.accent,
      linearMinHeight: 6,
      linearTrackColor: T.n300,
    ),
  );
}

OutlineInputBorder _inputBorder(Color c) => OutlineInputBorder(
  borderRadius: const BorderRadius.all(Radius.circular(T.radiusSm)),
  borderSide: BorderSide(color: c, width: T.hairline),
);
