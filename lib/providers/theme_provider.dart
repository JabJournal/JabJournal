import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const _keyDark = 'dark_mode';
  static const _keyOled = 'oled_mode';
  static const _keySystem = 'use_system';
  static const _seedColor = Colors.blue;

  bool _useSystem = true; // follow OS by default
  bool _darkMode = false;
  bool _oledMode = false;

  bool get useSystem => _useSystem;
  bool get darkMode => _darkMode;
  bool get oledMode => _oledMode;

  ThemeMode get themeMode {
    if (_useSystem) return ThemeMode.system;
    return _darkMode ? ThemeMode.dark : ThemeMode.light;
  }

  ThemeData get lightTheme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      );

  ThemeData get darkTheme {
    if (_oledMode) {
      return ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
          surface: Colors.black,
          // ignore: deprecated_member_use
          background: Colors.black,
        ),
        scaffoldBackgroundColor: Colors.black,
        cardColor: const Color(0xFF0D0D0D),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFF0D0D0D),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          surfaceTintColor: Colors.transparent,
        ),
        useMaterial3: true,
      );
    }

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _useSystem = prefs.getBool(_keySystem) ?? true;
    _darkMode = prefs.getBool(_keyDark) ?? false;
    _oledMode = prefs.getBool(_keyOled) ?? false;
    notifyListeners();
  }

  Future<void> setUseSystem(bool value) async {
    _useSystem = value;
    if (value) _oledMode = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySystem, _useSystem);
    await prefs.setBool(_keyOled, _oledMode);
  }

  Future<void> setDarkMode(bool value) async {
    _useSystem = false;
    _darkMode = value;
    if (!value) _oledMode = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySystem, _useSystem);
    await prefs.setBool(_keyDark, _darkMode);
    await prefs.setBool(_keyOled, _oledMode);
  }

  Future<void> setOledMode(bool value) async {
    if (!_darkMode) return;
    _oledMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOled, _oledMode);
  }
}
