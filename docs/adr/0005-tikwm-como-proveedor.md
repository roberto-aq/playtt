# ADR-0005: Usar tikwm.com detrás de la interfaz `TikTokService`

**Estado:** Aceptada

## Contexto
TikTok no ofrece una API pública para descargar videos. La versión React Native usaba tikwm.com: `GET https://www.tikwm.com/api/?url=<enlace>` devuelve `id`, `title`, `cover`, `author.nickname` y `play` (MP4 sin marca de agua). Acepta enlaces cortos (`vm.` / `vt.tiktok.com`) y largos.

## Decisión
- Mantener tikwm.com como proveedor, en la clase `TikwmService`.
- Aislarlo detrás de la interfaz `TikTokService` (`fetchVideo`, `downloadAudio`). La interfaz no sabe nada de carpetas: entrega un archivo temporal y `LibraryController` decide dónde guardarlo.
- La implementación concreta se elige en un único lugar: `home_shell.dart`.

## Alternativas consideradas
- **Analizar el HTML de TikTok directamente:** se rompe con cualquier cambio de TikTok y requiere manejar firmas y cookies.
- **Servidor propio con `yt-dlp`:** robusto, pero exige infraestructura y mantenimiento.

## Consecuencias
- ✅ Cero infraestructura y código simple; comportamiento idéntico al de la versión anterior.
- ✅ Cambiar de proveedor implica escribir otra clase que implemente `TikTokService`; la interfaz de usuario no cambia.
- ⚠️ Es un servicio de terceros sin garantías: puede limitar peticiones, cambiar el formato o dejar de funcionar.
- ⚠️ Las URL del video tienen fecha de caducidad (parámetro `x-expires`): hay que descargar poco después de procesar el enlace, no reutilizarlas más tarde.
