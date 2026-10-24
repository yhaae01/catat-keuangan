import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:catat_keuangan/core/constants/hive_constants.dart';
import 'package:catat_keuangan/data/datasources/hive_service.dart';
import 'package:catat_keuangan/data/models/category_model.dart';
import 'package:catat_keuangan/data/models/transaction_model.dart';
import 'package:catat_keuangan/data/models/transaction_type.dart';
import 'package:catat_keuangan/logic/providers/transaction_provider.dart';

void main() {
  late Directory tempDir;
  late HiveService hiveService;
  late CategoryModel foodCategory;

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);

    tempDir = await Directory.systemTemp.createTemp('hive_add_tx_test_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(HiveConstants.transactionTypeTypeId)) {
      Hive.registerAdapter(TransactionTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveConstants.categoryTypeId)) {
      Hive.registerAdapter(CategoryModelAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveConstants.transactionTypeId)) {
      Hive.registerAdapter(TransactionModelAdapter());
    }

    await Hive.openBox<CategoryModel>(HiveConstants.categoriesBox);
    await Hive.openBox<TransactionModel>(HiveConstants.transactionsBox);
    await Hive.openBox(HiveConstants.settingsBox);

    hiveService = HiveService();

    foodCategory = const CategoryModel(
      id: 'cat-makanan',
      name: 'Makanan & Minuman',
      icon: 'fastfood',
      type: TransactionType.expense,
    );
    await hiveService.categoryBox.put(foodCategory.id, foodCategory);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    await hiveService.transactionBox.clear();
  });

  group('TransactionProvider Single Header + Sub-items Tests', () {
    test(
      'addMultipleTransactions saves 1 header transaction with sub-items in Hive',
      () async {
        final txProvider = TransactionProvider(hiveService: hiveService);
        final now = DateTime.now();
        final success = await txProvider.addMultipleTransactions(
          items: [
            (title: 'Roti Coklat', amount: 6500.0, qty: 1),
            (title: 'Roti', amount: 7000.0, qty: 1),
          ],
          date: now,
          type: TransactionType.expense,
          categoryId: foodCategory.id,
          note: 'Belanja Pagi',
        );

        expect(success, isTrue);

        // Harus ada 1 transaksi header saja
        expect(txProvider.transactions, hasLength(1));
        expect(hiveService.transactionBox.values, hasLength(1));

        final header = txProvider.transactions.first;
        // Title header diambil dari note
        expect(header.title, 'Belanja Pagi');
        // Total amount = jumlah semua item
        expect(header.amount, 13500.0);
        expect(header.categoryId, foodCategory.id);
        // Sub-items tersimpan di dalam transaksi
        expect(header.items, hasLength(2));
        expect(header.items.map((e) => e.name), containsAll(['Roti Coklat', 'Roti']));
      },
    );
  });

  group('AddTransactionScreen Save Logic (via Provider)', () {
    test(
      'Single item with note: saves 1 header with note as title and item as sub-item',
      () async {
        final txProvider = TransactionProvider(hiveService: hiveService);
        final now = DateTime.now();

        // Simulasi: form dengan 1 item + catatan
        final ok = await txProvider.addMultipleTransactions(
          items: [(title: 'Bensin Motor', amount: 25000.0, qty: 1)],
          date: now,
          type: TransactionType.expense,
          categoryId: foodCategory.id,
          note: 'Bensin Motor',
        );

        expect(ok, isTrue);
        expect(txProvider.transactions, hasLength(1));

        final tx = txProvider.transactions.first;
        expect(tx.title, 'Bensin Motor');
        expect(tx.amount, 25000.0);
        expect(tx.items, hasLength(1));
        expect(tx.items.first.name, 'Bensin Motor');
      },
    );

    test(
      'Multi-item with note: saves 1 header with note as title and 2 sub-items',
      () async {
        final txProvider = TransactionProvider(hiveService: hiveService);
        final now = DateTime.now();

        // Simulasi: form dengan 2 item + catatan "Belanja Pagi"
        final ok = await txProvider.addMultipleTransactions(
          items: [
            (title: 'Roti Coklat', amount: 6500.0, qty: 1),
            (title: 'Roti', amount: 7000.0, qty: 1),
          ],
          date: now,
          type: TransactionType.expense,
          categoryId: foodCategory.id,
          note: 'Belanja Pagi',
        );

        expect(ok, isTrue);

        // Harus ada 1 transaksi header saja — bukan 2
        expect(txProvider.transactions, hasLength(1));

        final header = txProvider.transactions.first;
        // Title header = dari catatan
        expect(header.title, 'Belanja Pagi');
        // Total = 6.500 + 7.000 = 13.500
        expect(header.amount, 13500.0);
        // Sub-items tersimpan di dalam transaksi
        expect(header.items, hasLength(2));
        expect(
          header.items.map((e) => e.name),
          containsAll(['Roti Coklat', 'Roti']),
        );
      },
    );

    test(
      'Multi-item without note: header title = gabungan nama item',
      () async {
        final txProvider = TransactionProvider(hiveService: hiveService);
        final now = DateTime.now();

        // Simulasi: form dengan 2 item, tanpa catatan
        final ok = await txProvider.addMultipleTransactions(
          items: [
            (title: 'Roti A', amount: 7500.0, qty: 1),
            (title: 'Roti B', amount: 6000.0, qty: 1),
          ],
          date: now,
          type: TransactionType.expense,
          categoryId: foodCategory.id,
          // tidak ada note
        );

        expect(ok, isTrue);
        expect(txProvider.transactions, hasLength(1));

        final header = txProvider.transactions.first;
        // Title = gabungan nama item karena tidak ada catatan
        expect(header.title, contains('Roti A'));
        expect(header.title, contains('Roti B'));
        expect(header.amount, 13500.0);
        expect(header.items, hasLength(2));
      },
    );
  });
}
