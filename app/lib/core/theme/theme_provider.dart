import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage.dart';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final raw = await SecureStorage.instance.readThemeMode();
    state = _parse(raw);
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await SecureStorage.instance.writeThemeMode(_encode(mode));
  }

  static ThemeMode _parse(String? raw) {
    switch (raw) {
      case 'light':  return ThemeMode.light;
      case 'system': return ThemeMode.system;
      default:       return ThemeMode.system;
    }
  }

  static String _encode(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:  return 'light';
      case ThemeMode.system: return 'system';
      default:               return 'dark';
    }
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (_) => ThemeModeNotifier(),
);
