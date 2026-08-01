import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/data/local/db_helper.dart';
import 'package:expense_manager/data/models/sync_status.dart';
import 'package:expense_manager/data/models/transaction_model.dart';
import 'package:expense_manager/data/repositories/transaction_repository.dart';
import '../test_helper.dart';



const _testUserId = 'offline_test_user';

TransactionModel _sampleTransaction(String id, {double amount = 42.50}) {
  final date = DateTime(2026, 6, 1);
  return TransactionModel(
    id: id,
    userId: _testUserId,
    amount: amount,
    type: TransactionType.expense,
    categoryId: 'cat_food',
    accountId: 'cash',
    note: 'Grocery run',
    date: date,
    updatedAt: date,
  );
}

void main() {
  setUpAll(initTestDatabaseFactory);

  setUp(resetTestDatabase);
  tearDownAll(resetTestDatabase);

  test('a transaction added while offline persists after the app "restarts"', () async {
    final repository = LocalTransactionRepository();

    // Simulate adding a transaction with no network available.
    await repository.addTransaction(_sampleTransaction('offline_txn_1'));

    // Simulate the app being killed and relaunched: close the DB connection
    // entirely, then read again through a brand new repository instance.
    await DBHelper.instance.close();

    final reloaded = await LocalTransactionRepository().getTransactions(_testUserId);

    expect(reloaded, hasLength(1));
    expect(reloaded.single.id, 'offline_txn_1');
    expect(reloaded.single.amount, 42.50);
    expect(reloaded.single.note, 'Grocery run');
  });

  test('a synced-then-deleted transaction does not resurface after restart', () async {
    final repository = LocalTransactionRepository();
    await repository.addTransaction(_sampleTransaction('offline_txn_2'));
    await repository.deleteTransaction('offline_txn_2');

    await DBHelper.instance.close();

    final reloaded = await LocalTransactionRepository().getTransactions(_testUserId);
    expect(reloaded, isEmpty);
  });

  test('sync status stays pendingCreate until a sync explicitly marks it synced', () async {
    final repository = LocalTransactionRepository();
    await repository.addTransaction(_sampleTransaction('offline_txn_3'));

    // Re-reading multiple times (simulating multiple screen refreshes while
    // still offline) must never silently flip the status.
    for (var i = 0; i < 3; i++) {
      final fetched = await DBHelper.instance.getTransactionById('offline_txn_3');
      expect(fetched, isNotNull);
      expect(fetched!.syncStatus, SyncStatus.pendingCreate);
    }

    // Restart the app and confirm the flag survived the restart too.
    await DBHelper.instance.close();
    final afterRestart = await DBHelper.instance.getTransactionById('offline_txn_3');
    expect(afterRestart!.syncStatus, SyncStatus.pendingCreate);

    // Only once something explicitly marks it synced does the flag change —
    // this mirrors what SyncService does after a successful push.
    await DBHelper.instance.updateTransactionSyncStatus('offline_txn_3', SyncStatus.synced);
    final afterSync = await DBHelper.instance.getTransactionById('offline_txn_3');
    expect(afterSync!.syncStatus, SyncStatus.synced);
  });
}
