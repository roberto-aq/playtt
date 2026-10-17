import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

import 'audio_library.dart';
import 'downloader_screen.dart';
import 'library_controller.dart';
import 'library_screen.dart';
import 'mini_player.dart';
import 'native_bridge.dart';
import 'player_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'tiktok_service.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.library});

  final LibraryController library;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final TikTokService _tiktok = TikwmService();

  static const _downloaderTab = 1;

  int _tab = 0;
  late final StreamSubscription<PlayerException> _errors;

  /// Enlace recibido desde el menú "Compartir", pendiente de procesar por
  /// la pestaña Descargar.
  final _sharedLink = ValueNotifier<String?>(null);

  LibraryController get library => widget.library;

  @override
  void initState() {
    super.initState();
    _errors = library.player.errorStream.listen((e) {
      if (!mounted) return;
      showMessage(context, 'No se pudo reproducir: ${e.message ?? e.code}');
    });
    library.start();
    NativeBridge.listenSharedText(_onSharedText);
  }

  @override
  void dispose() {
    _errors.cancel();
    _sharedLink.dispose();
    super.dispose();
  }

  /// Texto compartido desde otra app: si trae un enlace de TikTok, se abre
  /// la pestaña Descargar y se procesa.
  void _onSharedText(String text) {
    if (!mounted) return;
    final url = extractTikTokUrl(text);
    if (url == null) {
      showAppAlert(
        context,
        'Enlace no válido',
        'Lo que compartiste no contiene un enlace de TikTok.',
      );
      return;
    }
    // Cierra el reproductor completo u otra pantalla abierta encima.
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() => _tab = _downloaderTab);
    _sharedLink.value = url;
  }

  /// Pide permisos y carga una carpeta: la de [path] o, si es `null`, la que
  /// se elija en el selector del sistema.
  Future<bool> _openFolder({String? path}) async {
    if (!await requestAudioPermission()) {
      if (!mounted) return false;
      showMessage(context, 'Se necesita permiso para leer tu música.');
      if (await Permission.audio.isPermanentlyDenied ||
          await Permission.storage.isPermanentlyDenied) {
        await openAppSettings();
      }
      return false;
    }

    try {
      if (path != null) {
        await library.openFolder(path);
        return true;
      }

      final picked = await NativeBridge.pickFolder();
      debugPrint('Elegir carpeta: ruta=${picked?.path} uri=${picked?.uri}');
      if (picked == null) return false;
      if (picked.path == null) {
        if (mounted) {
          showMessage(
            context,
            'Elige una carpeta del almacenamiento del teléfono.',
          );
        }
        return false;
      }
      await library.openFolder(picked.path!, uri: picked.uri);
      debugPrint('Elegir carpeta: ${library.tracks.length} audios cargados');
      return true;
    } catch (e) {
      debugPrint('Elegir carpeta: error $e');
      if (mounted) showMessage(context, 'Error al cargar la carpeta: $e');
      return false;
    }
  }

  void _openPlayer() {
    Navigator.of(context).push(PlayerScreen.route(library));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ListenableBuilder(
        listenable: library,
        builder: (context, _) {
          return Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: IndexedStack(
                    index: _tab,
                    children: [
                      LibraryScreen(
                        library: library,
                        onChooseFolder: _openFolder,
                        onTrackTap: (i) {
                          library.playTrack(i);
                          _openPlayer();
                        },
                      ),
                      DownloaderScreen(
                        library: library,
                        service: _tiktok,
                        sharedLink: _sharedLink,
                      ),
                      SettingsScreen(
                        library: library,
                        onChangeFolder: () async {
                          if (await _openFolder() && context.mounted) {
                            showAppAlert(
                              context,
                              'Carpeta Actualizada',
                              'La biblioteca ahora usará esta carpeta.',
                            );
                          }
                        },
                        onRestore: () async {
                          if (await _openFolder(path: defaultMusicFolder) &&
                              context.mounted) {
                            showAppAlert(
                              context,
                              'Restaurado',
                              'Se usará la carpeta Música/TikTok.',
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                if (library.tracks.isNotEmpty)
                  MiniPlayer(player: library.player, onTap: _openPlayer),
              ],
            ),
            bottomNavigationBar: _BottomBar(
              index: _tab,
              onTap: (i) => setState(() => _tab = i),
            ),
          );
        },
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      // Sin el efecto de onda (ripple) al tocar una pestaña.
      child: Theme(
        data: Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          currentIndex: index,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.header,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: AppColors.textSecondary,
          iconSize: 28,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.library_music),
              label: 'Biblioteca',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.download),
              label: 'Descargar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Configuración',
            ),
          ],
        ),
      ),
    );
  }
}
