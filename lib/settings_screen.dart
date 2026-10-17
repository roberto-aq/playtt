import 'package:flutter/material.dart';

import 'library_controller.dart';
import 'theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.library,
    required this.onChangeFolder,
    required this.onRestore,
  });

  final LibraryController library;
  final VoidCallback onChangeFolder;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final folder = library.folder;

    return GradientBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.divider)),
              ),
              child: const Text(
                'Configuración',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Biblioteca de Música',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.folder, color: AppColors.accent),
                            SizedBox(width: 10),
                            Text(
                              'Carpeta Fuente',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Text(
                          folder ?? 'Ninguna carpeta seleccionada',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _SmallButton(
                              label: folder == null
                                  ? 'Seleccionar Carpeta'
                                  : 'Cambiar Carpeta',
                              color: AppColors.accent,
                              onPressed: library.loading
                                  ? null
                                  : onChangeFolder,
                            ),
                            if (folder != defaultMusicFolder)
                              _SmallButton(
                                label: 'Restaurar',
                                color: AppColors.danger,
                                onPressed: library.loading ? null : onRestore,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Los audios descargados de TikTok se guardan en esta misma '
                    'carpeta. "Restaurar" vuelve a Música/TikTok.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}
