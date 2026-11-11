import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:my_workout/data/user_data_store.dart';
import 'package:my_workout/features/plan_editor/plan_draft.dart';
import 'package:my_workout/features/plan_import/plan_import.dart';
import 'package:my_workout/models/exercise.dart';
import 'package:my_workout/utils/formatters.dart';

/// "Importa la scheda": copi il prompt, lo dai a un'IA con il PDF, incolli
/// la risposta. L'anteprima mostra cosa è stato capito; "Usa questa scheda"
/// chiude la pagina restituendo la [PlanImport] (con pop).
///
/// Questa pagina non salva niente: chi la apre mette la scheda nella bozza
/// con [applyPlanImport], e l'utente la controlla nell'editor.
class PlanImportPage extends StatefulWidget {
  const PlanImportPage({super.key, required this.library});

  /// La libreria (anche gli esercizi personali): finisce nel prompt e serve
  /// a riconoscere gli esercizi della risposta.
  final Map<String, Exercise> library;

  @override
  State<PlanImportPage> createState() => _PlanImportPageState();
}

class _PlanImportPageState extends State<PlanImportPage> {
  final _answer = TextEditingController();

  // L'ultimo risultato: o la scheda letta, o il motivo per cui non si legge.
  PlanImport? _result;
  String? _error;

  late final String _prompt = buildPlanPrompt(widget.library.values);

  @override
  void initState() {
    super.initState();
    // Ogni volta che cambia il testo incollato, lo rileggiamo: è veloce.
    _answer.addListener(_parse);
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  void _parse() {
    final text = _answer.text;
    setState(() {
      if (text.trim().isEmpty) {
        _result = null;
        _error = null;
        return;
      }
      try {
        _result = parsePlanImport(text, widget.library, today: DateTime.now());
        _error = null;
      } on PlanImportException catch (e) {
        _result = null;
        _error = e.message;
      }
    });
  }

  Future<void> _copyPrompt() async {
    // Clipboard: gli "appunti" del telefono, gli stessi del copia e incolla.
    await Clipboard.setData(ClipboardData(text: _prompt));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Prompt copiato: incollalo nella tua IA')));
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (!mounted) return;
    if (text == null || text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Negli appunti non c\'è testo: copia la risposta dell\'IA')));
      return;
    }
    _answer.text = text; // il listener la rilegge da solo
  }

  void _showPrompt() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Il prompt'),
        // SelectableText: si può anche selezionare e copiare un pezzo.
        content: SingleChildScrollView(child: SelectableText(_prompt, style: const TextStyle(fontSize: 12))),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Chiudi'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('Importa la scheda')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Hai la scheda del tuo PT in PDF o in foto? Un\'IA come ChatGPT, Gemini o Claude '
            'può trascriverla per te in un minuto.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          _StepCard(
            number: 1,
            title: 'Copia il prompt',
            text: 'Sono le istruzioni per l\'IA, con l\'elenco degli esercizi di InScheda.',
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _copyPrompt,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copia il prompt'),
                  ),
                  TextButton(onPressed: _showPrompt, child: const Text('Leggilo')),
                ],
              ),
            ],
          ),
          _StepCard(
            number: 2,
            title: 'Chiedi all\'IA',
            text: 'Apri la tua IA, incolla il prompt e allega il PDF o la foto della scheda. '
                'Se ti fa delle domande (per esempio quale fase usare), rispondi.',
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, size: 18, color: secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Il file lo mandi tu, all\'IA che scegli tu: InScheda non invia niente a nessuno.',
                      style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
          _StepCard(
            number: 3,
            title: 'Incolla la risposta',
            text: 'Copia tutta la risposta dell\'IA e torna qui.',
            children: [
              FilledButton.tonalIcon(
                onPressed: _paste,
                icon: const Icon(Icons.content_paste),
                label: const Text('Incolla dagli appunti'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _answer,
                minLines: 3,
                maxLines: 8,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'Risposta dell\'IA',
                  hintText: '{ "inscheda": 1, "type": "workout", … }',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          if (_error case final error?) _ErrorCard(message: error),
          if (result != null) _Preview(result: result),
        ],
      ),
      bottomNavigationBar: result == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(result),
                  child: const Text('Usa questa scheda'),
                ),
              ),
            ),
    );
  }
}

/// Un passo numerato: "1 · Copia il prompt" con la spiegazione e i pulsanti.
class _StepCard extends StatelessWidget {
  const _StepCard({required this.number, required this.title, required this.text, required this.children});

  final int number;
  final String title;
  final String text;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: colors.primaryContainer,
              child: Text('$number', style: theme.textTheme.labelLarge?.copyWith(color: colors.onPrimaryContainer)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  ...children,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: colors.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: TextStyle(color: colors.onErrorContainer))),
          ],
        ),
      ),
    );
  }
}

/// Cosa è stato capito: schede, giorni, esercizi nuovi e cose da controllare.
class _Preview extends StatelessWidget {
  const _Preview({required this.result});

  final PlanImport result;

  static const _days = ['lun', 'mar', 'mer', 'gio', 'ven', 'sab', 'dom'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final workouts = result.workouts;
    final endDate = result.endDate;

    final summary = [
      workouts.length == 1 ? '1 scheda' : '${workouts.length} schede',
      if (result.weekdays.isNotEmpty) [for (final d in result.weekdays) _days[d - 1]].join(', '),
      '${result.exerciseCount} esercizi',
      if (endDate != null) 'fino al ${formatDayMonth(endDate)} ${endDate.year}',
    ].join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('Scheda letta', style: theme.textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 4),
            Text(summary, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            for (final workout in workouts)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${workout.name}: ${workout.exercises.length} esercizi',
                  style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
            if (result.weekdays.isEmpty)
              _Note(icon: Icons.event, text: 'L\'IA non ha scritto i giorni: li sceglierai tu.'),
            if (result.newExercises.isNotEmpty)
              _Note(
                icon: Icons.add_circle_outline,
                text: '${result.newExercises.length == 1 //
                    ? "1 esercizio nuovo, che non è nella libreria: diventerà un esercizio tuo."
                    : "${result.newExercises.length} esercizi nuovi, che non sono nella libreria: diventeranno esercizi tuoi."}\n'
                    '${result.newExercises.map((e) => e.name).join(', ')}',
              ),
            for (final warning in result.warnings) _Note(icon: Icons.info_outline, text: warning),
            const SizedBox(height: 8),
            Text(
              'Dopo potrai controllare e cambiare tutto, come se l\'avessi scritta tu.',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una riga dell'anteprima con la sua icona.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.tertiary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Mette la scheda importata nella bozza: prima salva gli esercizi nuovi
/// tra quelli personali (senza, la scheda salvata userebbe id sconosciuti),
/// poi sostituisce giorni e schede. [library] si aggiorna anche lei, così
/// l'editor mostra subito gli esercizi nuovi.
Future<void> applyPlanImport({
  required PlanImport result,
  required PlanDraft draft,
  required Map<String, Exercise> library,
  required UserDataStore userData,
}) async {
  await userData.addCustomExercises(result.newExercises);
  for (final exercise in result.newExercises) {
    library[exercise.id] = exercise;
  }
  draft.replaceWith(
    weekdays: result.weekdays,
    endDate: result.endDate,
    workouts: [for (final w in result.workouts) (w.name, w.exercises)],
  );
}
