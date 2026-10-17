import 'package:flutter/material.dart';

import 'library_controller.dart';
import 'theme.dart';

/// Menú de acciones de una canción (al mantenerla pulsada en la Biblioteca).
Future<void> showTrackActions(
  BuildContext context,
  LibraryController library,
  Track track,
) async {
  final action = await showModalBottomSheet<_TrackAction>(
    context: context,
    backgroundColor: AppColors.card,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              track.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          for (final action in _TrackAction.values)
            ListTile(
              leading: Icon(action.icon, color: action.color),
              title: Text(action.label, style: TextStyle(color: action.color)),
              onTap: () => Navigator.pop(context, action),
            ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;

  try {
    switch (action) {
      case _TrackAction.rename:
        final title = await showDialog<String>(
          context: context,
          builder: (_) => _RenameDialog(initial: track.title),
        );
        if (title != null) await library.renameTrack(track, title);
      case _TrackAction.share:
        await library.shareTrack(track);
      case _TrackAction.delete:
        if (await _confirmDelete(context, track)) {
          await library.deleteTrack(track);
          if (context.mounted) showMessage(context, 'Audio eliminado');
        }
    }
  } catch (e) {
    if (context.mounted) showAppAlert(context, 'Error', '$e');
  }
}

enum _TrackAction {
  rename('Renombrar', Icons.edit_outlined),
  share('Compartir', Icons.share_outlined),
  delete('Eliminar', Icons.delete_outline, AppColors.danger);

  const _TrackAction(this.label, this.icon, [this.color = Colors.white]);

  final String label;
  final IconData icon;
  final Color color;
}

Future<bool> _confirmDelete(BuildContext context, Track track) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('¿Eliminar audio?'),
      content: Text(
        '"${track.title}" se borrará del teléfono. Esta acción no se puede '
        'deshacer.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  // El texto empieza seleccionado para poder reemplazarlo directamente.
  late final _controller = TextEditingController(text: widget.initial)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('Renombrar'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 100,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        decoration: const InputDecoration(hintText: 'Nuevo nombre'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
