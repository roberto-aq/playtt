# Solución de problemas

Problemas encontrados durante el desarrollo, con su causa y su solución.

## Errores

### `PlatformException(channel-error, Unable to establish connection on channel: "…")`
**Causa:** el código Dart llama a un plugin cuyo lado nativo no responde. Pasa en dos casos:
- se agregó un paquete y se aplicó un hot reload o hot restart en lugar de una compilación completa;
- históricamente, `shared_preferences` dejaba de responder tras un hot restart en combinación con `audio_service` ([ADR-0002](adr/0002-ajustes-con-canal-nativo.md)).

**Solución:** compilación completa ([guía](development.md#hot-reload-vs-compilación-completa)). `shared_preferences` ya no forma parte del proyecto.

### MissingPluginException
Mensaje completo: `MissingPluginException(No implementation found for method …)`.

**Causa:** el APK instalado es anterior al código Dart: se llama a un método del canal nativo que esa compilación todavía no tiene. Señal típica: el número de proceso (`I/flutter (14127)`) no cambia entre ejecuciones.

**Solución:** ⏹ → forzar la detención de la app → **F5**. Confirma que aparezca `Running Gradle task 'assembleDebug'`.

### `Building with plugins requires symlink support`
**Causa:** Windows sin Modo de desarrollador.
**Solución:** `start ms-settings:developers` y activarlo.

### Error de Gradle en `permission_handler_android` (`Unresolved reference: compilerOptions`)
**Causa:** `permission_handler` 13.x requiere una versión de AGP o Kotlin más nueva que la del proyecto.
**Solución:** mantener `permission_handler: 12.0.1` hasta actualizar AGP.

## Carpetas y almacenamiento

### "No se pudo guardar en … Vuelve a elegir la carpeta en Configuración"
**Causa:** la carpeta no tiene permiso de escritura SAF. Pasa con carpetas guardadas antes de la versión que lo introdujo, o si el permiso se revocó.
**Solución:** **Configuración → Cambiar Carpeta** y elegir la carpeta de nuevo.

### La carpeta no se recuerda al reabrir la app
Revisa la línea `Restaurar:` en la consola:

| Mensaje | Causa |
|---|---|
| `no hay carpeta guardada` | Nunca se guardó (o el APK es viejo: ver `MissingPluginException`) |
| `la carpeta guardada ya no existe` | Se borró o se renombró |
| `falta el permiso de audio` | Se revocó en Ajustes del sistema |

### El selector de carpetas no devuelve nada
Filtra la consola por `Reproductor`:

| Mensaje | Significa |
|---|---|
| Solo `pickFolder: abriendo el selector` | El resultado no volvió a la app |
| `resultado=0 uri=null` | Se canceló el selector |
| `resultado=-1 … ruta=null` | La carpeta no es local (p. ej. de una nube) |

## Descargas

### "No se pudo encontrar el video. Verifica el enlace."
- El enlace está mal copiado, el video es privado o fue eliminado.
- tikwm.com puede limitar la cantidad de peticiones; espera unos minutos.

### "Ocurrió un problema conectando con el servidor."
Sin conexión, o tikwm.com no responde en 20 segundos.

## Mensajes de consola inofensivos

| Mensaje | Explicación |
|---|---|
| `D/permissions_handler: No permissions found in manifest for: []33` | El código 33 es `READ_MEDIA_AUDIO` (Android 13+). En versiones anteriores no existe; se usa el permiso de almacenamiento |
| `W/libc: Access denied finding property "vendor.oplus.…"` | El sistema del fabricante (Oppo / OnePlus / Realme) intenta leer un ajuste interno que Android no le permite a la app. Pasa en cualquier app multimedia |
| `hiddenapi: Accessing hidden method … allowed` | Aviso interno de AndroidX; está permitido |
| `I/OpenGLRenderer: Davey! duration=…` | Un fotograma tardó mucho. Normal mientras hay un diálogo del sistema abierto o en modo debug |
| `OMX.qcom.video.decoder.avc 576x1024` | El archivo que suena **contiene video**: típico de los archivos heredados de la versión React Native. Funciona, pero consume más batería |
