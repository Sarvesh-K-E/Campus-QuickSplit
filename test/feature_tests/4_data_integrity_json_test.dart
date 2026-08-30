import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_quicksplit/models/expense_group.dart';
import 'package:campus_quicksplit/models/expense.dart';
import 'package:campus_quicksplit/models/user.dart';
import 'package:campus_quicksplit/models/split_method.dart';

void main() {
  group('P2P Deep JSON Serialization Integrity', () {
    test('Correctly serializes and deserializes a complex group without data loss', () {
      final userA = User(id: 'uuid-a', name: 'Alice', upiId: 'alice@upi');
      final userB = User(id: 'uuid-b', name: 'Bob');
      
      final group = ExpenseGroup(id: 'group-uuid', name: 'Goa Trip', members: [userA, userB]);
      
      final expense = Expense(
        id: 'exp-uuid',
        groupId: 'group-uuid',
        title: 'Hotel',
        amount: 2500.50,
        category: 'Accommodation',
        splitMethod: SplitMethod.ratio,
        date: DateTime(2023, 1, 1, 12, 0),
        isRecurring: true,
        payers: [ExpenseParticipant(expenseId: 'exp-uuid', userId: 'uuid-a', amount: 2500.50)],
        splitters: [ExpenseParticipant(expenseId: 'exp-uuid', userId: 'uuid-a', amount: 1500.30), ExpenseParticipant(expenseId: 'exp-uuid', userId: 'uuid-b', amount: 1000.20)],
      );

      // 1. Serialize exactly as DataProvider does
      final Map<String, dynamic> dataToExport = {
        'group': group.toMap(),
        'members': group.members.map((m) {
          final map = m.toMap();
          map['is_local'] = 0; // Force remote
          return map;
        }).toList(),
        'expenses': [expense].map((e) {
          final map = e.toMap();
          map['payers'] = e.payers.map((p) => p.toMap()).toList();
          map['splitters'] = e.splitters.map((s) => s.toMap()).toList();
          return map;
        }).toList(),
      };

      final jsonString = jsonEncode(dataToExport);

      // 2. Deserialize exactly as DataProvider does
      final decodedData = jsonDecode(jsonString);
      
      final uGroupMap = decodedData['group'] as Map<String, dynamic>;
      final uMembersList = decodedData['members'] as List<dynamic>;
      final uExpensesList = decodedData['expenses'] as List<dynamic>;

      final restoredGroup = ExpenseGroup.fromMap(uGroupMap);
      
      final restoredMembers = uMembersList.map((m) => User.fromMap(m as Map<String, dynamic>)).toList();
      
      final restoredExpenses = uExpensesList.map((e) {
        final expenseMap = e as Map<String, dynamic>;
        final exp = Expense.fromMap(expenseMap);
        exp.payers = (expenseMap['payers'] as List<dynamic>).map((p) => ExpenseParticipant.fromMap(p)).toList();
        exp.splitters = (expenseMap['splitters'] as List<dynamic>).map((s) => ExpenseParticipant.fromMap(s)).toList();
        return exp;
      }).toList();

      // 3. Assertions
      expect(restoredGroup.id, 'group-uuid');
      expect(restoredGroup.name, 'Goa Trip');
      
      expect(restoredMembers.length, 2);
      expect(restoredMembers[0].name, 'Alice');
      expect(restoredMembers[0].upiId, 'alice@upi');
      expect(restoredMembers[0].isLocal, false); // Proves the injection worked
      
      expect(restoredExpenses.length, 1);
      final restExp = restoredExpenses[0];
      expect(restExp.id, 'exp-uuid');
      expect(restExp.amount, 2500.50);
      expect(restExp.category, 'Accommodation');
      expect(restExp.splitMethod, SplitMethod.ratio);
      expect(restExp.isRecurring, true);
      
      expect(restExp.payers.length, 1);
      expect(restExp.payers[0].userId, 'uuid-a');
      expect(restExp.payers[0].amount, 2500.50);
      
      expect(restExp.splitters.length, 2);
      expect(restExp.splitters[1].userId, 'uuid-b');
      expect(restExp.splitters[1].amount, 1000.20);
    });
  });
}
