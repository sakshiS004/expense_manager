import 'package:intl/intl.dart';

class Formatters {
  static String currencySymbol = '\$';

  static String currency(double amount, {String? symbol}) {
    final formatter = NumberFormat.currency(symbol: symbol ?? currencySymbol, decimalDigits: 2);
    return formatter.format(amount);
  }

  static String signedCurrency(double amount, {required bool isIncome, String? symbol}) {
    final sign = isIncome ? '+' : '-';
    return '$sign${currency(amount, symbol: symbol)}';
  }

  static String percentage(double value) => '${value.clamp(0, 999).toStringAsFixed(0)}%';

  static String date(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  static String time(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  static String relativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) return 'Today';
    if (target == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('E, MMM dd').format(date);
  }
}
