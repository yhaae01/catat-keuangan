import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../data/datasources/hive_service.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/transaction_type.dart';

class TransactionProvider extends ChangeNotifier {
  final HiveService _hiveService;
  final Uuid _uuid = const Uuid();

  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  TransactionProvider({HiveService? hiveService})
      : _hiveService = hiveService ?? HiveService() {
    loadTransactions();
  }

  // Getters
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Total saldo (Pemasukan - Pengeluaran)
  double get totalBalance => totalIncome - totalExpense;

  /// Total seluruh pemasukan
  double get totalIncome => _transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  /// Total seluruh pengeluaran
  double get totalExpense => _transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  /// Memuat semua transaksi dari Hive Box diurutkan dari yang terbaru
  void loadTransactions() {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final box = _hiveService.transactionBox;
      final list = box.values.toList();
      list.sort((a, b) => b.date.compareTo(a.date)); // descending date
      _transactions = list;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal memuat transaksi: $e';
      notifyListeners();
    }
  }

  /// Menambahkan transaksi baru
  Future<bool> addTransaction({
    required String title,
    required double amount,
    required DateTime date,
    required TransactionType type,
    required String categoryId,
  }) async {
    try {
      final newTx = TransactionModel(
        id: _uuid.v4(),
        title: title.trim(),
        amount: amount,
        date: date,
        type: type,
        categoryId: categoryId,
      );

      final box = _hiveService.transactionBox;
      await box.put(newTx.id, newTx);

      final list = box.values.toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      _transactions = list;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menambahkan transaksi: $e';
      notifyListeners();
      return false;
    }
  }

  /// Mengedit transaksi yang sudah ada
  Future<bool> updateTransaction(TransactionModel transaction) async {
    try {
      final box = _hiveService.transactionBox;
      if (!box.containsKey(transaction.id)) {
        _errorMessage = 'Transaksi dengan ID ${transaction.id} tidak ditemukan.';
        notifyListeners();
        return false;
      }

      await box.put(transaction.id, transaction);
      final list = box.values.toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      _transactions = list;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memperbarui transaksi: $e';
      notifyListeners();
      return false;
    }
  }

  /// Menghapus transaksi berdasarkan ID
  Future<bool> deleteTransaction(String id) async {
    try {
      final box = _hiveService.transactionBox;
      await box.delete(id);

      final list = box.values.toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      _transactions = list;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menghapus transaksi: $e';
      notifyListeners();
      return false;
    }
  }

  /// Mendapatkan transaksi berdasarkan kategori
  List<TransactionModel> getTransactionsByCategory(String categoryId) {
    return _transactions.where((t) => t.categoryId == categoryId).toList();
  }
}
