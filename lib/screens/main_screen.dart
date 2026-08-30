import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class MainScreen extends StatelessWidget {
  final Widget child;

  const MainScreen({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/groups')) return 1;
    if (location.startsWith('/analytics')) return 2;
    if (location.startsWith('/activity')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/groups');
        break;
      case 2:
        context.go('/analytics');
        break;
      case 3:
        context.go('/activity');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, width: 3)),
        ),
        child: NavigationBar(
          selectedIndex: _calculateSelectedIndex(context),
          onDestinationSelected: (index) => _onItemTapped(index, context),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined), 
              selectedIcon: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppTheme.neoYellow, border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, width: 2)),
                child: const Icon(Icons.home_filled, color: Colors.black),
              ), 
              label: 'Home'
            ),
            NavigationDestination(
              icon: const Icon(Icons.people_outline), 
              selectedIcon: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppTheme.neoPink, border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, width: 2)),
                child: const Icon(Icons.people_alt, color: Colors.black),
              ), 
              label: 'Groups'
            ),
            NavigationDestination(
              icon: const Icon(Icons.insert_chart_outlined), 
              selectedIcon: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppTheme.neoBlue, border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, width: 2)),
                child: const Icon(Icons.insert_chart, color: Colors.black),
              ), 
              label: 'Analytics'
            ),
            NavigationDestination(
              icon: const Icon(Icons.history_outlined), 
              selectedIcon: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppTheme.neoGreen, border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, width: 2)),
                child: const Icon(Icons.history, color: Colors.black),
              ), 
              label: 'Activity'
            ),
          ],
        ),
      ),
    );
  }
}
