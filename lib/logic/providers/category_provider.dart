import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../data/datasources/hive_service.dart';
import '../../data/models/category_model.dart';
import '../../data/models/transaction_type.dart';

class CategoryProvider extends ChangeNotifier {
  final HiveService _hiveService;
  final Uuid _uuid = const Uuid();

  List<CategoryModel> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;

  CategoryProvider({HiveService? hiveService})
      : _hiveService = hiveService ?? HiveService() {
    loadCategories();
  }

  // Getters
  List<CategoryModel> get categories => List.unmodifiable(_categories);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<CategoryModel> get incomeCategories =>
      _categories.where((c) => c.type == TransactionType.income).toList();

  List<CategoryModel> get expenseCategories =>
      _categories.where((c) => c.type == TransactionType.expense).toList();

  /// Memuat semua kategori dari Hive Box
  void loadCategories() {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final box = _hiveService.categoryBox;
      _categories = box.values.toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal memuat kategori: $e';
      notifyListeners();
    }
  }

  /// Menambahkan kategori baru ke Hive Box
  Future<bool> addCategory({
    required String name,
    required String icon,
    required TransactionType type,
  }) async {
    try {
      final newCategory = CategoryModel(
        id: _uuid.v4(),
        name: name.trim(),
        icon: icon,
        type: type,
      );

      final box = _hiveService.categoryBox;
      await box.put(newCategory.id, newCategory);

      _categories = box.values.toList();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menambahkan kategori: $e';
      notifyListeners();
      return false;
    }
  }

  /// Mengedit atau memperbarui kategori yang sudah ada
  Future<bool> updateCategory(CategoryModel category) async {
    try {
      final box = _hiveService.categoryBox;
      if (!box.containsKey(category.id)) {
        _errorMessage = 'Kategori dengan ID ${category.id} tidak ditemukan.';
        notifyListeners();
        return false;
      }

      await box.put(category.id, category);
      _categories = box.values.toList();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memperbarui kategori: $e';
      notifyListeners();
      return false;
    }
  }

  /// Menghapus kategori berdasarkan ID
  Future<bool> deleteCategory(String id) async {
    try {
      final box = _hiveService.categoryBox;
      await box.delete(id);

      _categories = box.values.toList();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menghapus kategori: $e';
      notifyListeners();
      return false;
    }
  }

  /// Mendapatkan kategori berdasarkan ID
  CategoryModel? getCategoryById(String id) {
    try {
      return _categories.firstWhere((category) => category.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Mendapatkan daftar kategori berdasarkan tipe (income / expense)
  List<CategoryModel> getCategoriesByType(TransactionType type) {
    return _categories.where((c) => c.type == type).toList();
  }
}
