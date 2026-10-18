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
dart format lib test     # formato oficial
flutter test             # pruebas unitarias (test/)
```

Las reglas de estilo vienen de `flutter_lints` (`analysis_options.yaml`). Detalles en [CONTRIBUTING.md](../CONTRIBUTING.md).

## Compilación para publicar

### Identidad de la app (ya configurada)

| Elemento | Valor | Dónde se cambia |
|---|---|---|
| Nombre visible | **PlayTT** | `android:label` en `AndroidManifest.xml` |
| Identificador | `com.playtt.app` | `applicationId` y `namespace` en `android/app/build.gradle.kts`, y el paquete de los `.kt` |
| Versión | `1.0.0+1` | `version:` en `pubspec.yaml` (`nombre+código`) |
| Ícono | `assets/branding/playtt_icon.png` | Reemplaza la imagen y ejecuta `dart run flutter_launcher_icons` |
| Ícono de la notificación | `res/drawable/ic_stat_playtt.xml` | Vector de un solo color; se conserva en release gracias a `res/raw/keep.xml` |

> ⚠️ **El identificador es permanente.** Si cambia, Android y Google Play lo tratan como otra app: los usuarios no reciben la actualización y pierden sus ajustes. Por eso el nombre interno del paquete Dart (`prueba_reproductor`) y el canal nativo (`prueba_reproductor/media`) no se renombraron: no son visibles y cambiarlos no aporta nada.

### 1. Crear la clave de firma (una sola vez)

Android solo instala una **actualización** si está firmada con la misma clave que la versión instalada. Esta clave te identifica como autor: **si la pierdes, no podrás actualizar la app**. Guárdala junto con sus contraseñas en un lugar seguro (gestor de contraseñas y copia de respaldo), nunca en el repositorio.

`keytool` viene con el JDK de Android Studio (`C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe` en Windows). Desde la carpeta `android/`:

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Te pedirá una contraseña y algunos datos (nombre, organización…).

### 2. Configurar `key.properties`

Copia `android/key.properties.example` como `android/key.properties` y complétalo:

```properties
storePassword=la contraseña que elegiste
keyPassword=la contraseña que elegiste
keyAlias=upload
storeFile=../upload-keystore.jks
```

`android/app/build.gradle.kts` lo lee automáticamente. Ni `key.properties` ni `*.jks` se suben: están en `android/.gitignore`.

> Sin `key.properties`, la versión release se firma con la clave de **depuración** y Gradle muestra un aviso. Sirve para probar, no para distribuir: ese APK no se podría actualizar después con uno firmado de verdad.

### 3. Compilar

```bash
flutter build apk --release --split-per-abi   # para instalar directamente (un APK por tipo de procesador, ~3 veces más livianos)
flutter build apk --release                   # un único APK para todos los teléfonos (~50 MB)
flutter build appbundle --release             # AAB para subir a Google Play
```

Los archivos quedan en `build/app/outputs/`. Para pasar la app a otra persona sin Google Play, envíale `app-arm64-v8a-release.apk`, que sirve para casi todos los teléfonos actuales. Tendrá que permitir "instalar apps de origen desconocido".

### Publicar en GitHub Releases

1. Compila: `flutter build apk --release --split-per-abi` y `flutter build apk --release`.
2. En GitHub: **Releases → Draft a new release**.
   - **Tag:** `v1.0.0` (debe coincidir con `version:` en `pubspec.yaml`).
   - **Título:** `PlayTT 1.0.0`.
   - **Descripción:** los puntos de esa versión en `CHANGELOG.md`, escritos para el usuario.
3. Adjunta `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` y `app-release.apk`.
4. **Publish release.** El enlace "Releases" del README siempre apunta a la última.

### 4. Antes de cada versión nueva

1. Sube `version:` en `pubspec.yaml`. El número después del `+` **siempre debe aumentar** (`1.0.0+1` → `1.0.1+2`); Android rechaza actualizaciones con un código igual o menor.
2. Pasa la sección **[Sin publicar]** de `CHANGELOG.md` a la nueva versión, con fecha.
3. `flutter analyze` y `flutter test` sin errores.
4. Prueba la versión release en un teléfono real: `flutter run --release`.

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
