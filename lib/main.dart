import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'home_shell.dart';
import 'library_controller.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Registra el servicio en segundo plano: crea la sesión multimedia del
  // sistema (controles de auriculares Bluetooth, pantalla de bloqueo) y la
  // notificación con anterior / pausa / siguiente.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.prueba_reproductor.audio',
    androidNotificationChannelName: 'Reproducción de audio',
    androidNotificationOngoing: true,
  );

  runApp(MainApp(library: LibraryController()));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.library});

  final LibraryController library;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reproductor',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: HomeShell(library: library),
    );
  }
}
