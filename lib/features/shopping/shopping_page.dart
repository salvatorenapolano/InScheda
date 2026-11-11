import 'package:flutter/material.dart';

import 'package:my_workout/data/shopping_repository.dart';
import 'package:my_workout/data/shopping_store.dart';
import 'package:my_workout/features/shopping/widgets/department_badge.dart';
import 'package:my_workout/features/shopping_editor/shopping_editor_page.dart';
import 'package:my_workout/models/shopping.dart';
import 'package:my_workout/widgets/dividers.dart';
import 'package:my_workout/widgets/empty_state.dart';
import 'package:my_workout/widgets/main_app_bar.dart';
import 'package:my_workout/widgets/page_title.dart';

/// Tab "Spesa": una scheda per lista, con i prodotti divisi per reparto da
/// spuntare, e il tasto Reset sempre visibile in basso a destra.
class ShoppingPage extends StatefulWidget {
  const ShoppingPage({super.key});

  @override
  State<ShoppingPage> createState() => _ShoppingPageState();
}

class _ShoppingPageState extends State<ShoppingPage> {
  // Il bundle dei dati: prima quelli dell'utente, poi quelli dell'app.
  // null = l'utente non ha ancora una lista.
  late final Future<ShoppingData?> _dataFuture = ShoppingRepository(bundle: DefaultAssetBundle.of(context)).load();

  void _openEditor() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ShoppingEditorPage()));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ShoppingData?>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _simplePage(Text('Non riesco a leggere la lista della spesa:\n${snapshot.error}'));
        }
        // Come nella Dieta: con un risultato null hasData è false, quindi
        // per il caricamento guardiamo connectionState.
        if (snapshot.connectionState != ConnectionState.done) {
          return _simplePage(const CircularProgressIndicator());
        }
        final data = snapshot.data;
        if (data == null || data.lists.isEmpty) {
          return _simplePage(EmptyState(
            icon: Icons.shopping_cart_outlined,
            title: 'Nessuna lista della spesa',
            message: 'Scrivi i prodotti da comprare, divisi per reparto, e spuntali al supermercato.',
            actionLabel: 'Crea la lista',
            onAction: _openEditor,
          ));
        }
        return _buildLists(data);
      },
    );
  }

  Widget _simplePage(Widget child) {
    return Scaffold(
      appBar: const MainAppBar(),
      body: Center(child: Padding(padding: const EdgeInsets.all(24), child: child)),
    );
  }

  Widget _buildLists(ShoppingData data) {
    final lists = data.lists;
    // Con una lista sola le schede non servono: resta solo il titolo.
    final showTabs = lists.length > 1;

    // Come nella Dieta: DefaultTabController tiene allineate le schede in
    // alto (TabBar) e le pagine sotto (TabBarView).
    return DefaultTabController(
      length: lists.length,
      child: Scaffold(
        appBar: MainAppBar(
          // Come nella Dieta: il titolo con la matita sopra le schede delle liste.
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(56 + (showTabs ? kTextTabBarHeight : 0)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: PageTitle(title: 'Spesa', editTooltip: 'Modifica la spesa', onEdit: _openEditor),
                ),
                if (showTabs)
                  TabBar(
                    tabs: [for (final list in lists) Tab(text: list.name)],
                    // Con più di 3 liste le schede scorrono invece di schiacciarsi.
                    isScrollable: lists.length > 3,
                    tabAlignment: lists.length > 3 ? TabAlignment.start : null,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    indicatorPadding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                  ),
              ],
            ),
          ),
        ),
        // Builder: ci dà un `context` che sta DENTRO il DefaultTabController,
        // così da lì possiamo chiedergli quale scheda è aperta.
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton.extended(
            // heroTag null: anche la tab Pesata ha un pulsante tondo e,
            // con lo stesso "tag" Hero, aprendo una pagina si scontrerebbero.
            heroTag: null,
            onPressed: () => _reset(context, lists[DefaultTabController.of(context).index]),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset'),
          ),
        ),
        body: TabBarView(
          children: [for (final list in lists) _ShoppingListView(data: data, list: list)],
        ),
      ),
    );
  }

  /// Toglie tutte le spunte della scheda aperta, con "Annulla" per ripensarci.
  Future<void> _reset(BuildContext context, ShoppingList list) async {
    final store = ShoppingScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final removed = await store.uncheckAll(list.items.map((i) => i.id));

    messenger.hideCurrentSnackBar();
    if (removed.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text('Nessuna spunta in "${list.name}"')));
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text('Spunte tolte da "${list.name}"'),
        action: SnackBarAction(label: 'Annulla', onPressed: () => store.checkAll(removed)),
      ),
    );
  }
}

