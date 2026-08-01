import '../local/db_helper.dart';
import '../models/category_model.dart';
import '../models/sync_status.dart';

abstract class CategoryRepository {
  Future<List<CategoryModel>> getCategories(String userId);
  Future<void> addCategory(CategoryModel category);
  Future<void> updateCategory(CategoryModel category);
  Future<void> deleteCategory(String id);
}

class LocalCategoryRepository implements CategoryRepository {
  LocalCategoryRepository({DBHelper? dbHelper})
      : _dbHelper = dbHelper ?? DBHelper.instance;

  final DBHelper _dbHelper;

  @override
  Future<List<CategoryModel>> getCategories(String userId) {
    return _dbHelper.getAllActiveCategories(userId);
  }

  @override
  Future<void> addCategory(CategoryModel category) {
    final toSave = category.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pendingCreate,
    );
    return _dbHelper.insertOrUpdateCategory(toSave);
  }

  @override
  Future<void> updateCategory(CategoryModel category) {
    final toSave = category.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pendingUpdate,
    );
    return _dbHelper.insertOrUpdateCategory(toSave);
  }

  @override
  Future<void> deleteCategory(String id) {
    return _dbHelper.softDeleteCategory(id);
  }
}