import 'package:flutter_test/flutter_test.dart';
import 'package:prueba_reproductor/volume_normalizer.dart';

void main() {
  group('VolumeNormalizer.adjustmentFor', () {
    const target = VolumeNormalizer.targetDb;

    test('sin medición deja el volumen normal', () {
      final a = VolumeNormalizer.adjustmentFor(null);
      expect(a.volume, 1.0);
      expect(a.boostDb, 0.0);
    });

    test('un audio ya en el objetivo no se toca', () {
      final a = VolumeNormalizer.adjustmentFor(target);
      expect(a.volume, 1.0);
      expect(a.boostDb, 0.0);
    });

    test('un audio fuerte se baja con setVolume y sin amplificar', () {
      // 6 dB por encima del objetivo → factor 10^(-6/20) ≈ 0,5.
      final a = VolumeNormalizer.adjustmentFor(target + 6);
      expect(a.volume, closeTo(0.501, 0.001));
      expect(a.boostDb, 0.0);
    });

    test('un audio bajo se amplifica en dB y el volumen queda al máximo', () {
      final a = VolumeNormalizer.adjustmentFor(target - 5);
      expect(a.volume, 1.0);
      expect(a.boostDb, closeTo(5, 1e-9));
    });

    test('la amplificación tiene un tope para no distorsionar', () {
      final a = VolumeNormalizer.adjustmentFor(target - 30);
      expect(a.boostDb, VolumeNormalizer.maxBoostDb);
    });

    test('el volumen nunca baja de 0,1 aunque el audio sea muy fuerte', () {
      final a = VolumeNormalizer.adjustmentFor(target + 40);
      expect(a.volume, 0.1);
    });
  });
}
