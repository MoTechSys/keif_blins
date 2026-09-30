// أداة قياس تجربة الاستخدام (ليست اختبارًا دائمًا — تُشغَّل يدويًا):
//   flutter test test/ux_metrics_audit_test.dart
// لكل شاشة × 3 مقاسات جوال × العلامتين تقيس:
//   1) أهداف اللمس الأصغر من 48×48 dp (معيار Material/WCAG 2.5.5)
//   2) أخطاء تجاوز الحدود (RenderFlex overflow) أثناء البناء
//   3) لقطة PNG في build/ux/<brand>/<size>/<screen>.png
// وتكتب تقريرًا JSON في build/ux/report.json يُقرأ لاحقًا ويُلخَّص في docs/AUDIT_*.md
@Tags(['audit'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
import 'package:keif_diafa/ui/drawer.dart';
import 'package:keif_diafa/ui/screens/claims_screen.dart';
import 'package:keif_diafa/ui/screens/client_form.dart';
import 'package:keif_diafa/ui/screens/clients_screen.dart';
import 'package:keif_diafa/ui/screens/doc_detail.dart';
import 'package:keif_diafa/ui/screens/doc_form.dart';
import 'package:keif_diafa/ui/screens/docs_screen.dart';
import 'package:keif_diafa/ui/screens/home_screen.dart';
import 'package:keif_diafa/ui/screens/payment_form.dart';
import 'package:keif_diafa/ui/screens/payments_screen.dart';
import 'package:keif_diafa/ui/screens/settings_screen.dart';
import 'package:keif_diafa/ui/screens/signin_screen.dart';
import 'package:keif_diafa/ui/screens/statements_screen.dart';
import 'package:keif_diafa/ui/shell.dart';
import 'package:keif_diafa/ui/theme.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// مقاسات منطقية (dp) تمثّل السوق السعودي: صغير قديم، شائع، كبير
const _sizes = <String, Size>{
  '320x640': Size(320, 640), // Galaxy J/A-series قديمة (الحد الأدنى)
  '360x800': Size(360, 800), // الأكثر شيوعًا (Samsung A/M, Redmi)
  '412x915': Size(412, 915), // Pixel 7 / S23+ (كبير)
};

const _minTap = 48.0;

Future<void> _loadFonts() async {
  final loader = FontLoader('Tajawal');
  for (final f in ['Regular', 'Bold', 'Black']) {
    final bytes = File('assets/fonts/Tajawal-$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
  final icons = FontLoader('MaterialIcons');
  const p =
      '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  if (File(p).existsSync()) {
    icons.addFont(
      Future.value(ByteData.view(File(p).readAsBytesSync().buffer)),
    );
    await icons.load();
  }
}

/// يجمع كل عنصر قابل للنقر مع حجمه المنطقي (dp) على الشاشة
List<Map<String, dynamic>> _tapTargets(WidgetTester t) {
  final out = <Map<String, dynamic>>[];
  final finders = <String, Finder>{
    'IconButton': find.byType(IconButton),
    'InkWell': find.byType(InkWell),
    'GestureDetector': find.byWidgetPredicate(
      (w) => w is GestureDetector && (w.onTap != null),
    ),
    'ElevatedButton': find.byType(ElevatedButton),
    'FilledButton': find.byType(FilledButton),
    'OutlinedButton': find.byType(OutlinedButton),
    'TextButton': find.byType(TextButton),
    'FAB': find.byType(FloatingActionButton),
    'Chip': find.byWidgetPredicate((w) => w is ChoiceChip || w is FilterChip),
    'Switch': find.byType(Switch),
    'Checkbox': find.byType(Checkbox),
    'ListTile': find.byWidgetPredicate((w) => w is ListTile && w.onTap != null),
  };
  final seen = <RenderObject>{};
  for (final e in finders.entries) {
    for (final el in e.value.evaluate()) {
      final ro = el.renderObject;
      if (ro is! RenderBox || !ro.hasSize || !ro.attached) continue;
      if (!seen.add(ro)) continue;
      // العناصر خارج الشاشة (غير مرئية) لا تُحتسب
      final origin = ro.localToGlobal(Offset.zero);
      final view = t.view.physicalSize / t.view.devicePixelRatio;
      if (origin.dy > view.height || origin.dy + ro.size.height < 0) continue;
      if (ro.size.width <= 0 || ro.size.height <= 0) continue;
      String label = '';
      el.visitChildren((c) {
        if (label.isNotEmpty) return;
        final w = c.widget;
        if (w is Text) label = w.data ?? '';
        if (w is Icon) label = 'icon:${w.icon?.codePoint.toRadixString(16)}';
        if (w is Tooltip) label = 'tip:${w.message}';
      });
      out.add({
        'type': e.key,
        'w': ro.size.width,
        'h': ro.size.height,
        'label': label,
      });
    }
  }
  return out;
}

void main() {
  late Directory tmp;
  var n = 0;
  final key = GlobalKey();
  final report = <Map<String, dynamic>>[];

  setUpAll(() async {
    sqfliteFfiInit();
    dbf.debugDbFactory = databaseFactoryFfi;
    tmp = Directory.systemTemp.createTempSync('ux_');
    Hive.init('${tmp.path}/h');
    HiveDb.skipInit = true;
    await _loadFonts();
  });
  tearDownAll(() {
    Brand.debugOverride = null;
    final f = File('build/ux/report.json');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(const JsonEncoder.withIndent(' ').convert(report));
  });

  const longDesc =
      'الضيافة:\n- 6 مضيفين بزي موحد من اختياركم (جنسية محددة)\n'
      '- نوفر عدة ومعاميل تقديم القهوة السعودية والمشروبات الساخنة\n'
      '- تمر سكري مفتل 4 صحن كل صحن 5 كيلو\n- شامل التوصيل';

  for (final brand in [Brand.keif, Brand.osool]) {
    for (final sz in _sizes.entries) {
      group('${brand.id} ${sz.key}', () {
        late Store s;
        late Invoice inv;
        late Client c;
        late Claim cl;

        Future<void> boot(WidgetTester t) async {
          Brand.debugOverride = brand;
          await t.runAsync(() async {
            SqliteDb.debugDir = '${tmp.path}/${brand.id}${n++}';
            Directory(SqliteDb.debugDir!).createSync(recursive: true);
            s = Store(db: SqliteDb());
            await s.init();
            c = Client(
              name: 'شركة طلوع الجزيرة التجارية',
              phone: '0551234567',
              address: 'جدة — حي الروضة',
            );
            await s.saveClient(c);
            inv = Invoice(
              clientId: c.id,
              clientName: c.name,
              eventDate: '2026-09-27',
              location: 'جدة — قاعة الأندلس',
              attendees: '300',
              items: [
                LineItem(desc: longDesc, unitPrice: 268000),
                LineItem(
                  desc: 'صانع مشروبات',
                  unitPrice: 1500000,
                  qty: 12.5,
                  unitLabel: 'ساعة',
                ),
              ],
            );
            inv.number = s.nextNumber(DocKind.invoice);
            await s.saveDoc(inv);
            await s.savePayment(
              Payment(clientId: c.id, invoiceId: inv.id, amount: 100000),
            );
            cl = s.claimFromInvoices(c, [inv]);
            await s.saveClaim(cl);
          });
        }

        Future<void> snap(WidgetTester t, String name) async {
          await t.runAsync(() async {
            final ro =
                key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final img = await ro.toImage(pixelRatio: 2);
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            final f = File('build/ux/${brand.id}/${sz.key}/$name.png');
            f.parent.createSync(recursive: true);
            f.writeAsBytesSync(bytes!.buffer.asUint8List());
          });
        }

        Future<List<String>> show(WidgetTester t, Widget w) async {
          final overflow = <String>[];
          final prev = FlutterError.onError;
          FlutterError.onError = (d) {
            final m = d.exceptionAsString();
            if (m.contains('overflowed') || m.contains('RenderFlex')) {
              overflow.add(m.split('\n').first);
            } else {
              prev?.call(d);
            }
          };
          t.view.physicalSize = sz.value * 2;
          t.view.devicePixelRatio = 2;
          addTearDown(t.view.reset);
          addTearDown(() => FlutterError.onError = prev);
          await t.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MultiProvider(
                providers: [
                  ChangeNotifierProvider.value(value: s),
                  ChangeNotifierProvider(create: (_) => LockService()),
                  ChangeNotifierProvider(create: (_) => LicenseService()),
                ],
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: buildTheme(AppTheme.fromKey(s.themeKey)),
                  locale: const Locale('ar'),
                  supportedLocales: const [Locale('ar')],
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  builder: (ctx, ch) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: ch!,
                  ),
                  home: w,
                ),
              ),
            ),
          );
          await t.pump(const Duration(milliseconds: 500));
          await t.pump(const Duration(milliseconds: 500));
          return overflow;
        }

        final screens = <String, Widget Function()>{
          'shell': () => const Shell(),
          'home': () => Scaffold(
            body: HomeScreen(onNavigate: (_) {}, onMenu: () {}),
          ),
          'docs': () => const DocsScreen(),
          'docForm-edit': () => DocForm(kind: DocKind.invoice, doc: inv),
          'docForm-new': () => const DocForm(kind: DocKind.quotation),
          'docDetail': () => DocDetail(id: inv.id),
          'clients': () => const ClientsScreen(),
          'clientDetail': () => ClientDetail(id: c.id),
          'clientForm': () => ClientForm(client: c),
          'payments': () => const PaymentsScreen(),
          'paymentForm': () => PaymentForm(clientId: c.id, invoiceId: inv.id),
          'statements': () => const StatementsScreen(),
          'claims': () => const ClaimsScreen(),
          'claimForm': () => ClaimForm(claim: cl),
          'settings': () => const SettingsHub(),
          'docSettings': () => const DocSettingsScreen(),
          'drawer': () => Scaffold(body: AppDrawer(onNavigate: (_) {})),
          'signin': () => const SignInScreen(),
        };

        for (final e in screens.entries) {
          testWidgets(e.key, (t) async {
            await boot(t);
            final overflow = await show(t, e.value());
            await snap(t, e.key);
            final targets = _tapTargets(t);
            final small = targets
                .where(
                  (m) =>
                      (m['w'] as double) < _minTap ||
                      (m['h'] as double) < _minTap,
                )
                .toList();
            report.add({
              'brand': brand.id,
              'size': sz.key,
              'screen': e.key,
              'targets': targets.length,
              'small': small,
              'overflow': overflow,
            });
            await t.pumpWidget(const SizedBox());
            await t.runAsync(
              () => Future.delayed(const Duration(milliseconds: 30)),
            );
          });
        }
      });
    }
  }
}
