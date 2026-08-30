import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/data_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/neo_card.dart';
import '../widgets/neo_button.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              context.push('/profile');
            },
          ),
          IconButton(
            icon: Icon(themeProvider.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeProvider.toggleTheme(themeProvider.themeMode != ThemeMode.dark);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBalanceCard(context, dataProvider).animate().fade(duration: 400.ms).slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOut),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: NeoButton(
                    color: AppTheme.neoYellow,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    onPressed: () {
                      context.push('/receive');
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_2, color: Colors.black, size: 24),
                        SizedBox(width: 8),
                        Text('RECEIVE\nPAYMENTS', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: NeoButton(
                    color: AppTheme.neoPink,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    onPressed: () {
                      context.push('/pending');
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payment, color: Colors.black, size: 24),
                        SizedBox(width: 8),
                        Text('PENDING\nPAYMENTS', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0)),
                      ],
                    ),
                  ),
                ),
              ],
            ).animate(delay: 50.ms).fade(duration: 400.ms).slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOut),
            const SizedBox(height: 24),
            _buildRecentSplits(context, dataProvider).animate(delay: 100.ms).fade(duration: 400.ms).slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOut),
            const SizedBox(height: 24),
            _buildGroupsPreview(context, dataProvider).animate(delay: 200.ms).fade(duration: 400.ms).slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOut),
            const SizedBox(height: 100), // Bottom padding for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, DataProvider dataProvider) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.neoBlue,
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
            offset: const Offset(4, 4),
            blurRadius: 0,
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          children: [
            Text(
              'TOTAL GROUP SPENDING (THIS MONTH)',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '₹ ${dataProvider.currentMonthTotalIST.toStringAsFixed(2)}', 
              style: const TextStyle(
                color: Colors.black, 
                fontSize: 40,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSplits(BuildContext context, DataProvider dataProvider) {
    final recentExpenses = dataProvider.allExpenses.where((e) => e.category != 'Payment').take(3).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECENT SPLITS',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        if (recentExpenses.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined, size: 48, color: Theme.of(context).primaryColor.withOpacity(0.4)),
                const SizedBox(height: 16),
                const Text(
                  'No recent splits',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'When you add expenses, they will\nappear right here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          )
        else
          ...recentExpenses.map((exp) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.neoPink,
                    border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, width: 2),
                  ),
                  child: const Icon(Icons.receipt_long, color: Colors.black),
                ),
                title: Text(exp.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(exp.category),
                trailing: Text('₹ ${exp.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildGroupsPreview(BuildContext context, DataProvider dataProvider) {
    final recentGroups = dataProvider.groups.take(3).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'YOUR GROUPS',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/groups'),
              child: const Text('More'),
            ),
          ],
        ),
        if (recentGroups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.group_add_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('No groups yet. Create one!', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          )
        else
          ...recentGroups.map((group) {
            return NeoCard(
              margin: const EdgeInsets.only(bottom: 8),
              onTap: () {
                context.push('/groups/${group.id}');
              },
              child: ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.neoOrange,
                    border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, width: 2),
                  ),
                  child: Center(child: Text(group.name[0].toUpperCase(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24))),
                ),
                title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${group.members.length} members'),
                trailing: const Icon(Icons.chevron_right),
              ),
            );
          }),
      ],
    );
  }
}
