import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/theme_provider.dart';
import 'dashboard/dashboard_page.dart';
import 'accounts/accounts_page.dart';
import 'transactions/transactions_page.dart';
import 'goals/goals_page.dart';
import 'settings/settings_page.dart';

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    const pages = [
      DashboardPage(),
      AccountsPage(),
      TransactionsPage(),
      GoalsPage(),
      SettingsPage(),
    ];

    return Scaffold(
      body: IndexedStack(
        key: ValueKey('main_stack_${themeMode.name}_$isDark'),
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Akun',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transaksi',
          ),
          NavigationDestination(
            icon: Icon(Icons.track_changes_outlined),
            selectedIcon: Icon(Icons.track_changes),
            label: 'Target',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}
