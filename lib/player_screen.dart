import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'library_controller.dart';
import 'theme.dart';

/// Reproductor a pantalla completa.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.library});

  final LibraryController library;

  /// Abre el reproductor deslizándose desde abajo.
  static Route<void> route(LibraryController library) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) => PlayerScreen(library: library),
      transitionsBuilder: (_, animation, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    );
  }

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  );
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final StreamSubscription<bool> _playing;

  AudioPlayer get player => widget.library.player;

  @override
  void initState() {
    super.initState();
    // El disco gira y "late" solo mientras suena.
    _playing = player.playingStream.listen((playing) {
      if (playing) {
        _spin.repeat();
        _pulse.repeat(reverse: true);
      } else {
        _spin.stop();
        _pulse.animateBack(0);
      }
    });
  }

  @override
  void dispose() {
    _playing.cancel();
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final albumSize = (size.width * 0.7).clamp(0.0, size.height * 0.35);

    return Scaffold(
      body: GradientBackground(
        colors: const [AppColors.header, AppColors.purple, AppColors.magenta],
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeader(context),
                ScaleTransition(
                  scale: Tween(begin: 1.0, end: 1.05).animate(_pulse),
                  child: RotationTransition(
                    turns: _spin,
                    child: Container(
                      width: albumSize,
                      height: albumSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.music_note, size: 80),
                    ),
                  ),
                ),
                _buildTrackInfo(),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: size.width * 0.075),
                  child: _SeekBar(player: player),
                ),
                _buildControls(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 35),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'Reproduciendo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildTrackInfo() {
    return StreamBuilder<SequenceState?>(
      stream: player.sequenceStateStream,
      builder: (context, snapshot) {
        final item = snapshot.data?.currentSource?.tag as MediaItem?;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              Text(
                item?.title ?? 'Sin canción',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                item?.album ?? 'Audio Local',
                style: const TextStyle(fontSize: 16, color: Color(0xFFCCCCCC)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    return StreamBuilder<SequenceState?>(
      stream: player.sequenceStateStream,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            StreamBuilder<bool>(
              stream: player.shuffleModeEnabledStream,
              builder: (context, snap) {
                final enabled = snap.data ?? false;
                return IconButton(
                  tooltip: 'Aleatorio',
                  iconSize: 28,
                  color: enabled ? AppColors.accent : Colors.white,
                  icon: const Icon(Icons.shuffle),
                  onPressed: () async {
                    if (!enabled) await player.shuffle();
                    await player.setShuffleModeEnabled(!enabled);
                  },
                );
              },
            ),
            IconButton(
              tooltip: 'Anterior',
              iconSize: 40,
              icon: const Icon(Icons.skip_previous),
              onPressed: player.hasPrevious ? player.seekToPrevious : null,
            ),
            _BigPlayButton(player: player),
            IconButton(
              tooltip: 'Siguiente',
              iconSize: 40,
              icon: const Icon(Icons.skip_next),
              onPressed: player.hasNext ? player.seekToNext : null,
            ),
            StreamBuilder<LoopMode>(
              stream: player.loopModeStream,
              builder: (context, snap) {
                final mode = snap.data ?? LoopMode.off;
                const next = {
                  LoopMode.off: LoopMode.all,
                  LoopMode.all: LoopMode.one,
                  LoopMode.one: LoopMode.off,
                };
                return IconButton(
                  tooltip: 'Repetir',
                  iconSize: 28,
                  color: mode == LoopMode.off ? Colors.white : AppColors.accent,
                  icon: Icon(
                    mode == LoopMode.one ? Icons.repeat_one : Icons.repeat,
                  ),
                  onPressed: () => player.setLoopMode(next[mode]!),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _BigPlayButton extends StatelessWidget {
  const _BigPlayButton({required this.player});

  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final processing = state?.processingState;
        final loading = processing == ProcessingState.loading ||
            processing == ProcessingState.buffering;
        final playing = state?.playing ?? false;

        final VoidCallback onPressed;
        final IconData icon;
        if (processing == ProcessingState.completed) {
          icon = Icons.replay;
          onPressed = () => player.seek(Duration.zero, index: 0);
        } else if (playing) {
          icon = Icons.pause;
          onPressed = player.pause;
        } else {
          icon = Icons.play_arrow;
          onPressed = player.play;
        }

        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Center(
                child: loading && playing
                    ? const SizedBox.square(
                        dimension: 28,
                        child: CircularProgressIndicator(color: Colors.black),
                      )
                    : Icon(icon, size: 40, color: Colors.black),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.player});

  final AudioPlayer player;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  /// Posición mientras el usuario arrastra, para que el slider no salte.
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: widget.player.durationStream,
      builder: (context, durationSnap) {
        final duration = durationSnap.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: widget.player.positionStream,
          builder: (context, positionSnap) {
            final position = positionSnap.data ?? Duration.zero;
            final max = duration.inMilliseconds.toDouble();
            final value = (_dragValue ?? position.inMilliseconds.toDouble())
                .clamp(0.0, max > 0 ? max : 0.0);
            const timeStyle = TextStyle(fontSize: 12, color: Color(0xFFCCCCCC));

            return Column(
              children: [
                Slider(
                  max: max > 0 ? max : 1,
                  value: max > 0 ? value : 0,
                  onChanged:
                      max > 0 ? (v) => setState(() => _dragValue = v) : null,
                  onChangeEnd: (v) {
                    widget.player.seek(Duration(milliseconds: v.round()));
                    setState(() => _dragValue = null);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatDuration(Duration(milliseconds: value.round())),
                        style: timeStyle,
                      ),
                      Text(formatDuration(duration), style: timeStyle),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
