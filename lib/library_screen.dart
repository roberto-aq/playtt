import 'package:flutter/material.dart';

import 'library_controller.dart';
import 'theme.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({
    super.key,
    required this.library,
    required this.onChooseFolder,
    required this.onTrackTap,
  });

  final LibraryController library;
  final VoidCallback onChooseFolder;
  final ValueChanged<int> onTrackTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(library: library),
        Expanded(
          child: library.loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                )
              : library.tracks.isEmpty
              ? _EmptyState(
                  hasFolder: library.folder != null,
                  onChooseFolder: onChooseFolder,
                )
              : _TrackList(library: library, onTrackTap: onTrackTap),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.library});

  final LibraryController library;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.header,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 20,
        20,
        20,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Biblioteca',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          if (library.loadingDurations)
            Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Cargando...',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          Material(
            color: Colors.white.withValues(alpha: 0.1),
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Recargar',
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: library.folder == null || library.loading
                  ? null
                  : library.reload,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackList extends StatelessWidget {
  const _TrackList({required this.library, required this.onTrackTap});

  final LibraryController library;
  final ValueChanged<int> onTrackTap;

  @override
  Widget build(BuildContext context) {
    final tracks = library.tracks;

    return StreamBuilder<int?>(
      stream: library.player.currentIndexStream,
      builder: (context, snapshot) {
        final current = snapshot.data;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tracks.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TrackCard(
              track: tracks[i],
              isCurrent: i == current,
              onTap: () => onTrackTap(i),
            ),
          ),
        );
      },
    );
  }
}

class TrackCard extends StatelessWidget {
  const TrackCard({
    super.key,
    required this.track,
    required this.isCurrent,
    required this.onTap,
  });

  final Track track;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const meta = TextStyle(fontSize: 12, color: AppColors.textSecondary);

    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCurrent ? Icons.graphic_eq : Icons.music_note,
                  color: isCurrent ? AppColors.accent : Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isCurrent ? AppColors.accent : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${track.duration == null ? '⏳' : formatDuration(track.duration!)}'
                      '  •  ${formatDate(track.modified)}',
                      style: meta,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.play_circle_outline,
                size: 28,
                color: AppColors.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFolder, required this.onChooseFolder});

  final bool hasFolder;
  final VoidCallback onChooseFolder;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.library_music_outlined,
              size: 60,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              hasFolder
                  ? 'Esta carpeta no tiene audios'
                  : 'No hay audios cargados',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 16),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onChooseFolder,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Text(hasFolder ? 'Cambiar carpeta' : 'Cargar Música'),
            ),
          ],
        ),
      ),
    );
  }
}
