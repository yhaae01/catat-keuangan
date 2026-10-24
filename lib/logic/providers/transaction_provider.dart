import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../data/datasources/hive_service.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/transaction_type.dart';

enum DashboardDateFilter { all, today, week, month, custom }

class TransactionProvider extends ChangeNotifier {
  final HiveService _hiveService;
  final Uuid _uuid = const Uuid();

  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;
  DashboardDateFilter _selectedFilter = DashboardDateFilter.all;
  DateTimeRange? _selectedDateRange;

  TransactionProvider({HiveService? hiveService})
    : _hiveService = hiveService ?? HiveService() {
    loadTransactions();
  }

  // Getters
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DashboardDateFilter get selectedFilter => _selectedFilter;
  DateTimeRange? get selectedDateRange => _selectedDateRange;

  String get activeRangeLabel {
    switch (_selectedFilter) {
      case DashboardDateFilter.all:
        return 'Semua Waktu';
      case DashboardDateFilter.today:
        return 'Hari Ini';
      case DashboardDateFilter.week:
        return 'Minggu Ini';
      case DashboardDateFilter.month:
        return 'Bulan Ini';
      case DashboardDateFilter.custom:
        if (_selectedDateRange == null) return 'Pilih Rentang';
        final start = DateFormat(
          'd MMM',
          'id_ID',
        ).format(_selectedDateRange!.start);
        final end = DateFormat(
          'd MMM yyyy',
          'id_ID',
        ).format(_selectedDateRange!.end);
        return '$start - $end';
    }
  }

  List<TransactionModel> get filteredTransactions {
    if (_selectedDateRange == null) {
      return transactions;
    }

    final range = _normalizeDateRange(_selectedDateRange!);
    final filtered = _transactions.where((tx) {
      return !tx.date.isBefore(range.start) && !tx.date.isAfter(range.end);
    }).toList();
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

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

  double get filteredBalance => filteredIncome - filteredExpense;

  double get filteredIncome => filteredTransactions
      .where((t) => t.type == TransactionType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get filteredExpense => filteredTransactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  void applyDateFilter({
    required DashboardDateFilter preset,
    DateTimeRange? customRange,
  }) {
    _selectedFilter = preset;
    _selectedDateRange = _buildRangeForPreset(preset, customRange: customRange);
    notifyListeners();
  }

  void clearDateFilter() {
    _selectedFilter = DashboardDateFilter.all;
    _selectedDateRange = null;
    notifyListeners();
  }

  @visibleForTesting
  void setTransactionsForTesting(List<TransactionModel> transactions) {
    _transactions = List.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  DateTimeRange? _buildRangeForPreset(
    DashboardDateFilter preset, {
    DateTimeRange? customRange,
  }) {
    final now = DateTime.now();

    switch (preset) {
      case DashboardDateFilter.all:
        return null;
      case DashboardDateFilter.today:
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      case DashboardDateFilter.week:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        );
        final end = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day + 6,
          23,
          59,
          59,
          999,
        );
        return DateTimeRange(start: start, end: end);
      case DashboardDateFilter.month:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      case DashboardDateFilter.custom:
        if (customRange == null) {
          return null;
        }
        return _normalizeDateRange(customRange);
    }
  }

  DateTimeRange _normalizeDateRange(DateTimeRange range) {
    return DateTimeRange(
      start: DateTime(range.start.year, range.start.month, range.start.day),
      end: DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
        999,
      ),
    );
  }

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

  /// Menambahkan beberapa transaksi baru sekaligus ke database Hive
  Future<bool> addTransactions(List<TransactionModel> transactions) async {
    try {
      if (transactions.isEmpty) return true;

      final box = _hiveService.transactionBox;
      final entries = {for (final tx in transactions) tx.id: tx};
      await box.putAll(entries);

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

  /// Menambahkan satu transaksi header dengan rincian sub-items.
  /// Hanya 1 baris transaksi yang dibuat di list utama; item-item
  /// disimpan sebagai detail di dalam transaksi tersebut.
  Future<bool> addMultipleTransactions({
    required List<({String title, double amount, int qty})> items,
    required DateTime date,
    required TransactionType type,
    required String categoryId,
    String? note,
  }) async {
    if (items.isEmpty) return true;

    // Hitung total dari semua item
    final double totalAmount = items.fold(0.0, (sum, e) => sum + e.amount);

    // Buat daftar sub-item
    final subItems = items
        .map(
          (e) => TransactionItemDetail(
            name: e.title,
            qty: e.qty,
            price: e.amount / (e.qty > 0 ? e.qty : 1),
          ),
        )
        .toList();

    // Judul header: ambil dari `note` jika ada, atau gabungan nama item
    final headerTitle = (note != null && note.isNotEmpty)
        ? note
        : items.map((e) => e.title).join(', ');

    // Simpan 1 transaksi header saja
    return addTransaction(
      title: headerTitle,
      amount: totalAmount,
      date: date,
      type: type,
      categoryId: categoryId,
      items: subItems,
    );
  }

  /// Menambahkan transaksi baru (dengan opsional sub-items)
  Future<bool> addTransaction({
    required String title,
    required double amount,
    required DateTime date,
    required TransactionType type,
    required String categoryId,
    List<TransactionItemDetail> items = const [],
  }) async {
    final newTx = TransactionModel(
      id: _uuid.v4(),
      title: title.trim(),
      amount: amount,
      date: date,
      type: type,
      categoryId: categoryId,
      items: items,
    );
    return addTransactions([newTx]);
  }

  /// Mengedit transaksi yang sudah ada
  Future<bool> updateTransaction(TransactionModel transaction) async {
    try {
      final box = _hiveService.transactionBox;
      if (!box.containsKey(transaction.id)) {
        _errorMessage =
            'Transaksi dengan ID ${transaction.id} tidak ditemukan.';
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
