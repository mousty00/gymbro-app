/// Configurazione dell'app, passata a build time:
///
///   flutter run --dart-define=API_BASE_URL=https://api.repbirds.app/api
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
  /// Serve per provare UX e UI in locale, in uno di questi modi:
  ///
  ///   flutter run -t lib/main_mock.dart
  ///   flutter run --dart-define=USE_MOCK=true
  ///
  /// Nelle build di debug si attiva anche dal login ("Usa dati demo")
  /// quando il server non risponde.
  static bool useMock = const bool.fromEnvironment('USE_MOCK');

  /// Tile della mappa (percorsi di corsa), formato `{z}/{x}/{y}`. Il default
  /// sono i server pubblici di OpenStreetMap, che vanno bene per sviluppo e
  /// test ma non ammettono il traffico di un'app pubblicata: in produzione usa
  /// un provider con chiave, es.
  ///
  ///   --dart-define=MAP_TILE_URL=https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=CHIAVE
  ///   --dart-define=MAP_ATTRIBUTION="MapTiler © OpenStreetMap contributors"
  static const String mapTileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static const String mapAttribution = String.fromEnvironment(
    'MAP_ATTRIBUTION',
    defaultValue: '© OpenStreetMap contributors',
  );

  /// Dimensione pagina usata per le liste paginate (il backend accetta 1..100).
  static const int pageSize = 20;
}
