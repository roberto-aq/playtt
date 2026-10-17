# ADR-0004: Extraer el audio con `MediaExtractor` + `MediaMuxer` (sin ffmpeg)

**Estado:** Aceptada

## Contexto
La API de TikTok entrega un video MP4 (H.264 + AAC). La versión React Native guardaba ese MP4 completo con extensión `.mp3`. Eso producía archivos varias veces más pesados de lo necesario, y el teléfono decodificaba un video que nadie veía: se observó `OMX.qcom.video.decoder.avc 576x1024` en la consola.

## Decisión
Extraer la pista de audio en Kotlin (`AudioExtractor.kt`):
1. `MediaExtractor` selecciona la primera pista `audio/*`.
2. `MediaMuxer` (formato MPEG-4) copia sus muestras **sin recodificar** a un `.m4a`.

Si la pista no se puede copiar tal cual, se guarda el MP4 completo con extensión `.m4a` como respaldo, para que la descarga no falle.

## Alternativas consideradas
- **`ffmpeg_kit_flutter`:** el proyecto original fue archivado y sus binarios añaden decenas de MB al APK.
- **Usar el MP3 de "sonido original" de la API:** solo contiene la música, no las voces del video; no cumple el requisito de "audio completo".
- **Recodificar con `MediaCodec`:** más lento, más código y pérdida de calidad, sin ninguna ventaja.

## Consecuencias
- ✅ Sin dependencias, archivos livianos, calidad original y menos de un segundo de proceso.
- ✅ Los archivos nuevos son solo audio: no se usa el decodificador de video.
- ⚠️ Solo Android.
- ⚠️ Depende de que el códec de audio sea compatible con el contenedor MP4. AAC lo es, y es lo que usa TikTok hoy.
