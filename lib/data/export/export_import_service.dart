import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../local/db_helper.dart';

/// Handles JSON backup/restore and CSV export of local data. Works directly
/// against DBHelper's raw table rows, so it has no dependency on any
/// model's toJson/fromJson.
class ExportImportService {
  ExportImportService({DBHelper? dbHelper}) : _dbHelper = dbHelper ?? DBHelper.instance;

  final DBHelper _dbHelper;

  Future<File> exportToJsonFile(String userId) async {
    final data = await _dbHelper.exportUserData(userId);
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = File('${dir.path}/expense_export_$timestamp.json');
    return file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  /// Exports the transactions table only — the common CSV use case
  /// (open in Excel/Sheets). Returns the written file.
  Future<File> exportToCsvFile(String userId) async {
    final data = await _dbHelper.exportUserData(userId);
    final transactions = (data['transactions'] as List).cast<Map<String, dynamic>>();

    final buffer = StringBuffer()
      ..writeln('Date,Type,Category,Account,Amount,Note');
    for (final t in transactions) {
      buffer.writeln([
        t['date'],
        t['type'],
        t['categoryId'],
        t['accountId'],
        t['amount'],
        _csvEscape(t['note']?.toString() ?? ''),
      ].join(','));
    }

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = File('${dir.path}/transactions_export_$timestamp.csv');
    return file.writeAsString(buffer.toString());
  }

  /// Returns the number of rows imported.
  Future<int> importFromJsonFile(File file) async {
    final raw = await file.readAsString();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return _dbHelper.importUserData(data);
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