/// Una scheda: i reparti uno sotto l'altro, ognuno nella sua card richiudibile.
class _ShoppingListView extends StatelessWidget {
  const _ShoppingListView({required this.data, required this.list});

  final ShoppingData data;
  final ShoppingList list;

  @override
  Widget build(BuildContext context) {
    if (list.items.isEmpty) {
      return const EmptyState(
        icon: Icons.shopping_basket_outlined,
        title: 'Lista vuota',
        message: 'Aggiungi i prodotti con la matita accanto a "Spesa".',
      );
    }
    return ListView(
      // In fondo più spazio: l'ultima riga non finisce sotto il tasto Reset.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        for (final (index, section) in list.sections.indexed)
          _SectionCard(
            // PageStorageKey: ExpansionTile si "appunta" lì se è aperto o
            // chiuso. Così cambiando scheda e tornando indietro un reparto
            // chiuso resta chiuso. La chiave deve essere unica e stabile.
            storageKey: PageStorageKey('${list.id}/$index/${section.name}'),
            department: data.departmentFor(section),
            section: section,
          ),
      ],
    );
  }
}

/// Un reparto: badge colorato, nome, "3/7"; tocchi l'intestazione e si chiude.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.storageKey, required this.department, required this.section});

  final PageStorageKey<String> storageKey;
  final ShoppingDepartment? department;
  final ShoppingSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = ShoppingScope.of(context);
    final taken = section.items.where((i) => store.isChecked(i.id)).length;
    final total = section.items.length;
    final done = taken == total;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: storageKey,
        initiallyExpanded: true,
        leading: DepartmentBadge(department: department),
        title: Row(
          children: [
            Expanded(child: Text(department?.name ?? section.name, style: theme.textTheme.titleLarge)),
            // Reparto finito: spunta e numero nel colore principale.
            if (done) ...[
              Icon(Icons.check_circle, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
            ],
            Text(
              '$taken/$total',
              style: theme.textTheme.titleMedium?.copyWith(
                color: done ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        children: [
          const Divider(),
          ...withDividers(indent: 56, [
            for (final item in section.items) _ShoppingItemTile(item: item),
          ]),
        ],
      ),
    );
  }
}

/// Un prodotto con la sua checkbox. Si spunta toccando tutta la riga.
class _ShoppingItemTile extends StatelessWidget {
  const _ShoppingItemTile({required this.item});

  final ShoppingItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = ShoppingScope.of(context);
    final checked = store.isChecked(item.id);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final quantity = item.quantity;
    final note = item.note;

    // CheckboxListTile: una riga con checkbox già pronta. Toccare il testo
    // o la casella fa la stessa cosa (chiama onChanged).
    return CheckboxListTile(
      value: checked,
      onChanged: (value) => store.setChecked(item.id, value ?? false),
      // leading: la casella a sinistra, come nella lista su carta.
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        item.name,
        // Preso: testo barrato e più chiaro, così a colpo d'occhio
        // vedi cosa manca ancora.
        style: TextStyle(
          decoration: checked ? TextDecoration.lineThrough : null,
          color: checked ? secondary : null,
        ),
      ),
      // La nota piccola sotto il nome; la quantità a destra, in colonna,
      // così si legge "quanto" senza cercarlo nel testo.
      subtitle: note == null ? null : Text(note, style: theme.textTheme.bodySmall?.copyWith(color: secondary)),
      secondary: quantity == null
          ? null
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                quantity,
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: checked ? secondary : null,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
    );
  }
}
