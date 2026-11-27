import 'package:flutter/material.dart';

import 'tokens.dart';

OutlineInputBorder _border(Color color, [double width = 1]) =>
    OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: color, width: width));

ThemeData appTheme() {
  const scheme = ColorScheme.light(
    primary: C.action,
    onPrimary: Colors.white,
    secondary: C.gold,
    onSecondary: C.goldInk,
    surface: C.surface,
    onSurface: C.ink,
    error: C.bad,
    onError: Colors.white,
    outline: C.line,
  );
  final base = ThemeData(useMaterial3: true, fontFamily: 'Inter', colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: C.canvas,
    dividerColor: C.lineSoft,
    dividerTheme: const DividerThemeData(color: C.lineSoft, thickness: 1, space: 1),
    splashFactory: InkSparkle.splashFactory,
    textTheme: base.textTheme.apply(bodyColor: C.ink, displayColor: C.ink, fontFamily: 'Inter'),
    appBarTheme: const AppBarTheme(
      backgroundColor: C.canvas,
      foregroundColor: C.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontFamily: 'Inter', color: C.ink, fontSize: 18, fontWeight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.action,
        foregroundColor: Colors.white,
        disabledBackgroundColor: C.lineStrong,
        disabledForegroundColor: C.surface,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.ink,
        backgroundColor: C.surface,
        side: const BorderSide(color: C.line),
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: C.ink,
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      hintStyle: const TextStyle(color: C.stone, fontSize: 14),
      border: _border(C.line),
      enabledBorder: _border(C.line),
      focusedBorder: _border(C.ink, 1.5),
      errorBorder: _border(C.bad),
      focusedErrorBorder: _border(C.bad, 1.5),
      disabledBorder: _border(C.lineSoft),
      errorStyle: const TextStyle(color: C.bad, fontSize: 12.5),
      helperStyle: const TextStyle(color: C.muted, fontSize: 12.5),
      counterStyle: const TextStyle(color: C.muted, fontSize: 12),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.ink : C.surface),
      side: const BorderSide(color: C.lineStrong, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: C.ink, linearTrackColor: C.chip),
    dialogTheme: DialogThemeData(
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: C.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: C.line)),
    ),
  );
}
