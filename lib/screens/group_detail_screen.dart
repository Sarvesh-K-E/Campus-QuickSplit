import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/data_provider.dart';
import '../models/expense_group.dart';
import '../models/expense.dart';
import '../models/split_method.dart';
import '../models/user.dart';
import '../services/settlement_service.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../widgets/neo_button.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DataProvider>(context, listen: false).loadGroupExpenses(widget.groupId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final group = dataProvider.groups.firstWhere((g) => g.id == widget.groupId, orElse: () => ExpenseGroup(id: '', name: ''));

    // Compute balances for embedded Settle Up view
    final balances = SettlementService.calculateBalances(group, dataProvider.currentGroupExpenses);

    final unoptimized = SettlementService.getUnoptimizedDebts(group, dataProvider.currentGroupExpenses);
    final transactions = SettlementService.simplifyDebts(balances);

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              context.push('/p2p_share/${widget.groupId}');
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.push('/groups/${widget.groupId}/edit');
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildUnifiedSettlementBlock(context, group, transactions),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          
          // EXPENSES SECTION
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text('EXPENSES', style: Theme.of(context).textTheme.titleMedium?.copyWith(letterSpacing: 1.2)),
            ),
          ),
          dataProvider.currentGroupExpenses.where((e) => e.category != 'Payment').isEmpty
              ? const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: Text('No expenses yet. Add one!')),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final expense = dataProvider.currentGroupExpenses.where((e) => e.category != 'Payment').toList()[index];
                      return _buildExpenseListItem(context, expense, dataProvider, index);
                    },
                    childCount: dataProvider.currentGroupExpenses.where((e) => e.category != 'Payment').length,
                  ),
                ),
                
          // PAYMENTS SECTION
          if (dataProvider.currentGroupExpenses.where((e) => e.category == 'Payment').isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 32.0, bottom: 8.0),
                child: Text('PAYMENTS', style: Theme.of(context).textTheme.titleMedium?.copyWith(letterSpacing: 1.2)),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final expense = dataProvider.currentGroupExpenses.where((e) => e.category == 'Payment').toList()[index];
                  return _buildExpenseListItem(context, expense, dataProvider, index);
                },
                childCount: dataProvider.currentGroupExpenses.where((e) => e.category == 'Payment').length,
              ),
            ),
          ],
          
          const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding for sticky bottom bar
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: const Border(top: BorderSide(color: Colors.black, width: 3)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: NeoButton(
                  color: AppTheme.neoPink,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  onPressed: () => context.push('/groups/${widget.groupId}/record_payment'),
                  child: const Text('RECORD PAYMENT', textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: NeoButton(
                  color: AppTheme.neoGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  onPressed: () => context.push('/groups/${widget.groupId}/add_expense'),
                  child: const Text('ADD EXPENSE', textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedSettlementBlock(BuildContext context, ExpenseGroup group, List<Transaction> transactions) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header (Formerly Debt Summary Card)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.neoYellow,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, 
                  width: transactions.isNotEmpty ? 3 : 0,
                )
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.neoPurple,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: const Icon(Icons.auto_graph, color: Colors.black, size: 24),
                ),
                const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transactions.isEmpty ? 'All settled up!' : '${transactions.length} transfers needed', 
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black)
                        ),
                        const SizedBox(height: 2),
                        const Text('Optimized payouts', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.1)),
                      ],
                    ),
                  ),
                  if (transactions.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.info_outline, color: Colors.black, size: 28),
                      onPressed: () {
                        context.push('/groups/${group.id}/graph');
                      },
                    ),
                ],
              ),
          ),
          
          // Transactions List
          if (transactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('WHO OWES WHO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2)),
                  const SizedBox(height: 16),
                  ...transactions.map((tx) => _buildTransactionCard(context, group, tx)).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, ExpenseGroup group, Transaction tx) {
    final fromUser = group.members.firstWhere(
      (m) => m.id == tx.from, 
      orElse: () => User(id: tx.from, name: 'Unknown', isLocal: false)
    );
    final toUser = group.members.firstWhere(
      (m) => m.id == tx.to,
      orElse: () => User(id: tx.to, name: 'Unknown', isLocal: false)
    );
    
    final avatarColor = [AppTheme.neoGreen, AppTheme.neoPink, AppTheme.neoBlue, AppTheme.neoOrange][fromUser.name.hashCode % 4];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.white,
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, width: 2),
      ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: avatarColor,
                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, width: 2),
              ),
              child: Center(child: Text(fromUser.name[0].toUpperCase(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fromUser.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      const Text('owes ', style: TextStyle(color: Colors.grey, fontSize: 14)),
                      Expanded(
                        child: Text(
                          toUser.name, 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        )
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '₹${tx.amount.toStringAsFixed(2)}', 
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18)
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Mark Settled'),
                    content: Text('Record a payment of ₹${tx.amount.toStringAsFixed(2)} from ${fromUser.name} to ${toUser.name}?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final expenseId = const Uuid().v4();
                            final expense = Expense(
                              id: expenseId,
                              groupId: group.id,
                              title: 'Payment: ${fromUser.name} to ${toUser.name}',
                              amount: tx.amount,
                              category: 'Payment',
                              splitMethod: SplitMethod.specific,
                              date: DateTime.now(),
                              payers: [ExpenseParticipant(expenseId: expenseId, userId: fromUser.id, amount: tx.amount)],
                              splitters: [ExpenseParticipant(expenseId: expenseId, userId: toUser.id, amount: tx.amount)],
                            );
                            await Provider.of<DataProvider>(context, listen: false).addExpense(expense);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settled successfully!')));
                          },
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.check),
              tooltip: 'Mark Settled',
              style: IconButton.styleFrom(backgroundColor: Colors.green.shade600),
            ),
          ],
        ),
    );
  }

  Widget _buildExpenseListItem(BuildContext context, Expense expense, DataProvider dataProvider, int index) {
    final isPayment = expense.category == 'Payment';
    return Slidable(
      key: ValueKey(expense.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) {
              dataProvider.deleteExpense(expense.id, expenseTitle: expense.title, expenseAmount: expense.amount);
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Deleted'),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'UNDO',
                  onPressed: () {
                    dataProvider.undoExpenseDeletion(expense);
                  },
                ),
              ));
            },
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: InkWell(
          onTap: () {
            context.push('/groups/${widget.groupId}/view_expense?expenseId=${expense.id}');
          },
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isPayment ? Colors.green.withOpacity(0.1) : Theme.of(context).primaryColor.withOpacity(0.1),
                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, width: 2),
              ),
              child: Icon(
                isPayment ? Icons.payments : Icons.receipt_long, 
                color: isPayment ? Colors.green : Theme.of(context).primaryColor
              ),
            ),
            title: Text(expense.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: isPayment ? null : Text(expense.category),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '₹ ${expense.amount.toStringAsFixed(2)}', 
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 16,
                    color: isPayment ? Colors.green : null,
                  )
                ),
                if (!isPayment)
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: InkWell(
                      onTap: () {
                        context.push('/groups/${widget.groupId}/add_expense?expenseId=${expense.id}');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.neoYellow,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: const Icon(Icons.edit, size: 18, color: Colors.black),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
