import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Recupero con l'app in background: un conto alla rovescia nella schermata di
/// blocco (Live Activity su iPhone, notifica fissa col cronometro su Android) e
/// una notifica all'ora giusta quando finisce, anche se l'app è sospesa. In
/// primo piano non servono, quindi partono uscendo e si tolgono al rientro.
abstract final class RestAlarm {
  static const _id = 4201;
  static const _liveId = 4202;
  static const _activity = MethodChannel('repbirds/rest_activity');
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  /// Da chiamare all'inizio della sessione: chiede il permesso una volta sola.
  static Future<void> requestPermission() async {
    try {
      await _init();
      if (Platform.isIOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, sound: true);
      } else if (Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Permesso notifiche non chiesto: $e');
    }
  }

  static Future<void> schedule(DateTime endsAt, {required String title, required String body}) async {
    try {
      await _init();
      final android = Platform.isAndroid
          ? _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          : null;
      // esatto se l'utente lo permette (Android 14+ lo nega di base), altrimenti può tardare un po'
      final exact = await android?.canScheduleExactNotifications() ?? true;
      await _plugin.zonedSchedule(
        id: _id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(endsAt, tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'rest_timer',
            'Recupero',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
          ),
          iOS: DarwinNotificationDetails(interruptionLevel: InterruptionLevel.timeSensitive),
        ),
        androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Notifica di fine recupero non programmata: $e');
    }
  }

  /// iPhone: Live Activity col conto alla rovescia (schermata di blocco e Dynamic
  /// Island). iOS la lascia avviare solo con l'app in primo piano, quindi parte
  /// insieme al recupero; null la chiude.
  static Future<void> liveActivity(DateTime? endsAt, {String title = '', String subtitle = ''}) async {
    if (!Platform.isIOS) return;
    try {
      if (endsAt == null) {
        await _activity.invokeMethod<void>('end');
      } else {
        await _activity.invokeMethod<void>('start', {
          'endsAt': endsAt.millisecondsSinceEpoch,
          'title': title,
          'subtitle': subtitle,
        });
      }
    } catch (e) {
      debugPrint('Live Activity non aggiornata: $e');
    }
  }

  /// Android: notifica fissa col cronometro che scende, mostrata uscendo dall'app.
  static Future<void> showCountdown(DateTime endsAt, {required String title, required String subtitle}) async {
    try {
      if (Platform.isAndroid) {
        await _init();
        final left = endsAt.difference(DateTime.now()).inMilliseconds;
        if (left <= 0) return;
        await _plugin.show(
          id: _liveId,
          title: title,
          body: subtitle,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              'rest_live',
              'Recupero in corso',
              importance: Importance.low,
              priority: Priority.low,
              ongoing: true,
              autoCancel: false,
              onlyAlertOnce: true,
              silent: true,
              showWhen: true,
              when: endsAt.millisecondsSinceEpoch,
              usesChronometer: true,
              chronometerCountDown: true,
              // sparisce da sola a fine recupero (poi arriva quella con il suono)
              timeoutAfter: left,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Conto alla rovescia non mostrato: $e');
    }
  }

  static Future<void> cancel() async {
    try {
      await _init();
      await _plugin.cancel(id: _id);
      await _plugin.cancel(id: _liveId);
    } catch (_) {}
  }
}
