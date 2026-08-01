import 'package:cloud_firestore/cloud_firestore.dart';

import 'sync_status.dart';

enum AccountType { cash, bank, creditCard, wallet, other }

extension AccountTypeX on AccountType {
  String get value => name;

  static AccountType fromValue(String? value) {
    return AccountType.values.firstWhere(
          (e) => e.name == value,
      orElse: () => AccountType.other,
    );
  }
}

class AccountModel {
  final String id;
  final String userId;
  final String name;
  final AccountType type;
  final double balance;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final SyncStatus syncStatus;

  const AccountModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.balance,
    required this.updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.pendingCreate,
  });

  bool get isDeleted => deletedAt != null;

  // JSON Aliases (used by ExportService / dashboard_screen.dart backup flow)
  Map<String, dynamic> toJson() => toMap();

  factory AccountModel.fromJson(Map<String, dynamic> json) =>
      AccountModel.fromMap(json);

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    return AccountModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      name: map['name'] as String,
      type: AccountTypeX.fromValue(map['type'] as String?),
      balance: (map['balance'] as num).toDouble(),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      deletedAt: map['deletedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['deletedAt'] as int)
          : null,
      syncStatus: SyncStatusX.fromValue(map['syncStatus'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'type': type.value,
      'balance': balance,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'deletedAt': deletedAt?.millisecondsSinceEpoch,
      'syncStatus': syncStatus.value,
    };
  }

  factory AccountModel.fromFirestore(Map<String, dynamic> map, String id) {
    return AccountModel(
      id: id,
      userId: map['userId'] as String,
      name: map['name'] as String,
      type: AccountTypeX.fromValue(map['type'] as String?),
      balance: (map['balance'] as num).toDouble(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      deletedAt: (map['deletedAt'] as Timestamp?)?.toDate(),
      syncStatus: SyncStatus.synced,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'type': type.value,
      'balance': balance,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    };
  }

  AccountModel copyWith({
    String? id,
    String? userId,
    String? name,
    AccountType? type,
    double? balance,
    DateTime? updatedAt,
    DateTime? deletedAt,
    SyncStatus? syncStatus,
    bool clearDeletedAt = false,
  }) {
    return AccountModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
