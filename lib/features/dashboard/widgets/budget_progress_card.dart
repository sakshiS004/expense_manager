import 'package:flutter/material.dart';
import 'package:expense_manager/core/constants/app_color.dart';
import 'package:expense_manager/core/utils/formatter.dart';
import 'package:expense_manager/data/models/budget_warning.dart';

class BudgetProgressCard extends StatelessWidget {
  const BudgetProgressCard({
    super.key,
    required this.spent,
    required this.budget,
    required this.percentage,
    required this.warning,
  });

  final double spent;
  final double budget;
  final double percentage;
  final BudgetWarning? warning;

  Color get _indicatorColor {
    switch (warning) {
      case null:
        return AppColors.budgetSafe;
      case BudgetWarning.fiftyPercent:
        return AppColors.budgetCaution;
      case BudgetWarning.seventyFivePercent:
        return AppColors.budgetWarning;
      case BudgetWarning.ninetyPercent:
      case BudgetWarning.hundredPercent:
      case BudgetWarning.exceeded:
        return AppColors.budgetDanger;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (budget <= 0) {
      return const SizedBox.shrink();
    }

    final remaining = budget - spent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Monthly Budget', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  Formatters.percentage(percentage),
                  style: TextStyle(color: _indicatorColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (percentage / 100).clamp(0, 1),
                minHeight: 8,
                backgroundColor: _indicatorColor.withValues(alpha:0.15),
                valueColor: AlwaysStoppedAnimation(_indicatorColor),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              remaining >= 0
                  ? '${Formatters.currency(remaining)} remaining of ${Formatters.currency(budget)}'
                  : '${Formatters.currency(remaining.abs())} over your ${Formatters.currency(budget)} budget',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (warning != null) ...[
              const SizedBox(height: 8),
              Text(
                warning!.label,
                style: TextStyle(color: _indicatorColor, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
