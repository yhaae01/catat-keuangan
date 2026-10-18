import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/utils/currency_helper.dart';
import '../../data/models/category_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/services/receipt_scanner_service.dart';
import '../../logic/providers/category_provider.dart';
import '../../logic/providers/transaction_provider.dart';
import '../widgets/balance_card.dart';
import '../widgets/transaction_form_sheet.dart';
import '../widgets/transaction_item.dart';
import 'category_screen.dart';
import '../../settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ReceiptScannerService _scannerService = ReceiptScannerService();
  bool _isScanning = false;

  /// Membuka form transaksi manual atau prefilled
  void _openTransactionForm({
    TransactionModel? transactionToEdit,
    String? initialTitle,
    double? initialAmount,
    CategoryModel? initialCategory,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => TransactionFormSheet(
        transactionToEdit: transactionToEdit,
        initialTitle: initialTitle,
        initialAmount: initialAmount,
        initialCategory: initialCategory,
      ),
    );
  }

  /// Proses pemindaian struk via Kamera atau Galeri
  Future<void> _handleScanReceipt(ImageSource source) async {
    final categoryProvider = context.read<CategoryProvider>();

    try {
      setState(() => _isScanning = true);

      // Tampilkan indikator proses
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 14),
              Text('Memindai struk dengan OCR...'),
            ],
          ),
          duration: Duration(seconds: 4),
        ),
      );

      final result = await _scannerService.scanAndProcessReceipt(
        source: source,
        categoryProvider: categoryProvider,
        autoCreateCategoryIfNotFound: true,
      );

      if (!mounted) return;
      setState(() => _isScanning = false);

      if (result == null) return; // User membatalkan pengambilan gambar

      if (result.isNewCategoryCreated) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kategori "${result.category.name}" otomatis dibuat dari analisis struk!'),
            backgroundColor: Colors.teal.shade700,
          ),
        );
      }

      // Buka bottom sheet dengan data yang sudah terisi otomatis dari OCR
      _openTransactionForm(
        initialTitle: result.detectedTitle,
        initialAmount: result.totalAmount,
        initialCategory: result.category,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membaca struk: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  /// Modal pilihan aksi FAB (Manual, Kamera, Galeri)
  void _showAddOptionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tambah Catatan Keuangan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pilih cara pencatatan transaksi yang Anda inginkan:',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),

                // Opsi 1: Input Manual
                _buildActionTile(
                  icon: Icons.edit_note_rounded,
                  color: const Color(0xFF0F766E),
                  title: 'Input Transaksi Manual',
                  subtitle: 'Ketik nominal, keterangan, dan pilih kategori',
                  onTap: () {
                    Navigator.pop(ctx);
                    _openTransactionForm();
                  },
                ),
                const SizedBox(height: 10),

                // Opsi 2: Scan Kamera
                _buildActionTile(
                  icon: Icons.camera_alt_rounded,
                  color: const Color(0xFF2563EB),
                  title: 'Scan Struk via Kamera',
                  subtitle: 'Ambil foto struk fisik untuk auto-ekstraksi OCR',
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleScanReceipt(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 10),

                // Opsi 3: Scan Galeri
                _buildActionTile(
                  icon: Icons.photo_library_rounded,
                  color: const Color(0xFF7C3AED),
                  title: 'Pilih Struk dari Galeri',
                  subtitle: 'Gunakan foto/struk digital yang tersimpan di galeri',
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleScanReceipt(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTransaction(BuildContext context, TransactionModel tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi?'),
        content: Text('Yakin ingin menghapus transaksi "${tx.title}" sebesar ${CurrencyHelper.formatRupiah(tx.amount)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<TransactionProvider>().deleteTransaction(tx.id);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final catProvider = context.watch<CategoryProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dompet Saya',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Text(
              'Catat Keuangan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          // Tombol Kelola Kategori
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color ?? Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: IconButton(
              tooltip: 'Kelola Kategori',
              icon: Icon(Icons.category_rounded, color: Theme.of(context).colorScheme.primary),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoryScreen()),
                );
              },
            ),
          ),
          // Tombol Pengaturan
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color ?? Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: IconButton(
              tooltip: 'Pengaturan',
              icon: Icon(Icons.settings_rounded, color: Theme.of(context).colorScheme.primary),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          txProvider.isLoading || catProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async {
                    txProvider.loadTransactions();
                    catProvider.loadCategories();
                  },
                  child: CustomScrollView(
                    slivers: [
                      if (_isScanning)
                        const SliverToBoxAdapter(
                          child: LinearProgressIndicator(
                            color: Color(0xFF0F766E),
                            backgroundColor: Color(0xFFCCFBF1),
                          ),
                        ),
                  // Balance Card Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: BalanceCard(
                        balance: txProvider.totalBalance,
                        income: txProvider.totalIncome,
                        expense: txProvider.totalExpense,
                      ),
                    ),
                  ),

                  // Header Riwayat Transaksi
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Transaksi Terakhir',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${txProvider.transactions.length} Transaksi',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Daftar Transaksi atau Tampilan Kosong
                  if (txProvider.transactions.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F766E).withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                size: 54,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Belum ada transaksi',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tekan tombol + di bawah untuk mencatat\nmanual atau scan struk belanja Anda',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final tx = txProvider.transactions[index];
                            final category = catProvider.getCategoryById(tx.categoryId);
                            return TransactionItem(
                              transaction: tx,
                              category: category,
                              onTap: () => _openTransactionForm(transactionToEdit: tx),
                              onDelete: () => _confirmDeleteTransaction(context, tx),
                            );
                          },
                          childCount: txProvider.transactions.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 80),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: _showAddOptionsModal,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Catat / Scan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
