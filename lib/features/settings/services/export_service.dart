import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:expense_manager/data/models/transaction_model.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../../data/local/db_helper.dart';
import '../../../data/models/account_model.dart';
import '../../../data/models/budget_model.dart';
import '../../../data/models/category_model.dart';
import '../../../providers/transaction_provider.dart';

class ExportService {
  ExportService({
    DBHelper? dbHelper,
  }) : _dbHelper = dbHelper ?? DBHelper.instance;

  final DBHelper _dbHelper;

  // 1. JSON Data Export

  Future<void> exportToJson(String userId) async {
    try {
      final transactions = await _dbHelper.getAllActiveTransactions(userId);
      final categories = await _dbHelper.getAllActiveCategories(userId);
      final budgets = await _dbHelper.getAllActiveBudgets(userId);
      final accounts = await _getAllAccounts(userId);

      final payload = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'transactions': transactions.map((t) => t.toMap()).toList(),
        'categories': categories.map((c) => c.toMap()).toList(),
        'accounts': accounts.map((a) => a.toMap()).toList(),
        'notifications': budgets.map((b) => b.toMap()).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(payload);
      final filename = 'expense_backup_${DateTime.now().millisecondsSinceEpoch}.json';

      await _shareFile(jsonString, filename, 'application/json');
    } catch (e) {
      throw Exception('Failed to export JSON backup: $e');
    }
  }

  // 2. JSON Data Import

  Future<void> importFromJson({
    required String jsonContent,
    required String userId,
    required TransactionProvider transactionProvider,
  }) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonContent);

      // Validate Schema
      if (!data.containsKey('version') || data['version'] != 1) {
        throw const FormatException('Unsupported or missing backup version.');
      }

      final transactionsRaw = data['transactions'] as List<dynamic>? ?? [];
      final categoriesRaw = data['categories'] as List<dynamic>? ?? [];
      final accountsRaw = data['accounts'] as List<dynamic>? ?? [];
      final budgetsRaw = data['notifications'] as List<dynamic>? ?? [];

      // Import Categories
      for (final raw in categoriesRaw) {
        final category = CategoryModel.fromMap(Map<String, dynamic>.from(raw));
        await _dbHelper.insertOrUpdateCategory(category);
      }

      // Import Accounts
      for (final raw in accountsRaw) {
        final account = AccountModel.fromMap(Map<String, dynamic>.from(raw));
        await _insertOrUpdateAccount(account);
      }

      // Import Budgets
      for (final raw in budgetsRaw) {
        final budget = BudgetModel.fromMap(Map<String, dynamic>.from(raw));
        await _dbHelper.insertOrUpdateBudget(budget);
      }

      // Import Transactions
      for (final raw in transactionsRaw) {
        final txn = TransactionModel.fromMap(Map<String, dynamic>.from(raw));
        await _dbHelper.insertOrUpdateTransaction(txn);
      }

      // Refresh Provider UI State
      await transactionProvider.loadTransactions(userId);
    } catch (e) {
      throw Exception('Failed to import backup: $e');
    }
  }

  // ==========================================
  // 3. CSV Transaction Export
  // ==========================================

  Future<void> exportToCsv({
    required String userId,
    DateTimeRange? dateRange,
    String? categoryId,
  }) async {
    try {
      // 1. Fetch transactions & lookups for category/account names
      var transactions = await _dbHelper.getAllActiveTransactions(userId);
      final categories = await _dbHelper.getAllActiveCategories(userId);
      final accounts = await _getAllAccounts(userId);

      final categoryMap = {for (final c in categories) c.id: c.name};
      final accountMap = {for (final a in accounts) a.id: a.name};

      // 2. Apply Filters
      if (dateRange != null) {
        transactions = transactions.where((t) {
          return t.date.isAfter(dateRange.start.subtract(const Duration(seconds: 1))) &&
              t.date.isBefore(dateRange.end.add(const Duration(days: 1)));
        }).toList();
      }

      if (categoryId != null && categoryId.isNotEmpty) {
        transactions = transactions.where((t) => t.categoryId == categoryId).toList();
      }

      // 3. Build CSV Grid
      final List<List<dynamic>> csvRows = [
        ['Date', 'Type', 'Category', 'Account', 'Amount', 'Note']
      ];

      for (final txn in transactions) {
        final catName = categoryMap[txn.categoryId] ?? 'Uncategorized';
        final accName = accountMap[txn.accountId] ?? 'Default Account';

        csvRows.add([
          txn.date.toIso8601String().split('T').first,
          txn.type.value,
          catName,
          accName,
          txn.amount,
          txn.note ?? '',
        ]);
      }

      // 4. Convert & Share
      final csvData = const ListToCsvConverter().convert(csvRows);
      final filename = 'transactions_export_${DateTime.now().millisecondsSinceEpoch}.csv';

      await _shareFile(csvData, filename, 'text/csv');
    } catch (e) {
      throw Exception('Failed to export CSV: $e');
    }
  }

  // ==========================================
  // Private Helper Methods
  // ==========================================

  Future<void> _shareFile(String content, String filename, String mimeType) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsString(content);

    final xFile = XFile(file.path, mimeType: mimeType);
    await Share.shareXFiles([xFile], text: 'Exported Expense Data');
  }

  Future<List<AccountModel>> _getAllAccounts(String userId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DBHelper.tableAccounts,
      where: 'userId = ? AND deletedAt IS NULL',
      whereArgs: [userId],
    );
    return rows.map((e) => AccountModel.fromMap(e)).toList();
  }

  Future<void> _insertOrUpdateAccount(AccountModel item) async {
    final db = await _dbHelper.database;
    await db.insert(
      DBHelper.tableAccounts,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}