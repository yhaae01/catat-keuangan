import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:catat_keuangan/data/models/category_model.dart';
import 'package:catat_keuangan/data/models/transaction_model.dart';
import 'package:catat_keuangan/data/models/transaction_type.dart';
import 'package:catat_keuangan/main.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_widget_test_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TransactionTypeAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(CategoryModelAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(TransactionModelAdapter());

    await Hive.openBox<CategoryModel>('categories_box');
    await Hive.openBox<TransactionModel>('transactions_box');
    await Hive.openBox('settings_box');
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('DashboardScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Dompet Saya'), findsOneWidget);
    expect(find.text('Catat Keuangan'), findsOneWidget);
    expect(find.text('Total Saldo'), findsOneWidget);
    expect(find.text('Catat / Scan'), findsOneWidget);
  });
}
