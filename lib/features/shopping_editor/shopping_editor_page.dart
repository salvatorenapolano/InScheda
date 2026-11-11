import 'package:flutter/material.dart';

import 'package:my_workout/data/diet_repository.dart';
import 'package:my_workout/data/shopping_repository.dart';
import 'package:my_workout/data/shopping_store.dart';
import 'package:my_workout/data/user_data_store.dart';
import 'package:my_workout/features/shopping/widgets/department_badge.dart';
import 'package:my_workout/features/shopping_editor/department_dialog.dart';
import 'package:my_workout/features/shopping_editor/shopping_draft.dart';
import 'package:my_workout/features/shopping_editor/shopping_item_dialog.dart';
import 'package:my_workout/models/diet.dart';
import 'package:my_workout/models/shopping.dart';
import 'package:my_workout/widgets/save_on_exit.dart';
import 'package:my_workout/widgets/text_input_dialog.dart';

/// L'editor della spesa: una scheda per lista, in ognuna i prodotti divisi
/// per reparto.
///
/// Si apre dalla tab Spesa vuota ("Crea la lista") o dalla matita accanto
/// al titolo. Come scheda e dieta, si salva da solo quando torni indietro.
class ShoppingEditorPage extends StatefulWidget {
  const ShoppingEditorPage({super.key});

  @override
  State<ShoppingEditorPage> createState() => _ShoppingEditorPageState();
}

class _ShoppingEditorPageState extends State<ShoppingEditorPage> {
  // La spesa attuale (se c'è) e la dieta, per suggerire i nomi degli alimenti.
  late final Future<(ShoppingData?, Diet?)> _data = _load();

  ShoppingDraft? _draft;

  /// L'ultimo reparto usato: il prossimo "Prodotto" parte da lì, perché
  /// di solito si scrivono di fila le cose dello stesso reparto.
  String? _lastDepartment;

  Future<(ShoppingData?, Diet?)> _load() async {
    final bundle = DefaultAssetBundle.of(context);
    final shopping = await ShoppingRepository(bundle: bundle).load();
    Diet? diet;
    try {
      diet = await DietRepository(bundle: bundle).load();
    } on Object {
      // Una dieta rovinata non deve bloccare la spesa: niente suggerimenti, e basta.
    }
    return (shopping, diet);
  }

  @override
  void dispose() {
    _draft?.dispose();
    super.dispose();
  }

  Future<void> _save(ShoppingDraft draft, UserDataStore userData, ShoppingStore checks) async {
    final data = draft.toData();
    await userData.saveShopping(data);
    await checks.retainOnly({
      for (final list in data.lists)
        for (final item in list.items) item.id,
    });
  }

  static String? _problem(ShoppingDraft draft) => draft.hasContent ? null : 'Aggiungi almeno un prodotto';

  Future<void> _addList(BuildContext context, ShoppingDraft draft) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const TextInputDialog(title: 'Nuova lista', hint: 'Es. Mensile, Casa al mare'),
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    final index = draft.addList(name);
    // La scheda nuova esiste solo dopo il prossimo disegno: allora la apriamo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) DefaultTabController.of(context).animateTo(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(ShoppingData?, Diet?)>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('Non riesco a leggere la lista della spesa:\n${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final (shopping, diet) = snapshot.requireData;
        final draft = _draft ??= shopping == null ? ShoppingDraft() : ShoppingDraft.fromData(shopping);
        final dietNames = [...?diet?.foods.values.map((f) => f.name)];

        // I suggerimenti: gli alimenti della dieta e i prodotti già scritti,
        // senza doppioni (un Set li toglie da solo).
        List<String> suggestions() => {...dietNames, ...draft.itemNames}.toList();

        Future<void> openItem(BuildContext context, int list, String departmentId, [int? index]) {
          final item = index == null ? null : draft.lists[list].section(departmentId)!.items[index];
          return showDialog<void>(
            context: context,
            builder: (context) => ShoppingItemDialog(
              draft: draft,
              departmentId: departmentId,
              item: item,
              suggestions: suggestions(),
              onSave: (written, toDepartment) {
                _lastDepartment = toDepartment;
                if (index == null) {
                  draft.addItem(list, toDepartment, written);
                } else {
                  draft.updateItem(list, departmentId, index, toDepartment, written);
                }
              },
            ),
          );
        }

        final userData = UserDataScope.of(context);
        final checks = ShoppingScope.of(context);

