import 'package:cloud_firestore/cloud_firestore.dart';

import 'sync_status.dart';

enum TransactionType { income, expense }

extension TransactionTypeX on TransactionType {
  String get value => name;

  static TransactionType fromValue(String? value) {
    return TransactionType.values.firstWhere(
          (e) => e.name == value,
      orElse: () => TransactionType.expense,
    );
  }
}

class TransactionModel {
  final String id;
  final String userId;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final String accountId;
  final String? note;
  final DateTime date;
  final String? attachmentPath;
  final bool isRecurring;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final SyncStatus syncStatus;

  const TransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.accountId,
    this.note,
    required this.date,
    this.attachmentPath,
    this.isRecurring = false,
    required this.updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.pendingCreate,
  });

  bool get isDeleted => deletedAt != null;

  // JSON Aliases
  Map<String, dynamic> toJson() => toMap();

  factory TransactionModel.fromJson(Map<String, dynamic> json) =>
      TransactionModel.fromMap(json);

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } else if (value is String) {
        return DateTime.parse(value);
      }
      return DateTime.now();
    }

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is int) return value == 1;
      return false;
    }

    return TransactionModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: TransactionTypeX.fromValue(map['type'] as String?),
      categoryId: map['categoryId'] as String,
      accountId: map['accountId'] as String,
      note: map['note'] as String?,
      date: parseDate(map['date']),
      attachmentPath: map['attachmentPath'] as String?,
      isRecurring: parseBool(map['isRecurring']),
      updatedAt: parseDate(map['updatedAt']),
      deletedAt: map['deletedAt'] != null ? parseDate(map['deletedAt']) : null,
      syncStatus: SyncStatusX.fromValue(map['syncStatus'] as String?),
    );
  }

  // Booleans/dates stored as int for sqflite (no native bool/DateTime support).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'type': type.value,
      'categoryId': categoryId,
      'accountId': accountId,
      'note': note,
      'date': date.millisecondsSinceEpoch,
      'attachmentPath': attachmentPath,
      'isRecurring': isRecurring ? 1 : 0,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'deletedAt': deletedAt?.millisecondsSinceEpoch,
      'syncStatus': syncStatus.value,
    };
  }

  factory TransactionModel.fromFirestore(Map<String, dynamic> map, String id) {
    return TransactionModel(
      id: id,
      userId: map['userId'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: TransactionTypeX.fromValue(map['type'] as String?),
      categoryId: map['categoryId'] as String,
      accountId: map['accountId'] as String,
      note: map['note'] as String?,
      date: (map['date'] as Timestamp).toDate(),
      attachmentPath: map['attachmentPath'] as String?,
      isRecurring: map['isRecurring'] as bool? ?? false,
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      deletedAt: (map['deletedAt'] as Timestamp?)?.toDate(),
      // Anything pulled from Firestore is by definition already synced.
      syncStatus: SyncStatus.synced,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'amount': amount,
      'type': type.value,
      'categoryId': categoryId,
      'accountId': accountId,
      'note': note,
      'date': Timestamp.fromDate(date),
      'attachmentPath': attachmentPath,
      'isRecurring': isRecurring,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    };
  }

  TransactionModel copyWith({
    String? id,
    String? userId,
    double? amount,
    TransactionType? type,
    String? categoryId,
    String? accountId,
    String? note,
    DateTime? date,
    String? attachmentPath,
    bool? isRecurring,
    DateTime? updatedAt,
    DateTime? deletedAt,
    SyncStatus? syncStatus,
    bool clearNote = false,
    bool clearAttachmentPath = false,
    bool clearDeletedAt = false,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      note: clearNote ? null : (note ?? this.note),
      date: date ?? this.date,
      attachmentPath:
      clearAttachmentPath ? null : (attachmentPath ?? this.attachmentPath),
      isRecurring: isRecurring ?? this.isRecurring,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}