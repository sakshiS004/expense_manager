import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:expense_manager/core/constants/app_color.dart';
import 'package:expense_manager/core/utils/formatter.dart';
import 'package:expense_manager/data/models/category_model.dart';
import 'package:expense_manager/data/models/transaction_model.dart';
import 'package:expense_manager/providers/category_provider.dart';
import 'package:expense_manager/providers/settings_provider.dart';
import 'package:expense_manager/providers/transaction_provider.dart';
import 'package:expense_manager/features/dashboard/widgets/transaction_tile.dart';
import '../transactions/add_transcation_screen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final _searchController = TextEditingController();
  final Set<String> _dismissedIds = {};

  String _query = '';
  TransactionType? _typeFilter;
  String? _categoryFilter;
  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _typeFilter != null || _categoryFilter != null || _dateRange != null || _query.isNotEmpty;

  void _clearFilters() {
    setState(() {
      _typeFilter = null;
      _categoryFilter = null;
      _dateRange = null;
      _query = '';
      _searchController.clear();
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _dateRange,
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  List<TransactionModel> _applyFilters(
      List<TransactionModel> source,
      Map<String, String> categoryNames,
      ) {
    final query = _query.trim().toLowerCase();

    return source.where((t) {
      if (_dismissedIds.contains(t.id)) return false;
      if (_typeFilter != null && t.type != _typeFilter) return false;
      if (_categoryFilter != null && t.categoryId != _categoryFilter) return false;

      if (_dateRange != null) {
        final day = DateTime(t.date.year, t.date.month, t.date.day);
        final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
        final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day);
        if (day.isBefore(start) || day.isAfter(end)) return false;
      }

      if (query.isNotEmpty) {
        final note = (t.note ?? '').toLowerCase();
        final category = (categoryNames[t.categoryId] ?? '').toLowerCase();
        final amount = Formatters.currency(t.amount).toLowerCase();
        if (!note.contains(query) && !category.contains(query) && !amount.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Map<DateTime, List<TransactionModel>> _groupByDate(List<TransactionModel> items) {
    final groups = <DateTime, List<TransactionModel>>{};
    for (final t in items) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      groups.putIfAbsent(day, () => []).add(t);
    }
    return groups;
  }

  void _openEdit(TransactionModel transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddTransactionScreen(initialTransaction: transaction),
    );
  }

  void _handleDelete(TransactionModel transaction) {
    setState(() => _dismissedIds.add(transaction.id));

    final provider = context.read<TransactionProvider>();
    provider.deleteTransaction(transaction.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Transaction deleted'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            setState(() => _dismissedIds.remove(transaction.id));
            provider.restoreTransaction(transaction);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionProvider = context.watch<TransactionProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    context.watch<SettingsProvider>();
    final categoryNames = {for (final c in categoryProvider.categories) c.id: c.name};

    final categoryOptions = _typeFilter == null
        ? categoryProvider.categories
        : categoryProvider.categoriesByType(_typeFilter!);

    if (_categoryFilter != null && !categoryOptions.any((c) => c.id == _categoryFilter)) {
      _categoryFilter = null;
    }

    final filtered = _applyFilters(transactionProvider.transactions, categoryNames);
    final grouped = _groupByDate(filtered);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          if (_hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_outlined),
              onPressed: _clearFilters,
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by note, category, or amount',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),

          // Single Line Filter Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                // 1. All Transactions / Type Filter
                PopupMenuButton<TransactionType?>(
                  onSelected: (type) => setState(() => _typeFilter = type),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: null, child: Text('All Transactions')),
                    const PopupMenuItem(value: TransactionType.income, child: Text('Income')),
                    const PopupMenuItem(value: TransactionType.expense, child: Text('Expense')),
                  ],
                  child: Chip(
                    label: Text(
                      _typeFilter == null
                          ? 'All Transactions'
                          : (_typeFilter == TransactionType.income ? 'Income' : 'Expense'),
                    ),
                    avatar: const Icon(Icons.swap_vert_outlined, size: 18),
                  ),
                ),
                const SizedBox(width: 8),

                // 2. Category Filter
                _CategoryFilterButton(
                  categories: categoryOptions,
                  selectedId: _categoryFilter,
                  onSelected: (id) => setState(() => _categoryFilter = id),
                ),
                const SizedBox(width: 8),

                // 3. Date Range Filter
                InputChip(
                  label: Text(
                    _dateRange == null
                        ? 'Date Range'
                        : '${Formatters.date(_dateRange!.start)} – ${Formatters.date(_dateRange!.end)}',
                  ),
                  avatar: const Icon(Icons.date_range_outlined, size: 18),
                  onPressed: _pickDateRange,
                  onDeleted: _dateRange == null
                      ? null
                      : () => setState(() => _dateRange = null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Transactions List
          Expanded(
            child: filtered.isEmpty
                ? Center(
              child: Text(
                _hasActiveFilters
                    ? 'No transactions match your filters.'
                    : 'No transactions yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
                : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: grouped.entries.expand((entry) {
                return [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      Formatters.relativeDate(entry.key),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textSecondaryLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...entry.value.map(
                        (t) => Dismissible(
                      key: ValueKey(t.id),
                      direction: DismissDirection.horizontal,
                      background: _swipeBackground(
                        alignment: Alignment.centerLeft,
                        color: AppColors.primary,
                        icon: Icons.edit,
                      ),
                      secondaryBackground: _swipeBackground(
                        alignment: Alignment.centerRight,
                        color: AppColors.expense,
                        icon: Icons.delete,
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          _openEdit(t);
                          return false;
                        }
                        return true;
                      },
                      onDismissed: (_) => _handleDelete(t),
                      child: TransactionTile(transaction: t),
                    ),
                  ),
                ];
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _swipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _CategoryFilterButton extends StatelessWidget {
  const _CategoryFilterButton({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<CategoryModel> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedName = selectedId == null
        ? 'Category'
        : categories.firstWhere((c) => c.id == selectedId, orElse: () => categories.first).name;

    return PopupMenuButton<String?>(
      onSelected: onSelected,
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('All Categories')),
        ...categories.map((c) => PopupMenuItem(value: c.id, child: Text(c.name))),
      ],
      child: Chip(
        label: Text(selectedName),
        avatar: const Icon(Icons.category_outlined, size: 18),
      ),
    );
  }
}