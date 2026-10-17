import 'package:flutter_test/flutter_test.dart';
import 'package:prueba_reproductor/library_screen.dart';
import 'package:prueba_reproductor/tiktok_service.dart';

void main() {
  group('foldForSearch', () {
    test('ignora mayúsculas y tildes', () {
      expect(foldForSearch('Canción ÑANDÚ'), 'cancion nandu');
    });

    test('permite buscar "cancion" dentro de "Mi Canción"', () {
      expect(
        foldForSearch('Mi Canción').contains(foldForSearch('cancion')),
        isTrue,
      );
    });
  });

  group('extractTikTokUrl', () {
    test('saca el enlace del texto que comparte TikTok', () {
      expect(
        extractTikTokUrl(
          'Mira el video de X en TikTok! #fyp https://vt.tiktok.com/ZSgju8QE6/',
        ),
        'https://vt.tiktok.com/ZSgju8QE6/',
      );
    });

    test('acepta enlaces largos con parámetros', () {
      const url = 'https://www.tiktok.com/@user/video/123?is_from_webapp=1';
      expect(extractTikTokUrl(url), url);
    });

    test('devuelve null si no hay enlace de TikTok', () {
      expect(extractTikTokUrl('https://youtube.com/watch?v=x'), isNull);
    });
  });

  group('cleanFileName', () {
    test('quita emojis, hashtags y puntos finales', () {
      expect(
        cleanFileName('vuelve a levantarte...🫵 #fyp'),
        'vuelve a levantarte',
      );
    });

    test('conserva tildes y ñ', () {
      expect(cleanFileName('Canción del año'), 'Canción del año');
    });

    test('queda vacío si el título solo tiene hashtags', () {
      expect(cleanFileName('#fyp #parati'), isEmpty);
    });

    test('recorta a 60 caracteres', () {
      expect(cleanFileName('a' * 100).length, 60);
    });
  });
}
