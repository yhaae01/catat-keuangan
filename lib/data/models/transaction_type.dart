import 'package:hive/hive.dart';
import '../../core/constants/hive_constants.dart';

enum TransactionType {
  income,
  expense;

  bool get isIncome => this == TransactionType.income;
  bool get isExpense => this == TransactionType.expense;

  String get label {
    switch (this) {
      case TransactionType.income:
        return 'Pemasukan';
      case TransactionType.expense:
        return 'Pengeluaran';
    }
  }
}

class TransactionTypeAdapter extends TypeAdapter<TransactionType> {
  @override
  final int typeId = HiveConstants.transactionTypeTypeId;

  @override
  TransactionType read(BinaryReader reader) {
    final index = reader.readByte();
    if (index >= 0 && index < TransactionType.values.length) {
      return TransactionType.values[index];
    }
    return TransactionType.expense;
  }

  @override
  void write(BinaryWriter writer, TransactionType obj) {
    writer.writeByte(obj.index);
  }
}
