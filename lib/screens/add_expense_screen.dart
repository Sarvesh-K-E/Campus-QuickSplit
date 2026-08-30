import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../providers/data_provider.dart';
import '../models/expense.dart';
import '../models/expense_group.dart';
import '../models/split_method.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../widgets/neo_button.dart';
import '../widgets/neo_card.dart';

class AddExpenseScreen extends StatefulWidget {
  final String groupId;
  final String? existingExpenseId;

  const AddExpenseScreen({super.key, required this.groupId, this.existingExpenseId});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _category = 'Food';
  SplitMethod _splitMethod = SplitMethod.uniform;
  
  Map<String, double> _manualSplits = {};
  Map<String, double> _ratios = {};
  Map<String, double> _payers = {}; 
  Map<String, bool> _participants = {};

  final List<String> _categories = ['Food', 'Transport', 'Subs', 'Supplies', 'Other'];
  
  final Map<String, IconData> _categoryIcons = {
    'Food': Icons.fastfood,
    'Transport': Icons.directions_car,
    'Subs': Icons.subscriptions,
    'Supplies': Icons.shopping_bag,
    'Other': Icons.category,
  };

  DateTime _originalDate = DateTime.now();
  bool _isRecurring = false;
  String? _lastProcessedMonth;

  @override
  void initState() {
    super.initState();
    
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final group = dataProvider.groups.firstWhere((g) => g.id == widget.groupId);
    final localUser = dataProvider.localUser;
    
    if (widget.existingExpenseId != null) {
      final existing = dataProvider.currentGroupExpenses.firstWhere((e) => e.id == widget.existingExpenseId);
      _titleController.text = existing.title;
      _amountController.text = existing.amount.toString();
      _category = existing.category;
      _splitMethod = existing.splitMethod;
      _originalDate = existing.date;
      _isRecurring = existing.isRecurring;
      _lastProcessedMonth = existing.lastProcessedMonth;

      for (var member in group.members) {
        _participants[member.id] = false;
        _payers[member.id] = 0.0;
      }
      
      for (var p in existing.payers) {
        _payers[p.userId] = p.amount;
      }
      
      for (var s in existing.splitters) {
        _participants[s.userId] = true;
        if (_splitMethod == SplitMethod.specific) {
          _manualSplits[s.userId] = s.amount;
        } else if (_splitMethod == SplitMethod.ratio) {
          _ratios[s.userId] = (s.amount / existing.amount) * 100;
        }
      }
    } else {
      if (localUser != null) {
        _payers[localUser.id] = 0.0;
      }
      for (var member in group.members) {
        _participants[member.id] = true;
      }
    }
  }

