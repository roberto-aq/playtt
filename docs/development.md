# Guía de desarrollo

## Preparar el entorno

1. Instala Flutter 3.38 (stable) y Android Studio (incluye SDK, JDK 17 y emulador).
2. Acepta las licencias de Android: `flutter doctor --android-licenses`.
3. **Windows:** activa el Modo de desarrollador (`start ms-settings:developers`).
4. Verifica con `flutter doctor`.
5. Instala las dependencias: `flutter pub get`.

## Ejecutar

```bash
flutter devices          # confirma que el teléfono aparece
flutter run              # compila, instala y abre la app en modo debug
```

En VS Code: **F5** (Iniciar depuración).

> Se recomienda un **teléfono físico**: la notificación multimedia, los botones Bluetooth y el selector de carpetas se comportan distinto en emuladores.

## Hot reload vs. compilación completa

Es la fuente número uno de errores "misteriosos" en este proyecto.

| Acción | VS Code | Terminal | Recompila Kotlin y plugins |
|---|---|---|---|
| Hot reload | Guardar / ⚡ | `r` | ❌ |
| Hot restart | ⟳ / `Ctrl+Shift+F5` | `R` | ❌ |
| **Compilación completa** | ⏹ y luego **F5** | `q` y luego `flutter run` | ✅ |

**Haz una compilación completa siempre que:**
- cambies algo dentro de `android/` (Kotlin, `AndroidManifest.xml`, Gradle);
- agregues, quites o actualices un paquete en `pubspec.yaml`.

**Cómo confirmar que fue completa:** la consola muestra `Running Gradle task 'assembleDebug'...` y el número de proceso en el log cambia (por ejemplo `I/flutter (16682)`).

`audio_service` mantiene vivo el proceso mientras está la notificación de música. Si la compilación completa parece no aplicar los cambios, cierra la notificación o fuerza la detención desde Ajustes → Apps antes de ejecutar de nuevo.

## Depuración

### Filtrar los logs útiles

En la Consola de depuración de VS Code, filtra por:

```
Reproductor|Restaurar|Elegir carpeta
```

| Prefijo | Origen | Qué informa |
|---|---|---|
| `Reproductor` | Kotlin (`Log.d`) | Selector de carpetas (`pickFolder:`) y texto compartido recibido (`share:`) |
| `Restaurar:` | `LibraryController.restore` | Por qué se recuperó (o no) la carpeta al arrancar |
| `Elegir carpeta:` | `HomeShell._openFolder` | Ruta elegida, audios cargados o error |

### Ruido que se puede ignorar
Ver [troubleshooting](troubleshooting.md#mensajes-de-consola-inofensivos).

## Calidad de código

```bash
flutter analyze          # debe terminar en "No issues found!"
dart format lib          # formato oficial
```

Las reglas de estilo vienen de `flutter_lints` (`analysis_options.yaml`). Detalles en [CONTRIBUTING.md](../CONTRIBUTING.md).

## Compilación para publicar

```bash
flutter build apk --release        # APK único
flutter build appbundle --release  # AAB para Google Play
```

Antes de distribuir la app fuera de tu teléfono:

1. **Identificador:** cambia `applicationId` y `namespace` en `android/app/build.gradle.kts` (hoy `com.example.prueba_reproductor`). Mueve el paquete de `MainActivity.kt` en consecuencia.
2. **Firma:** hoy `release` usa las claves de depuración. Crea un keystore y configúralo:
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   Referencia: <https://docs.flutter.dev/deployment/android#sign-the-app>. **Nunca** subas el keystore ni sus contraseñas al repositorio.
3. **Versión:** incrementa `version:` en `pubspec.yaml` (`nombre+código`, p. ej. `1.0.0+1`) y registra los cambios en `CHANGELOG.md`.
4. **Nombre e ícono:** `android:label` en `AndroidManifest.xml` e íconos en `android/app/src/main/res/mipmap-*`.

## Dependencias

| Paquete | Uso | Nota |
|---|---|---|
| `just_audio` | Motor de reproducción (ExoPlayer) | |
| `just_audio_background` | Notificación, pantalla de bloqueo y Bluetooth | Construido sobre `audio_service` |
| `permission_handler` | Permisos de audio y notificaciones | **Fijado en 12.0.1**: la 13.x requiere una versión de AGP más nueva que la del proyecto |
| `http` | API de tikwm y descarga con progreso | |
| `path_provider` | Carpeta temporal para descargas | |
| `path` | Manipulación de rutas | |

Antes de actualizar un paquete con código nativo, revisa su CHANGELOG para ver qué versiones de AGP y Kotlin requiere, y haz una compilación completa.
