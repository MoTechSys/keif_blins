/// storage_setup_screen.dart — إعداد مجلد التطبيق في الذاكرة الداخلية (مرة واحدة) | نظام الفواتير
///
/// يظهر عند أول تشغيل على أندرويد: يشرح أين تُحفظ الملفات ويطلب «الوصول إلى كل الملفات»
/// كي يُنشأ المجلد في جذر الذاكرة (/storage/emulated/0/<اسم التطبيق>) مثل واتساب.
/// «لاحقًا» يستخدم Documents/<اسم التطبيق> — ويمكن الترقية من «الملفات المحفوظة» في أي وقت.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../core/file_service.dart';
import '../../core/store.dart';
import '../theme.dart';
import '../widgets.dart';

class StorageSetupScreen extends StatefulWidget {
  const StorageSetupScreen({super.key});
  @override
  State<StorageSetupScreen> createState() => _StorageSetupScreenState();
}

class _StorageSetupScreenState extends State<StorageSetupScreen>
    with WidgetsBindingObserver {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// بعد الرجوع من شاشة صلاحيات النظام: نعيد الفحص تلقائيًا
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && _busy) _finishIfGranted();
  }

  Future<void> _finishIfGranted() async {
    if (await FileService.hasRootAccess()) {
      await FileService.refresh();
      await _done();
    }
  }

  Future<void> _allow() async {
    setState(() => _busy = true);
    final ok = await FileService.requestRootAccess();
    if (!mounted) return;
    if (ok) {
      await _done();
    } else {
      setState(() => _busy = false);
      toast(
        context,
        'لم تُمنح الصلاحية — سنحفظ الملفات في مجلد Documents بدلًا من ذلك',
        error: true,
      );
    }
  }

  Future<void> _later() async {
    await FileService.base();
    await _done();
  }

  Future<void> _done() async {
    await FileService.ensureTree();
    if (!mounted) return;
    await context.read<Store>().setKv('storageAsked', true);
  }

  @override
  Widget build(BuildContext context) {
    final b = Brand.current;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image(
                  image: AssetImage(C.isDark ? b.logoLight : b.logo),
                  width: 110,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'مجلد ${b.appName} على هاتفك',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: C.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'كل فاتورة أو عرض أو خطاب تُصدره يُحفظ فورًا ملف PDF في مجلد باسم التطبيق في الذاكرة الداخلية، مرتّبًا حسب النوع والسنة — تجده من «مدير الملفات» مباشرة.',
                textAlign: TextAlign.center,
                style: TextStyle(color: C.text2, fontSize: 13.5, height: 1.6),
              ),
              const SizedBox(height: 18),
              GoldCard(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row(
                        Icons.folder_rounded,
                        'الذاكرة الداخلية / ${b.folderName}',
                        bold: true,
                      ),
                      for (final k in FileKind.values)
                        _row(
                          k == FileKind.backup
                              ? Icons.backup_outlined
                              : Icons.folder_open_rounded,
                          '   ${k.folder}${k.byYear ? ' / ${DateTime.now().year}' : ''}',
                        ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'يطلب أندرويد لذلك صلاحية «الوصول إلى كل الملفات». التطبيق لا يقرأ ملفاتك الأخرى — يكتب فقط داخل مجلده.',
                textAlign: TextAlign.center,
                style: TextStyle(color: C.text3, fontSize: 11.5),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _allow,
                  icon: _busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: C.onGold,
                          ),
                        )
                      : const Icon(Icons.create_new_folder_rounded),
                  label: const Text(
                    'السماح وإنشاء المجلد',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : _later,
                child: Text(
                  'لاحقًا (الحفظ في مجلد Documents)',
                  style: TextStyle(color: C.text3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(IconData i, String t, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Icon(i, size: 18, color: C.gold),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            t,
            style: TextStyle(
              color: C.text,
              fontSize: 13,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
