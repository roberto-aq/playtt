import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path/path.dart' as p;

import 'audio_library.dart';
import 'download_history.dart';
import 'native_bridge.dart';
import 'playback_state.dart';
import 'volume_normalizer.dart';

/// Subcarpeta de Music usada como carpeta predeterminada. Android permite
/// crear y escribir audio dentro de Music sin permisos especiales, así que
/// sirve también para las descargas.
const _defaultSubfolder = 'TikTok';

class Track {
  Track({
    required this.file,
    required this.modified,
    this.duration,
    this.loudness,
  });

  final File file;
  final DateTime modified;

  /// `null` mientras se lee del archivo.
  Duration? duration;

  /// Sonoridad en dBFS para la nivelación de volumen; `null` sin medir.
  double? loudness;

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
///
/// Invariante: `tracks[i]` corresponde siempre a `player.audioSources[i]`.
/// Toda operación que agrega, quita o reemplaza canciones actualiza ambas
/// listas en la misma posición.
class LibraryController extends ChangeNotifier {
  LibraryController() {
    normalizer.addListener(notifyListeners);
    _subscriptions = [
      // Cada vez que cambia la canción se ajusta su volumen y se recuerda.
      player.currentIndexStream.listen((_) {
        _applyVolume();
        savePlaybackState();
      }),
      // Mientras suena, se guarda la posición cada pocos segundos; al pausar,
      // de inmediato.
      player.playingStream.listen((playing) {
        _saveTimer?.cancel();
        _saveTimer = playing
            ? Timer.periodic(_saveInterval, (_) => savePlaybackState())
            : null;
        if (!playing) savePlaybackState();
      }),
      player.shuffleModeEnabledStream.listen((_) => savePlaybackState()),
      player.loopModeStream.listen((_) => savePlaybackState()),
    ];
  }

  static const _folderKey = 'music_folder';
  static const _folderUriKey = 'music_folder_uri';
  static const _playbackKey = 'playback_state';
  static const _saveInterval = Duration(seconds: 5);

  /// Videos ya descargados, para avisar de duplicados.
  final downloads = DownloadHistory();

  /// Carpeta predeterminada (botón "Restaurar"): Music/TikTok. La ruta real
  /// de Music la informa Android en [start]; este valor es el de casi todos
  /// los teléfonos, por si la consulta falla.
  String defaultFolder = '/storage/emulated/0/Music/$_defaultSubfolder';

  Timer? _saveTimer;

  final _enhancer = AndroidLoudnessEnhancer();

  late final player = AudioPlayer(
    audioPipeline: AudioPipeline(androidAudioEffects: [_enhancer]),
  );

  late final normalizer = VolumeNormalizer(player, _enhancer);

  late final List<StreamSubscription<Object?>> _subscriptions;

  /// Ruta de la carpeta, para leer y reproducir los archivos.
  String? folder;

  /// Permiso de escritura sobre la carpeta (selector del sistema). `null` en
  /// la carpeta predeterminada, donde se escribe directamente por ruta.
  String? folderUri;

  List<Track> tracks = [];
  bool loading = false;
  bool loadingDurations = false;

  /// Canción que está sonando (o seleccionada), si la hay.
  Track? get currentTrack {
    final i = player.currentIndex;
    return i != null && i < tracks.length ? tracks[i] : null;
  }

  /// Prepara la nivelación de volumen y el historial, y abre la última
  /// carpeta usada.
  Future<void> start() async {
    await _enhancer.setEnabled(true);
    await normalizer.init();
    await downloads.load();
    try {
      defaultFolder = p.join(
        await NativeBridge.getMusicDirectory(),
        _defaultSubfolder,
      );
    } catch (e) {
      debugPrint('No se pudo consultar la carpeta Music: $e');
    }
    await restore();
  }

  /// Vuelve a abrir la última carpeta usada y deja lista (en pausa) la
  /// canción donde se quedó. Si algo falla se arranca sin carpeta.
  Future<void> restore() async {
    try {
      // Se lee antes de abrir la carpeta: abrirla cambia la canción actual
      // y eso sobrescribiría lo guardado.
      final resume = PlaybackState.decode(
        await NativeBridge.getSetting(_playbackKey),
      );
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
      await openFolder(
        saved,
        uri: await NativeBridge.getSetting(_folderUriKey),
        resume: resume,
      );
    } catch (e) {
      debugPrint('No se pudo restaurar la carpeta guardada: $e');
    }
  }

