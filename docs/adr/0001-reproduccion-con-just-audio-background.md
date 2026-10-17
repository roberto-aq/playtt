# ADR-0001: Reproducción en segundo plano con `just_audio_background`

**Estado:** Aceptada

## Contexto
El motivo principal para reescribir la app en Flutter fue que el reproductor de la versión React Native (`expo-audio`) no funcionaba bien. Además faltaban los controles del sistema: notificación con anterior / pausa / siguiente, pantalla de bloqueo y botones de auriculares Bluetooth.

En Android, esos controles requieren una `MediaSession` y un servicio en primer plano de tipo `mediaPlayback`.

## Decisión
Usar `just_audio` como motor (ExoPlayer en Android) y `just_audio_background` para la sesión multimedia. Este último está construido sobre `audio_service`.

- `MainActivity` hereda de `AudioServiceActivity`.
- El manifest declara el `AudioService` (`foregroundServiceType="mediaPlayback"`) y el `MediaButtonReceiver`.
- Cada canción lleva un `MediaItem` como `tag`; de ahí salen los datos que muestra el sistema.

## Alternativas consideradas
- **`audio_service` directamente:** da control total sobre los botones de la notificación, pero exige escribir un `AudioHandler` completo. Es innecesario para un reproductor de una sola lista.
- **`audioplayers`:** no integra la sesión multimedia del sistema.

## Consecuencias
- ✅ Notificación, pantalla de bloqueo y Bluetooth funcionan con muy poco código.
- ⚠️ `audio_service` crea y guarda en caché su propio `FlutterEngine`. Esto influye en cómo se comportan los plugins durante un hot restart (ver [ADR-0002](0002-ajustes-con-canal-nativo.md)).
- ⚠️ Solo admite **un** `AudioPlayer` en toda la app.
- ⚠️ El paquete sigue en *beta* (`0.0.1-beta.17`). Si se necesitan botones personalizados en la notificación, habrá que migrar a `audio_service` directamente.
