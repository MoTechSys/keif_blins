// اختبار دخاني للواجهة: كل الشاشات الرئيسية للعلامتين على شاشة جوال ضيقة
// (360×760) مع بيانات طويلة — يفشل عند أي تجاوز (overflow) أو استثناء.
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
import 'package:keif_diafa/ui/screens/statements_screen.dart';
import 'package:keif_diafa/ui/screens/license_screen.dart';
import 'package:keif_diafa/ui/screens/lock_screen.dart';
import 'package:keif_diafa/ui/screens/signin_screen.dart';
import 'package:keif_diafa/ui/screens/storage_setup_screen.dart';
import 'package:keif_diafa/ui/screens/files_screen.dart';
import 'package:keif_diafa/ui/drawer.dart';
import 'package:keif_diafa/ui/theme.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tmp;
  var n = 0;
  setUpAll(() async {
    sqfliteFfiInit();
    dbf.debugDbFactory = databaseFactoryFfi;
    tmp = Directory.systemTemp.createTempSync('ui_smoke_');
    Hive.init('${tmp.path}/h');
    HiveDb.skipInit = true;
  });
  tearDownAll(() => Brand.debugOverride = null);

  const longDesc =
      'الضيافة:\n- 6 مضيفين بزي موحد من اختياركم (جنسية محددة)\n'
      '- نوفر عدة ومعاميل تقديم القهوة السعودية والمشروبات الساخنة\n'
      '- تمر سكري مفتل 4 صحن كل صحن 5 كيلو\n- شامل التوصيل';
  const longName =
      'شركة طلوع الجزيرة التجارية للمقاولات العامة والصيانة المحدودة';

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
            name: longName,
            phone: '0551234567',
            address: 'جدة — حي الروضة — طريق الملك عبدالعزيز',
          );
          await s.saveClient(c);
          inv = Invoice(
            clientId: c.id,
            clientName: c.name,
            eventDate: '2026-09-27',
            location: 'جدة',
            attendees: '300',
            items: [
              LineItem(desc: longDesc, unitPrice: 268000),
              LineItem(
                desc: 'صانع مشروبات',
                unitPrice: 1500000,
                qty: 12.5,
                unitLabel: 'ساعة',
                external: 5000,
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

      Future<void> show(WidgetTester t, Widget w) async {
        final prev = FlutterError.onError;
        FlutterError.onError = (d) {
          // طباعة فورية والشجرة حيّة لمعرفة مكان الخطأ بدقة
          FlutterError.dumpErrorToConsole(d, forceReport: true);
          prev?.call(d);
        };
        addTearDown(() => FlutterError.onError = prev);
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
              theme: buildTheme(AppTheme.fromKey(s.themeKey)),
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
        await t.pump(const Duration(milliseconds: 400));
        await t.pump(const Duration(milliseconds: 400));
        // الأخطاء تُبلَّغ تلقائيًا عبر إطار الاختبار
      }

      final screens = <String, Widget Function()>{
        'home': () => HomeScreen(onNavigate: (_) {}, onMenu: () {}),
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
          // تمرير لأسفل لاختبار باقي المحتوى
          final sc = find.byType(Scrollable);
          if (sc.evaluate().isNotEmpty) {
            await t.drag(sc.first, const Offset(0, -1500), warnIfMissed: false);
            await t.pump(const Duration(milliseconds: 400));
            // الأخطاء تُبلَّغ تلقائيًا عبر إطار الاختبار
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
