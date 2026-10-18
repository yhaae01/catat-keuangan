/// Model untuk satu item belanjaan pada struk / form transaksi
class ReceiptItem {
  String name;
  int qty;
  double unitPrice;

  ReceiptItem({
    required this.name,
    this.qty = 1,
    required this.unitPrice,
  });

  double get subtotal => qty * unitPrice;

  ReceiptItem copyWith({
    String? name,
    int? qty,
    double? unitPrice,
  }) {
    return ReceiptItem(
      name: name ?? this.name,
      qty: qty ?? this.qty,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }

  @override
  String toString() => 'ReceiptItem($name x$qty @ $unitPrice = $subtotal)';
}
