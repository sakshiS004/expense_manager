import 'package:expense_manager/features/dashboard/widgets/sync_status_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense_manager/core/constants/app_color.dart';
import 'package:expense_manager/data/models/transaction_model.dart';
import 'package:expense_manager/features/auth/auth_service.dart';
import 'package:expense_manager/providers/budget_provider.dart';
import 'package:expense_manager/providers/settings_provider.dart';
import 'package:expense_manager/providers/transaction_provider.dart';
import '../transactions/add_transcation_screen.dart';
import 'widgets/balance_card.dart';
import 'widgets/budget_progress_card.dart';
import 'widgets/insight_card.dart';
import 'widgets/summary_card.dart';
import 'widgets/transaction_tile.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.userId});

  /// Optional override of which user's data to show. Currently unused by
  /// build() (data comes from the watched TransactionProvider), but kept so
  /// callers/tests can pass it explicitly without a constructor mismatch.
  final String? userId;

  void _openAddTransaction(BuildContext context, TransactionType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddTransactionScreen(forcedType: type),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionProvider = context.watch<TransactionProvider>();
    final budgetProvider = context.watch<BudgetProvider>();
    final authService = context.watch<AuthService>();
    context.watch<SettingsProvider>();

    if (transactionProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final greeting = authService.isGuest
        ? 'Welcome Back!'
        : 'Hi, ${authService.currentUser?.displayName?.split(' ').first ?? authService.currentUser?.email ?? 'there'}!';

    final now = DateTime.now();
    final monthlyBudget = budgetProvider.getMonthlyBudget(now.month, now.year);
    final monthlySpent = transactionProvider.monthlyExpenses(now.month, now.year);
    final usagePercentage =
    budgetProvider.getBudgetUsagePercentage(monthlySpent, monthlyBudget);
    final warning = budgetProvider.getBudgetWarning(monthlySpent, monthlyBudget);
    final insights = transactionProvider.generateSmartInsights();
    final recentTransactions = transactionProvider.transactions.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(greeting),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 16), child: SyncStatusBadge()),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final userId = transactionProvider.userId;
          if (userId != null) await transactionProvider.loadTransactions(userId);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            BalanceCard(balance: transactionProvider.totalBalance),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    key: const Key('income_card'),
                    title: 'Income',
                    amount: transactionProvider.totalIncome,
                    icon: Icons.arrow_downward,
                    color: AppColors.income,
                    onTap: () => _openAddTransaction(context, TransactionType.income),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SummaryCard(
                    key: const Key('expense_card'),
                    title: 'Expenses',
                    amount: transactionProvider.totalExpenses,
                    icon: Icons.arrow_upward,
                    color: AppColors.expense,
                    onTap: () => _openAddTransaction(context, TransactionType.expense),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            BudgetProgressCard(
              spent: monthlySpent,
              budget: monthlyBudget,
              percentage: usagePercentage,
              warning: warning,
            ),
            const SizedBox(height: 24),
            Text('Smart Insights', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: insights.length,
                itemBuilder: (_, index) => InsightCard(text: insights[index]),
              ),
            ),
            const SizedBox(height: 24),
            Text('Recent Transactions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (recentTransactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No transactions yet. Tap Income or Expenses above to add one.')),
              )
            else
              ...recentTransactions.map((t) => TransactionTile(transaction: t)),
          ],
        ),
      ),
    );
  }
}
