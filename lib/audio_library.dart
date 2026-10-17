import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

const audioExtensions = {
  '.mp3',
  '.m4a',
  '.aac',
  '.wav',
  '.ogg',
  '.oga',
  '.opus',
  '.flac',
};

/// Pide permiso para leer audio del almacenamiento.
///
/// Android 13+ usa READ_MEDIA_AUDIO ([Permission.audio]); versiones
/// anteriores usan READ_EXTERNAL_STORAGE ([Permission.storage]). Se piden
/// ambos y basta con que uno quede concedido.
Future<bool> requestAudioPermission() async {
  final statuses = await [Permission.audio, Permission.storage].request();
  // La notificación multimedia no depende de este permiso, pero pedirlo
  // evita que algunos fabricantes la oculten.
  await Permission.notification.request();
  return statuses.values.any((s) => s.isGranted || s.isLimited);
}

/// Como [requestAudioPermission] pero sin mostrar ningún diálogo.
Future<bool> hasAudioPermission() async {
  return await Permission.audio.isGranted ||
      await Permission.storage.isGranted;
}

/// Busca archivos de audio dentro de [dirPath], incluyendo subcarpetas.
Future<List<File>> findAudioFiles(String dirPath) async {
  final files = <File>[];
  final entries = Directory(dirPath)
      .list(recursive: true, followLinks: false)
      // Subcarpetas sin acceso: se ignoran y se sigue buscando.
      .handleError((_) {});

  await for (final entry in entries) {
    if (entry is File &&
        audioExtensions.contains(p.extension(entry.path).toLowerCase())) {
      files.add(entry);
    }
  }

  files.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
  return files;
}
