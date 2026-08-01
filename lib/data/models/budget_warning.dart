enum BudgetWarning { fiftyPercent, seventyFivePercent, ninetyPercent, hundredPercent, exceeded }

extension BudgetWarningX on BudgetWarning {
  String get label {
    switch (this) {
      case BudgetWarning.fiftyPercent:
        return 'You have used 50% of your budget.';
      case BudgetWarning.seventyFivePercent:
        return 'You have used 75% of your budget.';
      case BudgetWarning.ninetyPercent:
        return 'You have used 90% of your budget.';
      case BudgetWarning.hundredPercent:
        return 'You have reached your budget limit.';
      case BudgetWarning.exceeded:
        return 'You have exceeded your budget.';
    }
  }
}