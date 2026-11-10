import 'package:flutter/material.dart';

/// Un dialog con un solo campo di testo: restituisce il testo scritto
/// (anche vuoto) con Salva, o null con Annulla.
class TextInputDialog extends StatefulWidget {
  const TextInputDialog({super.key, required this.title, this.initialText = '', this.hint});

  final String title;
  final String initialText;
  final String? hint;

  @override
  State<TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<TextInputDialog> {
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annulla')),
        FilledButton(onPressed: _save, child: const Text('Salva')),
      ],
    );
  }
}
