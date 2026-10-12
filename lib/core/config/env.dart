/// Configurazione dell'app, passata a build time:
///
///   flutter run --dart-define=API_BASE_URL=https://api.gymbro.app/api
///
/// Il default punta al backend locale (context-path `/api`). Su emulatore
/// Android usa `http://10.0.2.2:8080/api`, su iOS simulator `http://localhost:8080/api`.
class Env {
  const Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api',
  );

  /// Modalità mock: l'app gira senza backend, con dati finti in memoria.
  /// Serve per provare UX e UI in locale:
  ///
  ///   flutter run --dart-define=USE_MOCK=true
  static const bool useMock = bool.fromEnvironment('USE_MOCK');

  /// Dimensione pagina usata per le liste paginate (il backend accetta 1..100).
  static const int pageSize = 20;
}
