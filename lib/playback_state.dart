import 'dart:convert';

import 'package:just_audio/just_audio.dart';

/// Dónde quedó la reproducción, para retomarla al volver a abrir la app.
class PlaybackState {
  const PlaybackState({
    required this.path,
    required this.position,
    this.shuffle = false,
    this.loopMode = LoopMode.off,
  });

  /// Archivo de la canción. Se guarda la ruta (no el índice) porque el orden
  /// de la lista cambia al descargar, renombrar o eliminar audios.
  final String path;
  final Duration position;
  final bool shuffle;
  final LoopMode loopMode;

  String encode() => jsonEncode({
    'path': path,
    'positionMs': position.inMilliseconds,
    'shuffle': shuffle,
    'loop': loopMode.name,
  });

  /// `null` si no hay nada guardado o el formato no es válido.
  static PlaybackState? decode(String? json) {
    if (json == null) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return PlaybackState(
        path: map['path'] as String,
        position: Duration(milliseconds: map['positionMs'] as int? ?? 0),
        shuffle: map['shuffle'] as bool? ?? false,
        loopMode: LoopMode.values.firstWhere(
          (m) => m.name == map['loop'],
          orElse: () => LoopMode.off,
        ),
      );
    } catch (_) {
      return null;
    }
  }
}
