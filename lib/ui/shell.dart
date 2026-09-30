/// shell.dart — الهيكل الرئيسي والتنقل السفلي | كيف الضيافة
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/brand.dart';
import '../core/file_service.dart';
import '../core/license_service.dart';
import '../core/lock_service.dart';
import '../core/store.dart';
import 'drawer.dart';
import 'screens/clients_screen.dart';
import 'screens/docs_screen.dart';
import 'screens/home_screen.dart';
import 'screens/license_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/restore_sheet.dart';
import 'screens/signin_screen.dart';
import 'screens/statements_screen.dart';
import 'screens/storage_setup_screen.dart';
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
  bool _restoreChecked = false;

  /// بعد إعادة التثبيت: قاعدة فارغة + نسخ سليمة في مجلد التطبيق ⇐ نعرض قائمة الاستعادة
  /// تلقائيًا مرة واحدة (حتى لا يظن المستخدم أن بياناته ضاعت)
  Future<void> _offerRestoreOnce() async {
    if (_restoreChecked) return;
    _restoreChecked = true;
    final store = context.read<Store>();
    if (!await shouldOfferRestore(store)) return;
    if (!mounted) return;
    await showRestoreSheet(context, store, auto: true);
  }

  void go(int i) {
    if (i != _tab) HapticFeedback.selectionClick();
    setState(() => _tab = i);
  }

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
        // نسخة احتياطية فورية عند الخروج (إن كان هناك تعديل لم يُحفظ في نسخة بعد)
        context.read<Store>().flushBackupOnExit();
      case AppLifecycleState.resumed:
        lock.onResumed();
        context.read<LicenseService>().onResumed();
      case AppLifecycleState.detached:
        // إغلاق كامل: آخر فرصة للكتابة
        context.read<Store>().flushBackupOnExit();
      case AppLifecycleState
          .inactive: // نوافذ النظام (المشاركة/الصلاحيات) لا تُقفل التطبيق
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
    final storageAsked = context.select<Store, bool>(
      (s) => s.kv('storageAsked') == true,
    );
    // القفل عن بُعد يسبق كل شيء (البيانات لا تُمس)
    final licensed = context.select<LicenseService, bool>((l) => l.allowed);
    if (!licensed) return const LicenseScreen();
    if (ready && lockReady && !signedIn) return const SignInScreen();
    // مرة واحدة على الهاتف: إنشاء مجلد التطبيق في جذر الذاكرة الداخلية
    if (ready &&
        lockReady &&
        !locked &&
        FileService.supported &&
        !storageAsked) {
      return const StorageSetupScreen();
    }
    if (ready && lockReady && locked) return const LockScreen();
    if (!ready || !lockReady) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image(image: AssetImage(Brand.current.logo), width: 130),
                  const SizedBox(height: 22),
                  if (initError == null) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 14),
                    Text(
                      'جارٍ تحميل بياناتك…',
                      style: TextStyle(
                        color: C.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ] else ...[
                    Icon(Icons.error_outline_rounded, color: C.red, size: 40),
                    const SizedBox(height: 10),
                    const Text(
                      'تعذّر فتح قاعدة البيانات',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
                ],
              ),
            ),
          ),
        ),
      );
    }
    // الواجهة الرئيسية جاهزة: عرض الاستعادة التلقائية إن لزم (بعد أول إطار)
    if (!_restoreChecked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _offerRestoreOnce());
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
      body: SafeArea(
        bottom: false,
        // تبديل التبويبات بتلاشٍ قصير بدل القطع المباشر، مع حفظ حالة كل تبويب
        // (Offstage يُبقي الشجرة حيّة كما يفعل IndexedStack، وTickerMode يوقف حركات المخفي)
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < pages.length; i++)
              Offstage(
                offstage: i != _tab,
                child: TickerMode(
                  enabled: i == _tab,
                  child: _FadeInTab(visible: i == _tab, child: pages[i]),
                ),
              ),
          ],
        ),
      ),
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
        color: C.isDark
            ? C.bg2.withValues(alpha: 0.96)
            : Colors.white.withValues(alpha: 0.96),
        border: Border(top: BorderSide(color: C.line)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: C.isDark ? 0.35 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: _NavItem(
                icon: _items[i].$1,
                label: _items[i].$2,
                selected: i == index,
                onTap: () => onTap(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String icon, label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Stack(
      alignment: Alignment.topCenter,
      children: [
        // خط ذهبي علوي للتبويب النشط
        AnimatedOpacity(
          opacity: selected ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Container(
            width: 44,
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [C.goldDeep, C.gold2, C.goldDeep],
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(4),
              ),
            ),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.0 : 0.86,
              duration: const Duration(milliseconds: 180),
              child: KIcon(icon, size: 30, opacity: selected ? 1 : 0.62),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: selected ? C.goldInk : C.text3,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// يُظهر التبويب بتلاشٍ قصير (180ms) كل مرة يصبح فيها مرئيًا، دون إعادة بناء محتواه
class _FadeInTab extends StatefulWidget {
  final bool visible;
  final Widget child;
  const _FadeInTab({required this.visible, required this.child});
  @override
  State<_FadeInTab> createState() => _FadeInTabState();
}

class _FadeInTabState extends State<_FadeInTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: 1,
  );

  @override
  void didUpdateWidget(_FadeInTab old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
    child: widget.child,
  );
}
