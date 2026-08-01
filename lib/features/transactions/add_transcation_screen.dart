import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:expense_manager/core/constants/app_color.dart';
import 'package:expense_manager/core/utils/category_icons.dart';
import 'package:expense_manager/core/utils/currency_input_formatter.dart';
import 'package:expense_manager/core/utils/formatter.dart';
import 'package:expense_manager/data/models/account_model.dart';
import 'package:expense_manager/data/models/category_model.dart';
import 'package:expense_manager/data/models/sync_status.dart';
import 'package:expense_manager/data/models/transaction_model.dart';
import 'package:expense_manager/features/auth/auth_service.dart';
import 'package:expense_manager/providers/category_provider.dart';
import 'package:expense_manager/providers/settings_provider.dart';
import 'package:expense_manager/providers/transaction_provider.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key, this.initialTransaction, this.forcedType});

  final TransactionModel? initialTransaction;
  final TransactionType? forcedType;

  bool get isEditing => initialTransaction != null;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _amountFormat = CurrencyInputFormatter();

  late TransactionType _type;
  String? _categoryId;
  late AccountType _accountType;
  late DateTime _date;
  late bool _isRecurring;

  @override
  void initState() {
    super.initState();
    final existing = widget.initialTransaction;

    _type = existing?.type ?? widget.forcedType ?? TransactionType.expense;
    _categoryId = existing?.categoryId;
    _accountType = existing != null
        ? AccountTypeX.fromValue(existing.accountId)
        : AccountType.cash;
    _date = existing?.date ?? DateTime.now();
    _isRecurring = existing?.isRecurring ?? false;

    if (existing != null) {
      _amountController.text = NumberFormat('#,##0.00').format(existing.amount);
    }
    _noteController.text = existing?.note ?? '';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category.')),
      );
      return;
    }

    final existing = widget.initialTransaction;
    final amount = double.parse(_amountController.text.replaceAll(',', ''));
    final now = DateTime.now();
    final userId = existing?.userId ?? context.read<AuthService>().currentUserId;

    final transaction = TransactionModel(
      id: existing?.id ?? const Uuid().v4(),
      userId: userId,
      amount: amount,
      type: _type,
      categoryId: _categoryId!,
      accountId: _accountType.value,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      date: _date,
      attachmentPath: existing?.attachmentPath,
      isRecurring: _isRecurring,
      updatedAt: now,
      deletedAt: existing?.deletedAt,
      syncStatus: widget.isEditing ? SyncStatus.pendingUpdate : SyncStatus.pendingCreate,
    );

    final provider = context.read<TransactionProvider>();
    final messenger = ScaffoldMessenger.of(context);

    if (widget.isEditing) {
      await provider.updateTransaction(transaction);
    } else {
      await provider.addTransaction(transaction);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(content: Text(widget.isEditing ? 'Transaction updated' : 'Transaction saved')),
    );
  }

  void _onTypeChanged(TransactionType type) {
    setState(() {
      _type = type;
      _categoryId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final currencySymbol = context.watch<SettingsProvider>().currencySymbol;
    final categories = categoryProvider.categoriesByType(_type);
    final typeIsLocked = widget.forcedType != null && !widget.isEditing;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                widget.isEditing
                    ? 'Edit Transaction'
                    : (_type == TransactionType.income ? 'Add Income' : 'Add Expense'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (!typeIsLocked)
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(value: TransactionType.expense, label: Text('Expense')),
                    ButtonSegment(value: TransactionType.income, label: Text('Income')),
                  ],
                  selected: {_type},
                  onSelectionChanged: (selection) => _onTypeChanged(selection.first),
                ),
              if (!typeIsLocked) const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_amountFormat],
                decoration: InputDecoration(labelText: 'Amount', prefixText: '$currencySymbol '),
                validator: (value) {
                  final parsed = double.tryParse((value ?? '').replaceAll(',', ''));
                  if (parsed == null || parsed <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Text('Category', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _CategorySelector(
                categories: categories,
                selectedId: _categoryId,
                onSelected: (id) => setState(() => _categoryId = id),
              ),
              const SizedBox(height: 20),
              Text('Account', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<AccountType>(
                segments: const [
                  ButtonSegment(value: AccountType.cash, label: Text('Cash')),
                  ButtonSegment(value: AccountType.bank, label: Text('Bank')),
                  ButtonSegment(value: AccountType.creditCard, label: Text('Credit Card')),
                ],
                selected: {_accountType},
                onSelectionChanged: (selection) =>
                    setState(() => _accountType = selection.first),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text(Formatters.date(_date)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickDate,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Note / Description (optional)'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Recurring transaction'),
                value: _isRecurring,
                onChanged: (value) => setState(() => _isRecurring = value),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(widget.isEditing ? 'Update Transaction' : 'Save Transaction'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<CategoryModel> categories;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Text('No categories available for this type yet.');
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: categories.map((category) {
        final isSelected = category.id == selectedId;
        final color = Color(category.color);

        return ChoiceChip(
          selected: isSelected,
          onSelected: (_) => onSelected(category.id),
          avatar: Icon(
            categoryIconFor(category.icon),
            size: 18,
            color: isSelected ? Colors.white : color,
          ),
          label: Text(category.name),
          selectedColor: color,
          labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimaryLight),
          backgroundColor: color.withValues(alpha:0.1),
        );
      }).toList(),
    );
  }
}
