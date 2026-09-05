/// drawer.dart — القائمة الجانبية: الإعدادات بهيكلية واضحة | كيف الضيافة
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/lock_service.dart';
import '../core/store.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class AppDrawer extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const AppDrawer({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final lock = context.watch<LockService>();
    final o = store.org;
    final theme = AppTheme.fromKey(store.themeKey);

    void open(Widget page) {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    }

    return Drawer(
      width: 304,
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
                  Text(o.phone, style: TextStyle(color: C.text3, fontSize: 12)),
                ]),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: C.text3)),
            ]),
          ),
          Divider(color: C.line),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(10, 6, 10, 20), children: [
              // المظهر — 3 ثيمات
              _Head('المظهر'),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                child: Row(children: [
                  for (final t in AppTheme.values) ...[
                    Expanded(child: _ThemeChip(t, selected: t == theme, onTap: () => store.setTheme(t.key))),
                    if (t != AppTheme.values.last) const SizedBox(width: 6),
                  ],
                ]),
              ),

              _Head('المؤسسة'),
              _Item(Ic.dallah, 'بيانات المؤسسة', 'الاسم، السجل، الهاتف، الحساب البنكي', onTap: () => open(const OrgForm())),
              _Item(Ic.stamp, 'الختم والشعار', 'إظهار الختم والعلامة المائية', onTap: () => open(const DocSettingsScreen(initialTab: 1))),

              _Head('المستندات'),
              _Item(Ic.invoice, 'إعدادات الفاتورة', _docHint(o), onTap: () => open(const DocSettingsScreen())),
              _Item(Ic.edit, 'الترقيم والشروط', '${o.invPrefix}0001 • ${o.quotePrefix}0001', onTap: () => open(const DocSettingsScreen(initialTab: 2))),

              _Head('البيانات'),
              _Item(Ic.share, 'النسخة الاحتياطية', store.lastAutoBackupAt == null ? 'لم تُحفظ نسخة بعد' : 'آخر نسخة: ${_ago(store.lastAutoBackupAt!)}', onTap: () => open(const BackupScreen())),
              _Item(Ic.pdf, 'ملفات الهاتف', 'المستندات المحفوظة PDF', onTap: () => open(const FilesEntryScreen())),
              _Item(Ic.chart, 'التقارير', 'ملخصات وتحليلات', onTap: () {
                Navigator.pop(context);
                onNavigate(3);
              }),

              _Head('الحماية'),
              _Item(Ic.check, 'قفل التطبيق', lock.enabled ? 'مفعّل برمز سري' : 'غير مفعّل', onTap: () => open(const SecurityScreen())),

              _Head('أخرى'),
              _Item(Ic.alert, 'منطقة الخطر', 'مسح جميع البيانات', onTap: () => open(const DangerScreen())),
              _Item(Ic.pin, 'حول التطبيق', 'كيف الضيافة v2.2.0', onTap: () => open(const AboutScreen())),
            ]),
          ),
        ]),
      ),
    );
  }

  static String _docHint(dynamic o) {
    final parts = <String>[];
    parts.add(o.vatEnabled ? 'ضريبة ${o.vatRateBp ~/ 100}%' : 'بدون ضريبة');
    parts.add(o.discountEnabled ? 'خصم مفعّل' : 'بدون خصم');
    return parts.join(' • ');
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'الآن';
    if (d.inMinutes < 60) return 'قبل ${d.inMinutes} دقيقة';
    if (d.inHours < 24) return 'قبل ${d.inHours} ساعة';
    return 'قبل ${d.inDays} يوم';
  }
}

class _Head extends StatelessWidget {
  final String t;
  const _Head(this.t);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
        child: Row(children: [
          Container(width: 3, height: 14, decoration: BoxDecoration(gradient: LinearGradient(colors: [C.gold2, C.goldDeep], begin: Alignment.topCenter, end: Alignment.bottomCenter), borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(t, style: TextStyle(color: C.text3, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
        ]),
      );
}

class _Item extends StatelessWidget {
  final String icon, title, sub;
  final VoidCallback onTap;
  const _Item(this.icon, this.title, this.sub, {required this.onTap});
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
                Icon(Icons.chevron_left_rounded, color: C.text3, size: 20),
              ]),
            ),
          ),
        ),
      );
}

class _ThemeChip extends StatelessWidget {
  final AppTheme t;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeChip(this.t, {required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(t);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: C.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? C.gold : C.line2, width: selected ? 1.6 : 1),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [p.bg, p.surface2], begin: Alignment.topLeft, end: Alignment.bottomRight),
              border: Border.all(color: p.gold, width: 2.5),
              boxShadow: selected ? [BoxShadow(color: C.gold.withValues(alpha: 0.4), blurRadius: 10)] : null,
            ),
            child: selected ? Icon(Icons.check_rounded, size: 16, color: p.gold) : null,
          ),
          const SizedBox(height: 6),
          Text(t.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: selected ? C.goldInk : C.text2), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}
