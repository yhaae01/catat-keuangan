import '../models/category_model.dart';

class ReceiptScanResult {
  final String rawText;
  final String detectedTitle;
  final double totalAmount;
  final CategoryModel category;
  final bool isNewCategoryCreated;
  final DateTime? detectedDate;

  const ReceiptScanResult({
    required this.rawText,
    required this.detectedTitle,
    required this.totalAmount,
    required this.category,
    this.isNewCategoryCreated = false,
    this.detectedDate,
  });

  @override
  String toString() {
    return 'ReceiptScanResult(title: $detectedTitle, amount: $totalAmount, category: ${category.name}, isNewCategory: $isNewCategoryCreated)';
  }
}
