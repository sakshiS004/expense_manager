import 'package:flutter/material.dart';

IconData categoryIconFor(String key) {
  switch (key) {
    case 'restaurant':
      return Icons.restaurant;
    case 'flight':
      return Icons.flight;
    case 'shopping_bag':
      return Icons.shopping_bag;
    case 'home':
      return Icons.home;
    case 'attach_money':
      return Icons.attach_money;
    case 'work':
      return Icons.work;
    default:
      return Icons.category;
  }
}
