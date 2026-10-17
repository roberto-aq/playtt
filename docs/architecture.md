# Arquitectura

Este documento describe cómo está organizada la app, cómo fluyen los datos y por qué. Las decisiones importantes tienen su justificación completa en los [ADR](adr/README.md).

## Visión general

```mermaid
flowchart TB
    subgraph UI["Interfaz (Flutter)"]
        Shell[HomeShell]
        Lib[LibraryScreen]
        Dl[DownloaderScreen]
        Set[SettingsScreen]
        Mini[MiniPlayer]
        Full[PlayerScreen]
    end

    subgraph Domain["Estado y servicios (Dart)"]
        LC[LibraryController]
        TS[TikTokService<br/>TikwmService]
        AL[audio_library]
        NB[NativeBridge]
    end

    subgraph Plugins["Plugins"]
        JA[just_audio]
        JAB[just_audio_background<br/>audio_service]
        PH[permission_handler]
    end

    subgraph Native["Android (Kotlin)"]
        MA[MainActivity]
        AE[AudioExtractor]
        SF[StorageFolders]
    end

    Ext[(tikwm.com)]

    Shell --> Lib & Dl & Set & Mini
    Lib & Mini --> Full
    Lib & Set & Mini & Full --> LC
    Dl --> TS
    Dl --> LC
    LC --> JA
    JA --- JAB
    LC --> AL --> PH
    LC --> NB
    TS --> NB
    TS --> Ext
    NB -- "MethodChannel<br/>prueba_reproductor/media" --> MA
    MA --> AE & SF
```

| Capa | Responsabilidad | No debe |
|---|---|---|
| **Interfaz** | Mostrar estado y traducir gestos en llamadas | Acceder a archivos, red o canal nativo directamente |
| **LibraryController** | Única fuente de verdad: carpeta, canciones, reproductor y guardado de archivos | Saber de TikTok |
| **TikTokService** | Resolver enlaces, descargar y extraer audio a un archivo temporal | Saber dónde se guarda el resultado |
| **NativeBridge** | Exponer el código Kotlin con una API Dart tipada | Contener lógica de negocio |
| **Kotlin** | Lo que Flutter no puede hacer: SAF, extracción de audio y metadatos | Mantener estado propio, salvo el selector pendiente |

## Gestión de estado

La app no usa paquetes de gestión de estado. `LibraryController` es un `ChangeNotifier` creado en `main()` y pasado por constructor:

- `HomeShell` lo escucha con un `ListenableBuilder` y reconstruye las pestañas cuando cambia.
- El estado de reproducción (posición, canción actual, play/pausa) **no** se duplica en el controlador. Los widgets se suscriben directamente a los *streams* de `AudioPlayer` con `StreamBuilder`.
- El estado efímero de cada pantalla (texto del enlace, progreso de la descarga) vive en su `State`.

Con la escala actual (3 pestañas, un controlador), esto evita dependencias y mantiene el flujo explícito. Si la app crece, la migración natural es `provider` o `riverpod` sin cambiar `LibraryController`.

## Reproducción

```mermaid
flowchart LR
    LC[LibraryController] -- "setAudioSources(lista)" --> AP[AudioPlayer<br/>just_audio / ExoPlayer]
    AP <--> AS[audio_service<br/>MediaSession]
    AS --> N[Notificación]
    AS --> L[Pantalla de bloqueo]
    BT[Auriculares Bluetooth] -- botones multimedia --> AS
```

- Cada canción es un `AudioSource.file` con un `MediaItem` como `tag` (título y álbum = nombre de la carpeta). Ese `MediaItem` es lo que muestran la notificación y los dispositivos Bluetooth.
- La lista se carga con `preload: false`: no se decodifica nada hasta que el usuario toca una canción. Mientras el reproductor está `idle`, el mini reproductor permanece oculto.
- Una descarga nueva se agrega con `insertAudioSource(0, …)`, sin interrumpir lo que está sonando.
- `MainActivity` hereda de `AudioServiceActivity`. Eso hace que el motor de Flutter lo cree y lo guarde en caché `audio_service`, para que la música siga sonando sin la actividad (ver [ADR-0001](adr/0001-reproduccion-con-just-audio-background.md)).

## Almacenamiento

### Modelo de carpeta

Una carpeta se identifica con **dos valores**, persistidos con las `SharedPreferences` nativas (archivo `app_settings`):

