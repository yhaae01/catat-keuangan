import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/utils/report_export_service.dart';
import 'logic/providers/transaction_provider.dart';
import 'theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final transactionProvider = context.watch<TransactionProvider>();
    final isDark = themeProvider.isDarkMode;
    final primary = themeProvider.primaryColor;

    Future<void> exportCsv() async {
      final file = await ReportExportService.exportCsvToFile(
        transactionProvider.filteredTransactions,
        dateRange: transactionProvider.selectedDateRange,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('CSV disimpan: ${file.path}')));
    }

    Future<void> exportPdf() async {
      final file = await ReportExportService.exportPdfToFile(
        transactionProvider.filteredTransactions,
        dateRange: transactionProvider.selectedDateRange,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('PDF disimpan: ${file.path}')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Section: Mode Tampilan
          const Text(
            'Tampilan',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.amber.withValues(alpha: 0.15)
                        : primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: isDark ? Colors.amber : primary,
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Mode Gelap (Night Mode)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: Text(
                  isDark
                      ? 'Tema gelap aktif, nyaman untuk mata di malam hari'
                      : 'Tema terang aktif',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                value: isDark,
                onChanged: (value) {
                  themeProvider.toggleTheme(value);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section: Warna Aksen Tema
          const Text(
            'Warna Tema',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pilih Palet Warna Aksen:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: themeProvider.availableColors.entries.map((
                      entry,
                    ) {
                      final name = entry.key;
                      final color = entry.value;
                      final isSelected =
                          themeProvider.selectedColorName == name;

                      return InkWell(
                        onTap: () {
                          themeProvider.setThemeColor(name);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Eksport Data',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.table_rows_rounded,
                      color: Colors.green,
                    ),
                    title: const Text('Ekspor CSV'),
                    subtitle: Text(
                      transactionProvider.selectedDateRange == null
                          ? 'Semua data saat ini'
                          : 'Periode aktif: ${transactionProvider.activeRangeLabel}',
                    ),
                    onTap: exportCsv,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Colors.red,
                    ),
                    title: const Text('Ekspor PDF'),
                    subtitle: Text(
                      transactionProvider.selectedDateRange == null
                          ? 'Semua data saat ini'
                          : 'Periode aktif: ${transactionProvider.activeRangeLabel}',
                    ),
                    onTap: exportPdf,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section: Info Aplikasi
          const Text(
            'Tentang Aplikasi',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      color: primary,
                      size: 22,
                    ),
                  ),
                  title: const Text(
                    'Catat Keuangan',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Versi 1.0.0+1 • Offline Local Database (Hive)',
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.document_scanner_rounded,
                      color: Colors.blue,
                      size: 22,
                    ),
                  ),
                  title: const Text(
                    'AI OCR Scanner',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: const Text('Google ML Kit Text Recognition Engine'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
