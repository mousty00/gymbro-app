import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tema scelto dalle impostazioni: di base segue il dispositivo.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'repbirds.theme';
  static const _storage = FlutterSecureStorage();

  /// Letto in main() prima di avviare l'app.
  static ThemeMode saved = ThemeMode.system;

  static Future<void> load() async {
    try {
      saved = ThemeMode.values.asNameMap()[await _storage.read(key: _key)] ?? ThemeMode.system;
    } catch (_) {}
  }

  @override
  ThemeMode build() => saved;

  Future<void> set(ThemeMode mode) async {
    state = saved = mode;
    try {
      await _storage.write(key: _key, value: mode.name);
    } catch (_) {}
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
