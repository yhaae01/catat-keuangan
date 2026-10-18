import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/currency_helper.dart';
import '../../core/utils/icon_helper.dart';
import '../../data/models/category_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/transaction_type.dart';
import '../../logic/providers/category_provider.dart';
import '../../logic/providers/transaction_provider.dart';

class TransactionFormSheet extends StatefulWidget {
  final TransactionModel? transactionToEdit;
  final String? initialTitle;
  final double? initialAmount;
  final CategoryModel? initialCategory;
  final TransactionType? initialType;

  const TransactionFormSheet({
    super.key,
    this.transactionToEdit,
    this.initialTitle,
    this.initialAmount,
    this.initialCategory,
    this.initialType,
  });

  @override
  State<TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<TransactionFormSheet> {
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TransactionType _selectedType;
  CategoryModel? _selectedCategory;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final edit = widget.transactionToEdit;

    _titleController = TextEditingController(
      text: edit?.title ?? widget.initialTitle ?? '',
    );

    final initialAmt = edit?.amount ?? widget.initialAmount;
    _amountController = TextEditingController(
      text: initialAmt != null && initialAmt > 0
          ? initialAmt.toStringAsFixed(0)
          : '',
    );

    _selectedType = edit?.type ?? widget.initialType ?? TransactionType.expense;
    _selectedDate = edit?.date ?? DateTime.now();

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
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onTypeChanged(TransactionType newType) {
    setState(() {
      _selectedType = newType;
      final categoryProvider = context.read<CategoryProvider>();
      final available = categoryProvider.getCategoriesByType(newType);
      if (!_selectedCategoryMatch(available)) {
        _selectedCategory = available.isNotEmpty ? available.first : null;
      }
    });
  }

  bool _selectedCategoryMatch(List<CategoryModel> available) {
    if (_selectedCategory == null) return false;
    return available.any((c) => c.id == _selectedCategory!.id);
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
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final availableCategories =
        categoryProvider.getCategoriesByType(_selectedType);
    final isEditing = widget.transactionToEdit != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sheet Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing ? 'Edit Transaksi' : 'Catat Transaksi Baru',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Segmented Type Selector (Pengeluaran / Pemasukan)
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Pengeluaran'),
                  icon: Icon(Icons.arrow_upward_rounded, color: Colors.red),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Pemasukan'),
                  icon: Icon(Icons.arrow_downward_rounded, color: Colors.teal),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (set) => _onTypeChanged(set.first),
            ),
            const SizedBox(height: 16),

            // Nominal Input
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                labelText: 'Nominal',
                prefixText: 'Rp ',
                prefixStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                hintText: '0',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Judul / Keterangan Transaksi
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Judul / Keterangan',
                hintText: 'Contoh: Belanja Bulanan, Kopi, Gaji, dll.',
                prefixIcon: const Icon(Icons.description_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Kategori Dropdown Selector
            DropdownButtonFormField<CategoryModel>(
              initialValue: _selectedCategoryMatch(availableCategories)
                  ? _selectedCategory
                  : (availableCategories.isNotEmpty ? availableCategories.first : null),
              decoration: InputDecoration(
                labelText: 'Kategori',
                prefixIcon: const Icon(Icons.category_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: availableCategories.map((cat) {
                return DropdownMenuItem<CategoryModel>(
                  value: cat,
                  child: Row(
                    children: [
                      Icon(
                        CategoryIconHelper.getIcon(cat.icon),
                        size: 20,
                        color: _selectedType.isIncome ? Colors.teal : Colors.red,
                      ),
                      const SizedBox(width: 10),
                      Text(cat.name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (cat) {
                setState(() {
                  _selectedCategory = cat;
                });
              },
            ),
            const SizedBox(height: 14),

            // Tanggal Transaksi Picker
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Tanggal & Waktu',
                  prefixIcon: const Icon(Icons.calendar_today_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  CurrencyHelper.formatDate(_selectedDate),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tombol Simpan
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedType.isIncome
                      ? const Color(0xFF0F766E)
                      : const Color(0xFFBE123C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  final title = _titleController.text.trim();
                  final amount = double.tryParse(
                    _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
                  );

                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Keterangan transaksi tidak boleh kosong!')),
                    );
                    return;
                  }

                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nominal harus lebih dari 0!')),
                    );
                    return;
                  }

                  if (_selectedCategory == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pilih kategori transaksi terlebih dahulu!')),
                    );
                    return;
                  }

                  final txProvider = context.read<TransactionProvider>();

                  if (isEditing) {
                    final updated = widget.transactionToEdit!.copyWith(
                      title: title,
                      amount: amount,
                      date: _selectedDate,
                      type: _selectedType,
                      categoryId: _selectedCategory!.id,
                    );
                    final ok = await txProvider.updateTransaction(updated);
                    if (context.mounted && ok) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transaksi berhasil diubah!')),
                      );
                    }
                  } else {
                    final ok = await txProvider.addTransaction(
                      title: title,
                      amount: amount,
                      date: _selectedDate,
                      type: _selectedType,
                      categoryId: _selectedCategory!.id,
                    );
                    if (context.mounted && ok) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transaksi berhasil disimpan!')),
                      );
                    }
                  }
                },
                child: Text(
                  isEditing ? 'Simpan Perubahan' : 'Simpan Transaksi',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
