import 'package:flutter/material.dart';
import 'tokens.dart';

ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: T.accent,
        brightness: Brightness.light,
      ).copyWith(
        surface: T.bg,
        primary: T.accent,
        onPrimary: T.accent100,
        secondary: T.accent2,
        onSurface: T.text,
        outline: T.divider,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: T.bg,
    fontFamily: T.fontBody,
    splashFactory: InkSparkle.splashFactory,
    dividerColor: T.divider,
    dividerTheme: const DividerThemeData(
      color: T.divider,
      thickness: T.hairline,
      space: 0,
    ),
    textTheme: const TextTheme(
      displayLarge: T.title,
      headlineMedium: T.screenTitle,
      titleMedium: T.cardTitle,
      bodyMedium: T.body,
      labelSmall: T.meta,
    ).apply(fontFamily: T.fontBody),
    iconTheme: const IconThemeData(color: T.text, size: 20, weight: 300),
    appBarTheme: const AppBarTheme(
      backgroundColor: T.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: T.n100,
      hintStyle: T.body.copyWith(color: T.n500),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      border: _inputBorder(T.divider),
      enabledBorder: _inputBorder(T.divider),
      focusedBorder: _inputBorder(T.accent),
      errorBorder: _inputBorder(Colors.red.shade700),
      focusedErrorBorder: _inputBorder(Colors.red.shade700),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: T.accent900,
      contentTextStyle: T.body.copyWith(color: T.accent100),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(T.radius)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: T.bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(T.radius)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: T.bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(T.radius)),
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? T.accent : T.n500,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: T.accent,
      linearMinHeight: 6,
      linearTrackColor: T.n300,
    ),
  );
}

OutlineInputBorder _inputBorder(Color c) => OutlineInputBorder(
  borderRadius: const BorderRadius.all(Radius.circular(T.radius)),
  borderSide: BorderSide(color: c, width: T.hairline),
);
