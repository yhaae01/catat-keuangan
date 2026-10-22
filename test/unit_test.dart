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

    test('Parses multi-line receipt formats (Indomaret/Alfamart style)', () {
      const receiptText = '''
ALFAMART MERUYA ILIR
================================
SARI ROTI TAWAR
15.000
AQUA BOTOL 600ML
2 x 3.500   7.000
INDOMIE GOR AYAM BPOP
3 PCS   9.300
================================
SUBTOTAL: 31.300
PPN 11%: 3.443
TOTAL BAYAR: 34.743
TUNAI: 50.000
KEMBALIAN: 15.257
TERIMA KASIH TELAH BERBELANJA
''';

      final items = ReceiptParserHelper.extractItems(receiptText);
      final total = ReceiptParserHelper.extractTotalAmount(receiptText);

      expect(items, hasLength(3));
      expect(items[0].name, 'Sari Roti Tawar');
      expect(items[0].qty, 1);
      expect(items[0].unitPrice, 15000.0);

      expect(items[1].name, 'Aqua Botol 600ml');
      expect(items[1].qty, 2);
      expect(items[1].unitPrice, 3500.0);

      expect(items[2].name, 'Indomie Gor Ayam Bpop');
      expect(items[2].qty, 3);
      expect(items[2].unitPrice, (9300.0 / 3).roundToDouble());

      // Total Bayar harus terdeteksi 34.743, bukan Subtotal (31.300) atau Tunai (50.000)
      expect(total, 34743.0);
    });

    test('Parses various quantity patterns and comma thousand separators', () {
      const receiptText = '''
WARUNG KOPI KITA
NO. NOTA: 8872
KASIR: BUDI
2 Kopi Susu Tetangga 36,000
Croissant Keju 1x 22,000
x3 Donat Gula 18,000
Apel Fuji 2 kg 40,000
--------------------------------
SUBTOTAL 116,000
PB1 (10%) 11,600
JUMLAH BAYAR 127,600
CASH 150,000
KEMBALI 22,400
''';

      final items = ReceiptParserHelper.extractItems(receiptText);
      final total = ReceiptParserHelper.extractTotalAmount(receiptText);

      expect(items, hasLength(4));
      // 2 Kopi Susu Tetangga
      expect(items[0].name, contains('Kopi Susu Tetangga'));
      expect(items[0].qty, 2);
      expect(items[0].unitPrice, 18000.0);

      // Croissant Keju 1x
      expect(items[1].name, contains('Croissant Keju'));
      expect(items[1].qty, 1);
      expect(items[1].unitPrice, 22000.0);

      // x3 Donat Gula
      expect(items[2].name, contains('Donat Gula'));
      expect(items[2].qty, 3);
      expect(items[2].unitPrice, 6000.0);

      // Apel Fuji 2 kg
      expect(items[3].name, contains('Apel Fuji'));
      expect(items[3].qty, 2);
      expect(items[3].unitPrice, 20000.0);

      // JUMLAH BAYAR harus 127600, bukan 116000 (subtotal) atau 150000 (cash)
      expect(total, 127600.0);
    });

    test('Correctly identifies universal headers & footers without false positives', () {
      // Baris yang harus dikenali sebagai header/footer
      expect(ReceiptParserHelper.isUniversalHeaderOrFooter('CETAK ULANG'), isTrue);
      expect(ReceiptParserHelper.isUniversalHeaderOrFooter('Kasir: Siti'), isTrue);
      expect(ReceiptParserHelper.isUniversalHeaderOrFooter('Tgl: 22/10/2026'), isTrue);
      expect(ReceiptParserHelper.isUniversalHeaderOrFooter('No. Nota: 1234'), isTrue);
      expect(ReceiptParserHelper.isUniversalHeaderOrFooter('TERIMA KASIH'), isTrue);
      expect(ReceiptParserHelper.isUniversalHeaderOrFooter('SUBTOTAL: 50.000'), isTrue);
      expect(ReceiptParserHelper.isUniversalHeaderOrFooter('TUNAI 100.000'), isTrue);
      expect(ReceiptParserHelper.isUniversalHeaderOrFooter('Kembalian: 50.000'), isTrue);
      expect(ReceiptParserHelper.isUniversalHeaderOrFooter('==================='), isTrue);

      // Nama item yang sah tidak boleh dianggap sebagai header/footer
      expect(ReceiptParserHelper.isUniversalHeaderOrFooter('Indomie Noodle Goreng'), isFalse);
      expect(ReceiptParserHelper.isUniversalHeaderOrFooter('Kopi Kenangan'), isFalse);
      expect(ReceiptParserHelper.isUniversalHeaderOrFooter('Teh Botol Sosro'), isFalse);
    });
  });
}
