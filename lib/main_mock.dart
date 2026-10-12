import 'core/config/env.dart';
import 'main.dart' as app;

/// Avvia l'app in modalità mock, senza backend:
///
///   flutter run -t lib/main_mock.dart
Future<void> main() {
  Env.useMock = true;
  return app.main();
}
