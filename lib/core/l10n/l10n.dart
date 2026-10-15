import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'en.dart';
import 'es.dart';
import 'fr.dart';

/// Lingue dell'app. I testi sono scritti in italiano nel codice e passano da
/// [tr]; le altre lingue sono mappe "testo italiano → traduzione".
abstract final class L10n {
  static const languages = {'it': 'Italiano', 'en': 'English', 'fr': 'Français', 'es': 'Español'};
  static const fallback = 'en';
  static const _maps = {'en': en, 'fr': fr, 'es': es};

  /// Lingua attiva, aggiornata da [AppThemeSync] (vedi app_theme.dart).
  static String lang = 'it';

  static List<Locale> get locales => [for (final l in languages.keys) Locale(l)];

  /// Lingua del dispositivo se supportata, altrimenti inglese.
  static Locale resolve(Locale? device, Iterable<Locale> supported) =>
      Locale(languages.containsKey(device?.languageCode) ? device!.languageCode : fallback);

  static String translate(String it) => lang == 'it' ? it : _maps[lang]?[it] ?? en[it] ?? it;
}

/// Traduce [it] nella lingua attiva. I segnaposto `{nome}` si riempiono con [args].
String tr(String it, [Map<String, Object?> args = const {}]) {
  var s = L10n.translate(it);
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

/// Lingua scelta nelle impostazioni; null = quella del dispositivo.
class LanguageNotifier extends Notifier<String?> {
  static const _key = 'repbirds.language';
  static const _storage = FlutterSecureStorage();

  /// Letta in main() prima di avviare l'app.
  static String? saved;

  static Future<void> load() async {
    try {
      saved = await _storage.read(key: _key);
    } catch (_) {}
  }

  @override
  String? build() => saved;

  Future<void> set(String? lang) async {
    state = saved = lang;
    try {
      lang == null ? await _storage.delete(key: _key) : await _storage.write(key: _key, value: lang);
    } catch (_) {}
  }
}

final languageProvider = NotifierProvider<LanguageNotifier, String?>(LanguageNotifier.new);
