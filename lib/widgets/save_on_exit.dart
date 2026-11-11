import 'package:flutter/material.dart';

/// Avvolge un editor (scheda, dieta, spesa) e lo salva da solo: niente
/// pulsante Salva, le modifiche si salvano quando torni indietro.
///
/// Come funziona:
/// - ascolta la bozza ([draft]): al primo cambiamento sa che c'è qualcosa
///   da salvare (se non tocchi niente, uscendo non scrive nessun file);
/// - [PopScope] "intercetta" l'uscita (freccia in alto, tasto o gesto
///   indietro di Android): prima salva, poi chiude la pagina;
/// - [AppLifecycleListener] salva anche se esci dall'app con l'editor
///   aperto: Android potrebbe chiuderla e le modifiche andrebbero perse.
///
/// Se la bozza non si può salvare ([problem] dice perché, es. "Scegli
/// almeno un giorno"), uscendo chiede se vuoi perdere le modifiche.
class SaveOnExit extends StatefulWidget {
  const SaveOnExit({
    super.key,
    required this.draft,
    required this.problem,
    required this.onSave,
    required this.savedMessage,
    required this.child,
  });

  /// La bozza dell'editor: un ChangeNotifier come PlanDraft o DietDraft.
  final Listenable draft;

  /// null se la bozza si può salvare, altrimenti il motivo.
  final String? Function() problem;

  /// Scrive la bozza (savePlan, saveDiet...).
  final Future<void> Function() onSave;

  /// Il messaggio in basso dopo il salvataggio: "Scheda salvata".
  final String savedMessage;

  final Widget child;

  @override
  State<SaveOnExit> createState() => _SaveOnExitState();
}

class _SaveOnExitState extends State<SaveOnExit> {
  /// Ci sono modifiche non ancora scritte su file?
  bool _dirty = false;
  bool _saving = false;
  bool _leaving = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    widget.draft.addListener(_markDirty);
    // onHide: l'app non si vede più (home, altra app, schermo spento).
    // Se qui il salvataggio fallisce, riproveremo uscendo dall'editor.
    _lifecycle = AppLifecycleListener(onHide: () => _saveIfPossible().catchError((_) => false));
  }

  @override
  void didUpdateWidget(SaveOnExit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft != widget.draft) {
      oldWidget.draft.removeListener(_markDirty);
      widget.draft.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    widget.draft.removeListener(_markDirty);
    _lifecycle.dispose();
    super.dispose();
  }

  void _markDirty() => _dirty = true;

  /// Salva se c'è qualcosa da salvare e la bozza è valida.
  /// Restituisce true se ha scritto il file.
  Future<bool> _saveIfPossible() async {
    if (!_dirty || _saving || widget.problem() != null) return false;
    _saving = true;
    // Prima di scrivere: se cambi qualcosa mentre salviamo, torna "da salvare".
    _dirty = false;
    try {
      await widget.onSave();
      return true;
    } catch (_) {
      _dirty = true;
      rethrow;
    } finally {
      _saving = false;
    }
  }

  Future<void> _leave() async {
    if (_leaving) return; // due "indietro" di fila: basta un'uscita
    _leaving = true;
    // Navigator e ScaffoldMessenger li prendiamo subito: dopo gli `await`
    // il context potrebbe non essere più valido.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final problem = _dirty ? widget.problem() : null;
    if (problem != null) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Non posso salvare'),
          content: Text('$problem\n\nSe esci adesso, le modifiche andranno perse.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Esci senza salvare')),
            FilledButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Continua a modificare')),
          ],
        ),
      );
      _leaving = false;
      if (discard == true) navigator.pop();
      return;
    }

    final bool saved;
    try {
      saved = await _saveIfPossible();
    } catch (error) {
      // Il file non si scrive (memoria piena?): restiamo nell'editor,
      // così le modifiche non si perdono.
      _leaving = false;
      messenger.showSnackBar(SnackBar(content: Text('Non riesco a salvare: $error')));
      return;
    }
    if (saved) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(widget.savedMessage)));
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // canPop false: la pagina non si chiude da sola, ci pensa _leave
      // dopo aver salvato. didPop è false proprio perché l'abbiamo fermata.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: widget.child,
    );
  }
}

/// La riga in fondo all'editor quando la bozza non si può ancora salvare:
/// dice cosa manca, al posto del vecchio pulsante Salva spento.
class EditorProblemBar extends StatelessWidget {
  const EditorProblemBar({super.key, required this.problem});

  final String problem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: colors.secondaryContainer, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: colors.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(problem, style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSecondaryContainer)),
            ),
          ],
        ),
      ),
    );
  }
}
