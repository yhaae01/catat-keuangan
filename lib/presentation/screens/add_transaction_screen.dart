import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/utils/currency_helper.dart';
import '../../core/utils/icon_helper.dart';
import '../../data/models/category_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/transaction_type.dart';
import '../../data/services/receipt_scanner_service.dart';
import '../../logic/providers/category_provider.dart';
import '../../logic/providers/transaction_provider.dart';

/// Halaman form transaksi lengkap dengan dua mode input:
/// 1. Input Manual — ketik item, qty, harga satuan
/// 2. Scan Struk (OCR) — ambil gambar dari kamera/galeri, auto-extract items
class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? transactionToEdit;
  final String? initialTitle;
  final double? initialAmount;
  final CategoryModel? initialCategory;
  final TransactionType? initialType;

  const AddTransactionScreen({
    super.key,
    this.transactionToEdit,
    this.initialTitle,
    this.initialAmount,
    this.initialCategory,
    this.initialType,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with SingleTickerProviderStateMixin {
  // Mode selector
  late TabController _tabController;
  int _currentMode = 0; // 0 = Manual, 1 = Scan

  // Form fields
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _noteController;
  late TransactionType _selectedType;
  CategoryModel? _selectedCategory;
  late DateTime _selectedDate;

  // Dynamic item list
  final List<_ItemEntry> _items = [];

  // OCR state
  final ReceiptScannerService _scannerService = ReceiptScannerService();
  bool _isScanning = false;
  String? _scannedImagePath;
  String? _rawOcrText;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentMode = _tabController.index);
      }
    });

    final edit = widget.transactionToEdit;
    _noteController = TextEditingController(
      text: edit?.title ?? widget.initialTitle ?? '',
    );
    _selectedType = edit?.type ?? widget.initialType ?? TransactionType.expense;
    _selectedDate = edit?.date ?? DateTime.now();

    // Inisialisasi items — minimal 1 baris kosong
    if (edit != null) {
      // Jika edit, masukkan satu item dengan data dari transaksi
      _items.add(_ItemEntry(
        nameController: TextEditingController(text: edit.title),
        qtyController: TextEditingController(text: '1'),
        priceController: TextEditingController(
          text: edit.amount.toStringAsFixed(0),
        ),
      ));
    } else if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _items.add(_ItemEntry(
        nameController: TextEditingController(text: widget.initialTitle ?? ''),
        qtyController: TextEditingController(text: '1'),
        priceController: TextEditingController(
          text: widget.initialAmount!.toStringAsFixed(0),
        ),
      ));
    } else {
      _addEmptyItem();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categoryProvider = context.read<CategoryProvider>();
      setState(() {
        if (edit != null) {
          _selectedCategory = categoryProvider.getCategoryById(edit.categoryId);
        } else if (widget.initialCategory != null) {
          _selectedCategory = widget.initialCategory;
        } else {
          final available = categoryProvider.getCategoriesByType(_selectedType);
          _selectedCategory = available.isNotEmpty ? available.first : null;
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _noteController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addEmptyItem() {
    _items.add(_ItemEntry(
      nameController: TextEditingController(),
      qtyController: TextEditingController(text: '1'),
      priceController: TextEditingController(),
    ));
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  double get _totalAmount {
    double total = 0;
    for (final item in _items) {
      final qty = int.tryParse(item.qtyController.text) ?? 1;
      final price = double.tryParse(
            item.priceController.text.replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          0;
      total += qty * price;
    }
    return total;
  }

  void _onTypeChanged(TransactionType newType) {
    setState(() {
      _selectedType = newType;
      final categoryProvider = context.read<CategoryProvider>();
      final available = categoryProvider.getCategoriesByType(newType);
      if (_selectedCategory == null ||
          !available.any((c) => c.id == _selectedCategory!.id)) {
        _selectedCategory = available.isNotEmpty ? available.first : null;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          DateTime.now().hour,
          DateTime.now().minute,
        );
      });
    }
  }

  /// Handle scan struk dari kamera atau galeri
  Future<void> _handleScan(ImageSource source) async {
    final categoryProvider = context.read<CategoryProvider>();
    try {
      setState(() => _isScanning = true);

      final result = await _scannerService.scanAndProcessReceipt(
        source: source,
        categoryProvider: categoryProvider,
        autoCreateCategoryIfNotFound: true,
      );

      if (!mounted) return;
      setState(() => _isScanning = false);

      if (result == null) return; // User membatalkan

      setState(() {
        _scannedImagePath = result.imagePath;
        _rawOcrText = result.rawText;

        // Isi catatan dari nama merchant
        if (result.detectedTitle.isNotEmpty) {
          _noteController.text = result.detectedTitle;
        }

        // Isi kategori
        _selectedCategory = result.category;

        // Populate items dari OCR
        if (result.detectedItems.isNotEmpty) {
          // Hapus item kosong yang ada
          for (final item in _items) {
            item.dispose();
          }
          _items.clear();

          for (final detected in result.detectedItems) {
            _items.add(_ItemEntry(
              nameController: TextEditingController(text: detected.name),
              qtyController: TextEditingController(
                text: detected.qty.toString(),
              ),
              priceController: TextEditingController(
                text: detected.unitPrice.toStringAsFixed(0),
              ),
            ));
          }
        } else if (result.totalAmount > 0) {
          // Jika tidak ada item terdeteksi, buat 1 item dengan total
          for (final item in _items) {
            item.dispose();
          }
          _items.clear();
          _items.add(_ItemEntry(
            nameController: TextEditingController(
              text: result.detectedTitle,
            ),
            qtyController: TextEditingController(text: '1'),
            priceController: TextEditingController(
              text: result.totalAmount.toStringAsFixed(0),
            ),
          ));
        }
      });

      if (result.isNewCategoryCreated && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kategori "${result.category.name}" otomatis dibuat dari analisis struk!',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
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

  Future<void> _saveTransaction() async {
    final total = _totalAmount;

    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Total nominal harus lebih dari 0!')),
      );
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kategori transaksi terlebih dahulu!'),
        ),
      );
      return;
    }

    // Build title dari item list atau dari catatan
    String title = _noteController.text.trim();
    if (title.isEmpty) {
      // Ambil nama item pertama yang tidak kosong
      final firstItem = _items
          .where((i) => i.nameController.text.trim().isNotEmpty)
          .firstOrNull;
      title = firstItem?.nameController.text.trim() ?? 'Transaksi';
    }

    final txProvider = context.read<TransactionProvider>();
    final isEditing = widget.transactionToEdit != null;

    bool ok;
    if (isEditing) {
      final updated = widget.transactionToEdit!.copyWith(
        title: title,
        amount: total,
        date: _selectedDate,
        type: _selectedType,
        categoryId: _selectedCategory!.id,
      );
      ok = await txProvider.updateTransaction(updated);
    } else {
      ok = await txProvider.addTransaction(
        title: title,
        amount: total,
        date: _selectedDate,
        type: _selectedType,
        categoryId: _selectedCategory!.id,
      );
    }

    if (mounted && ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Transaksi berhasil diubah!'
                : 'Transaksi berhasil disimpan!',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.transactionToEdit != null;
    final categoryProvider = context.watch<CategoryProvider>();
    final availableCategories =
        categoryProvider.getCategoriesByType(_selectedType);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Transaksi' : 'Catat Transaksi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ─── Mode Tabs (Manual / Scan) ───
          if (!isEditing)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: isDark
                    ? Colors.grey.shade400
                    : Colors.grey.shade700,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_note_rounded, size: 18),
                        SizedBox(width: 6),
                        Text('Input Manual'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.document_scanner_rounded, size: 18),
                        SizedBox(width: 6),
                        Text('Scan Struk'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // ─── Body ───
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Scan Area (hanya di tab Scan) ───
                    if (_currentMode == 1 && !isEditing) ...[
                      _buildScanArea(primary, isDark),
                      const SizedBox(height: 16),
                    ],

                    // ─── Type Selector ───
                    _buildTypeSelector(primary),
                    const SizedBox(height: 16),

                    // ─── Catatan / Keterangan ───
                    _buildNoteField(isDark),
                    const SizedBox(height: 16),

                    // ─── Item List Header ───
                    _buildItemListHeader(primary, isDark),
                    const SizedBox(height: 10),

                    // ─── Item List ───
                    ..._buildItemCards(primary, isDark),

                    // ─── Tombol Tambah Item ───
                    _buildAddItemButton(primary),
                    const SizedBox(height: 16),

                    // ─── Kategori & Tanggal ───
                    _buildCategorySelector(
                      availableCategories,
                      primary,
                      isDark,
                    ),
                    const SizedBox(height: 14),
                    _buildDatePicker(isDark),
                    const SizedBox(height: 24),

                    // ─── Total Amount ───
                    _buildTotalCard(primary, isDark),
                    const SizedBox(height: 20),

                    // ─── Tombol Simpan ───
                    _buildSaveButton(primary, isEditing),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BUILD WIDGETS
  // ===========================================================================

  Widget _buildScanArea(Color primary, bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Preview gambar struk
          if (_scannedImagePath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Image.file(
                    File(_scannedImagePath!),
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: InkWell(
                      onTap: () => setState(() {
                        _scannedImagePath = null;
                        _rawOcrText = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  // Badge: jumlah item terdeteksi
                  if (_items.isNotEmpty)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_items.length} item terdeteksi',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Tampilkan raw text OCR (collapsible)
            if (_rawOcrText != null && _rawOcrText!.isNotEmpty)
              _buildRawTextPreview(isDark),
            const SizedBox(height: 10),
            // Tombol re-scan
            OutlinedButton.icon(
              onPressed: _isScanning ? null : () => _showScanOptions(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Scan Ulang'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: BorderSide(color: primary.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ] else ...[
            // Tampilan awal — belum ada scan
            if (_isScanning)
              SizedBox(
                height: 160,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Memindai struk dengan OCR...',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      size: 40,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Scan Struk Belanja',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ambil foto struk atau pilih dari galeri.\nItem belanjaan akan diekstrak otomatis.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _buildScanOptionButton(
                          icon: Icons.camera_alt_rounded,
                          label: 'Kamera',
                          color: primary,
                          onTap: () => _handleScan(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildScanOptionButton(
                          icon: Icons.photo_library_rounded,
                          label: 'Galeri',
                          color: const Color(0xFF7C3AED),
                          onTap: () => _handleScan(ImageSource.gallery),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildScanOptionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRawTextPreview(bool isDark) {
    return ExpansionTile(
      dense: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
      collapsedBackgroundColor:
          isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
      title: const Text(
        'Lihat Teks OCR',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      leading: const Icon(Icons.text_snippet_rounded, size: 16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
            ),
          ),
          child: SelectableText(
            _rawOcrText ?? '',
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  void _showScanOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final primary = Theme.of(context).colorScheme.primary;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pilih Sumber Gambar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildScanOptionButton(
                        icon: Icons.camera_alt_rounded,
                        label: 'Kamera',
                        color: primary,
                        onTap: () {
                          Navigator.pop(ctx);
                          _handleScan(ImageSource.camera);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildScanOptionButton(
                        icon: Icons.photo_library_rounded,
                        label: 'Galeri',
                        color: const Color(0xFF7C3AED),
                        onTap: () {
                          Navigator.pop(ctx);
                          _handleScan(ImageSource.gallery);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypeSelector(Color primary) {
    return SegmentedButton<TransactionType>(
      segments: [
        const ButtonSegment(
          value: TransactionType.expense,
          label: Text('Pengeluaran'),
          icon: Icon(Icons.arrow_upward_rounded, color: Colors.red),
        ),
        ButtonSegment(
          value: TransactionType.income,
          label: const Text('Pemasukan'),
          icon: Icon(Icons.arrow_downward_rounded, color: primary),
        ),
      ],
      selected: {_selectedType},
      onSelectionChanged: (set) => _onTypeChanged(set.first),
    );
  }

  Widget _buildNoteField(bool isDark) {
    return TextField(
      controller: _noteController,
      decoration: InputDecoration(
        labelText: 'Catatan / Keterangan (Opsional)',
        hintText: 'Contoh: Belanja di Alfamart, Kopi pagi, dll.',
        prefixIcon: const Icon(Icons.notes_rounded),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
      ),
    );
  }

  Widget _buildItemListHeader(Color primary, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.list_alt_rounded, color: primary, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          'Daftar Item',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${_items.length} item',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildItemCards(Color primary, bool isDark) {
    return List.generate(_items.length, (index) {
      final item = _items[index];
      final qty = int.tryParse(item.qtyController.text) ?? 1;
      final price = double.tryParse(
            item.priceController.text.replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          0;
      final subtotal = qty * price;

      return Container(
        key: ValueKey(item.hashCode),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: item number + delete
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Item ${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
                if (_items.length > 1)
                  InkWell(
                    onTap: () => _removeItem(index),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red.shade400,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Nama Item
            TextField(
              controller: item.nameController,
              decoration: InputDecoration(
                labelText: 'Nama Item',
                hintText: 'Contoh: Mie Goreng, Kopi, dll.',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),

            // Qty & Harga Satuan
            Row(
              children: [
                // Qty
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: item.qtyController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Qty',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF0F172A)
                          : Colors.grey.shade50,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('×', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                // Harga Satuan
                Expanded(
                  child: TextField(
                    controller: item.priceController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Harga Satuan',
                      prefixText: 'Rp ',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF0F172A)
                          : Colors.grey.shade50,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            // Subtotal
            if (subtotal > 0) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Subtotal: ${CurrencyHelper.formatRupiah(subtotal)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildAddItemButton(Color primary) {
    return Center(
      child: TextButton.icon(
        onPressed: () {
          setState(() => _addEmptyItem());
        },
        icon: Icon(Icons.add_circle_outline_rounded, color: primary, size: 20),
        label: Text(
          'Tambah Item',
          style: TextStyle(
            color: primary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: primary.withValues(alpha: 0.3),
              style: BorderStyle.solid,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector(
    List<CategoryModel> availableCategories,
    Color primary,
    bool isDark,
  ) {
    return DropdownButtonFormField<CategoryModel>(
      initialValue: (_selectedCategory != null &&
              availableCategories.any((c) => c.id == _selectedCategory!.id))
          ? _selectedCategory
          : (availableCategories.isNotEmpty ? availableCategories.first : null),
      decoration: InputDecoration(
        labelText: 'Kategori',
        prefixIcon: const Icon(Icons.category_outlined),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
      ),
      items: availableCategories.map((cat) {
        return DropdownMenuItem<CategoryModel>(
          value: cat,
          child: Row(
            children: [
              Icon(
                CategoryIconHelper.getIcon(cat.icon),
                size: 20,
                color: _selectedType.isIncome ? primary : Colors.red,
              ),
              const SizedBox(width: 10),
              Text(cat.name),
            ],
          ),
        );
      }).toList(),
      onChanged: (cat) {
        setState(() => _selectedCategory = cat);
      },
    );
  }

  Widget _buildDatePicker(bool isDark) {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Tanggal Transaksi',
          prefixIcon: const Icon(Icons.calendar_today_rounded),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
        ),
        child: Text(
          CurrencyHelper.formatDate(_selectedDate),
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildTotalCard(Color primary, bool isDark) {
    final total = _totalAmount;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _selectedType.isExpense
              ? [const Color(0xFFBE123C), const Color(0xFFE11D48)]
              : [primary, primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (_selectedType.isExpense ? Colors.red : primary)
                .withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Total ${_selectedType.label}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            CurrencyHelper.formatRupiah(total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          if (_items.length > 1) ...[
            const SizedBox(height: 4),
            Text(
              '${_items.length} item',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaveButton(Color primary, bool isEditing) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        icon: Icon(isEditing ? Icons.check_rounded : Icons.save_rounded),
        label: Text(
          isEditing ? 'Simpan Perubahan' : 'Simpan Transaksi',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedType.isIncome
              ? primary
              : const Color(0xFFBE123C),
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: (_selectedType.isIncome ? primary : Colors.red)
              .withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: _saveTransaction,
      ),
    );
  }
}

// =============================================================================
// Helper: menyimpan state controller untuk tiap item di list
// =============================================================================
class _ItemEntry {
  final TextEditingController nameController;
  final TextEditingController qtyController;
  final TextEditingController priceController;

  _ItemEntry({
    required this.nameController,
    required this.qtyController,
    required this.priceController,
  });

  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    priceController.dispose();
  }
}
