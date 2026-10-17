import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'library_controller.dart';
import 'theme.dart';
import 'tiktok_service.dart';

class DownloaderScreen extends StatefulWidget {
  const DownloaderScreen({
    super.key,
    required this.library,
    required this.service,
    required this.sharedLink,
  });

  final LibraryController library;
  final TikTokService service;

  /// Enlaces recibidos desde el menú "Compartir". La pantalla los procesa
  /// automáticamente y vuelve a dejar el valor en `null`.
  final ValueNotifier<String?> sharedLink;

  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> {
  final _urlController = TextEditingController();

  TikTokVideo? _video;

  /// Nombre del audio si este video ya se había descargado.
  String? _existingTitle;
  bool _processing = false;
  bool _downloading = false;

  /// `null` mientras no se conoce el tamaño total de la descarga.
  double? _progress;

  /// Etapa actual: "Descargando...", "Extrayendo audio...", "Guardando...".
  String _status = '';

  @override
  void initState() {
    super.initState();
    // Para mostrar u ocultar el botón de borrar.
    _urlController.addListener(() => setState(() {}));
    widget.sharedLink.addListener(_onSharedLink);
    // Por si el enlace llegó antes de que esta pantalla existiera.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSharedLink());
  }

  @override
  void dispose() {
    widget.sharedLink.removeListener(_onSharedLink);
    _urlController.dispose();
    super.dispose();
  }

  /// Pone el enlace compartido en el campo y lo procesa, como si el usuario
  /// lo hubiera pegado y tocado "Procesar Link".
  void _onSharedLink() {
    final url = widget.sharedLink.value;
    if (url == null || !mounted) return;
    widget.sharedLink.value = null;

    if (_processing || _downloading) {
      showMessage(context, 'Espera a que termine el proceso actual.');
      return;
    }
    _urlController.text = url;
    _processLink();
  }

  Future<void> _processLink() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      showAppAlert(
        context,
        'Link Requerido',
        'Por favor pega un enlace de TikTok primero.',
      );
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() {
      _processing = true;
      _video = null;
      _existingTitle = null;
    });
    try {
      final video = await widget.service.fetchVideo(url);
      final existing = await widget.library.findDownloaded(
        video.id,
        title: cleanFileName(video.title),
      );
      if (mounted) {
        setState(() {
          _video = video;
          _existingTitle = existing == null
              ? null
              : p.basenameWithoutExtension(existing.path);
        });
      }
    } catch (e) {
      if (mounted) showAppAlert(context, 'Error', '$e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _extractAudio() async {
    final video = _video;
    final folder = widget.library.folder;
    if (video == null) return;
    if (folder == null) {
      showAppAlert(
        context,
        'Sin carpeta',
        'Elige primero una carpeta en Configuración.',
      );
      return;
    }

    setState(() {
      _downloading = true;
      _progress = null;
      _status = 'Descargando...';
    });
    try {
      final audio = await widget.service.downloadAudio(
        video,
        onProgress: (stage, progress) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
            _status = switch (stage) {
              DownloadStage.downloading => 'Descargando...',
              DownloadStage.extracting => 'Extrayendo audio...',
            };
          });
        },
      );

      setState(() {
        _progress = null;
        _status = 'Guardando...';
      });
      try {
        await widget.library.saveDownloadedAudio(
          audio.file,
          fileName: audio.fileName,
          mimeType: audio.mimeType,
          sourceId: video.id,
        );
      } finally {
        await audio.delete();
      }

      if (!mounted) return;
      setState(() {
        _video = null;
        _existingTitle = null;
        _urlController.clear();
      });
      await showAppAlert(
        context,
        'Guardado',
        'Audio guardado en tu carpeta seleccionada.',
      );
    } catch (e) {
      if (mounted) showAppAlert(context, 'Error', '$e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _processing || _downloading;

    return GradientBackground(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 10),
            const Icon(Icons.tiktok, size: 40, color: Colors.white),
            const SizedBox(height: 10),
            const Text(
              'Audio Extractor',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Descarga el audio completo (Voces + Música)',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 30),
            _UrlField(controller: _urlController, enabled: !busy),
            const SizedBox(height: 20),
            _PinkButton(
              loading: _processing,
              onPressed: busy ? null : _processLink,
              label: 'Procesar Link',
            ),
            const SizedBox(height: 30),
            if (_video != null)
              _ResultCard(
                video: _video!,
                downloading: _downloading,
                progress: _progress,
                status: _status,
                existingTitle: _existingTitle,
                onExtract: _extractAudio,
              ),
          ],
        ),
      ),
    );
  }
}

class _UrlField extends StatelessWidget {
  const _UrlField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.inputBorder),
    );

    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.url,
      autocorrect: false,
      // Igual que el buscador: tocar fuera le quita el foco y cierra el teclado.
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        hintText: 'https://vm.tiktok.com/...',
        hintStyle: const TextStyle(color: Color(0xFF999999)),
        filled: true,
        fillColor: AppColors.input,
        contentPadding: const EdgeInsets.all(15),
        border: border,
        enabledBorder: border,
        disabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : ClearFieldButton(onPressed: controller.clear),
      ),
    );
  }
}

class _PinkButton extends StatelessWidget {
  const _PinkButton({
    required this.loading,
    required this.onPressed,
    required this.label,
  });

  final bool loading;
  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: loading
              ? AppColors.accent.withValues(alpha: 0.5)
              : const Color(0xFF555555),
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        child: loading
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.video,
    required this.downloading,
    required this.progress,
    required this.status,
    required this.existingTitle,
    required this.onExtract,
  });

  final TikTokVideo video;
  final bool downloading;
  final double? progress;
  final String status;

  /// Nombre del audio si ya se había descargado; `null` si es nuevo.
  final String? existingTitle;
  final VoidCallback onExtract;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox.square(
                  dimension: 80,
                  child: video.coverUrl == null
                      ? const ColoredBox(
                          color: AppColors.inputBorder,
                          child: Icon(Icons.music_video, color: Colors.white54),
                        )
                      : Image.network(
                          video.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: AppColors.inputBorder),
                        ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title.isEmpty ? 'Video de TikTok' : video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Autor: ${video.author.isEmpty ? 'Unknown' : video.author}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFFCCCCCC)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (existingTitle != null) ...[
            const SizedBox(height: 15),
            _DuplicateNotice(title: existingTitle!),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: downloading ? null : onExtract,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.success.withValues(alpha: 0.6),
              disabledForegroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: downloading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        progress == null
                            ? status
                            : '$status ${(progress! * 100).round()}%',
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.music_note_outlined),
                      const SizedBox(width: 10),
                      Text(
                        existingTitle == null
                            ? 'Extraer Audio Completo'
                            : 'Descargar otra vez',
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Aviso de que el video ya está en la biblioteca.
class _DuplicateNotice extends StatelessWidget {
  const _DuplicateNotice({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFFFB74D);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Ya tienes este audio: '),
                  TextSpan(
                    text: title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              style: const TextStyle(color: amber, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
