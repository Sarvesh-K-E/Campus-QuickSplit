import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/data_provider.dart';
import '../models/user.dart';

class ViewExpenseScreen extends StatelessWidget {
  final String groupId;
  final String expenseId;

  const ViewExpenseScreen({super.key, required this.groupId, required this.expenseId});

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final group = dataProvider.groups.firstWhere((g) => g.id == groupId);
    final expense = dataProvider.currentGroupExpenses.firstWhere((e) => e.id == expenseId);

    return Scaffold(
      appBar: AppBar(
        title: Text(expense.category == 'Payment' ? 'Payment Details' : 'Expense Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, width: 2),
                  ),
                  child: Icon(Icons.receipt_long, size: 36, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(height: 16),
                Text(expense.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  '₹ ${expense.amount.toStringAsFixed(2)}',
                  style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Chip(label: Text(expense.category)),
                const SizedBox(height: 24),
                Text(
                  'Date: ${DateFormat('dd-MM-yy').format(expense.date.toUtc().add(const Duration(hours: 5, minutes: 30)))}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          Text('PAID BY', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          ...(() {
            final sortedPayers = List.of(expense.payers);
            sortedPayers.sort((a, b) {
              final idxA = group.members.indexWhere((m) => m.id == a.userId);
              final idxB = group.members.indexWhere((m) => m.id == b.userId);
              return idxA.compareTo(idxB);
            });
            return sortedPayers.map((p) {
              final member = group.members.firstWhere((m) => m.id == p.userId, orElse: () => User(id: '', name: 'Unknown'));
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, width: 2),
                      ),
                      child: Center(child: Text(member.name[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20))),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Text(member.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                    Text('₹ ${p.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            });
          })(),
          const SizedBox(height: 24),
          Text(expense.category == 'Payment' ? 'TO' : 'SPLIT AMONG', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          ...(() {
            final sortedSplitters = List.of(expense.splitters);
            sortedSplitters.sort((a, b) {
              final idxA = group.members.indexWhere((m) => m.id == a.userId);
              final idxB = group.members.indexWhere((m) => m.id == b.userId);
              return idxA.compareTo(idxB);
            });
            return sortedSplitters.map((s) {
              final member = group.members.firstWhere((m) => m.id == s.userId, orElse: () => User(id: '', name: 'Unknown'));
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, width: 2),
                      ),
                      child: Center(child: Text(member.name[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20))),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Text(member.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                    Text('₹ ${s.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            });
          })(),
        ],
      ),
    );
  }
}
