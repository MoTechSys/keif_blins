// الوحدات المرنة: تبويب الإعدادات (إضافة/تعديل/حذف/ترتيب/استعادة) + زر «+ وحدة» داخل نموذج
// البند، والحفظ الفعلي في SQLite ثم إعادة القراءة. يعمل على شاشة 360×760 ويفشل عند أي overflow.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:keif_diafa/core/brand.dart';
import 'package:keif_diafa/core/db.dart';
import 'package:keif_diafa/core/db_factory_io.dart' as dbf;
import 'package:keif_diafa/core/license_service.dart';
import 'package:keif_diafa/core/lock_service.dart';
import 'package:keif_diafa/core/models.dart';
import 'package:keif_diafa/core/store.dart';
import 'package:keif_diafa/ui/screens/doc_form.dart';
import 'package:keif_diafa/ui/screens/settings_screen.dart';
import 'package:keif_diafa/ui/theme.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tmp;
  var n = 0;
  late Store s;

  setUpAll(() {
    sqfliteFfiInit();
    dbf.debugDbFactory = databaseFactoryFfi;
    tmp = Directory.systemTemp.createTempSync('units_');
    Hive.init('${tmp.path}/h');
    HiveDb.skipInit = true;
    Brand.debugOverride = Brand.keif;
  });
  tearDownAll(() => Brand.debugOverride = null);

  Future<String> boot(WidgetTester t) async {
    final dir = '${tmp.path}/db${n++}';
    await t.runAsync(() async {
      SqliteDb.debugDir = dir;
      Directory(dir).createSync(recursive: true);
      s = Store(db: SqliteDb());
      await s.init();
      // كل حفظ يجدول نسخة احتياطية بعد 4 ثوانٍ — نعطّلها هنا حتى لا يبقى مؤقّت معلّقًا
      await s.setAutoBackup(false);
    });
    addTearDown(s.dispose);
    return dir;
  }

  Future<void> show(WidgetTester t, Widget w) async {
    t.view.physicalSize = const Size(360 * 3, 760 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: s),
          ChangeNotifierProvider(create: (_) => LockService()),
          ChangeNotifierProvider(create: (_) => LicenseService()),
        ],
        child: MaterialApp(
          theme: buildTheme(AppTheme.night),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (ctx, ch) =>
              Directionality(textDirection: TextDirection.rtl, child: ch!),
          home: w,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  /// يمرّر قائمة الشاشة (ListView الرئيسية — لا حقول النص) حتى يظهر العنصر
  Future<void> reveal(WidgetTester t, Finder f) async {
    if (f.evaluate().isNotEmpty) {
      // موجود في الشجرة لكن قد يكون خارج حدود الشاشة (مبني لكن مقصوص)
      await t.ensureVisible(f.first);
      await t.pumpAndSettle();
      return;
    }
    // أول Scrollable عمودي قابل للتمرير فعلًا (قائمة الشاشة) — لا حقول النص ولا القوائم المثبّتة
    final scrollables = find.byType(Scrollable).evaluate().where((e) {
      final w = e.widget as Scrollable;
      return w.axis == Axis.vertical &&
          w.physics is! NeverScrollableScrollPhysics;
    });
    final list = find.byWidget(scrollables.first.widget);
    await t.scrollUntilVisible(f, 150, scrollable: list, maxScrolls: 60);
    await t.pumpAndSettle();
  }

  Future<void> tapScrolled(WidgetTester t, Finder f) async {
    await reveal(t, f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  /// يُمهل عمليات القرص الحقيقية (SQLite ffi) لتكتمل ثم يعيد رسم الشجرة
  Future<void> settleIo(WidgetTester t) async {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 150)));
    await t.pumpAndSettle();
  }

  Future<void> typeInDialog(WidgetTester t, String text, String button) async {
    await t.enterText(find.byType(TextFormField).last, text);
    await t.tap(find.widgetWithText(FilledButton, button));
    await t.pumpAndSettle();
    await settleIo(t);
  }

  testWidgets('تبويب الوحدات: إضافة، رفض التكرار، تعديل، حذف، استعادة', (
    t,
  ) async {
    await boot(t);
    await show(t, const DocSettingsScreen(initialTab: 1));
    expect(find.text('الوحدات الحالية'), findsOneWidget);
    for (final u in unitLabels) {
      await reveal(t, find.text(u));
      expect(find.text(u), findsOneWidget);
    }
    expect(find.text('استعادة الافتراضي', skipOffstage: false), findsNothing);

    // إضافة
    await tapScrolled(t, find.text('إضافة وحدة'));
    await typeInDialog(t, '  طاولة ', 'إضافة');
    expect(s.org.units.last, 'طاولة');
    expect(find.text('طاولة', skipOffstage: false), findsOneWidget);
    expect(find.text('استعادة الافتراضي', skipOffstage: false), findsOneWidget);

    // تكرار مرفوض (بعد التنظيف)
    await tapScrolled(t, find.text('إضافة وحدة'));
    await t.enterText(find.byType(TextFormField).last, 'طاولة ');
    await t.tap(find.widgetWithText(FilledButton, 'إضافة'));
    await t.pumpAndSettle();
    expect(find.text('هذه الوحدة موجودة'), findsOneWidget);
    await t.tap(find.text('إلغاء'));
    await t.pumpAndSettle();
    expect(s.org.units.where((u) => u == 'طاولة').length, 1);

    // تعديل الأخيرة
    await tapScrolled(t, find.byTooltip('تعديل').last);
    await typeInDialog(t, 'ليلة', 'حفظ');
    expect(s.org.units.last, 'ليلة');
    expect(find.text('ليلة', skipOffstage: false), findsOneWidget);
    expect(find.text('طاولة', skipOffstage: false), findsNothing);

    // حذف الأخيرة
    await tapScrolled(t, find.byTooltip('حذف').last);
    await t.tap(find.widgetWithText(FilledButton, 'حذف'));
    await t.pumpAndSettle();
    await settleIo(t);
    expect(s.org.units.contains('ليلة'), isFalse);

    // حذف كل شيء ما عدا واحدة ⇐ زر الحذف الأخير معطّل
    while (s.org.units.length > 1) {
      await t.tap(find.byTooltip('حذف').first);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'حذف'));
      await t.pumpAndSettle();
      await settleIo(t);
    }
    final lastDel = t.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('حذف'),
        matching: find.byType(IconButton),
      ),
    );
    expect(lastDel.onPressed, isNull);

    // استعادة الافتراضي
    await tapScrolled(t, find.text('استعادة الافتراضي'));
    await t.tap(find.widgetWithText(FilledButton, 'استعادة'));
    await t.pumpAndSettle();
    await settleIo(t);
    expect(s.org.units, unitLabels);
    expect(find.text('استعادة الافتراضي', skipOffstage: false), findsNothing);
  });

  testWidgets('نموذج البند: الشرائح من الإعدادات + «وحدة» يضيف ويحفظ ويختار', (
    t,
  ) async {
    final dir = await boot(t);
    await t.runAsync(() => s.saveOrg(s.org..units = ['موقع', 'يوم']));
    await show(t, const DocForm(kind: DocKind.quotation));

    // الشرائح المعروضة = وحدات الإعدادات (+ وحدة البند الافتراضية إن اختلفت)
    await reveal(t, find.text('الوحدة:'));
    expect(find.widgetWithText(ChoiceChip, 'موقع'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'يوم'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'وجبة'), findsNothing);

    // إضافة وحدة من داخل النموذج
    await tapScrolled(t, find.widgetWithText(ActionChip, 'وحدة'));
    await typeInDialog(t, 'طاولة', 'إضافة');
    final chip = t.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'طاولة'));
    expect(chip.selected, isTrue, reason: 'الوحدة الجديدة تُختار للبند فورًا');
    expect(s.org.units, ['موقع', 'يوم', 'طاولة']);

    // مكررة (بعد التنظيف) ⇐ رسالة في النافذة، لا تكرار في الإعدادات
    await tapScrolled(t, find.widgetWithText(ActionChip, 'وحدة'));
    await t.enterText(find.byType(TextFormField).last, ' يوم');
    await t.tap(find.widgetWithText(FilledButton, 'إضافة'));
    await t.pumpAndSettle();
    expect(find.text('هذه الوحدة موجودة'), findsOneWidget);
    await t.tap(find.text('إلغاء'));
    await t.pumpAndSettle();
    expect(s.org.units, ['موقع', 'يوم', 'طاولة']);

    // الحفظ فعلي: متجر جديد على نفس القاعدة يقرأ نفس الوحدات
    await t.pumpWidget(const SizedBox());
    await t.runAsync(() async {
      SqliteDb.debugDir = dir;
      final s2 = Store(db: SqliteDb());
      await s2.init();
      expect(s2.org.units, ['موقع', 'يوم', 'طاولة']);
    });
  });

  testWidgets('بند قديم بوحدة محذوفة من الإعدادات يظل يعرض وحدته', (t) async {
    await boot(t);
    await t.runAsync(() => s.saveOrg(s.org..units = ['يوم']));
    final inv = Invoice(
      kind: DocKind.quotation,
      items: [LineItem(desc: 'ضيافة', unitPrice: 100, unitLabel: 'وجبة')],
    );
    await show(t, DocForm(kind: DocKind.quotation, doc: inv));
    await reveal(t, find.text('الوحدة:'));
    final chip = t.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'وجبة'));
    expect(chip.selected, isTrue);
    expect(find.widgetWithText(ChoiceChip, 'يوم'), findsOneWidget);
  });
}