| Clave | Ejemplo | Uso |
|---|---|---|
| `music_folder` | `/storage/emulated/0/TikTok Gym` | **Leer:** buscar y reproducir archivos con `dart:io` |
| `music_folder_uri` | `content://com.android.externalstorage.documents/tree/primary%3ATikTok%20Gym` | **Escribir:** crear archivos mediante el SAF |

¿Por qué dos? Desde Android 11, una app con permiso de lectura de audio puede **leer** con rutas normales casi cualquier carpeta. En cambio, solo puede **crear** archivos en ciertas carpetas estándar (`Music`, `Download`…). Para escribir en una carpeta propia de la raíz hace falta el permiso que se concede al elegirla en el selector del sistema ([ADR-0003](adr/0003-escritura-con-storage-access-framework.md)).

La carpeta predeterminada `Music/TikTok` (botón **Restaurar**) no tiene URI: ahí Android permite escribir directamente.

### Escritura de un archivo descargado

```mermaid
flowchart TD
    A[saveDownloadedAudio] --> B{¿hay URI SAF?}
    B -- Sí --> C[NativeBridge.saveToFolder<br/>DocumentsContract.createDocument]
    C --> D[Nombre final devuelto por Android<br/>p. ej. 'audio (1).m4a']
    B -- No --> E[File.copy a la ruta<br/>nombre único 'audio (2).m4a']
    D & E --> F[NativeBridge.scanFile<br/>visible para otras apps]
    F --> G[insertAudioSource en la posición 0]
```

## Descarga desde TikTok

```mermaid
sequenceDiagram
    actor U as Usuario
    participant D as DownloaderScreen
    participant T as TikwmService
    participant API as tikwm.com
    participant K as Kotlin (AudioExtractor)
    participant L as LibraryController

    U->>D: Pega enlace → Procesar Link
    D->>T: fetchVideo(url)
    T->>API: GET /api/?url=…
    API-->>T: id, title, cover, play, author
    T-->>D: TikTokVideo
    U->>D: Extraer Audio Completo
    D->>T: downloadAudio(video)
    T->>API: GET play (MP4, con progreso)
    T->>K: extractAudio(mp4, m4a)
    K-->>T: pista de audio copiada sin recodificar
    T-->>D: DownloadedAudio (temporal)
    D->>L: saveDownloadedAudio(archivo, nombre)
    L-->>D: archivo final en la carpeta
    D->>D: borra temporal · diálogo "Guardado"
```

- **Extracción:** `MediaExtractor` lee la pista AAC del MP4 y `MediaMuxer` la escribe en un contenedor MP4 solo de audio (`.m4a`). No hay recodificación ([ADR-0004](adr/0004-extraccion-de-audio-nativa.md)).
- **Respaldo:** si la pista no se puede copiar tal cual, se guarda el MP4 completo con extensión `.m4a`. Se reproduce igual, solo que es más pesado.
- **Nombre del archivo:** `cleanFileName(title)` quita hashtags, menciones, emojis y caracteres inválidos, recorta a 60 caracteres y elimina puntos finales. Si queda vacío, se usa `tiktok_<id>`.
- **Intercambiable:** la pantalla solo conoce la interfaz `TikTokService`. Cambiar de proveedor implica escribir otra implementación y cambiar una línea en `home_shell.dart`.

## Permisos

| Permiso | Versión de Android | Para qué |
|---|---|---|
| `READ_MEDIA_AUDIO` | 13+ | Leer audios de la carpeta |
| `READ_EXTERNAL_STORAGE` | ≤ 12 | Ídem en versiones anteriores |
| `WRITE_EXTERNAL_STORAGE` | ≤ 9 | Escribir en `Music/TikTok` |
| `INTERNET` | todas | API y descarga |
| `WAKE_LOCK`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | todas / 14+ | Reproducción en segundo plano |
| `POST_NOTIFICATIONS` | 13+ | Evitar que algunos fabricantes oculten la notificación |
| Permiso de carpeta SAF | todas | Escritura en la carpeta elegida (persistente) |

## Interfaz

| Elemento | Archivo | Notas |
|---|---|---|
| Tema y paleta | `theme.dart` | `AppColors` replica el diseño original: morado `#1C0F45`, rosa `#FF4081` y verde `#00C853` |
| Pestañas | `home_shell.dart` | `IndexedStack`: cada pestaña conserva su estado al cambiar |
| Diálogos | `theme.dart` → `showAppAlert` | Estilo de alerta nativa de Android |
| Reproductor | `player_screen.dart` | Disco que gira y late mientras suena (`AnimationController`) |
