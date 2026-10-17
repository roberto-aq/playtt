import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:prueba_reproductor/playback_state.dart';

void main() {
  group('PlaybackState', () {
    test('se guarda y se recupera igual', () {
      const state = PlaybackState(
        path: '/storage/emulated/0/TikTok Gym/audio.m4a',
        position: Duration(minutes: 1, seconds: 23),
        shuffle: true,
        loopMode: LoopMode.one,
      );
      final restored = PlaybackState.decode(state.encode())!;
      expect(restored.path, state.path);
      expect(restored.position, state.position);
      expect(restored.shuffle, isTrue);
      expect(restored.loopMode, LoopMode.one);
    });

    test('sin nada guardado devuelve null', () {
      expect(PlaybackState.decode(null), isNull);
    });

    test('un valor corrupto devuelve null en vez de fallar', () {
      expect(PlaybackState.decode('{no es json'), isNull);
      expect(PlaybackState.decode('{"positionMs": 10}'), isNull);
    });

    test('valores ausentes toman su valor por defecto', () {
      final state = PlaybackState.decode('{"path": "/a.m4a"}')!;
      expect(state.position, Duration.zero);
      expect(state.shuffle, isFalse);
      expect(state.loopMode, LoopMode.off);
    });
  });
}
