import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:expense_manager/core/constants/app_color.dart';
import 'package:expense_manager/core/utils/formatter.dart';
import 'package:expense_manager/data/models/transaction_model.dart';
import 'package:expense_manager/providers/category_provider.dart';
import 'package:expense_manager/providers/settings_provider.dart';
import 'package:expense_manager/providers/transaction_provider.dart';

enum AnalyticsPeriod { week, month, threeMonths, year }

extension AnalyticsPeriodX on AnalyticsPeriod {
  String get label {
    switch (this) {
      case AnalyticsPeriod.week:
        return 'Week';
      case AnalyticsPeriod.month:
        return 'Month';
      case AnalyticsPeriod.threeMonths:
        return '3 Months';
      case AnalyticsPeriod.year:
        return 'Year';
    }
  }

  int get days {
    switch (this) {
      case AnalyticsPeriod.week:
        return 7;
      case AnalyticsPeriod.month:
        return 30;
      case AnalyticsPeriod.threeMonths:
        return 90;
      case AnalyticsPeriod.year:
        return 365;
    }
  }
}

class _CategorySlice {
  const _CategorySlice({required this.name, required this.color, required this.amount});
  final String name;
  final Color color;
  final double amount;
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  AnalyticsPeriod _period = AnalyticsPeriod.month;

  List<TransactionModel> _inPeriod(List<TransactionModel> source) {
    final cutoff = DateTime.now().subtract(Duration(days: _period.days));
    return source.where((t) => t.date.isAfter(cutoff)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final transactionProvider = context.watch<TransactionProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    context.watch<SettingsProvider>();

    final periodTransactions = _inPeriod(transactionProvider.activeTransactions);

    final totalIncome = periodTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
    final totalExpense = periodTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
    final netSavings = totalIncome - totalExpense;

    final categoryAmounts = <String, double>{};
    for (final t in periodTransactions) {
      if (t.type != TransactionType.expense) continue;
      categoryAmounts[t.categoryId] = (categoryAmounts[t.categoryId] ?? 0) + t.amount;
    }

    final categoryNames = {for (final c in categoryProvider.categories) c.id: c.name};
    final categoryColors = {for (final c in categoryProvider.categories) c.id: Color(c.color)};

    final slices = categoryAmounts.entries
        .map((e) => _CategorySlice(
      name: categoryNames[e.key] ?? 'Other',
      color: categoryColors[e.key] ?? Colors.grey,
      amount: e.value,
    ))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PeriodToggle(selected: _period, onChanged: (p) => setState(() => _period = p)),
          const SizedBox(height: 16),
          _NetSavingsCard(netSavings: netSavings, income: totalIncome, expense: totalExpense),
          const SizedBox(height: 24),
          Text('Expense by Category', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _CategoryDonutChart(slices: slices),
            ),
          ),
          const SizedBox(height: 24),
          Text('Income vs Expense', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _IncomeExpenseBarChart(income: totalIncome, expense: totalExpense),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.selected, required this.onChanged});

  final AnalyticsPeriod selected;
  final ValueChanged<AnalyticsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AnalyticsPeriod>(
          value: selected,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down),
          items: AnalyticsPeriod.values
              .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
              .toList(),
          onChanged: (period) {
            if (period != null) onChanged(period);
          },
        ),
      ),
    );
  }
}

class _NetSavingsCard extends StatelessWidget {
  const _NetSavingsCard({required this.netSavings, required this.income, required this.expense});

  final double netSavings;
  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) {
    final isPositive = netSavings >= 0;
    final color = isPositive ? AppColors.income : AppColors.expense;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color.withValues(alpha:0.1), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Net Savings', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            Formatters.currency(netSavings),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Income: ${Formatters.currency(income)}', style: Theme.of(context).textTheme.bodySmall),
              Text('Expense: ${Formatters.currency(expense)}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryDonutChart extends StatelessWidget {
  const _CategoryDonutChart({required this.slices});

  final List<_CategorySlice> slices;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No expenses in this period.')),
      );
    }

    final total = slices.fold<double>(0, (sum, s) => sum + s.amount);

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 50,
              sections: slices.map((s) {
                final percentage = total == 0 ? 0.0 : (s.amount / total) * 100;
                return PieChartSectionData(
                  value: s.amount,
                  color: s.color,
                  radius: 60,
                  title: '${percentage.toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...slices.map((s) => _LegendRow(slice: s)),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice});

  final _CategorySlice slice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: slice.color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(slice.name)),
          Text(Formatters.currency(slice.amount)),
        ],
      ),
    );
  }
}

class _IncomeExpenseBarChart extends StatelessWidget {
  const _IncomeExpenseBarChart({required this.income, required this.expense});

  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) {
    if (income == 0 && expense == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No income or expenses in this period.')),
      );
    }

    final maxValue = [income, expense, 1.0].reduce((a, b) => a > b ? a : b);
    final maxY = maxValue * 1.3;
    final labelColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    value == 0 ? 'Income' : 'Expense',
                    style: TextStyle(color: labelColor, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(
                  toY: income,
                  color: AppColors.income,
                  width: 40,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
              showingTooltipIndicators: income > 0 ? [0] : [],
            ),
            BarChartGroupData(
              x: 1,
              barRods: [
                BarChartRodData(
                  toY: expense,
                  color: AppColors.expense,
                  width: 40,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
              showingTooltipIndicators: expense > 0 ? [0] : [],
            ),
          ],
          barTouchData: BarTouchData(
            enabled: false,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.transparent,
              tooltipPadding: EdgeInsets.zero,
              tooltipMargin: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final color = group.x == 0 ? AppColors.income : AppColors.expense;
                return BarTooltipItem(
                  Formatters.currency(rod.toY),
                  TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
