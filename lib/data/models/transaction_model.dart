import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import '../../core/constants/hive_constants.dart';
import 'transaction_type.dart';

/// Merepresentasikan satu baris rincian item di dalam sebuah transaksi.
class TransactionItemDetail {
  final String name;
  final int qty;
  final double price;

  const TransactionItemDetail({
    required this.name,
    required this.qty,
    required this.price,
  });

  /// Subtotal item ini (qty × price)
  double get subtotal => qty * price;

  Map<String, dynamic> toMap() => {
    'name': name,
    'qty': qty,
    'price': price,
  };

  factory TransactionItemDetail.fromMap(Map<dynamic, dynamic> map) {
    return TransactionItemDetail(
      name: (map['name'] as String?) ?? '',
      qty: (map['qty'] as num?)?.toInt() ?? 1,
      price: (map['price'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  String toString() => 'TransactionItemDetail(name: $name, qty: $qty, price: $price)';
}

class TransactionModel extends Equatable {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final String categoryId;

  /// Rincian sub-items (opsional, kosong = transaksi tunggal tanpa detail item)
  final List<TransactionItemDetail> items;

  /// Potongan diskon (opsional, hanya dipakai untuk pengeluaran).
  /// Nilai `amount` sudah merupakan nominal bersih setelah diskon.
  final double discount;

  const TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    required this.categoryId,
    this.items = const [],
    this.discount = 0,
  });

  bool get hasItems => items.isNotEmpty;

  bool get hasDiscount => discount > 0;

  /// Total kotor sebelum diskon
  double get grossAmount => amount + discount;

  TransactionModel copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    TransactionType? type,
    String? categoryId,
    List<TransactionItemDetail>? items,
    double? discount,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      items: items ?? this.items,
      discount: discount ?? this.discount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type.name,
      'categoryId': categoryId,
      'items': items.map((e) => e.toMap()).toList(),
      'discount': discount,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'];
    final List<TransactionItemDetail> parsedItems = rawItems is List
        ? rawItems
              .map((e) => TransactionItemDetail.fromMap(e as Map))
              .toList()
        : [];
    return TransactionModel(
      id: map['id'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      type: TransactionType.values.byName(map['type'] as String),
      categoryId: map['categoryId'] as String,
      items: parsedItems,
      discount: (map['discount'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    amount,
    date,
    type,
    categoryId,
    items,
    discount,
  ];
}

class TransactionModelAdapter extends TypeAdapter<TransactionModel> {
  @override
  final int typeId = HiveConstants.transactionTypeId;

  @override
  TransactionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    // Field index 6 = items (List<Map>) — opsional untuk backward-compat
    final rawItems = fields[6];
    final List<TransactionItemDetail> items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((e) => TransactionItemDetail.fromMap(e))
              .toList()
        : [];

    return TransactionModel(
      id: fields[0] as String,
      title: fields[1] as String,
      amount: (fields[2] as num).toDouble(),
      date: fields[3] as DateTime,
      type: fields[4] as TransactionType,
      categoryId: fields[5] as String,
      items: items,
      discount: (fields[7] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, TransactionModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.categoryId)
      ..writeByte(6)
      ..write(obj.items.map((e) => e.toMap()).toList())
      ..writeByte(7)
      ..write(obj.discount);
  }
}

