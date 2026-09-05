/// theme.dart — نظام التصميم: 3 ثيمات (ليل الضيافة / سماء الفجر / فحم وذهب) | كيف الضيافة
///
/// الألوان مطابقة لتصميم التطبيق الأصلي (css/app.css):
/// كحلي داكن + ذهبي دافئ + خط Tajawal.
library;


import 'package:flutter/material.dart';

/* ============================================================
   الثيمات
   ============================================================ */
enum AppTheme {
  night('night', 'ليل الضيافة', 'كحلي داكن وذهبي دافئ'),
  dawn('dawn', 'سماء الفجر', 'فاتح ومريح للعين'),
  charcoal('charcoal', 'فحم وذهب', 'أسود فحمي وذهب ملكي');

  final String key, label, desc;
  const AppTheme(this.key, this.label, this.desc);

  static AppTheme fromKey(String? k) => AppTheme.values.firstWhere((t) => t.key == k, orElse: () => AppTheme.night);
}

/// لوحة ألوان ثيم واحد
class Palette {
  final AppTheme id;
  final bool dark;
  final Color bg, bg2, surface, surface2, surface3;
  final Color line, line2;
  final Color gold, gold2, goldDeep, goldInk, onGold;
  final Color text, text2, text3;
  final Color ok, warn, danger, info;

  const Palette({
    required this.id,
    required this.dark,
    required this.bg,
    required this.bg2,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.line,
    required this.line2,
    required this.gold,
    required this.gold2,
    required this.goldDeep,
    required this.goldInk,
    required this.onGold,
    required this.text,
    required this.text2,
    required this.text3,
    required this.ok,
    required this.warn,
    required this.danger,
    required this.info,
  });

  /// ليل الضيافة — الثيم الأصلي
  static const night = Palette(
    id: AppTheme.night,
    dark: true,
    bg: Color(0xFF0B1220),
    bg2: Color(0xFF101A2E),
    surface: Color(0xFF16233C),
    surface2: Color(0xFF1C2C49),
    surface3: Color(0xFF24365A),
    line: Color(0x29D2A374),
    line2: Color(0x12FFFFFF),
    gold: Color(0xFFD2A374),
    gold2: Color(0xFFE8C79B),
    goldDeep: Color(0xFFB4854F),
    goldInk: Color(0xFFE8C79B),
    onGold: Color(0xFF12182A),
    text: Color(0xFFEEF2F8),
    text2: Color(0xFFA9B6CC),
    text3: Color(0xFF94A0B4),
    ok: Color(0xFF2ED08A),
    warn: Color(0xFFF0B429),
    danger: Color(0xFFFF7468),
    info: Color(0xFF59A9FF),
  );

  /// فحم وذهب
  static const charcoal = Palette(
    id: AppTheme.charcoal,
    dark: true,
    bg: Color(0xFF0D0D0F),
    bg2: Color(0xFF141417),
    surface: Color(0xFF1A1A1E),
    surface2: Color(0xFF222227),
    surface3: Color(0xFF2C2C33),
    line: Color(0x2ED4AF37),
    line2: Color(0x12FFFFFF),
    gold: Color(0xFFD4AF37),
    gold2: Color(0xFFF0D98A),
    goldDeep: Color(0xFFA8871F),
    goldInk: Color(0xFFF0D98A),
    onGold: Color(0xFF12182A),
    text: Color(0xFFF5F5F7),
    text2: Color(0xFFB0B0B8),
    text3: Color(0xFF93939B),
    ok: Color(0xFF2ED08A),
    warn: Color(0xFFF0B429),
    danger: Color(0xFFFF7468),
    info: Color(0xFF59A9FF),
  );

  /// سماء الفجر — فاتح
  static const dawn = Palette(
    id: AppTheme.dawn,
    dark: false,
    bg: Color(0xFFF4F6FA),
    bg2: Color(0xFFEAEEF6),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF7F9FC),
    surface3: Color(0xFFEDF1F8),
    line: Color(0x1F1E2A4A),
    line2: Color(0x121E2A4A),
    gold: Color(0xFF9C6E3C),
    gold2: Color(0xFFB4854F),
    goldDeep: Color(0xFF7A5228),
    goldInk: Color(0xFF89653C),
    onGold: Color(0xFFFFFFFF),
    text: Color(0xFF131C30),
    text2: Color(0xFF4A5875),
    text3: Color(0xFF6B778E),
    ok: Color(0xFF1E875A),
    warn: Color(0xFF8E6A18),
    danger: Color(0xFFC45248),
    info: Color(0xFF3F78B5),
  );

  static Palette of(AppTheme t) => switch (t) {
        AppTheme.night => night,
        AppTheme.dawn => dawn,
        AppTheme.charcoal => charcoal,
      };
}

