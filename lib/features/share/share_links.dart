/// Link pubblici da condividere fuori dall'app (WhatsApp, Telegram, …).
///
/// Puntano al sito: se l'app è installata il sistema la apre direttamente sulla
/// schermata giusta (App Links su Android, Universal Links su iOS, vedi
/// DEPLOY.md), altrimenti si apre la pagina web. Il dominio si cambia a build
/// time:
///
///   flutter run --dart-define=WEB_BASE_URL=https://staging.repbirds.com
class ShareLinks {
  const ShareLinks._();

  static const String webBaseUrl = String.fromEnvironment('WEB_BASE_URL', defaultValue: 'https://repbirds.com');

  /// `/w/<id>`: apre la scheda.
  static String workout(String id) => '$webBaseUrl/w/$id';

  /// `/u/<username>`: apre il profilo.
  static String profile(String username) => '$webBaseUrl/u/${Uri.encodeComponent(username)}';
}
