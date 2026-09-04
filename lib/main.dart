import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/store.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = Store();
  // التهيئة غير محجوبة: الواجهة تعرض شاشة تحميل، وعند الفشل تعرض رسالة وزر "إعادة المحاولة"
  store.init();
  runApp(KeifApp(store: store));
}

class KeifApp extends StatelessWidget {
  final Store store;
  const KeifApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(
        title: 'كيف الضيافة',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (ctx, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const Shell(),
      ),
    );
  }
}
