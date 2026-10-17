import 'package:flutter/material.dart';

/// Paleta tomada del diseño original en React Native.
abstract final class AppColors {
  static const background = Color(0xFF121212);
  static const header = Color(0xFF1C0F45);
  static const purple = Color(0xFF4A148C);
  static const magenta = Color(0xFF880E4F);
  static const accent = Color(0xFFFF4081);
  static const success = Color(0xFF00C853);
  static const danger = Color(0xFFD32F2F);
  static const card = Color(0xFF1E1E1E);
  static const iconBackground = Color(0xFF2C2C2C);
  static const input = Color(0xFF222222);
  static const inputBorder = Color(0xFF333333);
  static const textSecondary = Color(0xFFAAAAAA);
  static const textMuted = Color(0xFF666666);
  static const divider = Color(0x1AFFFFFF);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.dark,
  ).copyWith(primary: AppColors.accent, surface: AppColors.background);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.accent,
      inactiveTrackColor: Color(0x4DFFFFFF),
      thumbColor: AppColors.accent,
      overlayColor: Color(0x29FF4081),
      trackHeight: 3,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Fondo degradado morado → negro que usan Descargar y Configuración.
class GradientBackground extends StatelessWidget {
  const GradientBackground({
    super.key,
    required this.child,
    this.colors = const [AppColors.header, Colors.black],
  });

  final Widget child;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: child,
    );
  }
}

/// Botón ⓧ para vaciar un campo de texto. Se usa como `suffixIcon` y solo
/// debe mostrarse cuando el campo tiene texto.
class ClearFieldButton extends StatelessWidget {
  const ClearFieldButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Borrar',
      icon: const Icon(Icons.cancel, color: AppColors.textSecondary),
      onPressed: onPressed,
    );
  }
}

/// Diálogo simple estilo Android, como el "Guardado" del diseño original.
Future<void> showAppAlert(BuildContext context, String title, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF424242),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF80CBC4)),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

void showMessage(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

String formatDuration(Duration d) {
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '${d.inMinutes}:$seconds';
}

String formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}
