import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:catat_keuangan/data/models/category_model.dart';
import 'package:catat_keuangan/data/models/transaction_model.dart';
import 'package:catat_keuangan/data/models/transaction_type.dart';
import 'package:catat_keuangan/core/utils/icon_helper.dart';
import 'package:catat_keuangan/core/utils/receipt_parser_helper.dart';
import 'package:catat_keuangan/core/utils/report_export_service.dart';
import 'package:catat_keuangan/logic/providers/transaction_provider.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);

    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);

    Hive.registerAdapter(TransactionTypeAdapter());
    Hive.registerAdapter(CategoryModelAdapter());
    Hive.registerAdapter(TransactionModelAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CategoryModel & Hive Adapter Tests', () {
    test('Can store and retrieve CategoryModel in Hive', () async {
      final box = await Hive.openBox<CategoryModel>('test_categories');

      const category = CategoryModel(
        id: 'cat-1',
        name: 'Makan Siang',
        icon: 'fastfood',
        type: TransactionType.expense,
      );

      await box.put(category.id, category);
      final retrieved = box.get('cat-1');

      expect(retrieved, isNotNull);
      expect(retrieved?.id, 'cat-1');
      expect(retrieved?.name, 'Makan Siang');
      expect(retrieved?.icon, 'fastfood');
      expect(retrieved?.type, TransactionType.expense);
      expect(retrieved, equals(category));

      // Test copyWith
      final updated = category.copyWith(name: 'Makan Malam');
      expect(updated.name, 'Makan Malam');
      expect(updated.id, 'cat-1');

      await box.close();
    });
  });

  group('TransactionModel & Hive Adapter Tests', () {
    test('Can store and retrieve TransactionModel in Hive', () async {
      final box = await Hive.openBox<TransactionModel>('test_transactions');
      final now = DateTime.now();

      final transaction = TransactionModel(
        id: 'tx-1',
        title: 'Nasi Padang',
        amount: 25000.0,
        date: now,
        type: TransactionType.expense,
        categoryId: 'cat-1',
      );

      await box.put(transaction.id, transaction);
      final retrieved = box.get('tx-1');

      expect(retrieved, isNotNull);
      expect(retrieved?.id, 'tx-1');
      expect(retrieved?.title, 'Nasi Padang');
      expect(retrieved?.amount, 25000.0);
      expect(retrieved?.type, TransactionType.expense);
      expect(retrieved?.categoryId, 'cat-1');

      await box.close();
    });
  });

  group('CategoryIconHelper Tests', () {
    test('Returns default icon for unknown or empty strings', () {
      final fallback = CategoryIconHelper.getIcon('');
      expect(fallback, isNotNull);

      final fastfood = CategoryIconHelper.getIcon('fastfood');
      expect(fastfood, isNotNull);
    });
  });

  group('Transaction provider reporting filters', () {
    test(
      'Filters transactions by selected date range and recalculates totals',
      () {
        final now = DateTime(2026, 10, 20, 12, 0, 0);
        final transactions = [
          TransactionModel(
            id: 'tx-1',
            title: 'Gaji Bulanan',
            amount: 5000000,
            date: now,
            type: TransactionType.income,
            categoryId: 'cat-income',
          ),
          TransactionModel(
            id: 'tx-2',
            title: 'Belanja Makanan',
            amount: 85000,
            date: now.subtract(const Duration(days: 10)),
            type: TransactionType.expense,
            categoryId: 'cat-food',
          ),
          TransactionModel(
            id: 'tx-3',
            title: 'Bensin',
            amount: 120000,
            date: now.subtract(const Duration(days: 3)),
            type: TransactionType.expense,
            categoryId: 'cat-transport',
          ),
        ];

        final provider = TransactionProvider();
        provider.setTransactionsForTesting(transactions);
        provider.applyDateFilter(
          preset: DashboardDateFilter.custom,
          customRange: DateTimeRange(
            start: now.subtract(const Duration(days: 4)),
            end: now
                .add(const Duration(days: 1))
                .subtract(const Duration(microseconds: 1)),
          ),
        );

        expect(provider.filteredTransactions, hasLength(2));
        expect(provider.filteredIncome, 5000000.0);
        expect(provider.filteredExpense, 120000.0);
        expect(provider.filteredBalance, 4880000.0);
      },
    );
  });

  group('Report export service', () {
    test('Generates CSV rows for report export', () {
      final transactions = [
        TransactionModel(
          id: 'tx-1',
          title: 'Gaji Bulanan',
          amount: 5000000,
          date: DateTime(2026, 10, 20),
          type: TransactionType.income,
          categoryId: 'cat-income',
        ),
        TransactionModel(
          id: 'tx-2',
          title: 'Belanja Makanan',
          amount: 85000,
          date: DateTime(2026, 10, 18),
          type: TransactionType.expense,
          categoryId: 'cat-food',
        ),
      ];

      final csv = ReportExportService.generateCsv(transactions);
      expect(csv, contains('Tanggal'));
      expect(csv, contains('Gaji Bulanan'));
      expect(csv, contains('Belanja Makanan'));
      expect(csv, contains('5000000'));
    });
  });

  group('ReceiptParserHelper Tests', () {
    test('Extracts largest amount correctly from receipt text', () {
      const receiptText = '''
KOPI KENANGAN - MALL KELAPA GADING
JL. BOULEVARD RAYA NO. 1
TELP: 081234567890
TANGGAL: 18/10/2026 14:32

1x KENANGAN MANTAN         24.000
1x ROTI COKLAT KLASIK      15.000
1x AVOCADO COFFEE          32.000

SUBTOTAL                   71.000
PB1 (10%)                   7.100
TOTAL                     78.100
TUNAI                    100.000
KEMBALI                   21.900

TERIMA KASIH
''';

      final amount = ReceiptParserHelper.extractLargestAmount(receiptText);
      // Largest amount in receipt candidates: 100.000 or 78.100
      expect(amount, greaterThanOrEqualTo(78100.0));
      expect(amount, lessThanOrEqualTo(100000.0));
    });

    test('Ignores receipt header lines and extracts valid item lines', () {
      const receiptText = '''
CETAK ULANG
Mode: TAKE AWAY
Kasir : ALEX
Tanggal : 18/10/2026 14:32
No. Nota : 12345
Paket Wingers 1x @35.000  35.000
Saos Keju 1x @8.000  8.000
GRAND TOTAL
38.000
''';

      final items = ReceiptParserHelper.extractItems(receiptText);
      final totalAmount = ReceiptParserHelper.extractTotalAmount(receiptText);

      expect(items, hasLength(2));
      expect(
        items.map((e) => e.name),
        containsAll(['Paket Wingers', 'Saos Keju']),
      );
      expect(items.every((item) => item.qty > 0), isTrue);
      expect(totalAmount, 38000.0);
      expect(
        items.any(
          (item) => item.name.contains('Mode') || item.name.contains('Kasir'),
        ),
        isFalse,
      );
    });

    test('Extracts merchant title from header lines', () {
      const receiptText = '''
STRUK PEMBELIAN
INDOMARET FATMAWATI 2
JL. RS FATMAWATI NO 10
TOTAL: Rp 45.000
''';

      final title = ReceiptParserHelper.extractMerchantTitle(receiptText);
      expect(title, 'INDOMARET FATMAWATI 2');
    });

    test('Matches existing category based on keywords', () async {
      final existingCategories = [
        const CategoryModel(
          id: 'cat-food',
          name: 'Makanan & Minuman',
          icon: 'fastfood',
          type: TransactionType.expense,
        ),
        const CategoryModel(
          id: 'cat-shop',
          name: 'Belanja',
          icon: 'shopping_bag',
          type: TransactionType.expense,
        ),
      ];

      const receiptCoffee =
          'STARBUCKS COFFEE\nCAFE LATTE 55.000\nTOTAL: 55.000';
      final match1 = await ReceiptParserHelper.matchOrSuggestCategory(
        rawText: receiptCoffee,
        existingCategories: existingCategories,
      );

      expect(match1.category.name, 'Makanan & Minuman');
      expect(match1.isNewCreated, false);

      const receiptIndomaret =
          'INDOMARET POINT\nSNACK & MINUMAN\nTOTAL: 30.000';
      final match2 = await ReceiptParserHelper.matchOrSuggestCategory(
        rawText: receiptIndomaret,
        existingCategories: existingCategories,
      );

      expect(match2.category.name, isNotEmpty);
    });
  });
}
