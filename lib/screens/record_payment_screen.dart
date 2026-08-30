import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import '../providers/data_provider.dart';
import '../models/expense.dart';
import '../models/split_method.dart';
import '../models/expense_group.dart';
import '../theme/app_theme.dart';
import '../widgets/neo_button.dart';

class RecordPaymentScreen extends StatefulWidget {
  final String groupId;

  const RecordPaymentScreen({super.key, required this.groupId});

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _amountController = TextEditingController();
  String? _senderId;
  String? _receiverId;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _savePayment(ExpenseGroup group) async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amount must be greater than 0')));
      return;
    }
    if (_senderId == null || _receiverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select both a sender and receiver')));
      return;
    }
    if (_senderId == _receiverId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sender and receiver cannot be the same person')));
      return;
    }

    final senderName = group.members.firstWhere((m) => m.id == _senderId).name;
    final receiverName = group.members.firstWhere((m) => m.id == _receiverId).name;

    final expenseId = const Uuid().v4();
    final expense = Expense(
      id: expenseId,
      groupId: widget.groupId,
      title: 'Payment: $senderName to $receiverName',
      amount: amount,
      category: 'Payment',
      splitMethod: SplitMethod.specific,
      date: DateTime.now(),
      payers: [ExpenseParticipant(expenseId: expenseId, userId: _senderId!, amount: amount)],
      splitters: [ExpenseParticipant(expenseId: expenseId, userId: _receiverId!, amount: amount)],
    );

    await Provider.of<DataProvider>(context, listen: false).addExpense(expense);
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded successfully!')));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final group = dataProvider.groups.firstWhere((g) => g.id == widget.groupId, orElse: () => ExpenseGroup(id: '', name: ''));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Payment'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          const Text('Amount', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              prefixIcon: Padding(
                padding: EdgeInsets.only(left: 20, top: 12),
                child: Text('₹ ', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              // inheriting border from theme
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            ),
          ),
          const SizedBox(height: 24),
          
          const Text('Who is paying?', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _senderId,
            decoration: const InputDecoration(),
            items: group.members.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
            onChanged: (val) => setState(() => _senderId = val),
            hint: const Text('Select Sender'),
          ),
          const SizedBox(height: 24),

          const Center(child: Icon(Icons.arrow_downward, color: Colors.grey)),
          const SizedBox(height: 24),

          const Text('Who is receiving?', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _receiverId,
            decoration: const InputDecoration(),
            items: group.members.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
            onChanged: (val) => setState(() => _receiverId = val),
            hint: const Text('Select Receiver'),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: const Border(top: BorderSide(color: Colors.black, width: 3)),
        ),
        child: SafeArea(
          child: NeoButton(
            color: AppTheme.neoYellow,
            padding: const EdgeInsets.symmetric(vertical: 16),
            onPressed: () => _savePayment(group),
            child: const Text('SAVE PAYMENT', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
          ),
        ),
      ),
    );
  }
}
