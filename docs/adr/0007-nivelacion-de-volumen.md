# ADR-0007: Nivelación de volumen con medición propia y `AndroidLoudnessEnhancer`

**Estado:** Aceptada

## Contexto
Los audios de TikTok tienen volúmenes muy dispares y no traen metadatos de ganancia (ReplayGain). `just_audio` en Android ofrece `setVolume`, que ExoPlayer limita a 0–1, y el efecto `AndroidLoudnessEnhancer`, que amplifica en dB.

## Decisión
- Medir la sonoridad de cada archivo en Kotlin (`LoudnessAnalyzer`): decodificar a PCM y calcular la energía media en bloques de 400 ms, descartando los bloques de menos de −60 dBFS. Es una aproximación a LUFS sin el filtro K.
- Guardar las mediciones en una caché JSON con la clave `ruta|tamaño|fecha`.
- Al cambiar de pista, llevar cada audio a −14 dBFS: **bajar** con `setVolume` (mínimo 0,1) o **subir** con `AndroidLoudnessEnhancer` (máximo +8 dB).
- Activado por defecto, con un interruptor en Configuración.

Explicación completa: [guía de nivelación de volumen](../guides/nivelacion-de-volumen.md).

## Alternativas consideradas
- **Solo `AndroidLoudnessEnhancer` con ganancia fija:** sube todo por igual; no reduce las diferencias entre audios.
- **Normalizar el archivo al descargarlo** (recodificar): requiere un codificador (ffmpeg), pierde calidad y no sirve para los archivos que ya existen.
- **Etiquetas ReplayGain:** ExoPlayer no las aplica automáticamente y escribirlas en MP4 requiere una biblioteca de metadatos.
- **LUFS completo con filtro K:** más preciso, pero más código para una mejora poco perceptible en este uso.

## Consecuencias
- ✅ Sin dependencias nuevas; funciona con los archivos existentes y con los nuevos.
- ✅ Cada archivo se mide una sola vez.
- ⚠️ El primer análisis de una biblioteca grande tarda (se muestra "Analizando volumen…" y no bloquea el uso).
- ⚠️ Solo Android.
- ⚠️ Mientras un audio no está medido, suena a volumen normal.
