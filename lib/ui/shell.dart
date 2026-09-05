/// shell.dart — الهيكل الرئيسي والتنقل السفلي | كيف الضيافة
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/lock_service.dart';
import '../core/store.dart';
import 'drawer.dart';
import 'screens/clients_screen.dart';
import 'screens/docs_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/signin_screen.dart';
import 'screens/statements_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _tab = 0;
  final _scaffold = GlobalKey<ScaffoldState>();

  void go(int i) => setState(() => _tab = i);
  void openMenu() => _scaffold.currentState?.openDrawer();

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

  /// إعادة القفل عند الرجوع من الخلفية بعد المهلة
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = context.read<LockService>();
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        lock.onPaused();
      case AppLifecycleState.resumed:
        lock.onResumed();
      case AppLifecycleState.inactive: // نوافذ النظام (المشاركة/الصلاحيات) لا تُقفل التطبيق
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = context.select<Store, bool>((s) => s.ready);
    final initError = context.select<Store, String?>((s) => s.initError);
    final lockReady = context.select<LockService, bool>((l) => l.initialized);
    final locked = context.select<LockService, bool>((l) => l.locked);
    final signedIn = context.select<Store, bool>((s) => s.signedIn);
    if (ready && lockReady && !signedIn) return const SignInScreen();
    if (ready && lockReady && locked) return const LockScreen();
    if (!ready || !lockReady) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Image(image: AssetImage('assets/img/logo.png'), width: 130),
                const SizedBox(height: 22),
                if (initError == null) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 14),
                  Text('جارٍ تحميل بياناتك…', style: TextStyle(color: C.muted, fontWeight: FontWeight.w700)),
                ] else ...[
                  Icon(Icons.error_outline_rounded, color: C.red, size: 40),
                  const SizedBox(height: 10),
                  const Text('تعذّر فتح قاعدة البيانات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    'لا تقلق، بياناتك محفوظة على الجهاز. أعد المحاولة، وإن تكررت المشكلة أغلق التطبيق وافتحه من جديد.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: C.muted),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => context.read<Store>().init(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ]),
            ),
          ),
        ),
      );
    }
    final pages = [
      HomeScreen(onNavigate: go, onMenu: openMenu),
      const ClientsScreen(),
      const DocsScreen(),
      const StatementsScreen(),
    ];
    return Scaffold(
      key: _scaffold,
      drawer: AppDrawer(onNavigate: go),
      drawerEdgeDragWidth: 40,
      body: SafeArea(bottom: false, child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: _Nav3D(index: _tab, onTap: go),
    );
  }
}

/// شريط التنقل السفلي بأيقونات 3D (nav في التصميم الأصلي)
class _Nav3D extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _Nav3D({required this.index, required this.onTap});

  static const _items = [
    (Ic.dallah, 'الرئيسية'),
    (Ic.clients, 'العملاء'),
    (Ic.invoice, 'الفواتير'),
    (Ic.statement, 'الكشوف'),
  ];

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: 72 + pad,
      padding: EdgeInsets.only(bottom: pad),
      decoration: BoxDecoration(
        color: C.isDark ? C.bg2.withValues(alpha: 0.96) : Colors.white.withValues(alpha: 0.96),
        border: Border(top: BorderSide(color: C.line)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: C.isDark ? 0.35 : 0.08), blurRadius: 18, offset: const Offset(0, -6))],
      ),
      child: Row(children: [
        for (var i = 0; i < _items.length; i++)
          Expanded(
            child: _NavItem(icon: _items[i].$1, label: _items[i].$2, selected: i == index, onTap: () => onTap(i)),
          ),
      ]),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String icon, label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Stack(alignment: Alignment.topCenter, children: [
          // خط ذهبي علوي للتبويب النشط
          AnimatedOpacity(
            opacity: selected ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: Container(
              width: 44,
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [C.goldDeep, C.gold2, C.goldDeep]),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
              ),
            ),
          ),
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedScale(
              scale: selected ? 1.0 : 0.86,
              duration: const Duration(milliseconds: 180),
              child: KIcon(icon, size: 30, opacity: selected ? 1 : 0.62),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: selected ? C.goldInk : C.text3)),
          ]),
        ]),
      );
}
