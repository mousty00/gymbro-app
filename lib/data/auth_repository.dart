import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/storage/token_storage.dart';
import '../models/json.dart';
import '../models/user.dart';

/// Endpoint `/auth/**`.
class AuthRepository {
  AuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStorage _tokens;

  Future<User> login(String username, String password) async {
    final res = await _api.post<Json>('/auth/login', data: {
      'username': username,
      'password': password,
    });
    await _tokens.save(
      access: res['token'] as String,
      refresh: res['refreshToken'] as String,
    );
    return User.fromJson(Map<String, dynamic>.from(res['result'] as Map));
  }

  /// Il backend invia un OTP via email subito dopo la registrazione.
  Future<String> signup({
    required String username,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required DateTime birthDate,
  }) async {
    final res = await _api.post<Json>('/auth/signup', data: {
      'username': username,
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'birthDate': formatLocalDate(birthDate),
    });
    return res['message'] as String? ?? 'Registrazione completata';
  }

  Future<void> verifyOtp({required String username, required String otp}) =>
      _api.post<Json>('/auth/verify-otp', data: {'username': username, 'otp': otp});

  Future<void> sendVerifyOtp(String email) =>
      _api.post<dynamic>('/auth/send-otp', query: {'email': email});

  Future<void> sendResetOtp(String email) =>
      _api.post<dynamic>('/auth/send-reset-otp', query: {'email': email});

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) =>
      _api.post<Json>('/auth/reset-password', data: {
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
      });

  Future<User> profile() async =>
      User.fromJson(await _api.get<Json>('/auth/profile'));

  Future<bool> hasSession() async => await _tokens.accessToken != null;

  Future<void> logout() async {
    final refresh = await _tokens.refreshToken;
    try {
      if (refresh != null) {
        await _api.post<dynamic>('/auth/logout', data: {'refreshToken': refresh});
      }
    } catch (_) {
      // Logout locale comunque.
    } finally {
      await _tokens.clear();
    }
  }

  Future<void> clearSession() => _tokens.clear();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStorageProvider)),
);
