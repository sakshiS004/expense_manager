import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/budget_model.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String userId, String name) {
    return _firestore.collection('users').doc(userId).collection(name);
  }

  // ---------- Transactions ----------

  Future<void> uploadTransaction(TransactionModel item) async {
    await _collection(item.userId, 'transactions')
        .doc(item.id)
        .set(item.toFirestore(), SetOptions(merge: true));
  }

  Future<void> deleteRemoteTransaction(String userId, String transactionId) async {
    await _collection(userId, 'transactions').doc(transactionId).delete();
  }

  Future<List<TransactionModel>> fetchRemoteChanges(String userId, DateTime lastSyncAt) async {
    final snapshot = await _collection(userId, 'transactions')
        .where('updatedAt', isGreaterThan: Timestamp.fromDate(lastSyncAt))
        .get();

    return snapshot.docs.map((doc) => TransactionModel.fromFirestore(doc.data(), doc.id)).toList();
  }

  // ---------- Categories ----------

  Future<void> uploadCategory(CategoryModel item) async {
    await _collection(item.userId, 'categories')
        .doc(item.id)
        .set(item.toFirestore(), SetOptions(merge: true));
  }

  Future<void> deleteRemoteCategory(String userId, String categoryId) async {
    await _collection(userId, 'categories').doc(categoryId).delete();
  }

  Future<List<CategoryModel>> fetchRemoteCategoryChanges(String userId, DateTime lastSyncAt) async {
    final snapshot = await _collection(userId, 'categories')
        .where('updatedAt', isGreaterThan: Timestamp.fromDate(lastSyncAt))
        .get();

    return snapshot.docs.map((doc) => CategoryModel.fromFirestore(doc.data(), doc.id)).toList();
  }

  // ---------- Budgets ----------

  Future<void> uploadBudget(BudgetModel item) async {
    await _collection(item.userId, 'notifications')
        .doc(item.id)
        .set(item.toFirestore(), SetOptions(merge: true));
  }

  Future<void> deleteRemoteBudget(String userId, String budgetId) async {
    await _collection(userId, 'notifications').doc(budgetId).delete();
  }

  Future<List<BudgetModel>> fetchRemoteBudgetChanges(String userId, DateTime lastSyncAt) async {
    final snapshot = await _collection(userId, 'notifications')
        .where('updatedAt', isGreaterThan: Timestamp.fromDate(lastSyncAt))
        .get();

    return snapshot.docs.map((doc) => BudgetModel.fromFirestore(doc.data(), doc.id)).toList();
  }
}