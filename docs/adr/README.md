# Registro de decisiones de arquitectura (ADR)

Un ADR documenta una decisión técnica importante: el contexto en que se tomó, las alternativas consideradas y sus consecuencias. Sirve para que nadie tenga que adivinar *por qué* el código es como es.

| N.º | Decisión | Estado |
|---|---|---|
| [0001](0001-reproduccion-con-just-audio-background.md) | Reproducción en segundo plano con `just_audio_background` | Aceptada |
| [0002](0002-ajustes-con-canal-nativo.md) | Guardar ajustes con el canal nativo en lugar de `shared_preferences` | Aceptada |
| [0003](0003-escritura-con-storage-access-framework.md) | Escribir en la carpeta elegida mediante el Storage Access Framework | Aceptada |
| [0004](0004-extraccion-de-audio-nativa.md) | Extraer el audio con `MediaExtractor` + `MediaMuxer` (sin ffmpeg) | Aceptada |
| [0005](0005-tikwm-como-proveedor.md) | Usar tikwm.com detrás de la interfaz `TikTokService` | Aceptada |
| [0006](0006-recibir-enlaces-compartidos.md) | Recibir enlaces compartidos con código propio y `launchMode="singleTask"` | Aceptada |
| [0007](0007-nivelacion-de-volumen.md) | Nivelación de volumen con medición propia y `AndroidLoudnessEnhancer` | Aceptada |

## Cómo agregar un ADR

1. Copia la estructura de uno existente con el siguiente número: `000N-titulo-en-minusculas.md`.
2. Secciones: **Estado**, **Contexto**, **Decisión**, **Alternativas consideradas**, **Consecuencias**.
3. Un ADR aceptado no se edita para cambiar la decisión: se crea uno nuevo que lo **reemplaza** y se actualiza el estado del anterior.
4. Agrégalo a la tabla de arriba.
