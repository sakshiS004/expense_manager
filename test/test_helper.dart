import 'package:path/path.dart';
//import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_manager/data/local/db_helper.dart';

/// Points sqflite at the FFI (desktop/test) engine instead of the platform
/// channel implementation, which isn't available under `flutter test`.
/// This runs real SQLite, not a mock — it's the standard way to test
/// sqflite-backed code without a device/emulator.
void initTestDatabaseFactory() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// Closes and wipes the DBHelper singleton's backing file so each test
/// starts from a clean, freshly-seeded database.
Future<void> resetTestDatabase() async {
  await DBHelper.instance.close();
  final path = join(await getDatabasesPath(), 'expense_tracker.db');
  await databaseFactory.deleteDatabase(path);
}
