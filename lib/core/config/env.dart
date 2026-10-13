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
  /// Serve per provare UX e UI in locale, in uno di questi modi:
  ///
  ///   flutter run -t lib/main_mock.dart
  ///   flutter run --dart-define=USE_MOCK=true
  ///
  /// Nelle build di debug si attiva anche dal login ("Usa dati demo")
  /// quando il server non risponde.
  static bool useMock = const bool.fromEnvironment('USE_MOCK');

  /// Dimensione pagina usata per le liste paginate (il backend accetta 1..100).
  static const int pageSize = 20;

  // Firebase (push). Valori dal progetto Firebase, passati a build time:
  //
  //   --dart-define=FIREBASE_PROJECT_ID=gymbro-xxxx
  //   --dart-define=FIREBASE_SENDER_ID=1234567890
  //   --dart-define=FIREBASE_ANDROID_API_KEY=...  --dart-define=FIREBASE_ANDROID_APP_ID=1:...:android:...
  //   --dart-define=FIREBASE_IOS_API_KEY=...      --dart-define=FIREBASE_IOS_APP_ID=1:...:ios:...
  //
  // (oppure tutti in un file con --dart-define-from-file=firebase.json).
  // Senza, l'app funziona uguale ma non riceve push.
  static const String firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String firebaseSenderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const String firebaseAndroidApiKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const String firebaseAndroidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const String firebaseIosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const String firebaseIosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
}
