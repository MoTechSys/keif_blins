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
    if (!ready) {
      return const Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image(image: AssetImage('assets/img/logo.png'), width: 110),
            SizedBox(height: 18),
            CircularProgressIndicator(),
          ]),
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
