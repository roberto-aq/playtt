import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'theme.dart';

/// Barra flotante sobre las pestañas con la canción actual. Al tocarla abre
/// el reproductor completo.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.player, required this.onTap});

  final AudioPlayer player;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Mientras el reproductor está "idle" todavía no se tocó ninguna canción.
    return StreamBuilder<ProcessingState>(
      stream: player.processingStateStream,
      builder: (context, stateSnap) {
        if ((stateSnap.data ?? ProcessingState.idle) == ProcessingState.idle) {
          return const SizedBox.shrink();
        }
        return _buildBar();
      },
    );
  }

  Widget _buildBar() {
    return StreamBuilder<SequenceState?>(
      stream: player.sequenceStateStream,
      builder: (context, snapshot) {
        final item = snapshot.data?.currentSource?.tag as MediaItem?;
        if (item == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: Material(
            color: AppColors.iconBackground,
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                height: 60,
                child: Column(
                  children: [
                    _ThinProgress(player: player),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.purple,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(Icons.music_note, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    'Reproduciendo ahora',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFCCCCCC),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StreamBuilder<bool>(
                              stream: player.playingStream,
                              builder: (context, snap) {
                                final playing = snap.data ?? false;
                                return IconButton(
                                  icon: Icon(
                                    playing ? Icons.pause : Icons.play_arrow,
                                  ),
                                  onPressed:
                                      playing ? player.pause : player.play,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ThinProgress extends StatelessWidget {
  const _ThinProgress({required this.player});

  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final total = player.duration ?? Duration.zero;
        final value = total.inMilliseconds == 0
            ? 0.0
            : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
        return LinearProgressIndicator(
          value: value,
          minHeight: 2,
          color: AppColors.accent,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
        );
      },
    );
  }
}
