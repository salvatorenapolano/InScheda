import 'package:flutter/material.dart';

import 'package:my_workout/data/user_data_store.dart';
import 'package:my_workout/data/workout_repository.dart';
import 'package:my_workout/features/plan_editor/days_editor.dart';
import 'package:my_workout/features/plan_editor/plan_draft.dart';
import 'package:my_workout/features/plan_editor/workouts_editor.dart';

/// "Modifica la scheda" (dal cerchio del profilo): gli stessi pezzi
/// dell'onboarding, giorni e schede, in una pagina sola con "Salva".
///
/// Le modifiche restano nel [PlanDraft] finché non premi Salva: se torni
/// indietro senza salvare, la scheda resta com'era.
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

  bool _saving = false;

  @override
  void dispose() {
    _draft?.dispose();
    super.dispose();
  }

  Future<void> _save(PlanDraft draft) async {
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    await UserDataScope.of(context).savePlan(draft.toPlan(today: DateTime.now()));
    navigator.pop();
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
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        final data = snapshot.requireData;
        final plan = data.plan;
        final draft = _draft ??= plan == null ? PlanDraft() : PlanDraft.fromPlan(plan);

        return Scaffold(
          appBar: AppBar(title: const Text('La tua scheda')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              DaysEditor(draft: draft),
              const SizedBox(height: 32),
              Text('Schede', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              WorkoutsEditor(draft: draft, library: data.exercises),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ListenableBuilder(
                listenable: draft,
                builder: (context, _) {
                  final ready = draft.hasDays && draft.workoutsReady;
                  return FilledButton(
                    onPressed: ready && !_saving ? () => _save(draft) : null,
                    child: Text(switch ((draft.hasDays, draft.workoutsReady)) {
                      (false, _) => 'Scegli almeno un giorno',
                      (_, false) => 'Ogni scheda ha bisogno di esercizi',
                      _ => 'Salva',
                    }),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
