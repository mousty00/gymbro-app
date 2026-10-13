import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/notification_repository.dart';
import '../../data/providers.dart';
import '../../features/auth/session.dart';
import '../../models/notification.dart';
import '../config/env.dart';
import '../router/app_router.dart';

/// Per mostrare le push arrivate con l'app aperta (il sistema le mostra solo in background).
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Push via Firebase Cloud Messaging (Android, e iOS tramite APNs).
///
/// Dopo il login chiede il permesso e registra il token del dispositivo su
/// `POST /devices`; al logout lo cancella. Con l'app aperta una push ricarica le
/// notifiche e mostra un avviso; il tap su una push apre la schermata giusta.
/// Senza configurazione Firebase (vedi [Env]) o in modalità mock non fa nulla.
class PushService {
  PushService(this._ref);

  final Ref _ref;
  bool _ready = false;
  String? _token;
  final _subs = <StreamSubscription<Object?>>[];

  static FirebaseOptions? get _options {
    if (kIsWeb || Env.firebaseProjectId.isEmpty || Env.firebaseSenderId.isEmpty) return null;
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final apiKey = ios ? Env.firebaseIosApiKey : Env.firebaseAndroidApiKey;
    final appId = ios ? Env.firebaseIosAppId : Env.firebaseAndroidAppId;
    if (apiKey.isEmpty || appId.isEmpty) return null;
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: Env.firebaseSenderId,
      projectId: Env.firebaseProjectId,
    );
  }

  static String get _platform => defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';

  /// Da chiamare una volta all'avvio, prima di `runApp`.
  Future<void> init() async {
    final options = _options;
    if (options == null) return;
    try {
      await Firebase.initializeApp(options: options);
      _ready = true;
    } catch (e) {
      debugPrint('Push disattivate: Firebase non inizializzato ($e)');
      return;
    }
    final messaging = FirebaseMessaging.instance;
    await messaging.setForegroundNotificationPresentationOptions(alert: false, badge: true, sound: false);
    _subs
      ..add(FirebaseMessaging.onMessage.listen(_onForeground))
      ..add(FirebaseMessaging.onMessageOpenedApp.listen(_open))
      ..add(messaging.onTokenRefresh.listen(_register));
  }

  bool get _active => _ready && !Env.useMock;

  /// Dopo il login (e a ogni avvio con sessione valida).
  Future<void> onLogin() async {
    if (!_active) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await messaging.getToken();
      if (token != null) await _register(token);
      final initial = await messaging.getInitialMessage();
      if (initial != null) _open(initial);
    } catch (e) {
      debugPrint('Registrazione push non riuscita: $e');
    }
  }

  /// Prima del logout, finché la sessione è ancora valida.
  Future<void> onLogout() async {
    final token = _token;
    _token = null;
    if (!_active || token == null) return;
    try {
      await _ref.read(notificationRepositoryProvider).unregisterDevice(token);
    } catch (_) {
      // Il backend scarta comunque i token che FCM rifiuta.
    }
  }

  Future<void> _register(String token) async {
    if (_ref.read(sessionProvider).value == null) return;
    _token = token;
    await _ref.read(notificationRepositoryProvider).registerDevice(token, _platform);
  }

  void _onForeground(RemoteMessage message) {
    refreshNotifications(_ref.invalidate);
    final n = message.notification;
    final text = [n?.title, n?.body].whereType<String>().join(' · ');
    if (text.isEmpty) return;
    final route = _routeOf(message);
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        action: route == null
            ? null
            : SnackBarAction(label: 'Apri', onPressed: () => _ref.read(routerProvider).push(route)),
      ));
  }

  void _open(RemoteMessage message) {
    refreshNotifications(_ref.invalidate);
    final id = message.data['notificationId'];
    if (id is String) {
      _ref.read(notificationRepositoryProvider).markRead(id).catchError((_) {});
    }
    final route = _routeOf(message);
    if (route != null) _ref.read(routerProvider).push(route);
  }

  static String? _routeOf(RemoteMessage message) => AppNotification.routeFor(
        NotificationKind.parse(message.data['type']),
        message.data['referenceId'] as String?,
      );

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(ref);
  ref.onDispose(service.dispose);
  return service;
});
