import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/budget_model.dart';
import '../models/category_model.dart';
import '../models/sync_status.dart';
import '../models/transaction_model.dart';

class DBHelper {
  DBHelper._internal();
  static final DBHelper instance = DBHelper._internal();

  static Database? _database;

  static const String tableTransactions = 'transactions';
  static const String tableCategories = 'categories';
  static const String tableAccounts = 'accounts';
  static const String tableBudgets = 'budgets'; // was 'notifications' — collided with notification data

  Future<Database> get database async {
    _database ??= await _initDB();
    return _database!;
  }

  // ---------- Database Initialization ----------

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'expense_tracker.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  /// Injects an in-memory test database (e.g., from sqflite_ffi) and initializes tables & seed data.
  Future<void> initTestDatabase(Database testDb) async {
    _database = testDb;
    await _createDB(testDb, 1);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTransactions (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        accountId TEXT NOT NULL,
        note TEXT,
        date TEXT NOT NULL,
        attachmentPath TEXT,
        isRecurring INTEGER NOT NULL DEFAULT 0,
        updatedAt TEXT NOT NULL,
        deletedAt TEXT,
        syncStatus TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableCategories (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        type TEXT NOT NULL,
        color INTEGER NOT NULL,
        updatedAt TEXT NOT NULL,
        deletedAt TEXT,
        syncStatus TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableAccounts (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0,
        updatedAt TEXT NOT NULL,
        deletedAt TEXT,
        syncStatus TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableBudgets (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        amount REAL NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        updatedAt TEXT NOT NULL,
        deletedAt TEXT,
        syncStatus TEXT NOT NULL
      )
    ''');

    await _seedDefaultCategories(db);
  }

  // ---------- Seed Data ----------

  Future<void> _seedDefaultCategories(Database db) async {
    const uuid = Uuid();
    final now = DateTime.now().toIso8601String();

    final defaults = <Map<String, dynamic>>[
      {'name': 'Food', 'icon': 'restaurant', 'type': 'expense', 'color': 0xFFEF5350},
      {'name': 'Travel', 'icon': 'flight', 'type': 'expense', 'color': 0xFF42A5F5},
      {'name': 'Shopping', 'icon': 'shopping_bag', 'type': 'expense', 'color': 0xFFAB47BC},
      {'name': 'Rent', 'icon': 'home', 'type': 'expense', 'color': 0xFF8D6E63},
      {'name': 'Salary', 'icon': 'attach_money', 'type': 'income', 'color': 0xFF66BB6A},
      {'name': 'Freelance', 'icon': 'work', 'type': 'income', 'color': 0xFF26A69A},
    ];

    final batch = db.batch();
    for (final category in defaults) {
      batch.insert(tableCategories, {
        'id': uuid.v4(),
        'userId': 'default',
        'name': category['name'],
        'icon': category['icon'],
        'type': category['type'],
        'color': category['color'],
        'updatedAt': now,
        'deletedAt': null,
        'syncStatus': SyncStatus.synced.value,
      });
    }
    await batch.commit(noResult: true);
  }

  // ---------- Transaction Methods ----------

  Future<void> insertOrUpdateTransaction(TransactionModel item) async {
    final db = await database;
    await db.insert(
      tableTransactions,
      _txnToDbMap(item),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TransactionModel>> getAllActiveTransactions(String userId) async {
    final db = await database;
    final rows = await db.query(
      tableTransactions,
      where: 'userId = ? AND deletedAt IS NULL',
      whereArgs: [userId],
      orderBy: 'date DESC',
    );
    return rows.map(_txnFromDbMap).toList();
  }

  Future<void> softDeleteTransaction(String id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      tableTransactions,
      {
        'deletedAt': now,
        'updatedAt': now,
        'syncStatus': SyncStatus.pendingDelete.value,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<TransactionModel>> getPendingTransactions() async {
    final db = await database;
    final rows = await db.query(
      tableTransactions,
      where: 'syncStatus != ?',
      whereArgs: [SyncStatus.synced.value],
    );
    return rows.map(_txnFromDbMap).toList();
  }

  Future<void> updateTransactionSyncStatus(String id, SyncStatus status) async {
    final db = await database;
    await db.update(
      tableTransactions,
      {'syncStatus': status.value},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------- Category Methods ----------

  Future<void> insertOrUpdateCategory(CategoryModel item) async {
    final db = await database;
    await db.insert(
      tableCategories,
      _categoryToDbMap(item),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CategoryModel>> getAllActiveCategories(String userId) async {
    final db = await database;
    final rows = await db.query(
      tableCategories,
      where: 'deletedAt IS NULL AND (userId = ? OR userId = ?)',
      whereArgs: [userId, 'default'],
      orderBy: 'name ASC',
    );
    return rows.map(_categoryFromDbMap).toList();
  }

  Future<void> softDeleteCategory(String id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      tableCategories,
      {
        'deletedAt': now,
        'updatedAt': now,
        'syncStatus': SyncStatus.pendingDelete.value,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------- Budget Methods ----------

  Future<void> insertOrUpdateBudget(BudgetModel item) async {
    final db = await database;
    await db.insert(
      tableBudgets,
      _budgetToDbMap(item),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<BudgetModel>> getAllActiveBudgets(String userId) async {
    final db = await database;
    final rows = await db.query(
      tableBudgets,
      where: 'userId = ? AND deletedAt IS NULL',
      whereArgs: [userId],
      orderBy: 'year DESC, month DESC',
    );
    return rows.map(_budgetFromDbMap).toList();
  }

  Future<void> softDeleteBudget(String id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      tableBudgets,
      {
        'deletedAt': now,
        'updatedAt': now,
        'syncStatus': SyncStatus.pendingDelete.value,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------- Mapping Helpers ----------

  Map<String, dynamic> _txnToDbMap(TransactionModel item) {
    return {
      'id': item.id,
      'userId': item.userId,
      'amount': item.amount,
      'type': item.type.value,
      'categoryId': item.categoryId,
      'accountId': item.accountId,
      'note': item.note,
      'date': item.date.toIso8601String(),
      'attachmentPath': item.attachmentPath,
      'isRecurring': item.isRecurring ? 1 : 0,
      'updatedAt': item.updatedAt.toIso8601String(),
      'deletedAt': item.deletedAt?.toIso8601String(),
      'syncStatus': item.syncStatus.value,
    };
  }

  TransactionModel _txnFromDbMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: TransactionTypeX.fromValue(map['type'] as String?),
      categoryId: map['categoryId'] as String,
      accountId: map['accountId'] as String,
      note: map['note'] as String?,
      date: DateTime.parse(map['date'] as String),
      attachmentPath: map['attachmentPath'] as String?,
      isRecurring: (map['isRecurring'] as int) == 1,
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      deletedAt: map['deletedAt'] != null
          ? DateTime.parse(map['deletedAt'] as String)
          : null,
      syncStatus: SyncStatusX.fromValue(map['syncStatus'] as String?),
    );
  }

  Map<String, dynamic> _categoryToDbMap(CategoryModel item) {
    return {
      'id': item.id,
      'userId': item.userId,
      'name': item.name,
      'icon': item.icon,
      'type': item.type.value,
      'color': item.color,
      'updatedAt': item.updatedAt.toIso8601String(),
      'deletedAt': item.deletedAt?.toIso8601String(),
      'syncStatus': item.syncStatus.value,
    };
  }

  CategoryModel _categoryFromDbMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String,
      type: TransactionTypeX.fromValue(map['type'] as String?),
      color: map['color'] as int,
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      deletedAt: map['deletedAt'] != null
          ? DateTime.parse(map['deletedAt'] as String)
          : null,
      syncStatus: SyncStatusX.fromValue(map['syncStatus'] as String?),
    );
  }

  Map<String, dynamic> _budgetToDbMap(BudgetModel item) {
    return {
      'id': item.id,
      'userId': item.userId,
      'categoryId': item.categoryId,
      'amount': item.amount,
      'month': item.month,
      'year': item.year,
      'updatedAt': item.updatedAt.toIso8601String(),
      'deletedAt': item.deletedAt?.toIso8601String(),
      'syncStatus': item.syncStatus.value,
    };
  }

  BudgetModel _budgetFromDbMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      categoryId: map['categoryId'] as String,
      amount: (map['amount'] as num).toDouble(),
      month: map['month'] as int,
      year: map['year'] as int,
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      deletedAt: map['deletedAt'] != null
          ? DateTime.parse(map['deletedAt'] as String)
          : null,
      syncStatus: SyncStatusX.fromValue(map['syncStatus'] as String?),
    );
  }

  // ---------- Sync Helper Methods ----------

  Future<List<CategoryModel>> getPendingCategories() async {
    final db = await database;
    final rows = await db.query(
      tableCategories,
      where: 'syncStatus != ?',
      whereArgs: [SyncStatus.synced.value],
    );
    return rows.map(_categoryFromDbMap).toList();
  }

  Future<void> updateCategorySyncStatus(String id, SyncStatus status) async {
    final db = await database;
    await db.update(
      tableCategories,
      {'syncStatus': status.value},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<BudgetModel>> getPendingBudgets() async {
    final db = await database;
    final rows = await db.query(
      tableBudgets,
      where: 'syncStatus != ?',
      whereArgs: [SyncStatus.synced.value],
    );
    return rows.map(_budgetFromDbMap).toList();
  }

  Future<void> updateBudgetSyncStatus(String id, SyncStatus status) async {
    final db = await database;
    await db.update(
      tableBudgets,
      {'syncStatus': status.value},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------- Hard Deletes (called after a successful remote delete) ----------

  Future<void> deleteTransaction(String id) async {
    final db = await database;
    await db.delete(tableTransactions, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteCategory(String id) async {
    final db = await database;
    await db.delete(tableCategories, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteBudget(String id) async {
    final db = await database;
    await db.delete(tableBudgets, where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Single Item Lookups by ID ----------

  Future<TransactionModel?> getTransactionById(String id) async {
    final db = await database;
    final rows = await db.query(
      tableTransactions,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return _txnFromDbMap(rows.first);
    }
    return null;
  }

  Future<CategoryModel?> getCategoryById(String id) async {
    final db = await database;
    final rows = await db.query(
      tableCategories,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return _categoryFromDbMap(rows.first);
    }
    return null;
  }

  Future<BudgetModel?> getBudgetById(String id) async {
    final db = await database;
    final rows = await db.query(
      tableBudgets,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return _budgetFromDbMap(rows.first);
    }
    return null;
  }

  // ---------- Sync Support ----------

  Future<int> countPendingChanges() async {
    final db = await database;
    var total = 0;
    for (final table in [tableTransactions, tableCategories, tableBudgets]) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) AS count FROM $table WHERE syncStatus != ?',
        [SyncStatus.synced.value],
      );
      total += Sqflite.firstIntValue(result) ?? 0;
    }
    return total;
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  // ---------- Export / Import (raw rows, no model coupling) ----------

  Future<Map<String, dynamic>> exportUserData(String userId) async {
    final db = await database;
    final transactions = await db.query(
      tableTransactions,
      where: 'userId = ? AND deletedAt IS NULL',
      whereArgs: [userId],
    );
    final categories = await db.query(
      tableCategories,
      where: 'deletedAt IS NULL AND (userId = ? OR userId = ?)',
      whereArgs: [userId, 'default'],
    );
    final budgets = await db.query(
      tableBudgets,
      where: 'userId = ? AND deletedAt IS NULL',
      whereArgs: [userId],
    );
    final accounts = await db.query(
      tableAccounts,
      where: 'userId = ? AND deletedAt IS NULL',
      whereArgs: [userId],
    );

    return {
      'exportedAt': DateTime.now().toIso8601String(),
      'userId': userId,
      'transactions': transactions,
      'categories': categories,
      'budgets': budgets,
      'accounts': accounts,
    };
  }

  /// Returns the number of rows imported. Existing rows with matching ids
  /// are overwritten (conflictAlgorithm.replace).
  Future<int> importUserData(Map<String, dynamic> data) async {
    final db = await database;
    var count = 0;
    final batch = db.batch();

    void addRows(String table, dynamic rows) {
      if (rows is! List) return;
      for (final row in rows) {
        if (row is Map) {
          batch.insert(table, Map<String, dynamic>.from(row), conflictAlgorithm: ConflictAlgorithm.replace);
          count++;
        }
      }
    }

    addRows(tableTransactions, data['transactions']);
    addRows(tableCategories, data['categories']);
    addRows(tableBudgets, data['budgets']);
    addRows(tableAccounts, data['accounts']);

    await batch.commit(noResult: true);
    return count;
  }
}
