import 'package:cloud_firestore/cloud_firestore.dart';

import 'sync_status.dart';
import 'transaction_model.dart' show TransactionType, TransactionTypeX;

class CategoryModel {
  final String id;
  final String userId;
  final String name;
  final String icon;
  final TransactionType type;
  final int color;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final SyncStatus syncStatus;

  const CategoryModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.icon,
    required this.type,
    required this.color,
    required this.updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.pendingCreate,
  });

  bool get isDeleted => deletedAt != null;

  // JSON Aliases
  Map<String, dynamic> toJson() => toMap();

  factory CategoryModel.fromJson(Map<String, dynamic> json) =>
      CategoryModel.fromMap(json);

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } else if (value is String) {
        return DateTime.parse(value);
      }
      return DateTime.now();
    }

    return CategoryModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String,
      type: TransactionTypeX.fromValue(map['type'] as String?),
      color: map['color'] as int,
      updatedAt: parseDate(map['updatedAt']),
      deletedAt: map['deletedAt'] != null ? parseDate(map['deletedAt']) : null,
      syncStatus: SyncStatusX.fromValue(map['syncStatus'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'icon': icon,
      'type': type.value,
      'color': color,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'deletedAt': deletedAt?.millisecondsSinceEpoch,
      'syncStatus': syncStatus.value,
    };
  }

  factory CategoryModel.fromFirestore(Map<String, dynamic> map, String id) {
    return CategoryModel(
      id: id,
      userId: map['userId'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String,
      type: TransactionTypeX.fromValue(map['type'] as String?),
      color: map['color'] as int,
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      deletedAt: (map['deletedAt'] as Timestamp?)?.toDate(),
      syncStatus: SyncStatus.synced,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'icon': icon,
      'type': type.value,
      'color': color,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    };
  }

  CategoryModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? icon,
    TransactionType? type,
    int? color,
    DateTime? updatedAt,
    DateTime? deletedAt,
    SyncStatus? syncStatus,
    bool clearDeletedAt = false,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      type: type ?? this.type,
      color: color ?? this.color,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}