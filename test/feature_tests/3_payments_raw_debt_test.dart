import 'package:flutter_test/flutter_test.dart';
import 'package:campus_quicksplit/models/expense_group.dart';
import 'package:campus_quicksplit/models/expense.dart';
import 'package:campus_quicksplit/models/user.dart';
import 'package:campus_quicksplit/models/split_method.dart';
import 'package:campus_quicksplit/services/settlement_service.dart';

void main() {
  group('Raw Debt with Payments Deduction', () {
    test('Unoptimized debts strictly offset when a payment is made', () {
      final userA = User(id: 'A', name: 'Alice');
      final userB = User(id: 'B', name: 'Bob');
      
      final group = ExpenseGroup(
        id: 'group1',
        name: 'Test Group',
        members: [userA, userB],
      );

      // 1. A pays for dinner (1000). A paid 1000, A and B split equally (500 each).
      // So B owes A 500.
      final dinner = Expense(
        id: 'exp1',
        groupId: 'group1',
        title: 'Dinner',
        amount: 1000.0,
        category: 'Food',
        splitMethod: SplitMethod.uniform,
        date: DateTime.now(),
        payers: [ExpenseParticipant(expenseId: 'exp1', userId: 'A', amount: 1000.0)],
        splitters: [ExpenseParticipant(expenseId: 'exp1', userId: 'A', amount: 500.0), ExpenseParticipant(expenseId: 'exp1', userId: 'B', amount: 500.0)],
      );

      // 2. B makes a partial payment of 400 to A.
      // In a Payment, B is the payer (400), A is the splitter (owes 400 back to balance).
      final payment = Expense(
        id: 'exp2',
        groupId: 'group1',
        title: 'Payment: B to A',
        amount: 400.0,
        category: 'Payment', // Crucial category
        splitMethod: SplitMethod.uniform,
        date: DateTime.now().add(const Duration(hours: 1)),
        payers: [ExpenseParticipant(expenseId: 'exp2', userId: 'B', amount: 400.0)],
        splitters: [ExpenseParticipant(expenseId: 'exp2', userId: 'A', amount: 400.0)],
      );

      final expenses = [dinner, payment];

      // Calculate unoptimized debts. 
      // Before the fix, this would completely skip the payment and output B owes A 500.
      // After the fix, it correctly calculates B owes A 100.
      final rawDebts = SettlementService.getUnoptimizedDebts(group, expenses);

      expect(rawDebts.length, 1, reason: 'Should net to exactly 1 unoptimized debt path');
      
      final netDebt = rawDebts.first;
      expect(netDebt.from, 'B', reason: 'Bob still owes money');
      expect(netDebt.to, 'A', reason: 'Alice is owed money');
      expect(netDebt.amount, 100.0, reason: 'Original 500 debt minus 400 payment is exactly 100');
    });
  });
}
