# ADR-0003: Escribir en la carpeta elegida mediante el Storage Access Framework

**Estado:** Aceptada

## Contexto
Los audios descargados deben guardarse en **la misma carpeta** que se usa como biblioteca. La carpeta real del usuario es `/storage/emulated/0/TikTok Gym`, una carpeta propia en la raíz del almacenamiento.

Desde Android 11 (almacenamiento con alcance limitado, *scoped storage*):
- Con `READ_MEDIA_AUDIO` / `READ_EXTERNAL_STORAGE`, una app puede **leer** audios en casi cualquier carpeta usando rutas normales.
- Una app solo puede **crear** archivos con rutas normales en carpetas estándar (`Music`, `Download`, `Podcasts`…), no en carpetas propias de la raíz.

La versión React Native lo resolvía con el Storage Access Framework (SAF). El selector anterior en Flutter (`file_picker`) solo devolvía una ruta y no conservaba el permiso de escritura.

## Decisión
- Implementar un selector propio en Kotlin con `ACTION_OPEN_DOCUMENT_TREE` y `takePersistableUriPermission` (lectura y escritura).
- Guardar **dos valores** por carpeta: la ruta (para leer con `dart:io` y reproducir) y la URI SAF (para escribir con `DocumentsContract.createDocument`).
- La carpeta predeterminada `Music/TikTok` no necesita URI: allí se escribe directamente.
- Quitar `file_picker`.

## Alternativas consideradas
- **`MANAGE_EXTERNAL_STORAGE` ("acceso a todos los archivos"):** el código sería más simple, pero es un permiso invasivo y Google Play restringe su uso.
- **Guardar solo en `Music/`:** obligaría al usuario a mover su biblioteca existente.
- **Leer también por SAF:** innecesario y más lento, porque leer con rutas normales funciona con el permiso de audio.

## Consecuencias
- ✅ Funciona con cualquier carpeta local, incluidas las de la raíz.
- ✅ El permiso persiste tras reiniciar el teléfono.
- ⚠️ Las carpetas elegidas antes de este cambio no tienen URI: hay que volver a elegirlas para poder descargar en ellas.
- ⚠️ Convertir una URI en ruta asume volúmenes locales (`primary:` → `/storage/emulated/0`, `XXXX-XXXX:` → `/storage/XXXX-XXXX`). Las carpetas de proveedores en la nube se rechazan.
