import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/models/transaction_model.dart';
import '../data/repositories/transaction_repository.dart';

class TransactionProvider extends ChangeNotifier {
  TransactionProvider({required TransactionRepository repository})
      : _repository = repository;

  final TransactionRepository _repository;
  static const _uuid = Uuid();

  String? _userId;
  List<TransactionModel> _transactions = [];
  bool _isLoading = false;

  List<TransactionModel> get transactions => List.unmodifiable(_transactions);
  List<TransactionModel> get activeTransactions => transactions;
  bool get isLoading => _isLoading;
  String? get userId => _userId;

  // ---------- Loading ----------

  Future<void> loadTransactions(String userId) async {
    _userId = userId;
    _isLoading = true;
    notifyListeners();

    _transactions = await _repository.getTransactions(userId);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _reload() async {
    if (_userId == null) return;
    _transactions = await _repository.getTransactions(_userId!);
    notifyListeners();
  }

  // ---------- CRUD ----------

  Future<void> addTransaction(TransactionModel transaction) async {
    final toAdd = transaction.id.isEmpty
        ? transaction.copyWith(id: _uuid.v4())
        : transaction;
    await _repository.addTransaction(toAdd);
    await _reload();
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    await _repository.updateTransaction(transaction);
    await _reload();
  }

  Future<void> deleteTransaction(String id) async {
    await _repository.deleteTransaction(id);
    await _reload();
  }

  Future<void> restoreTransaction(TransactionModel transaction) async {
    await _repository.restoreTransaction(transaction);
    await _reload();
  }

  // ---------- Derived Totals ----------

  double get totalIncome => _sumByType(_transactions, TransactionType.income);

  double get totalExpenses =>
      _sumByType(_transactions, TransactionType.expense);

  double get totalBalance => totalIncome - totalExpenses;

  double monthlyExpenses(int month, int year) {
    return _sumByType(
      _transactions.where((t) => _inMonth(t.date, month, year)).toList(),
      TransactionType.expense,
    );
  }

  Map<String, double> categoryExpenses(int month, int year) {
    final result = <String, double>{};
    for (final t in _transactions) {
      if (t.type != TransactionType.expense) continue;
      if (!_inMonth(t.date, month, year)) continue;
      result[t.categoryId] = (result[t.categoryId] ?? 0) + t.amount;
    }
    return result;
  }

  double _sumByType(List<TransactionModel> items, TransactionType type) {
    return items
        .where((t) => t.type == type)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  bool _inMonth(DateTime date, int month, int year) {
    return date.month == month && date.year == year;
  }

  // ---------- Smart Insights ----------

  List<String> generateSmartInsights({Map<String, String>? categoryNames}) {
    if (_transactions.isEmpty) return ['Add some transactions to see insights.'];

    final insights = <String>[];
    final now = DateTime.now();

    insights.add(_weekOverWeekInsight(now));
    insights.add(_highestCategoryInsight(now, categoryNames));
    insights.add(_averageDailySpendInsight(now));

    return insights;
  }

  String _weekOverWeekInsight(DateTime now) {
    final thisWeekStart = now.subtract(const Duration(days: 7));
    final lastWeekStart = now.subtract(const Duration(days: 14));

    final thisWeekSpend = _sumByType(
      _transactions
          .where((t) => t.date.isAfter(thisWeekStart) && t.date.isBefore(now))
          .toList(),
      TransactionType.expense,
    );
    final lastWeekSpend = _sumByType(
      _transactions
          .where((t) =>
      t.date.isAfter(lastWeekStart) && t.date.isBefore(thisWeekStart))
          .toList(),
      TransactionType.expense,
    );

    if (lastWeekSpend == 0) {
      return thisWeekSpend > 0
          ? 'You spent ${thisWeekSpend.toStringAsFixed(0)} this week, with no spending recorded last week.'
          : 'No spending recorded in the last two weeks.';
    }

    final change = ((thisWeekSpend - lastWeekSpend) / lastWeekSpend) * 100;
    final direction = change >= 0 ? 'more' : 'less';
    return 'You spent ${change.abs().toStringAsFixed(0)}% $direction this week compared to last week.';
  }

  String _highestCategoryInsight(
      DateTime now,
      Map<String, String>? categoryNames,
      ) {
    final expenses = categoryExpenses(now.month, now.year);
    if (expenses.isEmpty) return 'No expenses recorded this month yet.';

    final topEntry =
    expenses.entries.reduce((a, b) => a.value > b.value ? a : b);
    final label = categoryNames?[topEntry.key] ?? topEntry.key;
    return 'Your highest spending category this month is $label at ${topEntry.value.toStringAsFixed(0)}.';
  }

  String _averageDailySpendInsight(DateTime now) {
    final monthTotal = monthlyExpenses(now.month, now.year);
    final daysElapsed = now.day;
    final average = monthTotal / daysElapsed;
    return 'You are averaging ${average.toStringAsFixed(0)} in spending per day this month.';
  }
}