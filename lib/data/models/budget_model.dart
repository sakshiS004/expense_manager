import 'package:cloud_firestore/cloud_firestore.dart';

import 'sync_status.dart';

class BudgetModel {
  final String id;
  final String userId;
  final String categoryId;
  final double amount;
  final int month; // 1-12
  final int year;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final SyncStatus syncStatus;

  const BudgetModel({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.amount,
    required this.month,
    required this.year,
    required this.updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.pendingCreate,
  });

  bool get isDeleted => deletedAt != null;

  // JSON Aliases
  Map<String, dynamic> toJson() => toMap();

  factory BudgetModel.fromJson(Map<String, dynamic> json) =>
      BudgetModel.fromMap(json);

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } else if (value is String) {
        return DateTime.parse(value);
      }
      return DateTime.now();
    }

    return BudgetModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      categoryId: map['categoryId'] as String,
      amount: (map['amount'] as num).toDouble(),
      month: map['month'] as int,
      year: map['year'] as int,
      updatedAt: parseDate(map['updatedAt']),
      deletedAt: map['deletedAt'] != null ? parseDate(map['deletedAt']) : null,
      syncStatus: SyncStatusX.fromValue(map['syncStatus'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'categoryId': categoryId,
      'amount': amount,
      'month': month,
      'year': year,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'deletedAt': deletedAt?.millisecondsSinceEpoch,
      'syncStatus': syncStatus.value,
    };
  }

  factory BudgetModel.fromFirestore(Map<String, dynamic> map, String id) {
    return BudgetModel(
      id: id,
      userId: map['userId'] as String,
      categoryId: map['categoryId'] as String,
      amount: (map['amount'] as num).toDouble(),
      month: map['month'] as int,
      year: map['year'] as int,
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      deletedAt: (map['deletedAt'] as Timestamp?)?.toDate(),
      syncStatus: SyncStatus.synced,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'categoryId': categoryId,
      'amount': amount,
      'month': month,
      'year': year,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    };
  }

  BudgetModel copyWith({
    String? id,
    String? userId,
    String? categoryId,
    double? amount,
    int? month,
    int? year,
    DateTime? updatedAt,
    DateTime? deletedAt,
    SyncStatus? syncStatus,
    bool clearDeletedAt = false,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      month: month ?? this.month,
      year: year ?? this.year,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}