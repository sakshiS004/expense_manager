import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/data/models/sync_status.dart';
import 'package:expense_manager/data/models/transaction_model.dart';
import 'package:expense_manager/data/repositories/transaction_repository.dart';
import 'package:expense_manager/providers/transaction_provider.dart';

class FakeTransactionRepository implements TransactionRepository {
  FakeTransactionRepository([List<TransactionModel> seed = const []]) : _items = List.of(seed);

  final List<TransactionModel> _items;

  @override
  Future<List<TransactionModel>> getTransactions(String userId) async => List.of(_items);

  @override
  Future<void> addTransaction(TransactionModel transaction) async => _items.add(transaction);

  @override
  Future<void> updateTransaction(TransactionModel transaction) async {}

  @override
  Future<void> deleteTransaction(String id) async {}

  @override
  Future<void> restoreTransaction(TransactionModel transaction) async {}

  @override
  Future<List<TransactionModel>> getPendingSyncTransactions() async => [];
}

TransactionModel _txn({
  required String id,
  required double amount,
  required TransactionType type,
  required DateTime date,
  String categoryId = 'cat_default',
}) {
  return TransactionModel(
    id: id,
    userId: 'test_user',
    amount: amount,
    type: type,
    categoryId: categoryId,
    accountId: 'cash',
    date: date,
    updatedAt: date,
    syncStatus: SyncStatus.synced,
  );
}

Future<TransactionProvider> _providerWith(List<TransactionModel> seed) async {
  final provider = TransactionProvider(repository: FakeTransactionRepository(seed));
  await provider.loadTransactions('test_user');
  return provider;
}

void main() {
  group('totalBalance', () {
    test('equals total income minus total expenses', () async {
      final now = DateTime.now();
      final provider = await _providerWith([
        _txn(id: '1', amount: 1000, type: TransactionType.income, date: now),
        _txn(id: '2', amount: 500, type: TransactionType.income, date: now),
        _txn(id: '3', amount: 300, type: TransactionType.expense, date: now),
        _txn(id: '4', amount: 200, type: TransactionType.expense, date: now),
      ]);

      expect(provider.totalIncome, 1500);
      expect(provider.totalExpenses, 500);
      expect(provider.totalBalance, 1000);
    });

    test('is negative when expenses exceed income', () async {
      final now = DateTime.now();
      final provider = await _providerWith([
        _txn(id: '1', amount: 100, type: TransactionType.income, date: now),
        _txn(id: '2', amount: 400, type: TransactionType.expense, date: now),
      ]);

      expect(provider.totalBalance, -300);
    });

    test('is zero with no transactions', () async {
      final provider = await _providerWith([]);
      expect(provider.totalBalance, 0);
    });
  });

  group('monthlyExpenses', () {
    test('only sums expenses within the given month and year', () async {
      final provider = await _providerWith([
        _txn(id: '1', amount: 100, type: TransactionType.expense, date: DateTime(2026, 1, 5)),
        _txn(id: '2', amount: 50, type: TransactionType.expense, date: DateTime(2026, 1, 20)),
        _txn(id: '3', amount: 999, type: TransactionType.expense, date: DateTime(2026, 2, 1)),
        _txn(id: '4', amount: 999, type: TransactionType.expense, date: DateTime(2025, 1, 5)),
      ]);

      expect(provider.monthlyExpenses(1, 2026), 150);
    });

    test('distinguishes the same month number across different years', () async {
      final provider = await _providerWith([
        _txn(id: '1', amount: 100, type: TransactionType.expense, date: DateTime(2025, 3, 10)),
        _txn(id: '2', amount: 400, type: TransactionType.expense, date: DateTime(2026, 3, 10)),
      ]);

      expect(provider.monthlyExpenses(3, 2025), 100);
      expect(provider.monthlyExpenses(3, 2026), 400);
    });

    test('excludes income transactions', () async {
      final provider = await _providerWith([
        _txn(id: '1', amount: 500, type: TransactionType.income, date: DateTime(2026, 4, 1)),
        _txn(id: '2', amount: 75, type: TransactionType.expense, date: DateTime(2026, 4, 1)),
      ]);

      expect(provider.monthlyExpenses(4, 2026), 75);
    });

    test('returns zero for a month with no matching transactions', () async {
      final provider = await _providerWith([
        _txn(id: '1', amount: 75, type: TransactionType.expense, date: DateTime(2026, 4, 1)),
      ]);

      expect(provider.monthlyExpenses(5, 2026), 0);
    });
  });

  group('generateSmartInsights', () {
    test('prompts to add transactions when there is no data', () async {
      final provider = await _providerWith([]);
      expect(provider.generateSmartInsights(), ['Add some transactions to see insights.']);
    });

    test('identifies the highest expense category for the current month', () async {
      final now = DateTime.now();
      final firstOfMonth = DateTime(now.year, now.month, 1);

      final provider = await _providerWith([
        _txn(id: '1', amount: 50, type: TransactionType.expense, date: firstOfMonth, categoryId: 'cat_travel'),
        _txn(id: '2', amount: 400, type: TransactionType.expense, date: firstOfMonth, categoryId: 'cat_food'),
        _txn(id: '3', amount: 100, type: TransactionType.expense, date: firstOfMonth, categoryId: 'cat_food'),
      ]);

      final insights = provider.generateSmartInsights();
      expect(insights.any((line) => line.contains('cat_food')), isTrue);
      expect(insights.any((line) => line.contains('cat_travel')), isFalse);
    });

    test('reports a spending increase versus the prior week', () async {
      final now = DateTime.now();

      final provider = await _providerWith([
        _txn(id: '1', amount: 200, type: TransactionType.expense, date: now.subtract(const Duration(days: 2))),
        _txn(id: '2', amount: 100, type: TransactionType.expense, date: now.subtract(const Duration(days: 10))),
      ]);

      final insights = provider.generateSmartInsights();
      final weekInsight = insights.first;
      expect(weekInsight, contains('100%'));
      expect(weekInsight, contains('more'));
    });

    test('reports a spending decrease versus the prior week', () async {
      final now = DateTime.now();

      final provider = await _providerWith([
        _txn(id: '1', amount: 50, type: TransactionType.expense, date: now.subtract(const Duration(days: 2))),
        _txn(id: '2', amount: 200, type: TransactionType.expense, date: now.subtract(const Duration(days: 10))),
      ]);

      final insights = provider.generateSmartInsights();
      final weekInsight = insights.first;
      expect(weekInsight, contains('75%'));
      expect(weekInsight, contains('less'));
    });
  });
}