/* ============================================================
   C — الوصول السريع لألوان الثيم الحالي
   (تُحدَّث عند تبديل الثيم عبر buildTheme)
   ============================================================ */
class C {
  static Palette p = Palette.night;

  static Color get bg => p.bg;
  static Color get bg2 => p.bg2;
  static Color get surface => p.surface;
  static Color get surface2 => p.surface2;
  static Color get surface3 => p.surface3;
  static Color get line => p.line;
  static Color get line2 => p.line2;
  static Color get gold => p.gold;
  static Color get gold2 => p.gold2;
  static Color get goldDeep => p.goldDeep;
  static Color get goldInk => p.goldInk;
  static Color get onGold => p.onGold;
  static Color get text => p.text;
  static Color get text2 => p.text2;
  static Color get text3 => p.text3;
  static Color get ok => p.ok;
  static Color get warn => p.warn;
  static Color get danger => p.danger;
  static Color get info => p.info;

  // أسماء متوافقة مع الكود السابق
  static Color get card => p.surface;
  static Color get card2 => p.surface2;
  static Color get muted => p.text2;
  static Color get red => p.danger;
  static Color get green => p.ok;
  static Color get amber => p.warn;
  static Color get blue => p.info;
  static Color get goldLight => p.gold2;
  static Color get goldDark => p.goldDeep;

  static bool get isDark => p.dark;

  /// تدرّج ذهبي معياري (أزرار/شارات)
  static LinearGradient get goldGradient => LinearGradient(
        colors: [p.gold2, p.gold, p.goldDeep],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// تدرّج البطاقات (surface → surface2)
  static LinearGradient get cardGradient => LinearGradient(
        colors: [p.surface, p.surface2],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

/* ============================================================
   ThemeData
   ============================================================ */
ThemeData buildTheme([AppTheme t = AppTheme.night]) {
  final p = Palette.of(t);
  C.p = p;
  final base = p.dark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
  final scheme = (p.dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
    primary: p.gold,
    onPrimary: p.onGold,
    secondary: p.gold2,
    onSecondary: p.onGold,
    surface: p.surface,
    onSurface: p.text,
    surfaceContainerHighest: p.surface3,
    onSurfaceVariant: p.text2,
    outline: p.line,
    outlineVariant: p.line2,
    error: p.danger,
    onError: Colors.white,
  );
  const font = 'Tajawal';
  final txt = base.textTheme.apply(fontFamily: font, bodyColor: p.text, displayColor: p.text);

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    textTheme: txt,
    primaryTextTheme: txt,
    dividerColor: p.line2,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: font, fontSize: 19, fontWeight: FontWeight.w800, color: p.text),
      iconTheme: IconThemeData(color: p.goldInk),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: p.bg2,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(22))),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: p.line2)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.bg2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titleTextStyle: TextStyle(fontFamily: font, fontSize: 18, fontWeight: FontWeight.w800, color: p.text),
      contentTextStyle: TextStyle(fontFamily: font, fontSize: 14.5, color: p.text2, height: 1.6),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.bg2,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: p.text3,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.dark ? p.bg2 : p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: TextStyle(color: p.text2, fontWeight: FontWeight.w600),
      floatingLabelStyle: TextStyle(color: p.goldInk, fontWeight: FontWeight.w800),
      hintStyle: TextStyle(color: p.text3, fontWeight: FontWeight.w500),
      prefixIconColor: p.text3,
      suffixIconColor: p.text3,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.gold, width: 1.6)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.danger)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.danger, width: 1.6)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.gold,
        foregroundColor: p.onGold,
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: font, fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.surface2,
        foregroundColor: p.text,
        elevation: 0,
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: p.line)),
        textStyle: const TextStyle(fontFamily: font, fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.goldInk,
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        side: BorderSide(color: p.gold.withValues(alpha: 0.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: font, fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.goldInk,
        textStyle: const TextStyle(fontFamily: font, fontWeight: FontWeight.w800),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: p.text2)),
    listTileTheme: ListTileThemeData(
      iconColor: p.goldInk,
      textColor: p.text,
      titleTextStyle: TextStyle(fontFamily: font, fontSize: 15, fontWeight: FontWeight.w700, color: p.text),
      subtitleTextStyle: TextStyle(fontFamily: font, fontSize: 12.5, color: p.text3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.dark ? p.bg2 : p.surface,
      indicatorColor: p.gold.withValues(alpha: 0.14),
      height: 72,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: font,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: s.contains(WidgetState.selected) ? p.goldInk : p.text3,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.dark ? p.surface3 : const Color(0xFF1E2A4A),
      contentTextStyle: const TextStyle(fontFamily: font, color: Color(0xFFEEF2F8), fontWeight: FontWeight.w700),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surface2,
      selectedColor: p.gold.withValues(alpha: 0.22),
      side: BorderSide(color: p.line),
      labelStyle: TextStyle(fontFamily: font, color: p.text, fontWeight: FontWeight.w700, fontSize: 12.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onGold : p.text3),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.gold : p.surface3),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.gold : Colors.transparent),
      checkColor: WidgetStateProperty.all(p.onGold),
      side: BorderSide(color: p.text3, width: 1.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    radioTheme: RadioThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.gold : p.text3)),
    popupMenuTheme: PopupMenuThemeData(
      color: p.bg2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: p.line)),
      textStyle: TextStyle(fontFamily: font, color: p.text, fontWeight: FontWeight.w700),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(backgroundColor: WidgetStateProperty.all(p.bg2), surfaceTintColor: WidgetStateProperty.all(Colors.transparent)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.gold, linearTrackColor: p.surface3),
    dividerTheme: DividerThemeData(color: p.line2, thickness: 1, space: 1),
    tabBarTheme: TabBarThemeData(
      labelColor: p.goldInk,
      unselectedLabelColor: p.text3,
      indicatorColor: p.gold,
      dividerColor: p.line2,
      labelStyle: const TextStyle(fontFamily: font, fontWeight: FontWeight.w800, fontSize: 14),
      unselectedLabelStyle: const TextStyle(fontFamily: font, fontWeight: FontWeight.w700, fontSize: 14),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: p.surface2,
        selectedBackgroundColor: p.gold,
        selectedForegroundColor: p.onGold,
        foregroundColor: p.text2,
        side: BorderSide(color: p.line),
        textStyle: const TextStyle(fontFamily: font, fontWeight: FontWeight.w800, fontSize: 13),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: p.bg2,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: p.surface2,
      headerForegroundColor: p.text,
      dayForegroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onGold : p.text),
      dayBackgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.gold : Colors.transparent),
      todayForegroundColor: WidgetStateProperty.all(p.goldInk),
      todayBorder: BorderSide(color: p.gold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
  );
}

