import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/data/models/budget_model.dart';
import 'package:expense_manager/data/models/budget_warning.dart';
import 'package:expense_manager/data/repositories/budget_repository.dart';
import 'package:expense_manager/providers/budget_provider.dart';

class FakeBudgetRepository implements BudgetRepository {
  @override
  Future<List<BudgetModel>> getBudgets(String userId) async => [];

  @override
  Future<void> addBudget(BudgetModel budget) async {}

  @override
  Future<void> updateBudget(BudgetModel budget) async {}

  @override
  Future<void> deleteBudget(String id) async {}
}

void main() {
  late BudgetProvider provider;

  setUp(() {
    provider = BudgetProvider(repository: FakeBudgetRepository());
  });

  group('getBudgetUsagePercentage', () {
    test('computes a plain percentage of budget used', () {
      expect(provider.getBudgetUsagePercentage(250, 1000), 25);
      expect(provider.getBudgetUsagePercentage(1000, 1000), 100);
    });

    test('returns 100 when there is no budget but spending exists', () {
      expect(provider.getBudgetUsagePercentage(50, 0), 100);
    });

    test('returns 0 when there is no budget and no spending', () {
      expect(provider.getBudgetUsagePercentage(0, 0), 0);
    });
  });

  group('getBudgetWarning', () {
    const budget = 1000.0;

    test('returns null below the 50% threshold', () {
      expect(provider.getBudgetWarning(200, budget), isNull);
      expect(provider.getBudgetWarning(499, budget), isNull);
    });

    test('returns fiftyPercent at exactly 50%', () {
      expect(provider.getBudgetWarning(500, budget), BudgetWarning.fiftyPercent);
    });

    test('returns fiftyPercent between 50% and 75%', () {
      expect(provider.getBudgetWarning(600, budget), BudgetWarning.fiftyPercent);
    });

    test('returns seventyFivePercent at exactly 75%', () {
      expect(provider.getBudgetWarning(750, budget), BudgetWarning.seventyFivePercent);
    });

    test('returns ninetyPercent at exactly 90%', () {
      expect(provider.getBudgetWarning(900, budget), BudgetWarning.ninetyPercent);
    });

    test('returns ninetyPercent between 90% and 100%', () {
      expect(provider.getBudgetWarning(950, budget), BudgetWarning.ninetyPercent);
    });

    test('returns hundredPercent at exactly 100%', () {
      expect(provider.getBudgetWarning(1000, budget), BudgetWarning.hundredPercent);
    });

    test('returns exceeded when spending is over budget', () {
      expect(provider.getBudgetWarning(1001, budget), BudgetWarning.exceeded);
      expect(provider.getBudgetWarning(1500, budget), BudgetWarning.exceeded);
    });

    test('treats an unset budget with spending as exceeded-equivalent (100%)', () {
      expect(provider.getBudgetWarning(50, 0), BudgetWarning.hundredPercent);
    });

    test('returns null for an unset budget with no spending', () {
      expect(provider.getBudgetWarning(0, 0), isNull);
    });
  });
}
