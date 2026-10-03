import 'package:flutter/material.dart';

/// Pide un texto en un diálogo. Devuelve el texto (sin espacios a los lados)
/// o null si se canceló.
///
/// El diálogo es dueño de su controlador: liberarlo apenas showDialog termina
/// rompe la animación de salida, que todavía dibuja el campo.
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String confirmLabel,
  String? hint,
  int maxLength = 300,
  int maxLines = 1,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextInputDialog(
    title: title,
    label: label,
    confirmLabel: confirmLabel,
    hint: hint,
    maxLength: maxLength,
    maxLines: maxLines,
  ),
);

class _TextInputDialog extends StatefulWidget {
  final String title;
  final String label;
  final String confirmLabel;
  final String? hint;
  final int maxLength;
  final int maxLines;

  const _TextInputDialog({
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.hint,
    required this.maxLength,
    required this.maxLines,
  });

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        maxLines: widget.maxLines,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
