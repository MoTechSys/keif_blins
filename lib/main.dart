import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/brand.dart';
import 'core/file_service.dart';
import 'core/license_service.dart';
import 'core/lock_service.dart';
import 'core/store.dart';
import 'core/update_service.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = Store();
  final lock = LockService();
  final license = LicenseService();
  // التهيئة غير محجوبة: الواجهة تعرض شاشة تحميل، وعند الفشل تعرض رسالة وزر "إعادة المحاولة"
  store.init();
  lock.init();
  license.init(); // القفل عن بُعد: آخر حالة محفوظة فورًا ثم تحديث من الشبكة
  // إنشاء مجلد التطبيق وكل مجلدات الأصناف فور التشغيل (على الهاتف)
  if (FileService.supported) FileService.base();
  // حذف ملفات تحديث منزَّلة سابقًا (بعد التثبيت لا حاجة لها)
  if (UpdateService.supported) UpdateService.cleanup();
  runApp(KeifApp(store: store, lock: lock, license: license));
}

class KeifApp extends StatelessWidget {
  final Store store;
  final LockService lock;
  final LicenseService? license;
  const KeifApp({
    super.key,
    required this.store,
    required this.lock,
    this.license,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: lock),
        ChangeNotifierProvider.value(value: license ?? LicenseService()),
        ChangeNotifierProvider(create: (_) => UpdateService()),
      ],
      child: Consumer<Store>(
        builder: (_, s, __) => MaterialApp(
          title: Brand.current.appName,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(AppTheme.fromKey(s.themeKey)),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (ctx, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: const Shell(),
        ),
      ),
    );
  }
}
