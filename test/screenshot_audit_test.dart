// أداة تدقيق بصري (ليست اختبارًا دائمًا): تصوّر كل شاشة للعلامتين بخط Tajawal الحقيقي
// على جوال 360×760 وتحفظ PNG في build/audit/<brand>/<screen>[_scrolled].png
// التشغيل: flutter test test/screenshot_audit_test.dart
@Tags(['audit'])
library;

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
import 'package:keif_diafa/ui/screens/files_screen.dart';
import 'package:keif_diafa/ui/screens/home_screen.dart';
import 'package:keif_diafa/ui/screens/license_screen.dart';
import 'package:keif_diafa/ui/screens/lock_screen.dart';
import 'package:keif_diafa/ui/screens/payment_form.dart';
import 'package:keif_diafa/ui/screens/payments_screen.dart';
import 'package:keif_diafa/ui/screens/settings_screen.dart';
import 'package:keif_diafa/ui/screens/signin_screen.dart';
import 'package:keif_diafa/ui/screens/statements_screen.dart';
import 'package:keif_diafa/ui/screens/storage_setup_screen.dart';
import 'package:keif_diafa/ui/shell.dart';
import 'package:keif_diafa/ui/theme.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> _loadFonts() async {
  final loader = FontLoader('Tajawal');
  for (final f in ['Regular', 'Bold', 'Black']) {
    final bytes = File('assets/fonts/Tajawal-$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
  final icons = FontLoader('MaterialIcons');
  final p =
      '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  if (File(p).existsSync()) {
    icons.addFont(
      Future.value(ByteData.view(File(p).readAsBytesSync().buffer)),
    );
    await icons.load();
  }
}

void main() {
  late Directory tmp;
  var n = 0;
  final key = GlobalKey();

  setUpAll(() async {
    sqfliteFfiInit();
    dbf.debugDbFactory = databaseFactoryFfi;
    tmp = Directory.systemTemp.createTempSync('audit_');
    Hive.init('${tmp.path}/h');
    HiveDb.skipInit = true;
    await _loadFonts();
  });
  tearDownAll(() => Brand.debugOverride = null);

  const longDesc =
      'الضيافة:\n- 6 مضيفين بزي موحد من اختياركم (جنسية محددة)\n'
      '- نوفر عدة ومعاميل تقديم القهوة السعودية والمشروبات الساخنة\n'
      '- تمر سكري مفتل 4 صحن كل صحن 5 كيلو\n- شامل التوصيل';

  for (final brand in [Brand.keif, Brand.osool]) {
    group(brand.id, () {
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
          final c2 = Client(
            name: 'مؤسسة النخبة للمناسبات',
            phone: '0509876543',
          );
          await s.saveClient(c2);
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
          final q = Invoice(
            kind: DocKind.quotation,
            clientId: c2.id,
            clientName: c2.name,
            eventDate: '2026-10-10',
            items: [LineItem(desc: 'ضيافة كاملة', unitPrice: 450000, qty: 2)],
          );
          q.number = s.nextNumber(DocKind.quotation);
          await s.saveDoc(q);
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
          final f = File('build/audit/${brand.id}/$name.png');
          f.parent.createSync(recursive: true);
          f.writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }

      Future<void> show(WidgetTester t, Widget w) async {
        t.view.physicalSize = const Size(360 * 2, 760 * 2);
        t.view.devicePixelRatio = 2;
        addTearDown(t.view.reset);
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
        'backup': () => const BackupScreen(),
        'trash': () => const TrashScreen(),
        'about': () => const AboutScreen(),
        'drawer': () => Scaffold(body: AppDrawer(onNavigate: (_) {})),
        'lock': () => const LockScreen(),
        'license': () => const LicenseScreen(),
        'signin': () => const SignInScreen(),
        'storageSetup': () => const StorageSetupScreen(),
        'files': () => const FilesScreen(),
        'appearance': () => const AppearanceScreen(),
        'security': () => const SecurityScreen(),
      };

      for (final e in screens.entries) {
        testWidgets(e.key, (t) async {
          await boot(t);
          await show(t, e.value());
          await snap(t, e.key);
          final sc = find.byType(Scrollable);
          if (sc.evaluate().isNotEmpty) {
            await t.drag(sc.first, const Offset(0, -600), warnIfMissed: false);
            await t.pump(const Duration(milliseconds: 500));
            await snap(t, '${e.key}_s1');
            await t.drag(sc.first, const Offset(0, -600), warnIfMissed: false);
            await t.pump(const Duration(milliseconds: 500));
            await snap(t, '${e.key}_s2');
          }
          await t.pumpWidget(const SizedBox());
          await t.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)),
          );
        });
      }
    });
  }
}
