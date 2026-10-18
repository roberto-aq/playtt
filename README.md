# PlayTT

Reproductor de música local para Android, hecho en Flutter, con descarga de audio desde TikTok.

La app lee los audios de una carpeta del teléfono y los reproduce con controles completos en la notificación, la pantalla de bloqueo y los auriculares Bluetooth. Desde la pestaña **Descargar** se pega un enlace de TikTok, se extrae el audio y se guarda en **esa misma carpeta**, que pasa a formar parte de la biblioteca al instante.

> Es la reescritura en Flutter de una versión anterior en React Native (Expo), cuyo reproductor tenía problemas de estabilidad.

---

## Contenido

- [Funcionalidades](#funcionalidades)
- [Descargar e instalar](#descargar-e-instalar)
- [Requisitos](#requisitos)
- [Inicio rápido](#inicio-rápido)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Documentación](#documentación)
- [Limitaciones conocidas](#limitaciones-conocidas)
- [Hoja de ruta](#hoja-de-ruta)
- [Aviso legal](#aviso-legal)

---

## Funcionalidades

### Biblioteca
- Elección de la carpeta de música con el selector del sistema; la app la recuerda entre sesiones.
- Búsqueda recursiva de audios (`.mp3`, `.m4a`, `.aac`, `.wav`, `.ogg`, `.oga`, `.opus`, `.flac`).
- Lista ordenada por fecha (más recientes primero), con duración y fecha de cada audio.
- Búsqueda que ignora mayúsculas y tildes.
- **Mantén pulsada una canción** para renombrarla, compartirla con otra app o eliminarla.

### Reproducción
- Reproducción en segundo plano.
- **Controles del sistema:** notificación con anterior / pausa / siguiente, pantalla de bloqueo y botones de auriculares Bluetooth o con cable.
- Mini reproductor flotante y reproductor a pantalla completa con barra de progreso, modo aleatorio y repetición (todo / una).
- **Retoma donde quedaste:** al abrir la app, la última canción queda lista en la misma posición.
- **Nivelación de volumen:** iguala el volumen entre audios para que ninguno suene mucho más fuerte o más bajo que otro (se puede desactivar en Configuración).

### Descarga desde TikTok
- **Desde el menú Compartir de TikTok:** *Compartir* → **PlayTT**, y la app se abre con el video ya procesado.
- También se puede pegar el enlace a mano: acepta `vm.tiktok.com`, `vt.tiktok.com` y `www.tiktok.com/@usuario/video/…`.
- Muestra portada, título y autor antes de descargar, y avisa si ese video ya está en la biblioteca.
- Extrae **solo la pista de audio**, sin recodificar (sin pérdida de calidad), a un archivo `.m4a`.
- Guarda el archivo en la carpeta de la biblioteca, incluidas carpetas propias en la raíz del almacenamiento, gracias al permiso del selector de carpetas del sistema (Storage Access Framework, SAF).

---

## Descargar e instalar

1. Entra a **[Releases](../../releases/latest)** y descarga el APK:
   - `app-arm64-v8a-release.apk`: para casi todos los teléfonos actuales (recomendado).
   - `app-release.apk`: universal, más pesado. Úsalo si el anterior no se instala.
2. Abre el archivo en el teléfono. Android pedirá permitir **"instalar apps de origen desconocido"** para la app desde la que lo abriste (Archivos, Chrome, WhatsApp…).
3. Abre **PlayTT** y elige la carpeta donde está tu música.

Requiere Android 7.0 o superior. Las actualizaciones se instalan encima de la versión anterior, sin perder los ajustes.

---

## Requisitos

| Herramienta | Versión |
|---|---|
| Flutter | 3.38.x (canal stable) |
| Dart | ≥ 3.10.7 |
| Android SDK | compileSdk / targetSdk 36 |
| Dispositivo | Android 7.0 (API 24) o superior |
| JDK | 17 (incluido en Android Studio) |

> **Windows:** activa el *Modo de desarrollador* (`start ms-settings:developers`). Flutter lo necesita para compilar proyectos con plugins.

---

## Inicio rápido

```bash
# 1. Instalar dependencias
flutter pub get

# 2. Conectar un teléfono Android con depuración USB y ejecutar
flutter run
```

Al abrir la app:

1. **Biblioteca → Cargar Música** (o **Configuración → Seleccionar Carpeta**) y elige una carpeta.
2. Toca una canción para reproducirla.
3. En **Descargar**, pega un enlace de TikTok → **Procesar Link** → **Extraer Audio Completo**.

> ⚠️ **Hot reload no recompila código nativo.** Si cambias algo en `android/` o agregas o quitas un paquete, detén la app y vuelve a ejecutar `flutter run`. Más detalles en [docs/development.md](docs/development.md#hot-reload-vs-compilación-completa).

---

## Estructura del proyecto

```
lib/
├── main.dart                 Punto de entrada: servicio de audio + tema
├── theme.dart                Paleta, tema y widgets/utilidades visuales compartidas
├── home_shell.dart           Pestañas, mini reproductor y flujo de elección de carpeta
│
├── library_controller.dart   Estado central: carpeta, canciones, reproductor, guardado
├── audio_library.dart        Permisos y búsqueda de archivos de audio
├── native_bridge.dart        Cliente Dart del canal nativo (Kotlin)
├── tiktok_service.dart       Contrato TikTokService + implementación TikwmService
│
├── library_screen.dart       Pestaña Biblioteca
├── downloader_screen.dart    Pestaña Descargar
├── settings_screen.dart      Pestaña Configuración
├── track_actions.dart        Menú de una canción: renombrar, compartir, eliminar
├── playback_state.dart       Qué se guarda para retomar la reproducción
├── download_history.dart     Videos ya descargados (aviso de duplicados)
├── volume_normalizer.dart    Nivelación de volumen (caché y compensación)
├── mini_player.dart          Barra de reproducción flotante
└── player_screen.dart        Reproductor a pantalla completa

android/app/src/main/kotlin/com/example/prueba_reproductor/
├── MainActivity.kt           Canal "prueba_reproductor/media" y selector de carpetas
├── AudioExtractor.kt         Extracción de audio MP4 → M4A (MediaExtractor + MediaMuxer)
├── LoudnessAnalyzer.kt       Medición de sonoridad (para la nivelación de volumen)
└── StorageFolders.kt         URI SAF ↔ ruta; crear, renombrar y eliminar en carpetas SAF

test/                         Pruebas unitarias (flutter test)

docs/                         Documentación técnica (ver abajo)
```

---

## Documentación

| Documento | Contenido |
|---|---|
| [docs/architecture.md](docs/architecture.md) | Capas, flujos de datos y modelo de almacenamiento |
| [docs/native-bridge.md](docs/native-bridge.md) | Referencia de los métodos del canal Dart ↔ Kotlin |
| [docs/development.md](docs/development.md) | Entorno, ejecución, depuración y compilación para publicar |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Errores conocidos y cómo resolverlos |
| [docs/adr/](docs/adr/README.md) | Registro de decisiones de arquitectura |
| [docs/guides/recibir-contenido-compartido.md](docs/guides/recibir-contenido-compartido.md) | Guía de estudio: cómo recibir contenido del menú Compartir y replicarlo en otros proyectos |
| [docs/guides/nivelacion-de-volumen.md](docs/guides/nivelacion-de-volumen.md) | Guía de estudio: decibelios, medición de sonoridad y compensación de volumen |
| [CHANGELOG.md](CHANGELOG.md) | Historial de cambios |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Convenciones de código, commits y revisiones |

---

## Limitaciones conocidas

- **Solo Android.** El código nativo (selector de carpetas, extracción y duraciones) está implementado únicamente en Kotlin.
- **Depende de un servicio externo** (tikwm.com) para resolver los enlaces de TikTok. Si cambia o deja de responder, la descarga falla; la reproducción no se ve afectada.
- **Metadatos mínimos:** el título del audio es el nombre del archivo. No se escriben etiquetas (artista, portada) dentro del `.m4a`.
- **Archivos heredados de la versión React Native:** eran videos MP4 guardados con extensión `.mp3`. Se reproducen bien, pero el teléfono también decodifica su video (más consumo de batería).
- **Pruebas parciales:** solo cubren las funciones puras (nombres de archivo, enlaces, búsqueda y fórmula de nivelación); no hay pruebas de integración.
- **Firma de la versión release:** hay que crear una clave propia una vez antes de distribuir. Sin ella, se firma con la clave de depuración. Ver [docs/development.md](docs/development.md#compilación-para-publicar).

## Hoja de ruta

- [x] Recibir enlaces desde el menú **Compartir** de TikTok.
- [x] Nivelación de volumen entre audios.
- [x] Buscar, renombrar, compartir y eliminar audios.
- [x] Retomar la reproducción donde quedó.
- [x] Aviso de descargas duplicadas.
- [x] Identidad propia (PlayTT, `com.playtt.app`, ícono) y firma configurable.
- [ ] Crear la clave de firma definitiva (manual, ver [docs/development.md](docs/development.md#1-crear-la-clave-de-firma-una-sola-vez)).
- [ ] Más pruebas: `TikwmService` con cliente HTTP simulado y `LibraryController`.

---

## Aviso legal

Esta app es un proyecto de práctica para uso personal. El contenido de TikTok está protegido por derechos de autor y por los [Términos de servicio de TikTok](https://www.tiktok.com/legal/terms-of-service). Descarga solo contenido que tengas derecho a guardar. El proyecto no está afiliado a TikTok ni a tikwm.com.
