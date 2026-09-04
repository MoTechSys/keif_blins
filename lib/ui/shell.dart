/// shell.dart — الهيكل الرئيسي والتنقل السفلي | كيف الضيافة
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/store.dart';
import 'screens/clients_screen.dart';
import 'screens/docs_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/statements_screen.dart';
import 'theme.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  void go(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final ready = context.select<Store, bool>((s) => s.ready);
    final initError = context.select<Store, String?>((s) => s.initError);
    if (!ready) {
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
                  const Text('جارٍ تحميل بياناتك…', style: TextStyle(color: C.muted, fontWeight: FontWeight.w700)),
                ] else ...[
                  const Icon(Icons.error_outline_rounded, color: C.red, size: 40),
                  const SizedBox(height: 10),
                  const Text('تعذّر فتح قاعدة البيانات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text(
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
      HomeScreen(onNavigate: go),
      const ClientsScreen(),
      const DocsScreen(),
      const StatementsScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.line))),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: go,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people_rounded), label: 'العملاء'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'الفواتير'),
            NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'الكشوف'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'الإعدادات'),
          ],
        ),
      ),
    );
  }
}
