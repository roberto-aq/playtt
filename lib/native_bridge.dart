import 'package:flutter/services.dart';

/// Llamadas al código Kotlin de MainActivity (canal "prueba_reproductor/media").
abstract final class NativeBridge {
  static const _channel = MethodChannel('prueba_reproductor/media');

  /// Abre el selector de carpetas del sistema y guarda el permiso de
  /// escritura sobre la elegida. `null` si el usuario cancela.
  static Future<PickedFolder?> pickFolder() async {
    final result = await _channel.invokeMapMethod<String, String?>(
      'pickFolder',
    );
    if (result == null) return null;
    return PickedFolder(uri: result['uri']!, path: result['path']);
  }

  /// Copia [sourcePath] dentro de la carpeta [treeUri] y devuelve el nombre
  /// final del archivo (Android agrega " (1)" si ya existía uno igual).
  static Future<String> saveToFolder({
    required String treeUri,
    required String sourcePath,
    required String name,
    required String mimeType,
  }) async {
    final saved = await _channel.invokeMethod<String>('saveToFolder', {
      'treeUri': treeUri,
      'source': sourcePath,
      'name': name,
      'mime': mimeType,
    });
    return saved ?? name;
  }

  /// Renombra [path] dentro de la carpeta SAF [treeUri] (cuya ruta es
  /// [folder]) y devuelve el nombre final que asignó Android.
  static Future<String> renameInFolder({
    required String treeUri,
    required String folder,
    required String path,
    required String newName,
  }) async {
    final name = await _channel.invokeMethod<String>('renameInFolder', {
      'treeUri': treeUri,
      'folder': folder,
      'path': path,
      'newName': newName,
    });
    return name ?? newName;
  }

  /// Elimina [path] dentro de la carpeta SAF [treeUri].
  static Future<void> deleteFromFolder({
    required String treeUri,
    required String folder,
    required String path,
  }) {
    return _channel.invokeMethod('deleteFromFolder', {
      'treeUri': treeUri,
      'folder': folder,
      'path': path,
    });
  }

  /// Abre el menú "Compartir" del sistema para enviar el archivo a otra app.
  static Future<void> shareFile(String path, String mimeType) {
    return _channel.invokeMethod('shareFile', {'path': path, 'mime': mimeType});
  }

  /// Sonoridad de cada archivo en dBFS (`null` si no se pudo medir).
  /// Decodifica el audio completo: puede tardar ~0,5 s por archivo.
  static Future<List<double?>> measureLoudness(List<String> paths) async {
    final result = await _channel.invokeListMethod<double?>('measureLoudness', {
      'paths': paths,
    });
    return result ?? List.filled(paths.length, null);
  }

  /// Extrae la pista de audio de un MP4 a un .m4a sin recodificar.
  static Future<void> extractAudio(String input, String output) {
    return _channel.invokeMethod('extractAudio', {
      'input': input,
      'output': output,
    });
  }

  /// Avisa al sistema para que otras apps de música vean el archivo.
  static Future<void> scanFile(String path) {
    return _channel.invokeMethod('scanFile', {'path': path});
  }

  /// Duraciones en milisegundos (`null` si no se pudo leer).
  static Future<List<int?>> getDurations(List<String> paths) async {
    final result = await _channel.invokeListMethod<int?>('getDurations', {
      'paths': paths,
    });
    return result ?? List.filled(paths.length, null);
  }

  /// Entrega a [onText] cada texto que otra app comparte con esta (menú
  /// "Compartir"): el que abrió la app, si lo hubo, y los que lleguen
  /// mientras está abierta.
  ///
  /// Kotlin guarda el texto y solo avisa que hay uno nuevo; Dart lo pide con
  /// `takeSharedText`. Así no se pierde aunque llegue antes de que Dart esté
  /// escuchando (ver docs/guides/recibir-contenido-compartido.md).
  static Future<void> listenSharedText(
    void Function(String text) onText,
  ) async {
    Future<void> take() async {
      final text = await _channel.invokeMethod<String>('takeSharedText');
      if (text != null && text.trim().isNotEmpty) onText(text);
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedTextAvailable') await take();
    });
    // Texto que llegó antes de registrar el handler (arranque en frío).
    await take();
  }

  /// Ruta de la carpeta pública Music del teléfono, según Android
  /// (normalmente /storage/emulated/0/Music).
  static Future<String> getMusicDirectory() async {
    return (await _channel.invokeMethod<String>('getMusicDirectory'))!;
  }

  static Future<String?> getSetting(String key) {
    return _channel.invokeMethod<String>('getSetting', {'key': key});
  }

  static Future<void> setSetting(String key, String? value) {
    return _channel.invokeMethod('setSetting', {'key': key, 'value': value});
  }
}

class PickedFolder {
  const PickedFolder({required this.uri, required this.path});

  /// URI con permiso de escritura (content://...tree/primary%3ATikTok%20Gym).
  final String uri;

  /// Ruta equivalente para leer los archivos, o `null` si la carpeta no está
  /// en el almacenamiento del teléfono (p. ej. Google Drive).
  final String? path;
}
