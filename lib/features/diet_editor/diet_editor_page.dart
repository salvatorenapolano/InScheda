import 'package:flutter/material.dart';

import 'package:my_workout/data/diet_repository.dart';
import 'package:my_workout/data/user_data_store.dart';
import 'package:my_workout/data/workout_repository.dart';
import 'package:my_workout/features/diet_editor/diet_draft.dart';
import 'package:my_workout/features/diet_editor/food_item_dialog.dart';
import 'package:my_workout/models/diet.dart';
import 'package:my_workout/models/workout_plan.dart';
import 'package:my_workout/widgets/save_on_exit.dart';
import 'package:my_workout/widgets/text_input_dialog.dart';

/// L'editor della dieta: una scheda per giorno (Lun … Dom), in ognuna i
/// pasti accesi (pranzo, cena...) con il nome del piatto e gli alimenti.
///
/// Si apre dalla tab Dieta vuota ("Crea la dieta") o dalla matita accanto
/// al titolo. Come per la scheda, si salva da sola quando torni indietro.
class DietEditorPage extends StatefulWidget {
  const DietEditorPage({super.key});

  @override
  State<DietEditorPage> createState() => _DietEditorPageState();
}

class _DietEditorPageState extends State<DietEditorPage> {
  // La dieta attuale (se c'è) e la scheda, per sapere i giorni di palestra.
  // Un record (a, b) per restituire due valori da una sola funzione.
  late final Future<(Diet?, WorkoutPlan?)> _data = _load();

  DietDraft? _draft;

  Future<(Diet?, WorkoutPlan?)> _load() async {
    final bundle = DefaultAssetBundle.of(context);
    final diet = await DietRepository(bundle: bundle).load();
    final workout = await WorkoutRepository(bundle: bundle).load();
    return (diet, workout.plan);
  }

  @override
  void dispose() {
    _draft?.dispose();
    super.dispose();
  }

  static String? _problem(DietDraft draft) => draft.hasContent ? null : 'Scrivi almeno un pasto';

  Future<void> _copyDay(BuildContext context, DietDraft draft) async {
    // Il giorno aperto: lo sa il DefaultTabController sopra di noi.
    final from = DefaultTabController.of(context).index;
    final targets = await showDialog<Set<int>>(
      context: context,
      builder: (context) => _CopyDayDialog(from: from),
    );
    if (targets != null && targets.isNotEmpty) draft.copyDay(from, targets);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(Diet?, WorkoutPlan?)>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('Non riesco a leggere la dieta:\n${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        // Il record si "spacchetta" in due variabili.
        final (diet, plan) = snapshot.requireData;
        final draft = _draft ??= diet == null ? DietDraft() : DietDraft.fromDiet(diet);
        final today = DateTime.now().weekday - 1;

        final userData = UserDataScope.of(context);

        return SaveOnExit(
          draft: draft,
          problem: () => _problem(draft),
          onSave: () => userData.saveDiet(draft.toDiet(trainingWeekdays: {...?plan?.schedule.weekdays})),
          savedMessage: 'Dieta salvata',
          child: DefaultTabController(
            length: 7,
            initialIndex: today,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('La tua dieta'),
                actions: [
                  // Builder: un context che sta DENTRO il DefaultTabController.
                  Builder(
                    builder: (context) => IconButton(
                      tooltip: 'Copia il giorno',
                      onPressed: () => _copyDay(context, draft),
                      icon: const Icon(Icons.copy_all_outlined),
                    ),
                  ),
                ],
                bottom: TabBar(
                  tabs: [for (final name in DietDraft.dayNames) Tab(text: name.substring(0, 3))],
                  labelPadding: EdgeInsets.zero,
                ),
              ),
              body: TabBarView(
                children: [for (var day = 0; day < 7; day++) _DayEditor(draft: draft, day: day)],
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
          ),
        );
      },
    );
  }
}

/// Un giorno dell'editor: i momenti da accendere e i pasti accesi.
class _DayEditor extends StatelessWidget {
  const _DayEditor({required this.draft, required this.day});

  final DietDraft draft;
  final int day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('Pasti da segnare', style: theme.textTheme.titleMedium),
          Text(
            'Valgono per tutti i giorni.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final slot in draft.slots)
                FilterChip(
                  label: Text([?slot.emoji, slot.name].join(' ')),
                  selected: draft.isActive(slot.id),
                  onSelected: (_) => draft.toggleSlot(slot.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
          for (final slot in draft.activeSlots) _MealEditor(draft: draft, day: day, slot: slot),
        ],
      ),
    );
  }
}

