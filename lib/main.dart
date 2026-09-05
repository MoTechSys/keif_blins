import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/lock_service.dart';
import 'core/store.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = Store();
  final lock = LockService();
  // التهيئة غير محجوبة: الواجهة تعرض شاشة تحميل، وعند الفشل تعرض رسالة وزر "إعادة المحاولة"
  store.init();
  lock.init();
  runApp(KeifApp(store: store, lock: lock));
}

class KeifApp extends StatelessWidget {
  final Store store;
  final LockService lock;
  const KeifApp({super.key, required this.store, required this.lock});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: lock),
      ],
      child: Consumer<Store>(
        builder: (_, s, __) => MaterialApp(
          title: 'كيف الضيافة',
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
