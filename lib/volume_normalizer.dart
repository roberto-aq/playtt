import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'native_bridge.dart';

/// Iguala el volumen percibido entre audios.
///
/// 1. Mide la sonoridad de cada archivo una sola vez (en Kotlin) y la guarda
///    en caché.
/// 2. Al cambiar de canción calcula cuánto le falta o le sobra respecto a
///    [targetDb] y lo compensa: baja con `setVolume` (que solo admite 0–1) o
///    sube con [AndroidLoudnessEnhancer].
///
/// Detalle y fórmulas en docs/guides/nivelacion-de-volumen.md.
class VolumeNormalizer extends ChangeNotifier {
  VolumeNormalizer(this._player, this._enhancer);

  /// Nivel al que se llevan todos los audios (dBFS, medición sin ponderar).
  static const targetDb = -14.0;

  /// Máximo que se sube un audio bajo: más allá, el amplificador distorsiona.
  static const maxBoostDb = 8.0;

  /// Mínimo de `setVolume` al bajar un audio muy fuerte.
  static const _minVolume = 0.1;

  static const _settingKey = 'normalize_volume';
  static const _cacheFileName = 'loudness_cache.json';

  final AudioPlayer _player;
  final AndroidLoudnessEnhancer _enhancer;

  bool enabled = true;
  bool analyzing = false;

  /// "ruta|tamaño|fecha" → dBFS. La clave cambia si el archivo cambia.
  Map<String, double> _cache = {};
  File? _cacheFile;

  /// Carga la preferencia y la caché guardadas.
  Future<void> init() async {
    try {
      enabled = await NativeBridge.getSetting(_settingKey) != 'false';
      final dir = await getApplicationSupportDirectory();
      _cacheFile = File(p.join(dir.path, _cacheFileName));
      if (await _cacheFile!.exists()) {
        final json = jsonDecode(await _cacheFile!.readAsString()) as Map;
        _cache = {
          for (final e in json.entries)
            e.key as String: (e.value as num).toDouble(),
        };
      }
    } catch (e) {
      debugPrint('Nivelación: no se pudo cargar la caché: $e');
    }
  }

  Future<void> setEnabled(bool value, {double? currentLoudness}) async {
    enabled = value;
    notifyListeners();
    await NativeBridge.setSetting(_settingKey, value ? 'true' : 'false');
    await apply(currentLoudness);
  }

  /// Ajusta el reproductor para un audio de sonoridad [loudnessDb].
  /// Con `null` (sin medir aún) o la nivelación apagada, volumen normal.
  Future<void> apply(double? loudnessDb) async {
    final adjustment = enabled
        ? adjustmentFor(loudnessDb)
        : (volume: 1.0, boostDb: 0.0);
    await _player.setVolume(adjustment.volume);
    await _enhancer.setTargetGain(adjustment.boostDb);
  }

  /// Cómo compensar un audio de sonoridad [loudnessDb] para llevarlo a
  /// [targetDb]: si suena fuerte se baja el volumen (0–1); si suena bajo se
  /// amplifica con el LoudnessEnhancer (dB). Nunca ambas cosas a la vez.
  static ({double volume, double boostDb}) adjustmentFor(double? loudnessDb) {
    if (loudnessDb == null) return (volume: 1.0, boostDb: 0.0);
    final gainDb = targetDb - loudnessDb;
    if (gainDb >= 0) {
      return (volume: 1.0, boostDb: math.min(gainDb, maxBoostDb));
    }
    // dB → factor lineal de amplitud: 10^(dB/20). -6 dB ≈ la mitad.
    final volume = math.pow(10, gainDb / 20).toDouble();
    return (volume: volume.clamp(_minVolume, 1.0), boostDb: 0.0);
  }

  /// Sonoridad ya conocida de [file], o `null` si no está en caché.
  Future<double?> cached(File file) async {
    return _cache[await _key(file)];
  }

  /// Mide los archivos que no estén en caché, en lotes, y llama a
  /// [onMeasured] con cada resultado para que la lista se actualice.
  Future<void> analyze(
    List<File> files,
    void Function(File file, double? loudness) onMeasured,
  ) async {
    final pending = <File>[];
    for (final f in files) {
      final known = _cache[await _key(f)];
      if (known != null) {
        onMeasured(f, known);
      } else {
        pending.add(f);
      }
    }
    if (pending.isEmpty) return;

    analyzing = true;
    notifyListeners();
    try {
      const batch = 4;
      for (var i = 0; i < pending.length; i += batch) {
        final chunk = pending.sublist(i, math.min(i + batch, pending.length));
        final results = await NativeBridge.measureLoudness([
          for (final f in chunk) f.path,
        ]);
        for (var j = 0; j < chunk.length; j++) {
          final value = results[j];
          if (value != null) _cache[await _key(chunk[j])] = value;
          onMeasured(chunk[j], value);
        }
        await _save();
      }
    } catch (e) {
      debugPrint('Nivelación: error al analizar: $e');
    } finally {
      analyzing = false;
      notifyListeners();
    }
  }

  /// Conserva la medición cuando un archivo cambia de nombre.
  Future<void> moved(String oldPath, File newFile, double? loudness) async {
    _cache.removeWhere((key, _) => key.startsWith('$oldPath|'));
    if (loudness != null) _cache[await _key(newFile)] = loudness;
    await _save();
  }

  Future<void> forget(String path) async {
    _cache.removeWhere((key, _) => key.startsWith('$path|'));
    await _save();
  }

  Future<String> _key(File file) async {
    final stat = await file.stat();
    return '${file.path}|${stat.size}|${stat.modified.millisecondsSinceEpoch}';
  }

  Future<void> _save() async {
    try {
      await _cacheFile?.writeAsString(jsonEncode(_cache));
    } catch (e) {
      debugPrint('Nivelación: no se pudo guardar la caché: $e');
    }
  }
}
