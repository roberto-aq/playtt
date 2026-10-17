# Reproductor

Reproductor de música local para Android, hecho en Flutter, con descarga de audio desde TikTok.

La app lee los audios de una carpeta del teléfono y los reproduce con controles completos en la notificación, la pantalla de bloqueo y los auriculares Bluetooth. Desde la pestaña **Descargar** se pega un enlace de TikTok, se extrae el audio y se guarda en **esa misma carpeta**, que pasa a formar parte de la biblioteca al instante.

> Es la reescritura en Flutter de una versión anterior en React Native (Expo), cuyo reproductor tenía problemas de estabilidad.

---

## Contenido

- [Funcionalidades](#funcionalidades)
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

### Reproducción
- Reproducción en segundo plano.
- **Controles del sistema:** notificación con anterior / pausa / siguiente, pantalla de bloqueo y botones de auriculares Bluetooth o con cable.
- Mini reproductor flotante y reproductor a pantalla completa con barra de progreso, modo aleatorio y repetición (todo / una).

### Descarga desde TikTok
- Acepta enlaces `vm.tiktok.com`, `vt.tiktok.com` y `www.tiktok.com/@usuario/video/…`.
- Muestra portada, título y autor antes de descargar.
- Extrae **solo la pista de audio**, sin recodificar (sin pérdida de calidad), a un archivo `.m4a`.
- Guarda el archivo en la carpeta de la biblioteca, incluidas carpetas propias en la raíz del almacenamiento, gracias al permiso del selector de carpetas del sistema (Storage Access Framework, SAF).

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
├── mini_player.dart          Barra de reproducción flotante
└── player_screen.dart        Reproductor a pantalla completa

android/app/src/main/kotlin/com/example/prueba_reproductor/
├── MainActivity.kt           Canal "prueba_reproductor/media" y selector de carpetas
├── AudioExtractor.kt         Extracción de audio MP4 → M4A (MediaExtractor + MediaMuxer)
└── StorageFolders.kt         Conversión URI SAF ↔ ruta y escritura en carpetas SAF

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
| [CHANGELOG.md](CHANGELOG.md) | Historial de cambios |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Convenciones de código, commits y revisiones |

---

## Limitaciones conocidas

- **Solo Android.** El código nativo (selector de carpetas, extracción y duraciones) está implementado únicamente en Kotlin.
- **Depende de un servicio externo** (tikwm.com) para resolver los enlaces de TikTok. Si cambia o deja de responder, la descarga falla; la reproducción no se ve afectada.
- **Metadatos mínimos:** el título del audio es el nombre del archivo. No se escriben etiquetas (artista, portada) dentro del `.m4a`.
- **Archivos heredados de la versión React Native:** eran videos MP4 guardados con extensión `.mp3`. Se reproducen bien, pero el teléfono también decodifica su video (más consumo de batería).
- **Sin pruebas automatizadas** todavía.
- **No apta para publicar sin ajustes:** el `applicationId` es `com.example.prueba_reproductor` y la versión *release* se firma con las claves de depuración. Ver [docs/development.md](docs/development.md#compilación-para-publicar).

## Hoja de ruta

- [ ] Recibir enlaces desde el menú **Compartir** de TikTok.
- [ ] Pruebas unitarias (`cleanFileName`, `TikwmService` con cliente HTTP simulado, `LibraryController`).
- [ ] Escribir etiquetas de título y autor en los archivos descargados.
- [ ] Convertir los archivos heredados (video) a audio puro.
- [ ] Identificador de aplicación y firma definitivos.

---

## Aviso legal

Esta app es un proyecto de práctica para uso personal. El contenido de TikTok está protegido por derechos de autor y por los [Términos de servicio de TikTok](https://www.tiktok.com/legal/terms-of-service). Descarga solo contenido que tengas derecho a guardar. El proyecto no está afiliado a TikTok ni a tikwm.com.
