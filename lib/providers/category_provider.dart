import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/models/category_model.dart';
import '../data/models/transaction_model.dart';
import '../data/repositories/category_repository.dart';

class CategoryProvider extends ChangeNotifier {
  CategoryProvider({required CategoryRepository repository})
      : _repository = repository;

  final CategoryRepository _repository;
  static const _uuid = Uuid();

  String? _userId;
  List<CategoryModel> _categories = [];
  bool _isLoading = false;

  List<CategoryModel> get categories => List.unmodifiable(_categories);
  bool get isLoading => _isLoading;

  List<CategoryModel> categoriesByType(TransactionType type) {
    return _categories.where((c) => c.type == type).toList();
  }

  Future<void> loadCategories(String userId) async {
    _userId = userId;
    _isLoading = true;
    notifyListeners();

    _categories = await _repository.getCategories(userId);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _reload() async {
    if (_userId == null) return;
    _categories = await _repository.getCategories(_userId!);
    notifyListeners();
  }

  Future<void> addCategory(CategoryModel category) async {
    final toAdd =
    category.id.isEmpty ? category.copyWith(id: _uuid.v4()) : category;
    await _repository.addCategory(toAdd);
    await _reload();
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _repository.updateCategory(category);
    await _reload();
  }

  Future<void> deleteCategory(String id) async {
    await _repository.deleteCategory(id);
    await _reload();
  }
}
