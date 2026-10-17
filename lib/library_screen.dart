import 'package:flutter/material.dart';

import 'library_controller.dart';
import 'theme.dart';
import 'track_actions.dart';

class LibraryScreen extends StatefulWidget {
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
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  LibraryController get library => widget.library;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (library.loading) {
      body = const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    } else if (library.tracks.isEmpty) {
      body = _EmptyState(
        hasFolder: library.folder != null,
        onChooseFolder: widget.onChooseFolder,
      );
    } else {
      body = _TrackList(
        library: library,
        query: _query,
        onTrackTap: widget.onTrackTap,
      );
    }

    return Column(
      children: [
        _Header(
          library: library,
          search: library.tracks.isEmpty
              ? null
              : _SearchField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                ),
        ),
        Expanded(child: body),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.library, this.search});

  final LibraryController library;
  final Widget? search;

  @override
  Widget build(BuildContext context) {
    final String? busy = library.loadingDurations
        ? 'Cargando...'
        : library.normalizer.analyzing
        ? 'Analizando volumen...'
        : null;

    return Container(
      color: AppColors.header,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 20,
        20,
        search == null ? 20 : 14,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Biblioteca',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              if (busy != null) _BusyChip(label: busy),
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
          if (search != null) ...[const SizedBox(height: 14), search!],
        ],
      ),
    );
  }
}

class _BusyChip extends StatelessWidget {
  const _BusyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Buscar en la biblioteca',
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
        suffixIcon: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => controller.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _TrackList extends StatelessWidget {
  const _TrackList({
    required this.library,
    required this.query,
    required this.onTrackTap,
  });

  final LibraryController library;
  final String query;
  final ValueChanged<int> onTrackTap;

  @override
  Widget build(BuildContext context) {
    final tracks = library.tracks;
    // Se guarda el índice real: el reproductor usa la lista completa.
    final needle = foldForSearch(query.trim());
    final visible = [
      for (var i = 0; i < tracks.length; i++)
        if (needle.isEmpty || foldForSearch(tracks[i].title).contains(needle))
          i,
    ];

    if (visible.isEmpty) {
      return Center(
        child: Text(
          'Ningún audio coincide con "$query"',
          style: const TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return StreamBuilder<int?>(
      stream: library.player.currentIndexStream,
      builder: (context, snapshot) {
        final current = snapshot.data;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: visible.length,
          itemBuilder: (context, position) {
            final i = visible[position];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TrackCard(
                track: tracks[i],
                isCurrent: i == current,
                onTap: () => onTrackTap(i),
                onLongPress: () =>
                    showTrackActions(context, library, tracks[i]),
              ),
            );
          },
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
    required this.onLongPress,
  });

  final Track track;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

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
        onLongPress: onLongPress,
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

/// Texto en minúsculas y sin tildes, para que "cancion" encuentre "Canción".
String foldForSearch(String text) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  final lower = text.toLowerCase();
  final out = StringBuffer();
  for (final char in lower.split('')) {
    final i = from.indexOf(char);
    out.write(i < 0 ? char : to[i]);
  }
  return out.toString();
}
