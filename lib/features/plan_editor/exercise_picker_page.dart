import 'package:flutter/material.dart';

import 'package:my_workout/data/user_data_store.dart';
import 'package:my_workout/features/plan_editor/custom_exercise_dialog.dart';
import 'package:my_workout/features/workout/widgets/exercise_preview.dart';
import 'package:my_workout/models/exercise.dart';
import 'package:my_workout/utils/search.dart';

/// La libreria degli esercizi divisa per gruppo muscolare, con le caselle
/// da spuntare, una barra di ricerca e "Crea un esercizio" per quelli che
/// mancano. "Aggiungi" chiude la pagina e restituisce gli id scelti,
/// nell'ordine in cui li hai toccati.
class ExercisePickerPage extends StatefulWidget {
  const ExercisePickerPage({super.key, required this.library, this.alreadyChosen = const {}});

  final Map<String, Exercise> library;

  /// Gli esercizi che la scheda ha già: compaiono spuntati e bloccati.
  final Set<String> alreadyChosen;

  @override
  State<ExercisePickerPage> createState() => _ExercisePickerPageState();
}

class _ExercisePickerPageState extends State<ExercisePickerPage> {
  // Un Set in Dart ricorda l'ordine di inserimento: gli esercizi finiranno
  // nella scheda nell'ordine in cui li hai spuntati.
  final _selected = <String>{};

  // Il testo della barra di ricerca. La pagina lo ascolta con un
  // ListenableBuilder: a ogni lettera la lista si filtra da sola.
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  /// Dove si cerca: nome, muscoli e gruppo ("Spalle" trova anche le
  /// alzate laterali, anche se tra i muscoli c'è scritto solo "Spalle").
  bool _matches(Exercise exercise) =>
      matchesSearch(_search.text, [exercise.name, ...exercise.muscles, exercise.group.label]);

  /// "Crea un esercizio": lo salva tra i dati dell'utente, lo aggiunge alla
  /// libreria che stiamo mostrando e lo spunta subito. Se stavi cercando
  /// qualcosa, il nome parte da quello che hai scritto.
  Future<void> _createExercise() async {
    final userData = UserDataScope.of(context);
    final exercise = await showDialog<Exercise>(
      context: context,
      builder: (context) => CustomExerciseDialog(
        takenIds: widget.library.keys.toSet(),
        initialName: _search.text.trim(),
      ),
    );
    if (exercise == null) return;
    await userData.addCustomExercise(exercise);
    // La mappa della libreria è la stessa che usano la pagina degli esercizi
    // e l'editor delle schede: aggiungendolo qui lo trovano anche loro.
    widget.library[exercise.id] = exercise;
    if (!mounted) return;
    // Svuotiamo la ricerca, così il nuovo esercizio si vede nella sua sezione.
    _search.clear();
    setState(() => _selected.add(exercise.id));
  }

  @override
  Widget build(BuildContext context) {
    final count = _selected.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scegli gli esercizi'),
        // bottom: la barra di ricerca resta sotto il titolo, sempre visibile
        // anche quando la lista scorre. PreferredSize perché AppBar vuole
        // sapere quanto è alta (come MainAppBar).
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ListenableBuilder(
              listenable: _search,
              // SearchBar: il campo di ricerca "a pillola" di Material 3.
              builder: (context, _) => SearchBar(
                controller: _search,
                hintText: 'Cerca un esercizio o un muscolo',
                leading: const Icon(Icons.search),
                elevation: const WidgetStatePropertyAll(0),
                trailing: [
                  if (_search.text.isNotEmpty)
                    IconButton(
                      tooltip: 'Cancella la ricerca',
                      onPressed: _search.clear,
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: ListenableBuilder(listenable: _search, builder: (context, _) => _buildList(context)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: count == 0 ? null : () => Navigator.of(context).pop(_selected.toList()),
            child: Text(count == 0 ? 'Scegli almeno un esercizio' : 'Aggiungi ($count)'),
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final theme = Theme.of(context);
    // I gruppi con almeno un esercizio che corrisponde alla ricerca.
    // Un record (gruppo, esercizi) per ogni sezione da mostrare.
    final sections = [
      for (final group in MuscleGroup.values)
        if (widget.library.values.where((e) => e.group == group && _matches(e)).toList() case final exercises
            when exercises.isNotEmpty)
          (group, exercises),
    ];
    final query = _search.text.trim();

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      // Scorrendo la lista la tastiera si chiude, così si vedono più righe.
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        // Per gli esercizi che nella libreria non ci sono.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: OutlinedButton.icon(
            onPressed: _createExercise,
            icon: const Icon(Icons.add),
            label: Text(query.isEmpty ? 'Crea un esercizio' : 'Crea "$query"'),
          ),
        ),
        if (sections.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
            child: Text(
              'Nessun esercizio trovato per "$query".\nControlla come l\'hai scritto, oppure crealo tu.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        // Una sezione per gruppo, nell'ordine dell'enum MuscleGroup.
        for (final (group, exercises) in sections) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text(
              group.label,
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          for (final exercise in exercises) _buildRow(exercise),
        ],
      ],
    );
  }

  Widget _buildRow(Exercise exercise) {
    final already = widget.alreadyChosen.contains(exercise.id);
    // CheckboxListTile: una riga intera che si spunta toccandola.
    return CheckboxListTile(
      value: already || _selected.contains(exercise.id),
      // onChanged null = riga spenta (l'esercizio è già nella scheda).
      onChanged: already ? null : (_) => _toggle(exercise.id),
      secondary: ExercisePreview(exercise: exercise, size: 40),
      title: Text(exercise.name),
      subtitle: Text(
        switch ((already, exercise.custom)) {
          (true, _) => 'Già nella scheda',
          (_, true) => ['Personale', ...exercise.muscles].join(' · '),
          _ => exercise.muscles.join(', '),
        },
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