/// خط الأرقام المالية (أرقام ثابتة العرض)
TextStyle moneyStyle(double size, {Color? color}) => TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w900,
      color: color ?? C.text,
      height: 1.1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/* ============================================================
   ألوان الألواح ثلاثية الأبعاد (premium.css .plate--*)
   ============================================================ */
enum PlateColor { gold, blue, green, violet, silver, red }

class PlateTones {
  final Color top, body, bottom, glow, ink;
  const PlateTones(this.top, this.body, this.bottom, this.glow, this.ink);

  static const gold = PlateTones(Color(0xFFF0CF9A), Color(0xFFC8944F), Color(0xFF7C5322), Color(0xFF96682C), Color(0xFF3B2708));
  static const blue = PlateTones(Color(0xFF8FC4F6), Color(0xFF2E76CC), Color(0xFF123C77), Color(0xFF2666BE), Color(0xFF06203A));
  static const green = PlateTones(Color(0xFF79E2B6), Color(0xFF19A46E), Color(0xFF0A5236), Color(0xFF168C5E), Color(0xFF04281A));
  static const violet = PlateTones(Color(0xFFC3A5FA), Color(0xFF7245D2), Color(0xFF361E74), Color(0xFF603CBE), Color(0xFF180938));
  static const silver = PlateTones(Color(0xFFEDF2F8), Color(0xFFAEB9C8), Color(0xFF5F6C7E), Color(0xFF465468), Color(0xFF141C2A));
  static const red = PlateTones(Color(0xFFFFB3A6), Color(0xFFE05A4C), Color(0xFF7A2118), Color(0xFFB43A2E), Color(0xFF3A0C08));

  static PlateTones of(PlateColor c) => switch (c) {
        PlateColor.gold => gold,
        PlateColor.blue => blue,
        PlateColor.green => green,
        PlateColor.violet => violet,
        PlateColor.silver => silver,
        PlateColor.red => red,
      };
}