  /// Carga todas las canciones de [path] (más recientes primero) y la guarda
  /// como carpeta de la app. [uri] es el permiso de escritura del selector.
  /// Con [resume], deja seleccionada esa canción en esa posición.
  Future<void> openFolder(
    String path, {
    String? uri,
    PlaybackState? resume,
  }) async {
    loading = true;
    notifyListeners();
    try {
      await Directory(path).create(recursive: true);
      final files = await findAudioFiles(path);
      final found = [
        for (final f in files)
          Track(
            file: f,
            modified: await f.lastModified(),
            loudness: await normalizer.cached(f),
          ),
      ]..sort((a, b) => b.modified.compareTo(a.modified));

      final album = p.basename(path);
      final sources = [for (final t in found) _sourceFor(t, album)];
      final resumeIndex = resume == null
          ? -1
          : found.indexWhere((t) => t.file.path == resume.path);

      if (resumeIndex >= 0) {
        debugPrint('Restaurar: retomando ${found[resumeIndex].title}');
        try {
          // preload: true carga la canción (en pausa) para que el mini
          // reproductor aparezca listo para continuar.
          await player.setAudioSources(
            sources,
            initialIndex: resumeIndex,
            initialPosition: resume!.position,
          );
        } on PlayerException {
          await player.setAudioSources(sources, preload: false);
        }
        await player.setShuffleModeEnabled(resume!.shuffle);
        await player.setLoopMode(resume.loopMode);
      } else {
        await player.setAudioSources(sources, preload: false);
      }

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
    _loadMetadata(tracks);
  }

  /// Vuelve a escanear la carpeta actual.
  Future<void> reload() async {
    if (folder != null) await openFolder(folder!, uri: folderUri);
  }

  /// Copia [source] a la carpeta de la biblioteca como [fileName] y lo agrega
  /// al inicio de la lista sin cortar lo que esté sonando.
  ///
  /// [sourceId] identifica el contenido de origen (el id del video) para
  /// detectar duplicados con [findDownloaded].
  Future<File> saveDownloadedAudio(
    File source, {
    required String fileName,
    required String mimeType,
    String? sourceId,
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
    if (sourceId != null) await downloads.add(sourceId, savedPath);
    return file;
  }

  /// Archivo ya descargado del contenido [sourceId], si existe.
  ///
  /// Para audios descargados antes de que existiera el historial, también
  /// compara con [title] (el nombre de archivo que se le daría): si en la
  /// biblioteca hay uno igual, probablemente es el mismo.
  Future<File?> findDownloaded(String sourceId, {String? title}) async {
    final path = await downloads.existingPath(sourceId);
    if (path != null) return File(path);
    if (title == null || title.isEmpty) return null;
    final wanted = title.toLowerCase();
    for (final track in tracks) {
      if (track.title.toLowerCase() == wanted) return track.file;
    }
    return null;
  }

  /// Guarda la canción actual y su posición para retomarla al reabrir la app.
  Future<void> savePlaybackState() async {
    // Mientras se carga una carpeta, el índice actual y la lista no coinciden.
    if (loading) return;
    final track = currentTrack;
    if (track == null) return;
    final state = PlaybackState(
      path: track.file.path,
      position: player.position,
      shuffle: player.shuffleModeEnabled,
      loopMode: player.loopMode,
    );
    try {
      await NativeBridge.setSetting(_playbackKey, state.encode());
    } catch (e) {
      debugPrint('No se pudo guardar la posición: $e');
    }
  }

  Future<void> playTrack(int index) async {
    await player.seek(Duration.zero, index: index);
    player.play();
  }

  /// Cambia el nombre visible de [track] a [newTitle] (sin extensión).
  Future<void> renameTrack(Track track, String newTitle) async {
    final title = newTitle.trim();
    if (title.isEmpty) {
      throw StorageException('El nombre no puede estar vacío.');
    }
    if (RegExp(r'[\\/:*?"<>|]').hasMatch(title)) {
      throw StorageException(r'El nombre no puede tener \ / : * ? " < > |');
    }
    if (title == track.title) return;

    final oldPath = track.file.path;
    final dir = p.dirname(oldPath);
    final newName = '$title${p.extension(oldPath)}';
    // En el almacenamiento de Android "Audio" y "audio" son el mismo nombre:
    // solo se valida si el cambio no es únicamente de mayúsculas.
    final onlyCase = title.toLowerCase() == track.title.toLowerCase();
    if (!onlyCase && await File(p.join(dir, newName)).exists()) {
      throw StorageException('Ya existe un audio con ese nombre.');
    }

    String newPath;
    try {
      if (folderUri != null) {
        final finalName = await NativeBridge.renameInFolder(
          treeUri: folderUri!,
          folder: folder!,
          path: oldPath,
          newName: newName,
        );
        newPath = p.join(dir, finalName);
      } else {
        newPath = (await track.file.rename(p.join(dir, newName))).path;
      }
    } catch (e) {
      throw StorageException(
        'No se pudo renombrar. Si la carpeta se eligió hace tiempo, '
        'vuelve a elegirla en Configuración.',
      );
    }

    await NativeBridge.scanFile(oldPath); // lo quita del índice del sistema
    await NativeBridge.scanFile(newPath);

    final renamed = Track(
      file: File(newPath),
      modified: track.modified,
      duration: track.duration,
      loudness: track.loudness,
    );
    await _replaceTrack(track, renamed);
    await normalizer.moved(oldPath, renamed.file, renamed.loudness);
    await downloads.moved(oldPath, newPath);
    await savePlaybackState(); // por si era la canción actual
  }

  /// Borra el archivo de [track] del teléfono y lo quita de la lista.
  Future<void> deleteTrack(Track track) async {
    final index = tracks.indexOf(track);
    if (index < 0) return;
    final path = track.file.path;

    try {
      if (folderUri != null) {
        await NativeBridge.deleteFromFolder(
          treeUri: folderUri!,
          folder: folder!,
          path: path,
        );
      } else {
        await track.file.delete();
      }
    } catch (e) {
      throw StorageException(
        'No se pudo eliminar. Si la carpeta se eligió hace tiempo, '
        'vuelve a elegirla en Configuración.',
      );
    }

    await NativeBridge.scanFile(path);
    await player.removeAudioSourceAt(index);
    tracks = [...tracks]..removeAt(index);
    notifyListeners();
    await normalizer.forget(path);
    await downloads.removed(path);
  }

  /// Abre el menú "Compartir" para enviar el audio a otra app.
  Future<void> shareTrack(Track track) {
    return NativeBridge.shareFile(
      track.file.path,
      _mimeTypes[p.extension(track.file.path).toLowerCase()] ?? 'audio/*',
    );
  }

  /// Activa o desactiva la nivelación y la aplica a la canción actual.
  Future<void> setNormalizeVolume(bool enabled) {
    return normalizer.setEnabled(
      enabled,
      currentLoudness: currentTrack?.loudness,
    );
  }

  Future<void> _addTrack(File file) async {
    final track = Track(file: file, modified: await file.lastModified());
    await player.insertAudioSource(0, _sourceFor(track, p.basename(folder!)));
    tracks = [track, ...tracks];
    notifyListeners();
    _loadMetadata([track]);
  }

  /// Reemplaza [old] por [updated] en la misma posición de la lista y del
  /// reproductor. Si era la canción actual, retoma desde el mismo punto.
  Future<void> _replaceTrack(Track old, Track updated) async {
    final index = tracks.indexOf(old);
    if (index < 0) return;

    final wasCurrent = player.currentIndex == index;
    final position = player.position;
    final wasPlaying = player.playing;

    await player.removeAudioSourceAt(index);
    await player.insertAudioSource(
      index,
      _sourceFor(updated, p.basename(folder!)),
    );
    tracks = [...tracks]..[index] = updated;
    notifyListeners();

    if (wasCurrent) {
      await player.seek(position, index: index);
      if (wasPlaying) player.play();
    }
  }

  AudioSource _sourceFor(Track track, String album) {
    return AudioSource.file(
      track.file.path,
      // El MediaItem es lo que muestran la notificación, la pantalla de
      // bloqueo y los dispositivos Bluetooth.
      tag: MediaItem(id: track.file.path, title: track.title, album: album),
    );
  }

  Future<void> _applyVolume() => normalizer.apply(currentTrack?.loudness);

  /// Primero las duraciones (rápido, para la lista) y después la sonoridad
  /// (más lento, para la nivelación).
  Future<void> _loadMetadata(List<Track> pending) async {
    await _loadDurations(pending);
    await normalizer.analyze([for (final t in pending) t.file], (file, value) {
      for (final t in tracks) {
        if (t.file.path == file.path) t.loudness = value;
      }
      if (currentTrack?.file.path == file.path) _applyVolume();
    });
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
          chunk[j].duration = ms == null
              ? Duration.zero
              : Duration(milliseconds: ms);
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
    _saveTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    normalizer.dispose();
    player.dispose();
    super.dispose();
  }
}

const _mimeTypes = {
  '.mp3': 'audio/mpeg',
  '.m4a': 'audio/mp4',
  '.aac': 'audio/aac',
  '.wav': 'audio/wav',
  '.ogg': 'audio/ogg',
  '.oga': 'audio/ogg',
  '.opus': 'audio/opus',
  '.flac': 'audio/flac',
};

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
