import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import '../../core/constants/hive_constants.dart';
import 'transaction_type.dart';

class CategoryModel extends Equatable {
  final String id;
  final String name;
  final String icon;
  final TransactionType type;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.type,
  });

  CategoryModel copyWith({
    String? id,
    String? name,
    String? icon,
    TransactionType? type,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'type': type.name,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String,
      type: TransactionType.values.byName(map['type'] as String),
    );
  }

  @override
  List<Object?> get props => [id, name, icon, type];
}

class CategoryModelAdapter extends TypeAdapter<CategoryModel> {
  @override
  final int typeId = HiveConstants.categoryTypeId;

  @override
  CategoryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CategoryModel(
      id: fields[0] as String,
      name: fields[1] as String,
      icon: fields[2] as String,
      type: fields[3] as TransactionType,
    );
  }

  @override
  void write(BinaryWriter writer, CategoryModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.icon)
      ..writeByte(3)
      ..write(obj.type);
  }
}
