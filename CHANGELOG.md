# Changelog

Todos los cambios relevantes del proyecto se registran en este archivo.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el proyecto usa [Versionado Semántico](https://semver.org/lang/es/).

## [Sin publicar]

### Agregado
- La app aparece en el menú **Compartir** de otras apps como "Extraer audio". Al compartir un TikTok, se abre en Descargar con el video ya procesado ([ADR-0006](docs/adr/0006-recibir-enlaces-compartidos.md)).
- Guía de estudio [Recibir contenido desde el menú "Compartir"](docs/guides/recibir-contenido-compartido.md).
- **Nivelación de volumen** entre audios, activada por defecto y con interruptor en Configuración ([ADR-0007](docs/adr/0007-nivelacion-de-volumen.md), [guía](docs/guides/nivelacion-de-volumen.md)).
- Búsqueda en la Biblioteca que ignora mayúsculas y tildes.
- Menú al mantener pulsada una canción: **Renombrar**, **Compartir** y **Eliminar**.
- Primeras pruebas unitarias (`test/`).

### Cambiado
- `MainActivity` usa `launchMode="singleTask"`: los enlaces compartidos y el toque en la notificación reutilizan siempre la misma pantalla.

## [0.1.0] - 2026-10-17

Primera versión funcional de la reescritura en Flutter.

### Agregado
- Biblioteca de música local a partir de una carpeta elegida, con búsqueda recursiva, duración y fecha por audio.
- Reproducción en segundo plano con controles en la notificación, la pantalla de bloqueo y auriculares Bluetooth.
- Mini reproductor flotante y reproductor a pantalla completa con modo aleatorio y repetición.
- Descarga de audio desde enlaces de TikTok mediante tikwm.com, con progreso por etapas.
- Extracción nativa del audio a `.m4a` sin recodificar ([ADR-0004](docs/adr/0004-extraccion-de-audio-nativa.md)).
- Selector de carpetas propio con permiso de escritura persistente, para guardar en carpetas de la raíz ([ADR-0003](docs/adr/0003-escritura-con-storage-access-framework.md)).
- Pantallas Biblioteca, Descargar y Configuración con el diseño de la versión React Native.
- Mensajes de diagnóstico en consola para la restauración y la elección de carpeta.
- Documentación técnica en `docs/`.

### Cambiado
- Los ajustes se guardan con el canal nativo en lugar de `shared_preferences` ([ADR-0002](docs/adr/0002-ajustes-con-canal-nativo.md)).
- La barra de pestañas ya no muestra el efecto de onda al tocarlas.

### Eliminado
- Dependencias `shared_preferences` y `file_picker`.

### Corregido
- La carpeta no se recordaba después de un hot restart.
- La respuesta del selector de carpetas se perdía si el sistema recreaba la actividad mientras estaba abierto.

[Sin publicar]: #sin-publicar
[0.1.0]: #010---2026-10-17
