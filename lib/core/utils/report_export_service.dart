import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/models/transaction_model.dart';
import '../../data/models/transaction_type.dart';

class ReportExportService {
  /// Ringkas rincian sub-item untuk laporan.
  static String _formatItems(TransactionModel tx) {
    if (!tx.hasItems) return '-';
    return tx.items
        .map(
          (item) =>
              '${item.name} (${item.qty}x @${item.price.toStringAsFixed(0)})',
        )
        .join('; ');
  }

  static String generateCsv(
    List<TransactionModel> transactions, {
    DateTimeRange? dateRange,
  }) {
    final rows = <List<String>>[
      [
        'Tanggal',
        'Judul',
        'Jenis',
        'Rincian Item',
        'Subtotal',
        'Diskon',
        'Nominal',
      ],
    ];

    for (final tx in transactions) {
      rows.add([
        DateFormat('yyyy-MM-dd', 'id_ID').format(tx.date),
        tx.title,
        tx.type == TransactionType.income ? 'Pemasukan' : 'Pengeluaran',
        _formatItems(tx),
        tx.grossAmount.toStringAsFixed(2),
        tx.discount.toStringAsFixed(2),
        tx.amount.toStringAsFixed(2),
      ]);
    }

    final totalIncome = transactions
        .where((tx) => tx.type == TransactionType.income)
        .fold(0.0, (sum, tx) => sum + tx.amount);
    final totalExpense = transactions
        .where((tx) => tx.type == TransactionType.expense)
        .fold(0.0, (sum, tx) => sum + tx.amount);
    final totalDiscount = transactions
        .where((tx) => tx.type == TransactionType.expense)
        .fold(0.0, (sum, tx) => sum + tx.discount);

    rows.add(['', '', '', '', '', '', '']);
    rows.add([
      '',
      '',
      'Total Pemasukan',
      '',
      '',
      '',
      totalIncome.toStringAsFixed(2),
    ]);
    rows.add([
      '',
      '',
      'Total Pengeluaran',
      '',
      '',
      '',
      totalExpense.toStringAsFixed(2),
    ]);
    rows.add([
      '',
      '',
      'Total Diskon',
      '',
      '',
      '',
      totalDiscount.toStringAsFixed(2),
    ]);
    rows.add([
      '',
      '',
      'Saldo',
      '',
      '',
      '',
      (totalIncome - totalExpense).toStringAsFixed(2),
    ]);

    if (dateRange != null) {
      rows.add([
        '',
        '',
        'Periode',
        '',
        '',
        '',
        '${DateFormat('dd/MM/yyyy', 'id_ID').format(dateRange.start)} - ${DateFormat('dd/MM/yyyy', 'id_ID').format(dateRange.end)}',
      ]);
    }

    return const CsvEncoder().convert(rows);
  }

  static Future<File> exportCsvToFile(
    List<TransactionModel> transactions, {
    DateTimeRange? dateRange,
    String? fileName,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat(
      'yyyyMMdd_HHmmss',
      'id_ID',
    ).format(DateTime.now());
    final targetFileName = fileName ?? 'laporan_keuangan_$timestamp.csv';
    final file = File('${directory.path}/$targetFileName');
    final content = generateCsv(transactions, dateRange: dateRange);
    await file.writeAsString(content);
    return file;
  }

  static Future<Uint8List> generatePdfBytes(
    List<TransactionModel> transactions, {
    DateTimeRange? dateRange,
  }) async {
    final pdf = pw.Document();
    final totalIncome = transactions
        .where((tx) => tx.type == TransactionType.income)
        .fold(0.0, (sum, tx) => sum + tx.amount);
    final totalExpense = transactions
        .where((tx) => tx.type == TransactionType.expense)
        .fold(0.0, (sum, tx) => sum + tx.amount);
    final totalDiscount = transactions
        .where((tx) => tx.type == TransactionType.expense)
        .fold(0.0, (sum, tx) => sum + tx.discount);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          final rows = transactions
              .map(
                (tx) => [
                  DateFormat('dd/MM/yyyy', 'id_ID').format(tx.date),
                  tx.title,
                  tx.type == TransactionType.income
                      ? 'Pemasukan'
                      : 'Pengeluaran',
                  _formatItems(tx),
                  NumberFormat.currency(
                    locale: 'id_ID',
                    symbol: 'Rp ',
                    decimalDigits: 0,
                  ).format(tx.grossAmount),
                  tx.discount > 0
                      ? '-${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(tx.discount)}'
                      : '-',
                  NumberFormat.currency(
                    locale: 'id_ID',
                    symbol: 'Rp ',
                    decimalDigits: 0,
                  ).format(tx.amount),
                ],
              )
              .toList();

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Laporan Keuangan',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                dateRange == null
                    ? 'Semua Waktu'
                    : '${DateFormat('dd/MM/yyyy', 'id_ID').format(dateRange.start)} - ${DateFormat('dd/MM/yyyy', 'id_ID').format(dateRange.end)}',
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: [
                  'Tanggal',
                  'Judul',
                  'Jenis',
                  'Rincian Item',
                  'Subtotal',
                  'Diskon',
                  'Nominal',
                ],
                data: rows,
                border: null,
                headerStyle: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FixedColumnWidth(52),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FixedColumnWidth(52),
                  3: const pw.FlexColumnWidth(3),
                  4: const pw.FixedColumnWidth(58),
                  5: const pw.FixedColumnWidth(52),
                  6: const pw.FixedColumnWidth(58),
                },
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'Total Pemasukan: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(totalIncome)}',
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      'Total Pengeluaran: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(totalExpense)}',
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Total Diskon: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(totalDiscount)}',
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Saldo: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(totalIncome - totalExpense)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<File> exportPdfToFile(
    List<TransactionModel> transactions, {
    DateTimeRange? dateRange,
    String? fileName,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat(
      'yyyyMMdd_HHmmss',
      'id_ID',
    ).format(DateTime.now());
    final targetFileName = fileName ?? 'laporan_keuangan_$timestamp.pdf';
    final file = File('${directory.path}/$targetFileName');
    final bytes = await generatePdfBytes(transactions, dateRange: dateRange);
    await file.writeAsBytes(bytes);
    return file;
  }
}
