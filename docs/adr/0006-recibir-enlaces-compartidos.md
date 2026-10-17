# ADR-0006: Recibir enlaces compartidos con código propio y `launchMode="singleTask"`

**Estado:** Aceptada

## Contexto
Para descargar un audio, el usuario tenía que copiar el enlace en TikTok, abrir la app, ir a Descargar, pegarlo y procesarlo. El objetivo es reducirlo a TikTok → *Compartir* → **PlayTT**.

Hay tres restricciones:
- **Sincronización:** Kotlin recibe el intent antes de que Dart registre sus handlers. Un aviso enviado en ese momento se pierde.
- **Instancias:** la actividad era `singleTop`, así que un intent de otra app crearía una segunda `MainActivity` dentro de la tarea de TikTok. Como `audio_service` comparte un único motor de Flutter en caché ([ADR-0001](0001-reproduccion-con-just-audio-background.md)), dos actividades competirían por él.
- **Alcance:** solo Android y solo texto.

## Decisión
- `intent-filter` con `ACTION_SEND` y `text/plain` en `MainActivity`, y `launchMode="singleTask"`.
- Manejar el intent en `onCreate` (en frío, solo si `savedInstanceState == null`) y en `onNewIntent` (en caliente), ignorando `FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY`.
- Patrón **guardar + avisar + pedir**: Kotlin guarda el texto en `pendingSharedText` y envía `sharedTextAvailable` sin datos. Dart pide el texto con `takeSharedText`, que lo entrega una sola vez. Dart también lo pide al arrancar.
- Extraer el enlace en Dart con `extractTikTokUrl` y entregarlo a la pestaña Descargar mediante un `ValueNotifier`.

Explicación completa: [guía de contenido compartido](../guides/recibir-contenido-compartido.md).

## Alternativas consideradas
- **Paquete `receive_sharing_intent`:** soporta iOS y archivos, pero agrega una dependencia nativa para unas 40 líneas de código. Además, cada dependencia nativa nueva ha sido fuente de problemas en este proyecto ([ADR-0002](0002-ajustes-con-canal-nativo.md)).
- **Actividad intermedia invisible** que reenvía a `MainActivity`: evita `singleTask`, pero agrega una actividad y obliga a cuidar el `taskAffinity=""` de la plantilla de Flutter.
- **Enviar el texto en el aviso (solo push):** se pierde en el arranque en frío.

## Consecuencias
- ✅ Compartir abre la app en Descargar con el video ya procesado, tanto con la app cerrada como abierta.
- ✅ Nunca hay dos instancias de `MainActivity`. El toque en la notificación de música también reutiliza la existente.
- ⚠️ Con `singleTask`, traer la app al frente cierra las actividades que estén encima en su tarea (p. ej. un selector de carpetas abierto).
- ⚠️ El canal Dart tiene ahora un handler de llamadas entrantes. Cualquier otro mensaje de Kotlin → Dart debe pasar por `NativeBridge` para no reemplazarlo.
- ⚠️ Solo Android. Para iOS habría que crear una *Share Extension* o adoptar el paquete.
