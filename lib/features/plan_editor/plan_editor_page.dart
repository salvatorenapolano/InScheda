import 'package:flutter/material.dart';

import 'package:my_workout/data/user_data_store.dart';
import 'package:my_workout/data/workout_repository.dart';
import 'package:my_workout/features/plan_editor/days_editor.dart';
import 'package:my_workout/features/plan_editor/plan_draft.dart';
import 'package:my_workout/features/plan_editor/workouts_editor.dart';
import 'package:my_workout/features/plan_import/plan_import.dart';
import 'package:my_workout/features/plan_import/plan_import_page.dart';
import 'package:my_workout/models/exercise.dart';
import 'package:my_workout/widgets/save_on_exit.dart';

/// "Modifica la scheda" (matita nella tab Allenamento): gli stessi pezzi
/// dell'onboarding, giorni e schede, in una pagina sola.
///
/// Le modifiche restano nel [PlanDraft] e si salvano da sole quando torni
/// indietro ([SaveOnExit]).
class PlanEditorPage extends StatefulWidget {
  const PlanEditorPage({super.key});

  @override
  State<PlanEditorPage> createState() => _PlanEditorPageState();
}

class _PlanEditorPageState extends State<PlanEditorPage> {
  // Scheda attuale (se c'è) e libreria degli esercizi.
  late final Future<WorkoutData> _data = WorkoutRepository(bundle: DefaultAssetBundle.of(context)).load();

  // Creato quando arrivano i dati. `??=` lo assegna solo se è ancora null,
  // così i ridisegni successivi non ripartono dalla scheda salvata.
  PlanDraft? _draft;

  @override
  void dispose() {
    _draft?.dispose();
    super.dispose();
  }

  /// Cosa manca perché la scheda si possa salvare (null = niente).
  static String? _problem(PlanDraft draft) => switch ((draft.hasDays, draft.workoutsReady)) {
    (false, _) => 'Scegli almeno un giorno',
    (_, false) => 'Ogni scheda ha bisogno di esercizi',
    _ => null,
  };

  /// "Importa con l'IA": la scheda importata sostituisce quella in modifica
  /// (prima chiede conferma, se c'erano già degli esercizi).
  Future<void> _import(PlanDraft draft, Map<String, Exercise> library) async {
    final userData = UserDataScope.of(context);
    final navigator = Navigator.of(context);
    final hasExercises = draft.workouts.any((w) => w.exercises.isNotEmpty);
    if (hasExercises) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sostituire la scheda?'),
          content: const Text(
            'Giorni ed esercizi verranno sostituiti con quelli della scheda importata. '
            'Prima di uscire potrai controllare tutto.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Continua')),
          ],
        ),
      );
      if (ok != true) return;
    }
    final result = await navigator.push<PlanImport>(
      MaterialPageRoute(builder: (_) => PlanImportPage(library: library)),
    );
    if (result == null) return;
    await applyPlanImport(result: result, draft: draft, library: library, userData: userData);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WorkoutData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('Non riesco a leggere la scheda:\n${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.requireData;
        final plan = data.plan;
        final draft = _draft ??= plan == null ? PlanDraft() : PlanDraft.fromPlan(plan);

        final userData = UserDataScope.of(context);

        return SaveOnExit(
          draft: draft,
          problem: () => _problem(draft),
          onSave: () => userData.savePlan(draft.toPlan(today: DateTime.now())),
          savedMessage: 'Scheda salvata',
          child: Scaffold(
            appBar: AppBar(title: const Text('La tua scheda')),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                DaysEditor(draft: draft),
                const SizedBox(height: 24),
                // Il titolo "Schede" con, accanto, il pulsante per importarle:
                // vicino a quello che cambia, e con una scritta (un'icona
                // da sola non si capiva).
                Row(
                  children: [
                    Expanded(child: Text('Schede', style: Theme.of(context).textTheme.titleMedium)),
                    FilledButton.tonalIcon(
                      onPressed: () => _import(draft, data.exercises),
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text("Importa con l'IA"),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                WorkoutsEditor(draft: draft, library: data.exercises),
              ],
            ),
            // Niente pulsante Salva: in fondo compare solo cosa manca, se manca qualcosa.
            bottomNavigationBar: ListenableBuilder(
              listenable: draft,
              builder: (context, _) => switch (_problem(draft)) {
                final problem? => EditorProblemBar(problem: problem),
                null => const SizedBox.shrink(),
              },
            ),
          ),
        );
      },
    );
  }
}
