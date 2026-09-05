/// drawer.dart — القائمة الجانبية القصيرة (ملاحظتا 4 و12) | كيف الضيافة
/// المبدأ: كل وجهة في مكان واحد فقط. الإعدادات في النهاية.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/store.dart';
import 'screens/docs_screen.dart';
import 'screens/payments_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class AppDrawer extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const AppDrawer({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final o = store.org;

    void open(Widget page) {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    }

    return Drawer(
      width: 300,
      child: SafeArea(
        child: Column(children: [
          // الترويسة
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              const SizedBox(width: 54, height: 54, child: Image(image: AssetImage('assets/img/logo.png'), fit: BoxFit.contain)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(o.name, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, color: C.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(o.phone, textDirection: TextDirection.ltr, style: TextStyle(color: C.text3, fontSize: 12)),
                ]),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: C.text3)),
            ]),
          ),
          Divider(color: C.line),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(10, 8, 10, 20), children: [
              DrawerItem(Ic.edit, 'عروض الأسعار', '${store.quotes.length} عرض', onTap: () => open(const DocsScreen(initialTab: 1))),
              DrawerItem(Ic.cash, 'الدفعات وسندات القبض', '${store.payments.length} دفعة', onTap: () => open(const PaymentsScreen())),
              DrawerItem(Ic.chart, 'التقارير', 'ملخصات وتحليلات', onTap: () {
                Navigator.pop(context);
                onNavigate(3);
              }),
              DrawerItem(Ic.share, 'النسخة الاحتياطية', store.lastAutoBackupAt == null ? 'لم تُحفظ نسخة بعد' : 'آخر نسخة: ${agoLabel(store.lastAutoBackupAt!)}', onTap: () => open(const BackupScreen())),
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(color: C.line)),
              DrawerItem(Ic.gear, 'الإعدادات', 'المؤسسة، الفواتير، المظهر، الأمان، سلة المحذوفات', onTap: () => open(const SettingsHub())),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('كيف الضيافة v${SettingsHub.version}', style: TextStyle(color: C.text3, fontSize: 11)),
          ),
        ]),
      ),
    );
  }
}

/// «قبل 5 دقائق» …
String agoLabel(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'الآن';
  if (d.inMinutes < 60) return 'قبل ${d.inMinutes} دقيقة';
  if (d.inHours < 24) return 'قبل ${d.inHours} ساعة';
  return 'قبل ${d.inDays} يوم';
}

/// عنصر قائمة موحّد (يُستخدم في القائمة الجانبية ومركز الإعدادات)
class DrawerItem extends StatelessWidget {
  final String icon, title, sub;
  final VoidCallback onTap;
  final Widget? trailing;
  const DrawerItem(this.icon, this.title, this.sub, {super.key, required this.onTap, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(gradient: C.cardGradient, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line2)),
              child: Row(children: [
                KIcon(icon, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: C.text)),
                    Text(sub, style: TextStyle(color: C.text3, fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                trailing ?? Icon(Icons.chevron_left_rounded, color: C.text3, size: 20),
              ]),
            ),
          ),
        ),
      );
}
