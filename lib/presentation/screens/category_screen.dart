import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/icon_helper.dart';
import '../../data/models/category_model.dart';
import '../../data/models/transaction_type.dart';
import '../../logic/providers/category_provider.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCategoryFormDialog(BuildContext context, {CategoryModel? categoryToEdit}) {
    final isEditing = categoryToEdit != null;
    final nameController =
        TextEditingController(text: categoryToEdit?.name ?? '');
    var selectedType = categoryToEdit?.type ??
        (_tabController.index == 0
            ? TransactionType.expense
            : TransactionType.income);
    var selectedIcon = categoryToEdit?.icon ??
        (selectedType == TransactionType.expense ? 'fastfood' : 'account_balance_wallet');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? 'Edit Kategori' : 'Tambah Kategori',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Type Selector (Pemasukan / Pengeluaran)
                    SegmentedButton<TransactionType>(
                      segments: const [
                        ButtonSegment(
                          value: TransactionType.expense,
                          label: Text('Pengeluaran'),
                          icon: Icon(Icons.arrow_downward_rounded, color: Colors.red),
                        ),
                        ButtonSegment(
                          value: TransactionType.income,
                          label: Text('Pemasukan'),
                          icon: Icon(Icons.arrow_upward_rounded, color: Colors.green),
                        ),
                      ],
                      selected: {selectedType},
                      onSelectionChanged: (newSelection) {
                        setSheetState(() {
                          selectedType = newSelection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Input Nama Kategori
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Nama Kategori',
                        hintText: 'Contoh: Makanan, Gaji, dll.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(CategoryIconHelper.getIcon(selectedIcon)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Icon Picker
                    const Text(
                      'Pilih Ikon:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: CategoryIconHelper.allIconKeys.length,
                        itemBuilder: (context, index) {
                          final iconKey = CategoryIconHelper.allIconKeys[index];
                          final isSelected = iconKey == selectedIcon;

                          return InkWell(
                            onTap: () {
                              setSheetState(() {
                                selectedIcon = iconKey;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Icon(
                                CategoryIconHelper.getIcon(iconKey),
                                color: isSelected ? Colors.white : Colors.black87,
                                size: 22,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Simpan Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Nama kategori tidak boleh kosong!'),
                              ),
                            );
                            return;
                          }

                          final provider =
                              Provider.of<CategoryProvider>(context, listen: false);

                          if (isEditing) {
                            final updated = categoryToEdit.copyWith(
                              name: name,
                              icon: selectedIcon,
                              type: selectedType,
                            );
                            final success = await provider.updateCategory(updated);
                            if (context.mounted && success) {
                              Navigator.pop(sheetContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Kategori berhasil diperbarui!')),
                              );
                            }
                          } else {
                            final success = await provider.addCategory(
                              name: name,
                              icon: selectedIcon,
                              type: selectedType,
                            );
                            if (context.mounted && success) {
                              Navigator.pop(sheetContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Kategori baru berhasil ditambahkan!')),
                              );
                            }
                          }
                        },
                        child: Text(
                          isEditing ? 'Simpan Perubahan' : 'Tambah Kategori',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, CategoryModel category) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Hapus Kategori?'),
          content: Text('Apakah Anda yakin ingin menghapus kategori "${category.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final provider =
                    Provider.of<CategoryProvider>(context, listen: false);
                await provider.deleteCategory(category.id);
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Kategori "${category.name}" berhasil dihapus.')),
                  );
                }
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Kategori'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pengeluaran', icon: Icon(Icons.arrow_downward_rounded)),
            Tab(text: 'Pemasukan', icon: Icon(Icons.arrow_upward_rounded)),
          ],
        ),
      ),
      body: Consumer<CategoryProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildCategoryList(context, provider.expenseCategories, Colors.red.shade400),
              _buildCategoryList(context, provider.incomeCategories, Colors.green.shade500),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryFormDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Kategori Baru'),
      ),
    );
  }

  Widget _buildCategoryList(
    BuildContext context,
    List<CategoryModel> categories,
    Color accentColor,
  ) {
    if (categories.isEmpty) {
      return const Center(
        child: Text('Belum ada kategori.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: categories.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final category = categories[index];
        return Card(
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: accentColor.withValues(alpha: 0.15),
              child: Icon(
                CategoryIconHelper.getIcon(category.icon),
                color: accentColor,
              ),
            ),
            title: Text(
              category.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              category.type.label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _showCategoryFormDialog(
                    context,
                    categoryToEdit: category,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  onPressed: () => _confirmDelete(context, category),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
