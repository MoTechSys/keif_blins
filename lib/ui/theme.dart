/// theme.dart — سمة التطبيق (كحلي داكن + ذهبي) | كيف الضيافة
library;

import 'package:flutter/material.dart';

class C {
  static const bg = Color(0xFF0B1630);
  static const bg2 = Color(0xFF101E3E);
  static const card = Color(0xFF16264B);
  static const card2 = Color(0xFF1C2F5A);
  static const line = Color(0xFF26396B);
  static const gold = Color(0xFFC9A961);
  static const goldDark = Color(0xFFA88938);
  static const goldLight = Color(0xFFDFC689);
  static const text = Color(0xFFF3EEE2);
  static const muted = Color(0xFF98A3C2);
  static const red = Color(0xFFE05563);
  static const green = Color(0xFF3FC380);
  static const amber = Color(0xFFE8B84A);
  static const blue = Color(0xFF5B9CF6);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  const font = 'Tajawal';
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    colorScheme: const ColorScheme.dark(
      primary: C.gold,
      onPrimary: C.bg,
      secondary: C.goldLight,
      surface: C.card,
      onSurface: C.text,
      error: C.red,
    ),
    textTheme: base.textTheme.apply(fontFamily: font, bodyColor: C.text, displayColor: C.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: C.bg,
      foregroundColor: C.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: font, fontSize: 19, fontWeight: FontWeight.w800, color: C.text),
    ),
    cardTheme: CardThemeData(
      color: C.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: C.line)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: C.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(fontFamily: font, fontSize: 18, fontWeight: FontWeight.w800, color: C.text),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: C.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      showDragHandle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.bg2,
      labelStyle: const TextStyle(color: C.muted, fontFamily: font),
      hintStyle: const TextStyle(color: C.muted, fontFamily: font),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.gold, width: 1.4)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.red)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.red, width: 1.4)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.gold,
        foregroundColor: C.bg,
        textStyle: const TextStyle(fontFamily: font, fontWeight: FontWeight.w800, fontSize: 15),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.gold,
        side: const BorderSide(color: C.gold),
        textStyle: const TextStyle(fontFamily: font, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: C.goldLight, textStyle: const TextStyle(fontFamily: font, fontWeight: FontWeight.w700)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: C.bg2,
      indicatorColor: C.gold.withValues(alpha: 0.18),
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: font,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: s.contains(WidgetState.selected) ? C.gold : C.muted,
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? C.gold : C.muted, size: 24)),
    ),
    dividerTheme: const DividerThemeData(color: C.line, thickness: 1, space: 1),
    listTileTheme: const ListTileThemeData(iconColor: C.gold, textColor: C.text),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.card2,
      contentTextStyle: const TextStyle(fontFamily: font, color: C.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: C.bg2,
      selectedColor: C.gold.withValues(alpha: 0.2),
      labelStyle: const TextStyle(fontFamily: font, color: C.text, fontWeight: FontWeight.w700),
      side: const BorderSide(color: C.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.bg : C.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.gold : C.line),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: C.gold),
    popupMenuTheme: PopupMenuThemeData(
      color: C.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: C.line)),
      textStyle: const TextStyle(fontFamily: font, color: C.text),
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(textStyle: TextStyle(fontFamily: font, color: C.text)),
  );
}

/// نص ذهبي كبير للمبالغ
TextStyle moneyStyle(double size, {Color color = C.text}) =>
    TextStyle(fontSize: size, fontWeight: FontWeight.w900, color: color, height: 1.1, fontFeatures: const [FontFeature.tabularFigures()]);