        return SaveOnExit(
          draft: draft,
          problem: () => _problem(draft),
          onSave: () => _save(draft, userData, checks),
          savedMessage: 'Spesa salvata',
          child: ListenableBuilder(
            listenable: draft,
            builder: (context, _) => DefaultTabController(
              // Il numero di schede cambia quando aggiungi o togli una lista:
              // DefaultTabController se ne accorge da solo e si adatta.
              length: draft.lists.length,
              // Builder: un context che sta DENTRO il DefaultTabController.
              child: Builder(
                builder: (context) => Scaffold(
                  appBar: AppBar(
                    title: const Text('La tua spesa'),
                    actions: [
                      IconButton(
                        tooltip: 'Nuova lista',
                        onPressed: () => _addList(context, draft),
                        icon: const Icon(Icons.playlist_add),
                      ),
                    ],
                    bottom: TabBar(
                      // Scorrevole: con tante liste i nomi non si schiacciano.
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: [for (final list in draft.lists) Tab(text: list.name)],
                    ),
                  ),
                  body: TabBarView(
                    children: [
                      for (var i = 0; i < draft.lists.length; i++)
                        _ListEditor(draft: draft, list: i, openItem: openItem),
                    ],
                  ),
                  floatingActionButton: FloatingActionButton.extended(
                    heroTag: null,
                    onPressed: () {
                      final list = DefaultTabController.of(context).index;
                      final sections = draft.lists[list].sections;
                      final start =
                          _lastDepartment ??
                          (sections.isEmpty
                              ? ShoppingDepartment.defaultDepartments.first.id
                              : sections.first.departmentId);
                      openItem(context, list, start);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Prodotto'),
                  ),
                  // Niente pulsante Salva: in fondo compare solo cosa manca, se manca qualcosa.
                  bottomNavigationBar: switch (_problem(draft)) {
                    final problem? => EditorProblemBar(problem: problem),
                    null => null,
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Apre il dialog di un prodotto: [index] null = prodotto nuovo.
typedef _OpenItem = Future<void> Function(BuildContext context, int list, String departmentId, [int? index]);

/// Una lista dell'editor: il nome (con matita e cestino) e i suoi reparti.
class _ListEditor extends StatelessWidget {
  const _ListEditor({required this.draft, required this.list, required this.openItem});

  final ShoppingDraft draft;
  final int list;
  final _OpenItem openItem;

  Future<void> _rename(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => TextInputDialog(title: 'Nome della lista', initialText: draft.lists[list].name),
    );
    if (name != null && name.trim().isNotEmpty) draft.renameList(list, name);
  }

  Future<void> _remove(BuildContext context) async {
    final current = draft.lists[list];
    final count = current.itemCount;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminare "${current.name}"?'),
        content: Text(
          count == 0
              ? 'La lista è vuota.'
              : count == 1
              ? 'Verrà cancellato anche il suo prodotto.'
              : 'Verranno cancellati anche i suoi $count prodotti.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Elimina')),
        ],
      ),
    );
    if (ok == true) draft.removeList(list);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = draft.lists[list];

    return ListView(
      // In fondo più spazio: l'ultima riga non finisce sotto il pulsante "Prodotto".
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Row(
          children: [
            Expanded(child: Text(current.name, style: theme.textTheme.titleLarge)),
            IconButton(
              tooltip: 'Rinomina la lista',
              onPressed: () => _rename(context),
              icon: const Icon(Icons.edit_outlined),
            ),
            if (draft.lists.length > 1)
              IconButton(
                tooltip: 'Elimina la lista',
                onPressed: () => _remove(context),
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (current.sections.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Tocca "Prodotto" per aggiungere il primo: scegli il reparto e la lista si divide da sola.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        for (final (position, section) in current.sections.indexed)
          _SectionEditor(
            draft: draft,
            list: list,
            section: section,
            position: position,
            count: current.sections.length,
            openItem: openItem,
          ),
      ],
    );
  }
}

/// Cosa si può fare con un reparto dal suo menu "⋮".
enum _SectionAction { up, down, edit, remove }

/// Un reparto della lista: intestazione col badge e menu, prodotti, "Aggiungi in…".
class _SectionEditor extends StatelessWidget {
  const _SectionEditor({
    required this.draft,
    required this.list,
    required this.section,
    required this.position,
    required this.count,
    required this.openItem,
  });

  final ShoppingDraft draft;
  final int list;
  final ShoppingSectionDraft section;

  /// La posizione del reparto nella lista e quanti sono: per Sposta su/giù.
  final int position;
  final int count;
  final _OpenItem openItem;

  Future<void> _onAction(BuildContext context, _SectionAction action) async {
    final department = draft.department(section.departmentId);
    switch (action) {
      case _SectionAction.up:
        draft.moveSection(list, section.departmentId, -1);
      case _SectionAction.down:
        draft.moveSection(list, section.departmentId, 1);
      case _SectionAction.edit:
        final edited = await showDialog<ShoppingDepartment>(
          context: context,
          builder: (context) => DepartmentDialog(department: department),
        );
        if (edited != null) draft.updateDepartment(edited);
      case _SectionAction.remove:
        final items = section.items.length;
        if (items > 0) {
          final ok = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Togliere ${department.name}?'),
              content: Text(
                items == 1
                    ? 'Verrà cancellato anche il suo prodotto in questa lista.'
                    : 'Verranno cancellati anche i suoi $items prodotti in questa lista.',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla')),
                FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Togli')),
              ],
            ),
          );
          if (ok != true) return;
        }
        draft.removeSection(list, section.departmentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final department = draft.department(section.departmentId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: DepartmentBadge(department: department),
              title: Text(department.name, style: theme.textTheme.titleMedium),
              trailing: PopupMenuButton<_SectionAction>(
                tooltip: 'Opzioni di ${department.name}',
                onSelected: (action) => _onAction(context, action),
                itemBuilder: (context) => [
                  if (position > 0) const PopupMenuItem(value: _SectionAction.up, child: Text('Sposta su')),
                  if (position < count - 1) const PopupMenuItem(value: _SectionAction.down, child: Text('Sposta giù')),
                  if (department.isCustom)
                    const PopupMenuItem(value: _SectionAction.edit, child: Text('Modifica il reparto')),
                  const PopupMenuItem(value: _SectionAction.remove, child: Text('Togli il reparto')),
                ],
              ),
            ),
            for (final (index, item) in section.items.indexed)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 68, right: 4),
                title: Text(item.name, style: theme.textTheme.bodyLarge),
                subtitle: item.details == null ? null : Text(item.details!),
                onTap: () => openItem(context, list, section.departmentId, index),
                trailing: IconButton(
                  tooltip: 'Togli ${item.name}',
                  onPressed: () => draft.removeItem(list, section.departmentId, index),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 56),
                child: TextButton.icon(
                  onPressed: () => openItem(context, list, section.departmentId),
                  icon: const Icon(Icons.add),
                  label: Text('Aggiungi in ${department.name}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
