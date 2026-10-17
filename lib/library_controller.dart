import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path/path.dart' as p;

import 'audio_library.dart';
import 'native_bridge.dart';

/// Carpeta predeterminada. Android permite crear y escribir audio dentro de
/// Music sin permisos especiales, así que sirve también para las descargas.
const defaultMusicFolder = '/storage/emulated/0/Music/TikTok';

class Track {
  Track({required this.file, required this.modified, this.duration});

  final File file;
  final DateTime modified;

  /// `null` mientras se lee del archivo.
  Duration? duration;

  String get title => p.basenameWithoutExtension(file.path);
}

class StorageException implements Exception {
  StorageException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Estado compartido entre pestañas: la carpeta de música, sus canciones y el
/// reproductor. La carpeta elegida es también donde se guardan las descargas.
class LibraryController extends ChangeNotifier {
  static const _folderKey = 'music_folder';
  static const _folderUriKey = 'music_folder_uri';

  final player = AudioPlayer();

  /// Ruta de la carpeta, para leer y reproducir los archivos.
  String? folder;

  /// Permiso de escritura sobre la carpeta (selector del sistema). `null` en
  /// la carpeta predeterminada, donde se escribe directamente por ruta.
  String? folderUri;

  List<Track> tracks = [];
  bool loading = false;
  bool loadingDurations = false;

  /// Vuelve a abrir la última carpeta usada, sin empezar a reproducir.
  /// Si algo falla se arranca sin carpeta, como la primera vez.
  Future<void> restore() async {
    try {
      final saved = await NativeBridge.getSetting(_folderKey);
      if (saved == null) {
        debugPrint('Restaurar: no hay carpeta guardada.');
        return;
      }
      if (!await Directory(saved).exists()) {
        debugPrint('Restaurar: la carpeta guardada ya no existe: $saved');
        return;
      }
      if (!await hasAudioPermission()) {
        debugPrint('Restaurar: falta el permiso de audio.');
        return;
      }
      debugPrint('Restaurar: abriendo $saved');
      await openFolder(saved, uri: await NativeBridge.getSetting(_folderUriKey));
    } catch (e) {
      debugPrint('No se pudo restaurar la carpeta guardada: $e');
    }
  }

  /// Carga todas las canciones de [path] (más recientes primero) y la guarda
  /// como carpeta de la app. [uri] es el permiso de escritura del selector.
  Future<void> openFolder(String path, {String? uri}) async {
    loading = true;
    notifyListeners();
    try {
      await Directory(path).create(recursive: true);
      final files = await findAudioFiles(path);
      final found = [
        for (final f in files)
          Track(file: f, modified: await f.lastModified()),
      ]..sort((a, b) => b.modified.compareTo(a.modified));

      final album = p.basename(path);
      await player.setAudioSources(
        [for (final t in found) _sourceFor(t, album)],
        preload: false,
      );

      folder = path;
      folderUri = uri;
      tracks = found;
      // Recordar la carpeta no es crítico: si falla, igual queda cargada.
      try {
        await NativeBridge.setSetting(_folderKey, path);
        await NativeBridge.setSetting(_folderUriKey, uri);
      } catch (e) {
        debugPrint('No se pudo guardar la carpeta: $e');
      }
    } finally {
      loading = false;
      notifyListeners();
    }
    _loadDurations(tracks);
  }

  /// Vuelve a escanear la carpeta actual.
  Future<void> reload() async {
    if (folder != null) await openFolder(folder!, uri: folderUri);
  }

  /// Copia [source] a la carpeta de la biblioteca como [fileName] y lo agrega
  /// al inicio de la lista sin cortar lo que esté sonando.
  Future<File> saveDownloadedAudio(
    File source, {
    required String fileName,
    required String mimeType,
  }) async {
    final dir = folder;
    if (dir == null) {
      throw StorageException('Elige primero una carpeta en Configuración.');
    }

    final String savedPath;
    if (folderUri != null) {
      try {
        final finalName = await NativeBridge.saveToFolder(
          treeUri: folderUri!,
          sourcePath: source.path,
          name: fileName,
          mimeType: mimeType,
        );
        savedPath = p.join(dir, finalName);
      } catch (e) {
        throw StorageException(
          'No se pudo guardar en "${p.basename(dir)}". '
          'Vuelve a elegir la carpeta en Configuración.',
        );
      }
    } else {
      final dest = await _uniqueFile(dir, fileName);
      try {
        await source.copy(dest.path);
      } on FileSystemException {
        // Carpetas elegidas antes de tener el permiso de escritura.
        throw StorageException(
          'Android no permite guardar en "${p.basename(dir)}" sin permiso. '
          'Vuelve a elegir la carpeta en Configuración.',
        );
      }
      savedPath = dest.path;
    }

    await NativeBridge.scanFile(savedPath);
    final file = File(savedPath);
    await _addTrack(file);
    return file;
  }

  Future<void> playTrack(int index) async {
    await player.seek(Duration.zero, index: index);
    player.play();
  }

  Future<void> _addTrack(File file) async {
    final track = Track(file: file, modified: await file.lastModified());
    await player.insertAudioSource(0, _sourceFor(track, p.basename(folder!)));
    tracks = [track, ...tracks];
    notifyListeners();
    _loadDurations([track]);
  }

  AudioSource _sourceFor(Track track, String album) {
    return AudioSource.file(
      track.file.path,
      // El MediaItem es lo que muestran la notificación, la pantalla de
      // bloqueo y los dispositivos Bluetooth.
      tag: MediaItem(id: track.file.path, title: track.title, album: album),
    );
  }

  /// Lee las duraciones en lotes para que la lista se vaya completando.
  Future<void> _loadDurations(List<Track> pending) async {
    if (pending.isEmpty) return;
    loadingDurations = true;
    notifyListeners();
    try {
      const batch = 20;
      for (var i = 0; i < pending.length; i += batch) {
        final chunk = pending.sublist(i, (i + batch).clamp(0, pending.length));
        final millis = await NativeBridge.getDurations([
          for (final t in chunk) t.file.path,
        ]);
        for (var j = 0; j < chunk.length; j++) {
          final ms = millis[j];
          chunk[j].duration =
              ms == null ? Duration.zero : Duration(milliseconds: ms);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('No se pudieron leer las duraciones: $e');
    } finally {
      loadingDurations = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}

/// "nombre.m4a", o "nombre (2).m4a" si ya existe.
Future<File> _uniqueFile(String folder, String fileName) async {
  final name = p.basenameWithoutExtension(fileName);
  final ext = p.extension(fileName);
  var file = File(p.join(folder, fileName));
  var n = 2;
  while (await file.exists()) {
    file = File(p.join(folder, '$name ($n)$ext'));
    n++;
  }
  return file;
}
