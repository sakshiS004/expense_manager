import 'package:flutter/material.dart';

import '../../../core/constants/app_color.dart';
import '../../../core/utils/formatter.dart';
import '../../../data/models/transaction_model.dart';



class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.transaction});

  final TransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final color = isIncome ? AppColors.income : AppColors.expense;
    final title = (transaction.note?.isNotEmpty ?? false)
        ? transaction.note!
        : (isIncome ? 'Income' : 'Expense');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha:0.15),
        child: Icon(
          isIncome ? Icons.arrow_downward : Icons.arrow_upward,
          color: color,
          size: 18,
        ),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${transaction.accountId} • ${Formatters.relativeDate(transaction.date)}'),
      trailing: Text(
        Formatters.signedCurrency(transaction.amount, isIncome: isIncome),
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
