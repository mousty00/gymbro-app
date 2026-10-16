import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// La sessione in corso salvata sul telefono, per riprenderla se il sistema
/// chiude l'app mentre sei fuori (o se si chiude da sola).
class SavedSession {
  const SavedSession({
    required this.workoutId,
    this.groupId,
    required this.startedAt,
    this.done = const {},
    this.focus = 0,
    this.restEndsAt,
    this.restTotal = 0,
    this.notes = '',
  });

  final String workoutId;
  final String? groupId;
  final DateTime startedAt;
  final Map<String, int> done;
  final int focus;
  final DateTime? restEndsAt;
  final int restTotal;
  final String notes;

  static const _key = 'repbirds.session';
  static const _storage = FlutterSecureStorage();

  /// Oltre questo tempo una sessione lasciata a metà non si riprende più.
  static const maxAge = Duration(hours: 12);

  String get route => '/workout/$workoutId/session${groupId == null ? '' : '?group=$groupId'}';

  Map<String, dynamic> toJson() => {
        'workoutId': workoutId,
        'groupId': groupId,
        'startedAt': startedAt.toIso8601String(),
        'done': done,
        'focus': focus,
        'restEndsAt': restEndsAt?.toIso8601String(),
        'restTotal': restTotal,
        'notes': notes,
      };

  factory SavedSession.fromJson(Map<String, dynamic> j) => SavedSession(
        workoutId: j['workoutId'] as String,
        groupId: j['groupId'] as String?,
        startedAt: DateTime.parse(j['startedAt'] as String),
        done: {for (final e in (j['done'] as Map).entries) '${e.key}': (e.value as num).toInt()},
        focus: (j['focus'] as num?)?.toInt() ?? 0,
        restEndsAt: j['restEndsAt'] == null ? null : DateTime.parse(j['restEndsAt'] as String),
        restTotal: (j['restTotal'] as num?)?.toInt() ?? 0,
        notes: j['notes'] as String? ?? '',
      );

  /// La sessione salvata, se c'è e non è troppo vecchia.
  static Future<SavedSession?> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      final s = SavedSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (DateTime.now().difference(s.startedAt) > maxAge) {
        await clear();
        return null;
      }
      return s;
    } catch (e) {
      debugPrint('Sessione salvata illeggibile: $e');
      await clear();
      return null;
    }
  }

  Future<void> save() async {
    try {
      await _storage.write(key: _key, value: jsonEncode(toJson()));
    } catch (e) {
      debugPrint('Sessione non salvata: $e');
    }
  }

  static Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}
