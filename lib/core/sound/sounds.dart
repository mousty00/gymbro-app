import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// I suoni dell'app (assets/sounds, generati da tool/make_sounds.py).
enum Sound { launch, rep, restEnd, finish }

/// Suona effetti brevi. Si mischiano alla musica dell'utente (non la fermano)
/// e su iPhone rispettano il tasto silenzioso. Un suono che non parte non deve
/// rompere niente: gli errori si ignorano.
abstract final class Sounds {
  static final _players = <Sound, AudioPlayer>{};
  static bool _configured = false;

  static String _file(Sound s) => switch (s) {
    Sound.launch => 'sounds/launch.wav',
    Sound.rep => 'sounds/rep.wav',
    Sound.restEnd => 'sounds/rest_end.wav',
    Sound.finish => 'sounds/finish.wav',
  };

  static Future<void> play(Sound sound) async {
    if (!SoundNotifier.on) return;
    try {
      if (!_configured) {
        _configured = true;
        await AudioPlayer.global.setAudioContext(
          AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers, respectSilence: true).build(),
        );
      }
      final player = _players[sound] ??= AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
      await player.stop();
      await player.play(AssetSource(_file(sound)));
    } catch (e) {
      debugPrint('Suono non riprodotto: $e');
    }
  }
}

/// Suoni attivi o no (impostazioni). Di base attivi.
class SoundNotifier extends Notifier<bool> {
  static const _key = 'repbirds.sounds';
  static const _storage = FlutterSecureStorage();

  /// Letto in main() prima di avviare l'app.
  static bool on = true;

  static Future<void> load() async {
    try {
      on = await _storage.read(key: _key) != 'off';
    } catch (_) {}
  }

  @override
  bool build() => on;

  Future<void> set(bool value) async {
    state = on = value;
    try {
      await _storage.write(key: _key, value: value ? 'on' : 'off');
    } catch (_) {}
  }
}

final soundProvider = NotifierProvider<SoundNotifier, bool>(SoundNotifier.new);
