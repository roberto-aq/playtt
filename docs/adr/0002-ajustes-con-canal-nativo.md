# ADR-0002: Guardar ajustes con el canal nativo en lugar de `shared_preferences`

**Estado:** Aceptada

## Contexto
La app solo necesita recordar dos textos: la ruta de la carpeta y su URI SAF. Se usaba `shared_preferences`, pero después de cada hot restart fallaba con:

```
PlatformException(channel-error, Unable to establish connection on channel:
"dev.flutter.pigeon.shared_preferences_android.SharedPreferencesApi.getAll")
```

En la misma sesión, `permission_handler` seguía respondiendo con normalidad. La diferencia observada es que `shared_preferences_android` atiende sus llamadas en un `TaskQueue` de segundo plano, y `audio_service` reutiliza un motor de Flutter en caché ([ADR-0001](0001-reproduccion-con-just-audio-background.md)). No se encontró un caso documentado idéntico; la causa exacta es una hipótesis basada en esa diferencia.

## Decisión
Quitar `shared_preferences` y guardar los ajustes con las `SharedPreferences` nativas de Android, mediante los métodos `getSetting` / `setSetting` del canal propio ([referencia](../native-bridge.md#getsetting--setsetting)).

## Alternativas consideradas
- **Mantener `shared_preferences` y no usar hot restart:** frágil e incómodo durante el desarrollo.
- **Archivo JSON con `dart:io`:** exige `path_provider` para ubicarlo; no aporta ventajas sobre el canal que ya existe.

## Consecuencias
- ✅ Una dependencia nativa menos y comportamiento estable tras un hot restart.
- ✅ Guardar la carpeta dejó de ser crítico: si falla, la carpeta se carga igual.
- ⚠️ Los ajustes solo existen en Android. Para soportar iOS habría que implementar estos métodos en Swift.
