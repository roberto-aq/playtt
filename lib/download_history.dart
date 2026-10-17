import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Recuerda qué contenidos ya se descargaron (id de origen → ruta del archivo)
/// para avisar antes de descargar uno repetido.
///
/// No sabe de TikTok: el id lo decide quien descarga (aquí, el id del video).
class DownloadHistory {
  static const _fileName = 'downloads.json';

  Map<String, String> _pathById = {};
  File? _file;

  Future<void> load() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File(p.join(dir.path, _fileName));
      if (await _file!.exists()) {
        final json = jsonDecode(await _file!.readAsString()) as Map;
        _pathById = json.map((k, v) => MapEntry(k as String, v as String));
      }
    } catch (e) {
      debugPrint('Historial de descargas: no se pudo cargar: $e');
    }
  }

  /// Ruta del archivo descargado con [id], si todavía existe.
  Future<String?> existingPath(String id) async {
    final path = _pathById[id];
    if (path == null) return null;
    if (await File(path).exists()) return path;
    // El archivo se borró por fuera de la app: se olvida.
    _pathById.remove(id);
    await _save();
    return null;
  }

  Future<void> add(String id, String path) async {
    _pathById[id] = path;
    await _save();
  }

  /// El archivo cambió de nombre dentro de la app.
  Future<void> moved(String oldPath, String newPath) async {
    var changed = false;
    _pathById.updateAll((_, path) {
      if (path != oldPath) return path;
      changed = true;
      return newPath;
    });
    if (changed) await _save();
  }

  /// El archivo se eliminó dentro de la app.
  Future<void> removed(String path) async {
    final before = _pathById.length;
    _pathById.removeWhere((_, value) => value == path);
    if (_pathById.length != before) await _save();
  }

  Future<void> _save() async {
    try {
      await _file?.writeAsString(jsonEncode(_pathById));
    } catch (e) {
      debugPrint('Historial de descargas: no se pudo guardar: $e');
    }
  }
}
