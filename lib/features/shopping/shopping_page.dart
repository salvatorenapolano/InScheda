import 'package:flutter/material.dart';

import 'package:my_workout/data/shopping_repository.dart';
import 'package:my_workout/data/shopping_store.dart';
import 'package:my_workout/models/shopping.dart';
import 'package:my_workout/widgets/dividers.dart';
import 'package:my_workout/widgets/empty_state.dart';
import 'package:my_workout/widgets/main_app_bar.dart';
import 'package:my_workout/widgets/page_title.dart';

/// Tab "Spesa": due schede (Settimanale, Mensile) con i prodotti da
/// spuntare, e il tasto Reset sempre visibile in basso a destra.
class ShoppingPage extends StatefulWidget {
  const ShoppingPage({super.key});

  @override
  State<ShoppingPage> createState() => _ShoppingPageState();
}

class _ShoppingPageState extends State<ShoppingPage> {
  // Il bundle dei dati: prima quelli dell'utente, poi quelli dell'app.
  // null = l'utente non ha ancora una lista.
  late final Future<List<ShoppingList>?> _listsFuture =
      ShoppingRepository(bundle: DefaultAssetBundle.of(context)).load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ShoppingList>?>(
      future: _listsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _simplePage(Text('Non riesco a leggere la lista della spesa:\n${snapshot.error}'));
        }
        // Come nella Dieta: con un risultato null hasData è false, quindi
        // per il caricamento guardiamo connectionState.
        if (snapshot.connectionState != ConnectionState.done) {
          return _simplePage(const CircularProgressIndicator());
        }
        final lists = snapshot.data;
        if (lists == null) {
          return _simplePage(const EmptyState(
            icon: Icons.shopping_cart_outlined,
            title: 'Nessuna lista della spesa',
            message: 'Qui vedrai i prodotti da comprare, da spuntare al supermercato. '
                'Presto potrai inserirli dall\'app.',
          ));
        }
        return _buildLists(lists);
      },
    );
  }

  Widget _simplePage(Widget child) {
    return Scaffold(
      appBar: const MainAppBar(),
      body: Center(child: Padding(padding: const EdgeInsets.all(24), child: child)),
    );
  }

  Widget _buildLists(List<ShoppingList> lists) {
    // Come nella Dieta: DefaultTabController tiene allineate le schede in
    // alto (TabBar) e le pagine sotto (TabBarView).
    return DefaultTabController(
      length: lists.length,
      child: Scaffold(
        appBar: MainAppBar(
          // Come nella Dieta: il titolo sopra le schede delle liste. Per ora
          // senza pulsante di modifica (l'editor della spesa arriverà dopo).
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56 + kTextTabBarHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  // Alto 48 come il titolo della Dieta col suo pulsante:
                  // così le due tab hanno l'header della stessa altezza.
                  child: SizedBox(
                    height: 48,
                    child: Align(alignment: Alignment.centerLeft, child: PageTitle(title: 'Spesa')),
                  ),
                ),
                TabBar(
                  tabs: [for (final list in lists) Tab(text: list.name)],
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
          children: [for (final list in lists) _ShoppingListView(list: list)],
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
      messenger.showSnackBar(
        SnackBar(content: Text('Nessuna spunta nella spesa ${list.name.toLowerCase()}')),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text('Spunte tolte dalla spesa ${list.name.toLowerCase()}'),
        action: SnackBarAction(label: 'Annulla', onPressed: () => store.checkAll(removed)),
      ),
    );
  }
}

/// Una scheda: le sezioni una sotto l'altra, ognuna nella sua card.
class _ShoppingListView extends StatelessWidget {
  const _ShoppingListView({required this.list});

  final ShoppingList list;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = ShoppingScope.of(context);

    return ListView(
      // In fondo più spazio: l'ultima riga non finisce sotto il tasto Reset.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        for (final section in list.sections) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Row(
              children: [
                Expanded(child: Text(section.name, style: theme.textTheme.titleLarge)),
                // Quanti prodotti della sezione hai già preso: "3/7".
                Text(
                  '${section.items.where((i) => store.isChecked(i.id)).length}'
                  '/${section.items.length}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Card(
            child: Column(
              children: withDividers(indent: 56, [
                for (final item in section.items) _ShoppingItemTile(item: item),
              ]),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
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
    final quantity = item.quantity;

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
          color: checked ? theme.colorScheme.onSurfaceVariant : null,
        ),
      ),
      subtitle: quantity == null ? null : Text(quantity),
    );
  }
}
