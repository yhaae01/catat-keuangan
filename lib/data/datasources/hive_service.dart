import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/hive_constants.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../models/transaction_type.dart';

class HiveService {
  static final HiveService _instance = HiveService._internal();
  factory HiveService() => _instance;
  HiveService._internal();

  Box<CategoryModel>? _categoryBox;
  Box<TransactionModel>? _transactionBox;

  Box<CategoryModel> get categoryBox {
    if (_categoryBox == null || !_categoryBox!.isOpen) {
      throw StateError('CategoryBox belum diinisialisasi atau telah tertutup.');
    }
    return _categoryBox!;
  }

  Box<TransactionModel> get transactionBox {
    if (_transactionBox == null || !_transactionBox!.isOpen) {
      throw StateError('TransactionBox belum diinisialisasi atau telah tertutup.');
    }
    return _transactionBox!;
  }

  /// Inisialisasi Hive, mendaftarkan TypeAdapter, dan membuka Boxes
  Future<void> init() async {
    await Hive.initFlutter();

    // Register Type Adapters jika belum terdaftar
    if (!Hive.isAdapterRegistered(HiveConstants.transactionTypeTypeId)) {
      Hive.registerAdapter(TransactionTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveConstants.categoryTypeId)) {
      Hive.registerAdapter(CategoryModelAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveConstants.transactionTypeId)) {
      Hive.registerAdapter(TransactionModelAdapter());
    }

    // Buka Box untuk Kategori dan Transaksi
    _categoryBox = await Hive.openBox<CategoryModel>(HiveConstants.categoriesBox);
    _transactionBox = await Hive.openBox<TransactionModel>(HiveConstants.transactionsBox);

    // Seed default kategori jika box masih kosong
    await _seedDefaultCategoriesIfEmpty();
  }

  /// Mengisi data default kategori awal
  Future<void> _seedDefaultCategoriesIfEmpty() async {
    if (_categoryBox != null && _categoryBox!.isEmpty) {
      const uuid = Uuid();
      final defaultCategories = <CategoryModel>[
        // Pengeluaran (Expense)
        CategoryModel(
          id: uuid.v4(),
          name: 'Makanan & Minuman',
          icon: 'fastfood',
          type: TransactionType.expense,
        ),
        CategoryModel(
          id: uuid.v4(),
          name: 'Transportasi',
          icon: 'directions_car',
          type: TransactionType.expense,
        ),
        CategoryModel(
          id: uuid.v4(),
          name: 'Belanja',
          icon: 'shopping_bag',
          type: TransactionType.expense,
        ),
        CategoryModel(
          id: uuid.v4(),
          name: 'Tagihan & Utilitas',
          icon: 'receipt_long',
          type: TransactionType.expense,
        ),
        CategoryModel(
          id: uuid.v4(),
          name: 'Hiburan',
          icon: 'movie',
          type: TransactionType.expense,
        ),
        CategoryModel(
          id: uuid.v4(),
          name: 'Kesehatan',
          icon: 'medical_services',
          type: TransactionType.expense,
        ),
        CategoryModel(
          id: uuid.v4(),
          name: 'Pendidikan',
          icon: 'school',
          type: TransactionType.expense,
        ),
        CategoryModel(
          id: uuid.v4(),
          name: 'Lainnya (Pengeluaran)',
          icon: 'more_horiz',
          type: TransactionType.expense,
        ),

        // Pemasukan (Income)
        CategoryModel(
          id: uuid.v4(),
          name: 'Gaji Pokok',
          icon: 'account_balance_wallet',
          type: TransactionType.income,
        ),
        CategoryModel(
          id: uuid.v4(),
          name: 'Bonus & THR',
          icon: 'card_giftcard',
          type: TransactionType.income,
        ),
        CategoryModel(
          id: uuid.v4(),
          name: 'Investasi',
          icon: 'trending_up',
          type: TransactionType.income,
        ),
        CategoryModel(
          id: uuid.v4(),
          name: 'Penjualan / Usaha',
          icon: 'storefront',
          type: TransactionType.income,
        ),
        CategoryModel(
          id: uuid.v4(),
          name: 'Hadiah / Pemberian',
          icon: 'redeem',
          type: TransactionType.income,
        ),
        CategoryModel(
          id: uuid.v4(),
          name: 'Lainnya (Pemasukan)',
          icon: 'savings',
          type: TransactionType.income,
        ),
      ];

      for (final category in defaultCategories) {
        await _categoryBox!.put(category.id, category);
      }
    }
  }

  /// Tutup semua boxes jika diperlukan
  Future<void> close() async {
    await _categoryBox?.close();
    await _transactionBox?.close();
  }
}
