import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'native_bridge.dart';

/// Datos mínimos de un video para mostrarlo y guardar su audio.
class TikTokVideo {
  const TikTokVideo({
    required this.id,
    required this.title,
    required this.author,
    required this.videoUrl,
    this.coverUrl,
  });

  final String id;
  final String title;
  final String author;
  final String? coverUrl;

  /// Video sin marca de agua; de aquí sale el audio completo (voces + música).
  final String videoUrl;
}

/// Audio ya extraído, todavía en la carpeta temporal de la app.
class DownloadedAudio {
  const DownloadedAudio({
    required this.file,
    required this.fileName,
    required this.mimeType,
  });

  final File file;

  /// Nombre sugerido para guardarlo, con extensión ("Mi audio.m4a").
  final String fileName;
  final String mimeType;

  Future<void> delete() async {
    if (await file.exists()) await file.delete();
  }
}

enum DownloadStage { downloading, extracting }

/// Error con un mensaje listo para mostrar al usuario.
class TikTokException implements Exception {
  TikTokException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Contrato de la descarga de TikTok. La pantalla Descargar solo conoce
/// esta interfaz; dónde se guarda el archivo lo decide LibraryController.
abstract interface class TikTokService {
  /// Obtiene los datos del video a partir de un enlace de TikTok
  /// (vm.tiktok.com, vt.tiktok.com, www.tiktok.com/@user/video/...).
  Future<TikTokVideo> fetchVideo(String url);

  /// Descarga el video y extrae su audio a un archivo temporal.
  /// [onProgress] recibe la etapa y un valor de 0 a 1 (o `null` si no se
  /// conoce el total).
  Future<DownloadedAudio> downloadAudio(
    TikTokVideo video, {
    void Function(DownloadStage stage, double? progress)? onProgress,
  });
}

/// Implementación con la API pública de tikwm.com (la misma que usaba la
/// versión en React Native).
class TikwmService implements TikTokService {
  static const _api = 'https://www.tikwm.com';
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/126.0 Mobile Safari/537.36';

  @override
  Future<TikTokVideo> fetchVideo(String url) async {
    final uri = Uri.parse('$_api/api/').replace(queryParameters: {'url': url});
    final http.Response response;
    try {
      response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 20));
    } on Exception {
      throw TikTokException('Ocurrió un problema conectando con el servidor.');
    }
    if (response.statusCode != 200) {
      throw TikTokException('El servidor respondió ${response.statusCode}.');
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw TikTokException('Respuesta inválida del servidor.');
    }

    final data = body['data'];
    if (body['code'] != 0 || data is! Map<String, dynamic> || data['play'] == null) {
      throw TikTokException('No se pudo encontrar el video. Verifica el enlace.');
    }

    final author = data['author'] as Map<String, dynamic>?;
    return TikTokVideo(
      id: '${data['id']}',
      title: (data['title'] as String? ?? '').trim(),
      author: author?['nickname'] as String? ?? '',
      coverUrl: _absolute(data['cover'] as String?),
      videoUrl: _absolute(data['play'] as String)!,
    );
  }

  @override
  Future<DownloadedAudio> downloadAudio(
    TikTokVideo video, {
    void Function(DownloadStage stage, double? progress)? onProgress,
  }) async {
    final tmp = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final mp4 = File(p.join(tmp.path, 'tiktok_$stamp.mp4'));
    final m4a = File(p.join(tmp.path, 'tiktok_$stamp.m4a'));

    try {
      await _download(
        video.videoUrl,
        mp4,
        (v) => onProgress?.call(DownloadStage.downloading, v),
      );

      onProgress?.call(DownloadStage.extracting, null);
      final name = cleanFileName(video.title);
      final fileName = '${name.isEmpty ? 'tiktok_${video.id}' : name}.m4a';

      try {
        await NativeBridge.extractAudio(mp4.path, m4a.path);
        return DownloadedAudio(file: m4a, fileName: fileName, mimeType: 'audio/mp4');
      } on PlatformException {
        // Si el códec no se puede copiar tal cual, el MP4 completo igual se
        // reproduce como audio; se guarda con extensión .m4a.
        await mp4.rename(m4a.path);
        return DownloadedAudio(file: m4a, fileName: fileName, mimeType: 'audio/mp4');
      }
    } catch (_) {
      if (await m4a.exists()) await m4a.delete();
      rethrow;
    } finally {
      if (await mp4.exists()) await mp4.delete();
    }
  }

  Future<void> _download(
    String url,
    File target,
    void Function(double? progress) onProgress,
  ) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url))
        ..headers['User-Agent'] = _userAgent
        ..headers['Referer'] = '$_api/';
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw TikTokException('Falló la descarga (${response.statusCode}).');
      }

      final total = response.contentLength;
      var received = 0;
      final sink = target.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          onProgress(total == null || total == 0 ? null : received / total);
        }
      } finally {
        await sink.close();
      }
    } on SocketException {
      throw TikTokException('Se perdió la conexión durante la descarga.');
    } on http.ClientException {
      throw TikTokException('Se perdió la conexión durante la descarga.');
    } finally {
      client.close();
    }
  }

  /// tikwm a veces devuelve rutas relativas a su propio dominio.
  static String? _absolute(String? url) {
    if (url == null || url.isEmpty) return null;
    return url.startsWith('/') ? '$_api$url' : url;
  }
}

/// Convierte el título del video en un nombre de archivo válido: quita
/// hashtags, menciones, emojis y caracteres que Android no acepta.
String cleanFileName(String title) {
  var name = title
      .replaceAll(RegExp(r'[#@]\S+'), '')
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s_.,()!¡-]', unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (name.length > 60) name = name.substring(0, 60);
  // Sin puntos ni espacios al final ("levantarte..." → "levantarte").
  return name.replaceAll(RegExp(r'[.\s]+$'), '');
}