  void _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final group = dataProvider.groups.firstWhere((g) => g.id == widget.groupId);

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) return;

    double totalPaid = _payers.values.fold(0, (sum, val) => sum + val);
    if ((totalPaid - amount).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Total paid upfront must equal total expense amount')));
      return;
    }

    int includedCount = _participants.values.where((v) => v).length;
    if (includedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At least one person must be included in the split')));
      return;
    }


    if (_splitMethod == SplitMethod.specific) {
      double totalSplit = _manualSplits.values.fold(0.0, (sum, val) => sum + val);
      if ((totalSplit - amount).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Manual splits must exactly equal the total expense amount')));
        return;
      }
    } else if (_splitMethod == SplitMethod.ratio) {
      double totalRatio = _ratios.values.fold(0.0, (sum, val) => sum + val);
      if ((totalRatio - 100).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ratios must exactly equal 100%')));
        return;
      }
    }

    final expenseId = widget.existingExpenseId ?? const Uuid().v4();
    List<ExpenseParticipant> payersList = [];
    _payers.forEach((userId, paidAmount) {
      if (paidAmount > 0) {
        payersList.add(ExpenseParticipant(expenseId: expenseId, userId: userId, amount: paidAmount));
      }
    });

    List<ExpenseParticipant> splitters = [];
    double totalDistributed = 0.0;
    int processedCount = 0;

    for (var member in group.members) {
      if (_participants[member.id] != true) continue;
      processedCount++;

      double splitAmount = 0;
      if (_splitMethod == SplitMethod.uniform) {
        splitAmount = double.parse((amount / includedCount).toStringAsFixed(2));
        if (processedCount == includedCount) {
          double remainder = amount - totalDistributed;
          splitAmount = double.parse(remainder.toStringAsFixed(2));
        }
      } else if (_splitMethod == SplitMethod.specific) {
        splitAmount = _manualSplits[member.id] ?? 0.0;
      } else if (_splitMethod == SplitMethod.ratio) {
        splitAmount = amount * ((_ratios[member.id] ?? 0.0) / 100.0);
      }

      totalDistributed += splitAmount;

      if (splitAmount > 0) {
        splitters.add(ExpenseParticipant(expenseId: expenseId, userId: member.id, amount: splitAmount));
      }
    }

    final expense = Expense(
      id: expenseId,
      groupId: widget.groupId,
      title: _titleController.text.trim(),
      amount: amount,
      category: _category,
      splitMethod: _splitMethod,
      date: widget.existingExpenseId != null ? _originalDate : DateTime.now().toUtc(),
      isRecurring: _isRecurring,
      lastProcessedMonth: widget.existingExpenseId == null && _isRecurring ? "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}" : _lastProcessedMonth,
      payers: payersList,
      splitters: splitters,
    );

    if (widget.existingExpenseId != null) {
      await dataProvider.updateExpense(expense);
    } else {
      await dataProvider.addExpense(expense);
    }
    
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = Provider.of<DataProvider>(context).groups.firstWhere((g) => g.id == widget.groupId);
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    double totalPaid = _payers.values.fold(0, (sum, val) => sum + val);
    bool payersBalanced = (totalPaid - amount).abs() < 0.01 && amount > 0;

    return Scaffold(
      appBar: AppBar(title: Text(widget.existingExpenseId != null ? 'Edit Expense' : 'Add Expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder(), prefixText: '₹ '),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Invalid amount';
                return null;
              },
              onChanged: (v) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Text('Category', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              children: _categories.map((c) {
                final isSelected = _category == c;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () => setState(() => _category = c),
                      borderRadius: BorderRadius.zero,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.15) : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.zero,
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _categoryIcons[c],
                              size: 28,
                              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              c,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 32),
            Text('Who Paid Upfront?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.zero,
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                  width: 2,
                ),
              ),
              child: Column(
                children: group.members.map((member) => _buildPayerField(member)).toList(),
              ),
            ),
            if (amount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 24.0),
                child: Text(
                  'Contributions matched: ₹${totalPaid.toStringAsFixed(2)} / ₹${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: payersBalanced ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            const SizedBox(height: 16),
            Text('Who is Included?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.zero,
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                  width: 2,
                ),
              ),
              child: Column(
                children: group.members.map((member) {
                  return CheckboxListTile(
                    title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    value: _participants[member.id] ?? false,
                    onChanged: (bool? value) {
                      setState(() {
                        _participants[member.id] = value ?? false;
                      });
                    },
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 32),
            Text('Split Method', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<SplitMethod>(
              segments: const [
                ButtonSegment(value: SplitMethod.uniform, label: Text('Uniform')),
                ButtonSegment(value: SplitMethod.specific, label: Text('Specific')),
                ButtonSegment(value: SplitMethod.ratio, label: Text('Ratio %')),
              ],
              selected: {_splitMethod},
              onSelectionChanged: (Set<SplitMethod> selection) {
                setState(() => _splitMethod = selection.first);
              },
            ),
            
            const SizedBox(height: 24),
            if (_splitMethod != SplitMethod.uniform)
              Text('Allocate Amounts', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            if (_splitMethod == SplitMethod.ratio)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Text('Total allocated: ${_ratios.values.fold(0.0, (sum, val) => sum + val).toStringAsFixed(1)}% / 100%', style: TextStyle(color: (_ratios.values.fold(0.0, (sum, val) => sum + val) - 100).abs() < 0.01 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
              ),
            if (_splitMethod == SplitMethod.specific)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Text('Total allocated: ₹${_manualSplits.values.fold(0.0, (sum, val) => sum + val).toStringAsFixed(2)} / ₹${amount.toStringAsFixed(2)}', style: TextStyle(color: (_manualSplits.values.fold(0.0, (sum, val) => sum + val) - amount).abs() < 0.01 && amount > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
              ),
            if (_splitMethod != SplitMethod.uniform) const SizedBox(height: 8),
            ...group.members
                .where((member) => _participants[member.id] == true)
                .map((member) => _buildSplitField(member, amount)).toList(),
            
            const SizedBox(height: 24),
            NeoCard(
              color: _isRecurring ? AppTheme.neoYellow : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white),
              margin: EdgeInsets.zero,
              child: CheckboxListTile(
                title: Text(
                  'Monthly Subscription', 
                  style: TextStyle(fontWeight: FontWeight.w900, color: _isRecurring ? Colors.black : null)
                ),
                subtitle: Text(
                  'Repeats on the 1st of every month',
                  style: TextStyle(fontWeight: FontWeight.w700, color: _isRecurring ? Colors.black87 : null)
                ),
                value: _isRecurring,
                activeColor: AppTheme.neoPink,
                checkColor: Colors.black,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                side: BorderSide(
                  color: _isRecurring ? Colors.black : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black), 
                  width: 2
                ),
                onChanged: (val) => setState(() => _isRecurring = val ?? false),
              ),
            ),
            
            const SizedBox(height: 32),
            NeoButton(
              onPressed: _saveExpense,
              color: AppTheme.neoGreen,
              child: Center(child: Text(widget.existingExpenseId != null ? 'Update Expense' : 'Save Expense', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPayerField(User member) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.2),
              border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, width: 2),
            ),
            child: Center(child: Text(member.name[0], style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 16, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: Text(member.name, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(
            flex: 3,
            child: TextFormField(
              key: ValueKey('payer_${member.id}'),
              initialValue: _payers[member.id] != null && _payers[member.id]! > 0 ? _payers[member.id].toString() : '',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              decoration: const InputDecoration(
                prefixIcon: Padding(
                  padding: EdgeInsets.only(left: 12, top: 13),
                  child: Text('₹ ', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ),
                border: OutlineInputBorder(),
                isDense: true,
                hintText: '0.00'
              ),
              onChanged: (val) {
                final v = double.tryParse(val) ?? 0.0;
                _payers[member.id] = v;
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitField(User member, double totalAmount) {
    if (_splitMethod == SplitMethod.uniform) {
      return const SizedBox.shrink();
    }

    final isRatio = _splitMethod == SplitMethod.ratio;
    final val = isRatio ? _ratios[member.id] : _manualSplits[member.id];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
            flex: 3,
            child: TextFormField(
              key: ValueKey('split_${member.id}'),
              initialValue: val != null && val > 0 ? val.toString() : '',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              decoration: InputDecoration(
                prefixIcon: isRatio ? null : const Padding(
                  padding: EdgeInsets.only(left: 12, top: 13),
                  child: Text('₹ ', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ),
                suffixText: isRatio ? '%' : '',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (vStr) {
                final v = double.tryParse(vStr) ?? 0.0;
                if (isRatio) {
                  _ratios[member.id] = v;
                } else {
                  _manualSplits[member.id] = v;
                }
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }
}
