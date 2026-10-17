# Guía de contribución

## Flujo de trabajo

1. Crea una rama desde `main`: `feat/compartir-desde-tiktok`, `fix/carpeta-no-se-recuerda`, `docs/…`.
2. Haz commits pequeños siguiendo [Conventional Commits](#mensajes-de-commit).
3. Antes de abrir el *pull request*, completa la [lista de verificación](#lista-de-verificación).
4. Registra el cambio en `CHANGELOG.md`, sección **[Sin publicar]**.

## Estilo de código

### Dart
- Formato oficial: `dart format lib`.
- `flutter analyze` debe terminar sin avisos.
- **Nombres en inglés** (clases, métodos, variables); **comentarios, documentación y textos de la interfaz en español**.
- Comentarios de documentación (`///`) en clases y métodos públicos. Explica el *porqué*, no el *qué*.
- Cada archivo tiene una responsabilidad. Respeta las capas descritas en [docs/architecture.md](docs/architecture.md):
  - las pantallas no usan `dart:io`, `http` ni el `MethodChannel`;
  - el canal nativo se usa **solo** desde `NativeBridge`;
  - los colores salen de `AppColors`, nunca de valores sueltos en las pantallas.
- Los errores que verá el usuario se lanzan como excepciones con un mensaje listo para mostrar (`TikTokException`, `StorageException`).

### Kotlin
- Las operaciones de disco o decodificación se ejecutan con `inBackground(result) { … }`, nunca en el hilo principal.
- Los logs de diagnóstico usan la etiqueta `Reproductor`.
- Todo método nuevo del canal se documenta en [docs/native-bridge.md](docs/native-bridge.md).

## Mensajes de commit

Formato [Conventional Commits](https://www.conventionalcommits.org/es/v1.0.0/):

```
<tipo>(<ámbito opcional>): <resumen en imperativo>

<cuerpo opcional: qué y por qué>
```

| Tipo | Uso |
|---|---|
| `feat` | Funcionalidad nueva |
| `fix` | Corrección de un error |
| `docs` | Solo documentación |
| `refactor` | Cambio de código sin cambiar el comportamiento |
| `perf` | Mejora de rendimiento |
| `test` | Pruebas |
| `chore` | Dependencias, configuración, tareas de mantenimiento |

Ejemplos:
```
feat(descargas): recibir enlaces desde el menú Compartir
fix(carpetas): conservar el selector pendiente si se recrea la actividad
docs(adr): registrar el uso del Storage Access Framework
```

## Decisiones de arquitectura

Si un cambio introduce o reemplaza una decisión técnica relevante (nueva dependencia nativa, cambio de proveedor, nuevo modelo de almacenamiento), agrega un ADR en [docs/adr/](docs/adr/README.md).

## Lista de verificación

- [ ] `flutter analyze` sin avisos.
- [ ] `flutter test` pasa. Las funciones puras nuevas llevan su prueba en `test/`.
- [ ] `dart format lib` aplicado.
- [ ] Probado en un **teléfono físico** con una **compilación completa** si se tocó `android/` o `pubspec.yaml`.
- [ ] Si cambia la reproducción: notificación, pantalla de bloqueo y botones Bluetooth siguen funcionando.
- [ ] Si cambia el almacenamiento: probado con la carpeta predeterminada (`Music/TikTok`) y con una carpeta de la raíz.
- [ ] Documentación actualizada (`README`, `docs/`, ADR si corresponde).
- [ ] Entrada en `CHANGELOG.md`.
