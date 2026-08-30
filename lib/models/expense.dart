import 'split_method.dart';

class Expense {
  final String id;
  final String groupId;
  final String title;
  final double amount;
  final String category;
  final SplitMethod splitMethod;
  final DateTime date;
  final bool isRecurring;
  final String? lastProcessedMonth;

  // Populated in-memory
  List<ExpenseParticipant> payers; 
  List<ExpenseParticipant> splitters;

  Expense({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amount,
    required this.category,
    required this.splitMethod,
    required this.date,
    this.isRecurring = false,
    this.lastProcessedMonth,
    this.payers = const [],
    this.splitters = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'title': title,
      'amount': amount,
      'category': category,
      'split_method': splitMethod.index,
      'date': date.toIso8601String(),
      'is_recurring': isRecurring ? 1 : 0,
      'last_processed_month': lastProcessedMonth,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      groupId: map['group_id'],
      title: map['title'],
      amount: (map['amount'] as num).toDouble(),
      category: map['category'],
      splitMethod: SplitMethod.values[map['split_method']],
      date: DateTime.parse(map['date']),
      isRecurring: map['is_recurring'] == 1,
      lastProcessedMonth: map['last_processed_month'],
    );
  }
}

class ExpenseParticipant {
  final String expenseId;
  final String userId;
  final double amount;

  ExpenseParticipant({
    required this.expenseId,
    required this.userId,
    required this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'expense_id': expenseId,
      'user_id': userId,
      'amount': amount,
    };
  }

  factory ExpenseParticipant.fromMap(Map<String, dynamic> map) {
    return ExpenseParticipant(
      expenseId: map['expense_id'],
      userId: map['user_id'],
      amount: (map['amount'] as num).toDouble(),
    );
  }
}