/// Un pasto: il momento, il nome del piatto e gli alimenti.
class _MealEditor extends StatelessWidget {
  const _MealEditor({required this.draft, required this.day, required this.slot});

  final DietDraft draft;
  final int day;
  final MealSlot slot;

  Future<void> _editTitle(BuildContext context, MealDraft meal) async {
    final title = await showDialog<String>(
      context: context,
      builder: (context) =>
          TextInputDialog(title: 'Nome del piatto', initialText: meal.title, hint: 'Es. Pasta al tonno (facoltativo)'),
    );
    if (title != null) draft.setTitle(day, slot.id, title);
  }

  Future<void> _setEveryDay(BuildContext context, bool value) async {
    // Accendendola, se negli altri giorni c'è un pasto diverso lo
    // sostituiamo: meglio chiedere prima.
    if (value && draft.othersDiffer(day, slot.id)) {
      final dayName = DietDraft.dayNames[day].toLowerCase();
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${slot.name} uguale tutti i giorni?'),
          content: Text('Il ${slot.name.toLowerCase()} di $dayName sostituirà quello scritto negli altri giorni.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sostituisci')),
          ],
        ),
      );
      if (ok != true) return;
    }
    draft.setEveryDay(day, slot.id, value);
  }

  Future<void> _editItem(BuildContext context, MealDraft meal, int? index) async {
    final item = await showDialog<FoodItemDraft>(
      context: context,
      builder: (context) => FoodItemDialog(item: index == null ? null : meal.items[index]),
    );
    if (item == null) return;
    if (index == null) {
      draft.addItem(day, slot.id, item);
    } else {
      draft.updateItem(day, slot.id, index, item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final meal = draft.meal(day, slot.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                [?slot.emoji, slot.name].join('  '),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // La spunta: questo pasto è lo stesso dal lunedì alla domenica.
            CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Uguale tutti i giorni'),
              subtitle: draft.isEveryDay(slot.id) ? const Text('Se lo cambi qui, cambia in tutti i giorni') : null,
              value: draft.isEveryDay(slot.id),
              onChanged: (value) => _setEveryDay(context, value ?? false),
            ),
            ListTile(
              title: Text(
                meal.title.isEmpty ? 'Nome del piatto' : meal.title,
                style: meal.title.isEmpty ? TextStyle(color: secondary) : theme.textTheme.titleMedium,
              ),
              subtitle: meal.title.isEmpty ? const Text('Facoltativo: tocca per scriverlo') : null,
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editTitle(context, meal),
            ),
            for (final (index, item) in meal.items.indexed)
              ListTile(
                dense: true,
                leading: Icon(Icons.circle, size: 8, color: theme.colorScheme.primary),
                minLeadingWidth: 8,
                title: Text(item.name, style: theme.textTheme.bodyLarge),
                subtitle: [item.amountLabel, item.note].nonNulls.isEmpty
                    ? null
                    // nonNulls: toglie i null dalla lista prima di unire i pezzi.
                    : Text([item.amountLabel, item.note].nonNulls.join(' · ')),
                onTap: () => _editItem(context, meal, index),
                trailing: IconButton(
                  tooltip: 'Togli ${item.name}',
                  onPressed: () => draft.removeItem(day, slot.id, index),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextButton.icon(
                  onPressed: () => _editItem(context, meal, null),
                  icon: const Icon(Icons.add),
                  label: const Text('Aggiungi alimento'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Copia il lunedì su…": le caselle degli altri giorni.
class _CopyDayDialog extends StatefulWidget {
  const _CopyDayDialog({required this.from});

  final int from;

  @override
  State<_CopyDayDialog> createState() => _CopyDayDialogState();
}

class _CopyDayDialogState extends State<_CopyDayDialog> {
  final _selected = <int>{};

  @override
  Widget build(BuildContext context) {
    final fromName = DietDraft.dayNames[widget.from];
    return AlertDialog(
      title: Text('Copia $fromName su…'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'I pasti dei giorni scelti verranno sostituiti con quelli di $fromName.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          for (var day = 0; day < 7; day++)
            if (day != widget.from)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(DietDraft.dayNames[day]),
                value: _selected.contains(day),
                onChanged: (_) => setState(() {
                  if (!_selected.remove(day)) _selected.add(day);
                }),
              ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annulla')),
        FilledButton(
          onPressed: _selected.isEmpty ? null : () => Navigator.of(context).pop(_selected),
          child: const Text('Copia'),
        ),
      ],
    );
  }
}
