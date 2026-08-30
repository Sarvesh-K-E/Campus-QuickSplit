import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense.dart';
import '../models/expense_group.dart';
import '../models/user.dart';
import '../services/database_service.dart';
import '../services/settlement_service.dart';
import '../services/notification_service.dart';
import '../models/app_action.dart';

class DataProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService.instance;

  bool _notificationsEnabled = true;
  bool get notificationsEnabled => _notificationsEnabled;

  void updateNotifications() {
    if (_localUser != null) {
      if (_notificationsEnabled) {
        final outgoing = getPendingOutgoingSettlements();
        NotificationService().scheduleDailyNotification(outgoing.length);
      } else {
        NotificationService().scheduleDailyNotification(0); // This cancels them
      }
    }
  }

  Future<void> toggleNotifications(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    updateNotifications();
    notifyListeners();
  }

  User? _localUser;
  List<User> _allUsers = [];
  List<ExpenseGroup> _groups = [];
  String? _currentGroupId;
  List<Expense> _currentGroupExpenses = [];
  List<Expense> _allExpenses = [];
  List<AppAction> _activityLogs = [];

  User? get localUser => _localUser;
  List<User> get allUsers => _allUsers;
  List<ExpenseGroup> get groups => _groups.reversed.toList();
  List<Expense> get currentGroupExpenses => _currentGroupExpenses;
  List<Expense> get allExpenses => _allExpenses;
  List<AppAction> get activityLogs => _activityLogs;

  // IST Timezone is UTC + 5:30
  DateTime get _istNow => DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

  double get currentMonthTotalIST {
    final now = _istNow;
    double total = 0;
    for (var exp in _allExpenses) {
      if (exp.category == 'Payment') continue;
      // Parse expense date, assume stored as UTC, convert to IST for comparison
      final expDate = exp.date.toUtc().add(const Duration(hours: 5, minutes: 30));
      if (expDate.year == now.year && expDate.month == now.month) {
        total += exp.amount;
      }
    }
    return total;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    
    _localUser = await _dbService.getLocalUser();
    if (_localUser != null) {
      await _dbService.restoreLocalUserToAllGroups();
    }
    _allUsers = await _dbService.getAllUsers();
    
    _groups = await _dbService.getAllGroups();
    _allExpenses = await _dbService.getAllExpenses();
    _activityLogs = await _dbService.getAllActions();
    
    await _checkRecurringSubscriptions();
    
    notifyListeners();
  }

  Future<void> _checkRecurringSubscriptions({DateTime? simulatedDate}) async {
    final now = simulatedDate ?? DateTime.now();
    bool changed = false;

    for (var i = 0; i < _allExpenses.length; i++) {
      var expense = _allExpenses[i];
      if (!expense.isRecurring) continue;

      String lastProcessed = expense.lastProcessedMonth ?? "${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}";
      
      List<String> parts = lastProcessed.split('-');
      if (parts.length != 2) continue;
      int year = int.tryParse(parts[0]) ?? now.year;
      int month = int.tryParse(parts[1]) ?? now.month;

      int nextMonth = month + 1;
      int nextYear = year;
      if (nextMonth > 12) {
        nextMonth = 1;
        nextYear++;
      }
      
      DateTime nextProcessedDate = DateTime(nextYear, nextMonth);
      DateTime currentDate = DateTime(now.year, now.month);

      if (!nextProcessedDate.isAfter(currentDate)) {
        // Update master expense
        final updatedMaster = Expense(
          id: expense.id,
          groupId: expense.groupId,
          title: expense.title,
          amount: expense.amount,
          category: expense.category,
          splitMethod: expense.splitMethod,
          date: expense.date,
          isRecurring: true,
          lastProcessedMonth: "$nextYear-${nextMonth.toString().padLeft(2, '0')}",
          payers: expense.payers,
          splitters: expense.splitters,
        );
        
        // Use DataProvider's updateExpense to ensure it deletes the old one correctly
        await updateExpense(updatedMaster);
        
        // Create non-recurring clone
        final newId = const Uuid().v4();
        final newExpense = Expense(
          id: newId,
          groupId: expense.groupId,
          title: "${expense.title} (Recurring)",
          amount: expense.amount,
          category: expense.category,
          splitMethod: expense.splitMethod,
          date: DateTime(nextYear, nextMonth, 1),
          isRecurring: false,
        );
        newExpense.payers = expense.payers.map((p) => ExpenseParticipant(
          expenseId: newId,
          userId: p.userId,
          amount: p.amount,
        )).toList();
        newExpense.splitters = expense.splitters.map((p) => ExpenseParticipant(
          expenseId: newId,
          userId: p.userId,
          amount: p.amount,
        )).toList();

        await addExpense(newExpense);
        await _logAction('Subscription Processed', 'Automatically added $nextYear-${nextMonth.toString().padLeft(2, '0')} for ${expense.title}', 'subscription');
        changed = true;
      }
    }
    
    if (changed) {
      _allExpenses = await _dbService.getAllExpenses();
      await _checkRecurringSubscriptions(simulatedDate: simulatedDate);
    }
  }

  int _simulatedMonthOffset = 0;
  Future<void> simulateNextMonthOffset() async {
    _simulatedMonthOffset += 1;
    DateTime simulated = DateTime.now();
    int newMonth = simulated.month + _simulatedMonthOffset;
    int newYear = simulated.year;
    while(newMonth > 12) {
      newMonth -= 12;
      newYear++;
    }
    await _checkRecurringSubscriptions(simulatedDate: DateTime(newYear, newMonth, simulated.day));
    notifyListeners();
  }

  Future<void> _logAction(String title, String subtitle, String type) async {
    final action = AppAction(
      id: const Uuid().v4(),
      title: title,
      subtitle: subtitle,
      actionType: type,
      timestamp: DateTime.now().toUtc(),
    );
    await _dbService.createAction(action);
    _activityLogs.insert(0, action);
  }

  Future<void> registerLocalUser(String name, String id) async {
    final newUser = User(id: id, name: name, isLocal: true);
    await _dbService.createUser(newUser);
    _localUser = newUser;
    _allUsers.add(newUser);
    notifyListeners();
  }

  Future<User> createUser(String name, String id) async {
    final newUser = User(id: id, name: name, isLocal: false);
    await _dbService.createUser(newUser);
    _allUsers.add(newUser);
    notifyListeners();
    return newUser;
  }

  Future<void> addGroup(ExpenseGroup group, List<String> memberUserIds) async {
    await _dbService.createGroup(group, memberUserIds);
    await _logAction('Created Group', group.name, 'group_created');
    // Reload groups
    _groups = await _dbService.getAllGroups();
    notifyListeners();
  }

  Future<void> updateGroupName(String groupId, String newName) async {
    await _dbService.updateGroupName(groupId, newName);
    await _logAction('Renamed Group', newName, 'group_edited');
    _groups = await _dbService.getAllGroups();
    notifyListeners();
  }

  Future<void> removeMemberFromGroup(String groupId, String userId) async {
    await _dbService.removeUserFromGroup(groupId, userId);
    _groups = await _dbService.getAllGroups();
    notifyListeners();
  }

  Future<void> addMemberToGroup(String groupId, User user) async {
    // Ensure user exists globally first, if not this is handled by caller via createUser
    await _dbService.addUserToGroup(groupId, user.id);
    _groups = await _dbService.getAllGroups();
    notifyListeners();
  }

  Future<void> loadGroupExpenses(String groupId) async {
    _currentGroupId = groupId;
    _currentGroupExpenses = await _dbService.getExpensesByGroup(groupId);
    notifyListeners();
  }

  Future<void> addExpense(Expense expense) async {
    await _dbService.createExpense(expense);
    if (_currentGroupId == expense.groupId) {
      _currentGroupExpenses.insert(0, expense); // Add to top since sorted by date DESC
    }
    
    // insert to all expenses sorted
    _allExpenses.insert(0, expense);
    _allExpenses.sort((a, b) => b.date.compareTo(a.date));
    if (expense.category == 'Payment') {
      await _logAction('Recorded Payment', '₹${expense.amount.toStringAsFixed(2)} for ${expense.title}', 'payment_recorded');
    } else {
      await _logAction('Added Expense', '₹${expense.amount.toStringAsFixed(2)} for ${expense.title}', 'expense_added');
    }
    updateNotifications();
    notifyListeners();
  }

  Future<void> updateExpense(Expense expense) async {
    await _dbService.deleteExpense(expense.id);
    await _dbService.createExpense(expense);
    
    final groupIdx = _currentGroupExpenses.indexWhere((e) => e.id == expense.id);
    if (groupIdx != -1) _currentGroupExpenses[groupIdx] = expense;
    
    final allIdx = _allExpenses.indexWhere((e) => e.id == expense.id);
    if (allIdx != -1) _allExpenses[allIdx] = expense;
    if (expense.category == 'Payment') {
      await _logAction('Updated Payment', '₹${expense.amount.toStringAsFixed(2)} for ${expense.title}', 'payment_edited');
    } else {
      await _logAction('Updated Expense', '₹${expense.amount.toStringAsFixed(2)} for ${expense.title}', 'expense_edited');
    }
    updateNotifications();
    notifyListeners();
  }

  Future<void> deleteExpense(String expenseId, {String? expenseTitle, double? expenseAmount}) async {
    await _dbService.deleteExpense(expenseId);
    _currentGroupExpenses.removeWhere((e) => e.id == expenseId);
    _allExpenses.removeWhere((e) => e.id == expenseId);
    if (expenseTitle?.startsWith('Payment:') ?? false) {
      await _logAction('Deleted Payment', '₹${(expenseAmount ?? 0).toStringAsFixed(2)} for ${expenseTitle ?? "Unknown"}', 'payment_deleted');
    } else {
      await _logAction('Deleted Expense', '₹${(expenseAmount ?? 0).toStringAsFixed(2)} for ${expenseTitle ?? "Unknown"}', 'expense_deleted');
    }
    updateNotifications();
    notifyListeners();
  }

  Future<void> undoExpenseDeletion(Expense expense) async {
    await _dbService.createExpense(expense);
    if (_currentGroupId == expense.groupId) {
      _currentGroupExpenses.insert(0, expense);
    }
    _currentGroupExpenses.sort((a, b) => b.date.compareTo(a.date));
    
    _allExpenses.insert(0, expense);
    _allExpenses.sort((a, b) => b.date.compareTo(a.date));
    
    await _logAction('Restored Expense', '₹${expense.amount.toStringAsFixed(2)} for ${expense.title}', 'expense_restored');
    
    updateNotifications();
    notifyListeners();
  }

  Future<void> deleteGroup(String groupId, {String? groupName}) async {
    final db = await _dbService.database;
    
    // Explicit cascade cleanup for existing orphans prior to the PRAGMA fix
    await db.delete('expense_payers', where: 'expense_id IN (SELECT id FROM expenses WHERE group_id = ?)', whereArgs: [groupId]);
    await db.delete('expense_splits', where: 'expense_id IN (SELECT id FROM expenses WHERE group_id = ?)', whereArgs: [groupId]);
    await db.delete('expenses', where: 'group_id = ?', whereArgs: [groupId]);
    await db.delete('group_members', where: 'group_id = ?', whereArgs: [groupId]);
    
    await db.delete('groups', where: 'id = ?', whereArgs: [groupId]);
    _groups.removeWhere((g) => g.id == groupId);
    // Also remove from allExpenses locally so UI updates instantly
    _allExpenses.removeWhere((e) => e.groupId == groupId);
    
    await _logAction('Deleted Group', groupName ?? "Unknown", 'group_deleted');
    
    notifyListeners();
  }

  Future<void> undoGroupDeletion(ExpenseGroup group, List<Expense> expenses) async {
    // Re-create the group and its members
    await _dbService.createGroup(group, group.members.map((m) => m.id).toList());
    // Re-insert all expenses
    for (var expense in expenses) {
      await _dbService.createExpense(expense);
    }
    
    _groups = await _dbService.getAllGroups();
    _allExpenses = await _dbService.getAllExpenses();
    
    await _logAction('Restored Group', group.name, 'group_restored');
    
    notifyListeners();
  }

  Future<void> updateLocalUserProfile(String newName, String? newUpiId) async {
    if (_localUser == null || newName.trim().isEmpty) return;
    
    final oldName = _localUser!.name.replaceAll(' (You)', '');
    final cleanNewName = newName.trim();
    
    final updatedUser = User(
      id: _localUser!.id,
      name: cleanNewName,
      isLocal: true,
      upiId: newUpiId?.trim().isEmpty == true ? null : newUpiId?.trim(),
    );
    
    await _dbService.updateUser(updatedUser);    
    _localUser = updatedUser;
    
    // Refresh ALL memory state to pull the updated user profile for all groups, expenses, and logs
    _allUsers = await _dbService.getAllUsers();
    _groups = await _dbService.getAllGroups();
    _allExpenses = await _dbService.getAllExpenses();
    _activityLogs = await _dbService.getAllActions();
    
    notifyListeners();
  }

  List<Map<String, dynamic>> getPendingIncomingSettlements() {
    if (_localUser == null) return [];
    
    final List<Map<String, dynamic>> pending = [];
    
    for (var group in _groups) {
      final groupExpenses = _allExpenses.where((e) => e.groupId == group.id).toList();
      final balances = SettlementService.calculateBalances(group, groupExpenses);
      final unoptimized = SettlementService.getUnoptimizedDebts(group, groupExpenses);
      final transactions = SettlementService.simplifyDebts(balances);
      
      for (var tx in transactions) {
        if (tx.to == _localUser!.id) {
          final payer = group.members.firstWhere((m) => m.id == tx.from, orElse: () => User(id: '', name: 'Unknown'));
          pending.add({
            'groupName': group.name,
            'groupId': group.id,
            'payerName': payer.name,
            'payerId': payer.id,
            'amount': tx.amount,
          });
        }
      }
    }
    return pending;
  }

  List<Map<String, dynamic>> getPendingOutgoingSettlements() {
    if (_localUser == null) return [];
    
    final List<Map<String, dynamic>> pending = [];
    
    for (var group in _groups) {
      final groupExpenses = _allExpenses.where((e) => e.groupId == group.id).toList();
      final balances = SettlementService.calculateBalances(group, groupExpenses);
      final unoptimized = SettlementService.getUnoptimizedDebts(group, groupExpenses);
      final transactions = SettlementService.simplifyDebts(balances);
      
      for (var tx in transactions) {
        if (tx.from == _localUser!.id) {
          final receiver = group.members.firstWhere((m) => m.id == tx.to, orElse: () => User(id: '', name: 'Unknown'));
          pending.add({
            'groupName': group.name,
            'groupId': group.id,
            'receiverName': receiver.name,
            'receiverId': receiver.id,
            'amount': tx.amount,
          });
        }
      }
    }
    return pending;
  }
  Future<String> exportGroupAsJsonString(String groupId) async {
    final group = _groups.firstWhere((g) => g.id == groupId);
    final expenses = _allExpenses.where((e) => e.groupId == groupId).toList();
    
    final data = {
      'group': group.toMap(),
      'members': group.members.map((m) {
        final map = m.toMap();
        map['is_local'] = 0;
        return map;
      }).toList(),
      'expenses': expenses.map((e) {
        final map = e.toMap();
        map['payers'] = e.payers.map((p) => p.toMap()).toList();
        map['splitters'] = e.splitters.map((s) => s.toMap()).toList();
        return map;
      }).toList(),
    };
    
    return jsonEncode(data);
  }

  Future<File> exportGroupAsJson(String groupId) async {
    final group = _groups.firstWhere((g) => g.id == groupId);
    final jsonStr = await exportGroupAsJsonString(groupId);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/CampusQuickSplit_${group.name.replaceAll(' ', '_')}.cqs');
    await file.writeAsString(jsonStr);
    return file;
  }

  Future<void> importGroup(String jsonStr, String mappedUserId) async {
    if (_localUser == null) return;
    
    // Get the old name of the mapped user from the original JSON
    final originalData = jsonDecode(jsonStr);
    final originalMembers = originalData['members'] as List<dynamic>;
    String? mappedUserName;
    for (var m in originalMembers) {
      if (m['id'] == mappedUserId) {
        mappedUserName = m['name'];
        break;
      }
    }

    // Deep replace the mapped user's UUID with the current local user's UUID
    // This safely assigns all debts/credits in the imported JSON to the current device user
    String updatedJson = jsonStr.replaceAll(mappedUserId, _localUser!.id);
    
    final updatedData = jsonDecode(updatedJson);

    final uGroupMap = updatedData['group'] as Map<String, dynamic>;
    final uMembersList = updatedData['members'] as List<dynamic>;
    final uExpensesList = updatedData['expenses'] as List<dynamic>;

    final group = ExpenseGroup.fromMap(uGroupMap);
    
    List<String> userIds = [];
    for (var m in uMembersList) {
      final user = User.fromMap(m as Map<String, dynamic>);
      userIds.add(user.id);
      
      if (user.id != _localUser!.id) {
        String cleanName = user.name.replaceAll(' (You)', '');
        final safeUser = User(id: user.id, name: cleanName, isLocal: false, upiId: user.upiId);
        await _dbService.createUser(safeUser);
      }
    }
    
    await _dbService.createGroup(group, userIds);
    
    for (var e in uExpensesList) {
      final expenseMap = e as Map<String, dynamic>;
      final expense = Expense.fromMap(expenseMap);
      
      final payersList = expenseMap['payers'] as List<dynamic>;
      expense.payers = payersList.map((p) => ExpenseParticipant.fromMap(p as Map<String, dynamic>)).toList();
      
      final splittersList = expenseMap['splitters'] as List<dynamic>;
      expense.splitters = splittersList.map((s) => ExpenseParticipant.fromMap(s as Map<String, dynamic>)).toList();
      
      await _dbService.createExpense(expense);
    }
    
    await _logAction('Group Imported', 'Successfully imported ${group.name}', 'group_import');
    
    // Refresh all data
    _groups = await _dbService.getAllGroups();
    _allExpenses = await _dbService.getAllExpenses();
    _activityLogs = await _dbService.getAllActions();
    notifyListeners();
  }
}
