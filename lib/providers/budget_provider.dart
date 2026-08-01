import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/models/budget_model.dart';
import '../data/models/budget_warning.dart';
import '../data/repositories/budget_repository.dart';

class BudgetProvider extends ChangeNotifier {
  BudgetProvider({required BudgetRepository repository})
      : _repository = repository;

  final BudgetRepository _repository;
  static const _uuid = Uuid();

  String? _userId;
  List<BudgetModel> _budgets = [];
  bool _isLoading = false;

  List<BudgetModel> get budgets => List.unmodifiable(_budgets);
  bool get isLoading => _isLoading;

  // ---------- Loading ----------

  Future<void> loadBudgets(String userId) async {
    _userId = userId;
    _isLoading = true;
    notifyListeners();

    _budgets = await _repository.getBudgets(userId);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _reload() async {
    if (_userId == null) return;
    _budgets = await _repository.getBudgets(_userId!);
    notifyListeners();
  }

  // ---------- CRUD ----------

  Future<void> addBudget(BudgetModel budget) async {
    final toAdd =
    budget.id.isEmpty ? budget.copyWith(id: _uuid.v4()) : budget;
    await _repository.addBudget(toAdd);
    await _reload();
  }

  Future<void> updateBudget(BudgetModel budget) async {
    await _repository.updateBudget(budget);
    await _reload();
  }

  Future<void> deleteBudget(String id) async {
    await _repository.deleteBudget(id);
    await _reload();
  }

  // ---------- Budget Queries ----------

  double getMonthlyBudget(int month, int year) {
    return _budgets
        .where((b) => b.month == month && b.year == year)
        .fold(0.0, (sum, b) => sum + b.amount);
  }

  double? getCategoryBudget(String categoryId, int month, int year) {
    final match = _budgets.where(
          (b) => b.categoryId == categoryId && b.month == month && b.year == year,
    );
    return match.isEmpty ? null : match.first.amount;
  }

  // ---------- Usage & Warnings ----------

  double getBudgetUsagePercentage(double totalExpenses, double budgetAmount) {
    if (budgetAmount <= 0) return totalExpenses > 0 ? 100.0 : 0.0;
    return (totalExpenses / budgetAmount) * 100;
  }

  BudgetWarning? getBudgetWarning(double spent, double totalBudget) {
    final percentage = getBudgetUsagePercentage(spent, totalBudget);

    if (percentage >= 100) {
      return percentage > 100 ? BudgetWarning.exceeded : BudgetWarning.hundredPercent;
    }
    if (percentage >= 90) return BudgetWarning.ninetyPercent;
    if (percentage >= 75) return BudgetWarning.seventyFivePercent;
    if (percentage >= 50) return BudgetWarning.fiftyPercent;
    return null;
  }
}