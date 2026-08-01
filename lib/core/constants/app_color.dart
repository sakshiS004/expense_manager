import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color secondary = Color(0xFF10B981); // Emerald Green

  static const Color income = Color(0xFF10B981);
  static const Color expense = Color(0xFFEF4444);

  static const Color backgroundLight = Color(0xFFF9FAFB);
  static const Color surfaceLight = Colors.white;
  static const Color cardLight = Colors.white;

  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardDark = Color(0xFF1E293B);

  static const Color textPrimaryLight = Color(0xFF111827);
  static const Color textSecondaryLight = Color(0xFF6B7280);

  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);

  // Budget usage indicator levels: safe -> caution -> warning -> danger
  static const Color budgetSafe = Color(0xFF10B981);
  static const Color budgetCaution = Color(0xFFF59E0B);
  static const Color budgetWarning = Color(0xFFF97316);
  static const Color budgetDanger = Color(0xFFEF4444);
}
