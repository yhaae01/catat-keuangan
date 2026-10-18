import '../models/category_model.dart';
import '../models/receipt_item_model.dart';

/// Hasil pemindaian struk yang diperkaya dengan daftar item belanjaan
class ReceiptScanResult {
  final String rawText;
  final String detectedTitle;
  final double totalAmount;
  final CategoryModel category;
  final bool isNewCategoryCreated;
  final DateTime? detectedDate;
  final List<ReceiptItem> detectedItems;
  final String? imagePath;

  const ReceiptScanResult({
    required this.rawText,
    required this.detectedTitle,
    required this.totalAmount,
    required this.category,
    this.isNewCategoryCreated = false,
    this.detectedDate,
    this.detectedItems = const [],
    this.imagePath,
  });

  @override
  String toString() {
    return 'ReceiptScanResult(title: $detectedTitle, amount: $totalAmount, '
        'category: ${category.name}, items: ${detectedItems.length}, '
        'isNewCategory: $isNewCategoryCreated)';
  }
}
