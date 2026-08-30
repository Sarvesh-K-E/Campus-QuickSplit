import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/expense_group.dart';
import '../models/expense.dart';
import '../models/split_method.dart';
import '../models/app_action.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('campus_quicksplit.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path, 
      version: 4, 
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onOpen: (db) async {
        // One-time sweep to eradicate any orphaned expenses from before the PRAGMA fix
        await db.execute('DELETE FROM expenses WHERE group_id NOT IN (SELECT id FROM groups)');
      },
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
CREATE TABLE app_actions (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  subtitle TEXT NOT NULL,
  action_type TEXT NOT NULL,
  timestamp TEXT NOT NULL
)
''');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE users ADD COLUMN upi_id TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE expenses ADD COLUMN is_recurring INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE expenses ADD COLUMN last_processed_month TEXT');
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  is_local INTEGER NOT NULL,
  upi_id TEXT
)
''');

    await db.execute('''
CREATE TABLE groups (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL
)
''');

    await db.execute('''
CREATE TABLE group_members (
  group_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  PRIMARY KEY (group_id, user_id),
  FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE expenses (
  id TEXT PRIMARY KEY,
  group_id TEXT NOT NULL,
  title TEXT NOT NULL,
  amount REAL NOT NULL,
  category TEXT NOT NULL,
  split_method INTEGER NOT NULL,
  date TEXT NOT NULL,
  is_recurring INTEGER DEFAULT 0,
  last_processed_month TEXT,
  FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE expense_payers (
  expense_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  amount REAL NOT NULL,
  PRIMARY KEY (expense_id, user_id),
  FOREIGN KEY (expense_id) REFERENCES expenses (id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE expense_splits (
  expense_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  amount REAL NOT NULL,
  PRIMARY KEY (expense_id, user_id),
  FOREIGN KEY (expense_id) REFERENCES expenses (id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE app_actions (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  subtitle TEXT NOT NULL,
  action_type TEXT NOT NULL,
  timestamp TEXT NOT NULL
)
''');
  }

  // --- Users ---
  Future<User> createUser(User user) async {
    final db = await instance.database;
    await db.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    return user;
  }



  Future<void> updateExpense(Expense expense) async {
    final db = await database;
    await db.update('expenses', expense.toMap(), where: 'id = ?', whereArgs: [expense.id]);
    
    // Also update participants if needed, but for our case we are just updating the expense row
  }

  Future<void> updateUser(User user) async {
    final db = await instance.database;
    await db.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  Future<List<User>> getAllUsers() async {
    final db = await instance.database;
    final result = await db.query('users');
    return result.map((json) => User.fromMap(json)).toList();
  }

  Future<User?> getLocalUser() async {
    final db = await instance.database;
    final result = await db.query('users', where: 'is_local = ?', whereArgs: [1]);
    if (result.isNotEmpty) {
      return User.fromMap(result.first);
    }
    return null;
  }

  Future<void> restoreLocalUserToAllGroups() async {
    final db = await instance.database;
    final localUser = await getLocalUser();
    if (localUser != null) {
      await db.execute('''
        INSERT OR IGNORE INTO group_members (group_id, user_id)
        SELECT id, ? FROM groups
      ''', [localUser.id]);
    }
  }



  // --- Groups ---
  Future<ExpenseGroup> createGroup(ExpenseGroup group, List<String> memberUserIds) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.insert('groups', group.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      for (var userId in memberUserIds) {
        await txn.insert('group_members', {'group_id': group.id, 'user_id': userId}, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
    return group;
  }

  Future<void> updateGroupName(String groupId, String newName) async {
    final db = await instance.database;
    await db.update('groups', {'name': newName}, where: 'id = ?', whereArgs: [groupId]);
  }

  Future<void> removeUserFromGroup(String groupId, String userId) async {
    final db = await instance.database;
    await db.delete('group_members', where: 'group_id = ? AND user_id = ?', whereArgs: [groupId, userId]);
  }

  Future<void> addUserToGroup(String groupId, String userId) async {
    final db = await instance.database;
    await db.insert('group_members', {'group_id': groupId, 'user_id': userId}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<ExpenseGroup>> getAllGroups() async {
    final db = await instance.database;
    final result = await db.query('groups');
    List<ExpenseGroup> groups = result.map((json) => ExpenseGroup.fromMap(json)).toList();
    
    // Load and sort members for each group
    for (var group in groups) {
      group.members = await getGroupMembers(group.id);
      group.members.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return groups;
  }

  Future<List<User>> getGroupMembers(String groupId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT users.* FROM users 
      INNER JOIN group_members ON users.id = group_members.user_id 
      WHERE group_members.group_id = ?
      ORDER BY users.name ASC
    ''', [groupId]);
    return result.map((json) => User.fromMap(json)).toList();
  }

  // --- Expenses ---
  Future<Expense> createExpense(Expense expense) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.insert('expenses', expense.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      
      for (var payer in expense.payers) {
        await txn.insert('expense_payers', payer.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      
      for (var split in expense.splitters) {
        await txn.insert('expense_splits', split.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    return expense;
  }

  Future<List<Expense>> getExpensesByGroup(String groupId) async {
    final db = await instance.database;
    final result = await db.query('expenses', where: 'group_id = ?', whereArgs: [groupId], orderBy: 'date DESC');
    
    List<Expense> expenses = result.map((json) => Expense.fromMap(json)).toList();
    
    for (var exp in expenses) {
      exp.payers = await _getExpensePayers(exp.id);
      exp.splitters = await _getExpenseSplits(exp.id);
    }
    
    return expenses;
  }

  Future<List<ExpenseParticipant>> _getExpensePayers(String expenseId) async {
    final db = await instance.database;
    final result = await db.query('expense_payers', where: 'expense_id = ?', whereArgs: [expenseId]);
    return result.map((json) => ExpenseParticipant.fromMap(json)).toList();
  }

  Future<List<ExpenseParticipant>> _getExpenseSplits(String expenseId) async {
    final db = await instance.database;
    final result = await db.query('expense_splits', where: 'expense_id = ?', whereArgs: [expenseId]);
    return result.map((json) => ExpenseParticipant.fromMap(json)).toList();
  }

  Future<List<Expense>> getAllExpenses() async {
    final db = await instance.database;
    final result = await db.query('expenses', orderBy: 'date DESC');
    
    List<Expense> expenses = result.map((json) => Expense.fromMap(json)).toList();
    
    for (var exp in expenses) {
      exp.payers = await _getExpensePayers(exp.id);
      exp.splitters = await _getExpenseSplits(exp.id);
    }
    
    return expenses;
  }

  Future<void> deleteExpense(String expenseId) async {
    final db = await instance.database;
    // Explicitly delete children to clean up any past orphans, then expense
    await db.delete('expense_payers', where: 'expense_id = ?', whereArgs: [expenseId]);
    await db.delete('expense_splits', where: 'expense_id = ?', whereArgs: [expenseId]);
    await db.delete('expenses', where: 'id = ?', whereArgs: [expenseId]);
  }

  // --- App Actions ---
  Future<AppAction> createAction(AppAction action) async {
    final db = await instance.database;
    await db.insert('app_actions', action.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return action;
  }

  Future<List<AppAction>> getAllActions() async {
    final db = await instance.database;
    final result = await db.query('app_actions', orderBy: 'timestamp DESC');
    return result.map((json) => AppAction.fromMap(json)).toList();
  }
}
