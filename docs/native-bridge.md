# Canal nativo `prueba_reproductor/media`

Referencia de la comunicación entre Dart y Kotlin.

- **Lado Dart:** `lib/native_bridge.dart` (clase `NativeBridge`). Es el **único** punto del código Dart que usa el `MethodChannel`.
- **Lado Kotlin:** `MainActivity.configureFlutterEngine`.

## Convenciones

- Los argumentos viajan como un mapa `Map<String, Object?>`.
- Las operaciones lentas (disco, decodificación) corren en un hilo aparte con `inBackground`. El resultado se entrega en el hilo principal.
- Los errores llegan a Dart como `PlatformException` con estos códigos:

| Código | Origen |
|---|---|
| `NATIVE_ERROR` | Excepción dentro de `inBackground` (extracción, escritura SAF, duraciones) |
| `PICK_FAILED` | No se pudo abrir el selector o guardar el permiso de la carpeta |

- Un método desconocido responde `notImplemented`. En Dart eso llega como `MissingPluginException` y casi siempre significa que el APK instalado es anterior al código Dart (ver [troubleshooting](troubleshooting.md#missingpluginexception)).

## Métodos

### `pickFolder`
Abre el selector de carpetas del sistema (`ACTION_OPEN_DOCUMENT_TREE`) y guarda el permiso de lectura/escritura con `takePersistableUriPermission`.

| | |
|---|---|
| Argumentos | ninguno |
| Devuelve | `{uri: String, path: String?}` o `null` si el usuario cancela |
| Dart | `NativeBridge.pickFolder() → PickedFolder?` |

- `path` es `null` cuando la carpeta no está en un volumen local (p. ej. Google Drive).
- La respuesta pendiente se guarda en un campo **estático**. Algunos fabricantes destruyen la actividad mientras el selector está abierto; así la respuesta sobrevive a esa recreación.
- Si se llama otra vez con una selección pendiente, la anterior se responde con `null`.

### `saveToFolder`
Copia un archivo dentro de una carpeta SAF.

| Argumento | Tipo | Descripción |
|---|---|---|
| `treeUri` | String | URI devuelta por `pickFolder` |
| `source` | String | Ruta del archivo a copiar (temporal de la app) |
| `name` | String | Nombre deseado con extensión |
| `mime` | String | Tipo MIME (`audio/mp4`) |

**Devuelve:** el nombre final (`String`). Android agrega ` (1)` si ya existía uno igual. Si la copia falla, el documento creado se elimina.

### `extractAudio`
Copia la primera pista de audio de un MP4 a un `.m4a`, sin recodificar.

| Argumento | Tipo | Descripción |
|---|---|---|
| `input` | String | Ruta del MP4 |
| `output` | String | Ruta del `.m4a` a crear |

**Devuelve:** `null`. Lanza `NATIVE_ERROR` si no hay pista de audio o el códec no se puede copiar tal cual. En ese caso el archivo de salida se borra.

### `scanFile`
Pide a `MediaScannerConnection` que indexe un archivo, para que otras apps de música lo vean.

| Argumento | Tipo |
|---|---|
| `path` | String |

### `getDurations`
Lee la duración de varios archivos con `MediaMetadataRetriever`.

| Argumento | Tipo |
|---|---|
| `paths` | `List<String>` |

**Devuelve:** `List<int?>` en milisegundos, en el mismo orden. `null` si un archivo no se pudo leer. Dart lo llama en lotes de 20.

### `takeSharedText`
Devuelve el texto recibido desde el menú **Compartir** de otra app y lo borra, de modo que se entrega **una sola vez**.

| | |
|---|---|
| Argumentos | ninguno |
| Devuelve | `String?` (`null` si no hay texto pendiente) |
| Dart | Usado internamente por `NativeBridge.listenSharedText(onText)` |

Dart lo llama al arrancar y cada vez que recibe `sharedTextAvailable` (ver abajo). Explicación del diseño en la [guía de contenido compartido](guides/recibir-contenido-compartido.md#2-el-problema-de-sincronización-con-flutter).

### `getSetting` / `setSetting`
Ajustes de texto en las `SharedPreferences` nativas (archivo `app_settings`).

| Método | Argumentos | Devuelve |
|---|---|---|
| `getSetting` | `key` | `String?` |
| `setSetting` | `key`, `value` (`null` borra la clave) | `null` |

Claves en uso: `music_folder` y `music_folder_uri`. El motivo de no usar `shared_preferences` está en el [ADR-0002](adr/0002-ajustes-con-canal-nativo.md).

## Llamadas de Kotlin hacia Dart

Kotlin también puede llamar a Dart por el mismo canal. Dart las atiende con un **único** `setMethodCallHandler`, registrado en `NativeBridge.listenSharedText`.

| Método | Argumentos | Cuándo se envía |
|---|---|---|
| `sharedTextAvailable` | ninguno | Llegó un `ACTION_SEND` con texto (en `onCreate` u `onNewIntent`). Es solo un aviso: Dart lee el texto con `takeSharedText` |

> ⚠️ Un canal admite un solo handler en Dart. No llames a `setMethodCallHandler` desde otro archivo: agrega el nuevo `case` en `NativeBridge`.

## Agregar un método nuevo

1. Agrega el `case` en `MainActivity.configureFlutterEngine`. Si toca disco o red, envuélvelo en `inBackground(result) { … }`.
2. Agrega un método estático tipado en `NativeBridge`. No llames al canal desde otro archivo.
3. Documenta el método en esta página.
4. Recompila por completo: ⏹ y luego `flutter run`. Un hot reload deja el APK viejo y termina en `MissingPluginException`.
