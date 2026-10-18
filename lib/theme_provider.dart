import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/constants/hive_constants.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _isDarkModeKey = 'is_dark_mode';
  static const String _themeColorKey = 'theme_color';

  static const Map<String, Color> themeColors = {
    'Emerald': Color(0xFF0F766E),
    'Blue': Color(0xFF2563EB),
    'Purple': Color(0xFF7C3AED),
    'Amber': Color(0xFFD97706),
    'Pink': Color(0xFFEC4899), // Pink spesial buat istri 💕
  };

  bool _isDarkMode = false;
  String _selectedColorName = 'Emerald';
  late Box _settingsBox;

  ThemeProvider() {
    _initPreferences();
  }

  bool get isDarkMode => _isDarkMode;
  String get selectedColorName => _selectedColorName;
  Color get primaryColor =>
      themeColors[_selectedColorName] ?? const Color(0xFF0F766E);

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Map<String, Color> get availableColors => themeColors;

  /// Memuat preferensi tema dari Hive
  void _initPreferences() {
    if (Hive.isBoxOpen(HiveConstants.settingsBox)) {
      _settingsBox = Hive.box(HiveConstants.settingsBox);
    } else {
      _settingsBox = Hive.box(HiveConstants.settingsBox);
    }
    _isDarkMode = _settingsBox.get(_isDarkModeKey, defaultValue: false) as bool;
    _selectedColorName =
        _settingsBox.get(_themeColorKey, defaultValue: 'Emerald') as String;
    if (!themeColors.containsKey(_selectedColorName)) {
      _selectedColorName = 'Emerald';
    }
  }

  /// Mengubah mode terang/gelap (Light / Dark Mode)
  Future<void> toggleTheme(bool isDark) async {
    _isDarkMode = isDark;
    await _settingsBox.put(_isDarkModeKey, isDark);
    notifyListeners();
  }

  /// Mengubah warna aksen tema (Emerald, Blue, Purple, Amber, Pink)
  Future<void> setThemeColor(String colorName) async {
    if (themeColors.containsKey(colorName)) {
      _selectedColorName = colorName;
      await _settingsBox.put(_themeColorKey, colorName);
      notifyListeners();
    }
  }

  /// ThemeData untuk Light Mode
  ThemeData get lightTheme {
    final seed = primaryColor;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        primary: seed,
        brightness: Brightness.light,
        surface: Colors.white,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: seed,
        foregroundColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF8FAFC),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        titleTextStyle: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }

  /// ThemeData untuk Dark Mode (Night Mode)
  ThemeData get darkTheme {
    final seed = primaryColor;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A), // Dark slate
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        primary: seed,
        brightness: Brightness.dark,
        surface: const Color(0xFF1E293B),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: seed,
        foregroundColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
      ),
    );
  }
}
