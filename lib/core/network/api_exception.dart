import 'package:dio/dio.dart';

/// Errore leggibile ricavato dall'`ErrorResponse` del backend
/// (`{timestamp, status, error, message, details}`).
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.details = const {}, this.unreachable = false});

  final String message;
  final int? statusCode;
  final Map<String, String> details;

  bool get isUnauthorized => statusCode == 401;

  /// Nessuna risposta: server spento, URL sbagliato o rete assente.
  final bool unreachable;
  bool get isEmailNotVerified =>
      statusCode == 403 && message.toLowerCase().contains('not verified');

  factory ApiException.fromDio(Object error) {
    if (error is ApiException) return error;
    if (error is! DioException) {
      return ApiException('Qualcosa è andato storto. Riprova.');
    }
    final response = error.response;
    if (response == null) {
      return ApiException(
        'Impossibile raggiungere il server. Controlla la connessione.',
        unreachable: true,
      );
    }
    final data = response.data;
    var message = 'Errore ${response.statusCode ?? ''}'.trim();
    final details = <String, String>{};
    if (data is Map) {
      final m = data['message'];
      if (m is String && m.isNotEmpty) message = m;
      final d = data['details'];
      if (d is Map) {
        d.forEach((k, v) => details['$k'] = '$v');
      }
    }
    if (details.isNotEmpty) {
      message = details.values.join('\n');
    }
    final status = response.statusCode ?? 0;
    if (status == 429) {
      // rate limit sulle rotte /auth (20 richieste al minuto per IP)
      message = 'Troppi tentativi. Aspetta un minuto e riprova.';
    } else if (status >= 500 && details.isEmpty) {
      message = 'Il server ha avuto un problema. Riprova tra poco.';
    }
    return ApiException(message, statusCode: response.statusCode, details: details);
  }

  @override
  String toString() => message;
}
