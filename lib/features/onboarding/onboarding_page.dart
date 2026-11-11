import 'package:flutter/material.dart';

import 'package:my_workout/data/profile_store.dart';
import 'package:my_workout/data/user_data_store.dart';
import 'package:my_workout/data/workout_repository.dart';
import 'package:my_workout/features/plan_editor/days_editor.dart';
import 'package:my_workout/features/plan_editor/plan_draft.dart';
import 'package:my_workout/features/plan_editor/workouts_editor.dart';
import 'package:my_workout/features/profile/profile_avatar.dart';
import 'package:my_workout/features/weigh_in/widgets/weigh_in_day_picker.dart';
import 'package:my_workout/models/body_weight.dart';
import 'package:my_workout/models/exercise.dart';
import 'package:my_workout/utils/formatters.dart';

/// Le pagine del primo avvio:
/// benvenuto → nome → giorni → schede ed esercizi → pesata → tutto pronto.
///
/// Le pagine stanno in un PageView, il widget che mostra una pagina alla
/// volta e scorre in orizzontale fra l'una e l'altra. Il PageController è
/// il suo "telecomando": con animateToPage() lo facciamo scorrere noi.
///
/// La scheda si costruisce in un [PlanDraft] e si salva solo alla fine,
/// con "Entra": se l'app si chiude a metà, al prossimo avvio si riparte.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();

  // Il controller di un TextField: tiene il testo scritto. È anche un
  // ChangeNotifier, quindi possiamo "ascoltarlo" mentre l'utente scrive.
  final _nameController = TextEditingController();

  // La scheda in preparazione: la riempiono le pagine dei giorni e delle schede.
  final _draft = PlanDraft();

  // La libreria degli esercizi, letta una volta sola per tutto l'onboarding.
  late final Future<Map<String, Exercise>> _library =
      WorkoutRepository(bundle: DefaultAssetBundle.of(context)).loadLibrary();

  // La pagina mostrata: serve per i pallini e per la freccia indietro.
  int _page = 0;

  // true mentre salviamo: il pulsante "Entra" si spegne (niente doppi tocchi).
  bool _saving = false;

  // Il giorno della pesata: venerdì finché l'utente non ne sceglie un altro.
  int _weighInDay = defaultWeighInWeekday;

  static const _pageCount = 6;

  // Controller e simili vanno liberati quando la pagina sparisce,
  // altrimenti restano in memoria ad ascoltare per sempre.
  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _draft.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    // Chiude la tastiera, se era aperta sul campo del nome.
    FocusScope.of(context).unfocus();
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    // Gli store li prendiamo PRIMA degli await: dopo, questa pagina
    // potrebbe non esserci più (e il suo context con lei).
    final userData = UserDataScope.of(context);
    final profile = ProfileScope.of(context);
    // Prima la scheda, poi il profilo: completeOnboarding() chiama
    // notifyListeners(), MyWorkoutApp si ridisegna e al posto di questa
    // pagina mostra le tab (con la scheda già salvata). Non serve Navigator.
    await userData.savePlan(_draft.toPlan(today: DateTime.now()));
    await profile.completeOnboarding(name: _nameController.text, weighInWeekday: _weighInDay);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              page: _page,
              pageCount: _pageCount,
              onBack: _page == 0 ? null : () => _goTo(_page - 1),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                // Niente scorrimento col dito: si va avanti solo coi pulsanti,
                // così non si salta la pagina del nome lasciandola vuota.
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _page = page),
                children: [
                  _WelcomeStep(onNext: () => _goTo(1)),
                  _NameStep(controller: _nameController, onNext: () => _goTo(2)),
                  _DaysStep(draft: _draft, onNext: () => _goTo(3)),
                  _WorkoutsStep(draft: _draft, library: _library, onNext: () => _goTo(4)),
                  _WeighInStep(
                    day: _weighInDay,
                    onChanged: (day) => setState(() => _weighInDay = day),
                    onNext: () => _goTo(5),
                  ),
                  // Listenable.merge: si ridisegna quando cambia il nome o la
                  // scheda, così il riepilogo è sempre quello giusto.
                  ListenableBuilder(
                    listenable: Listenable.merge([_nameController, _draft]),
                    builder: (context, _) => _ReadyStep(
                      name: _nameController.text.trim(),
                      draft: _draft,
                      weighInDay: _weighInDay,
                      onDone: _saving ? null : _finish,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// In alto: freccia indietro (se c'è una pagina prima) e i pallini.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.page, required this.pageCount, required this.onBack});

  final int page;
  final int pageCount;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // width infinita: senza, lo Stack sarebbe largo solo quanto i pallini
    // e la freccia finirebbe in mezzo, sopra di loro.
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (onBack != null)
            Positioned(
              left: 4,
              child: IconButton(
                tooltip: 'Indietro',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < pageCount; i++)
                // AnimatedContainer: quando cambiano larghezza o colore,
                // passa dal vecchio al nuovo valore con un'animazione.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == page ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == page ? colors.primary : colors.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lo scheletro comune delle pagine: contenuto che scorre se non ci sta
/// (con la tastiera aperta lo spazio si riduce) e il pulsante in fondo.
class _StepLayout extends StatelessWidget {
  const _StepLayout({required this.children, required this.button});

  final List<Widget> children;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
          const SizedBox(height: 16),
          button,
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return _StepLayout(
      button: FilledButton(onPressed: onNext, child: const Text('Iniziamo')),
      children: [
        const SizedBox(height: 32),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: colors.primaryContainer, shape: BoxShape.circle),
            child: Icon(Icons.fitness_center, size: 48, color: colors.onPrimaryContainer),
          ),
        ),
        const SizedBox(height: 32),
        Text.rich(
          TextSpan(
            text: 'Benvenuto su In',
            children: [TextSpan(text: 'Scheda', style: TextStyle(color: colors.primary))],
          ),
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'La tua scheda della palestra, sempre in tasca.',
          style: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        const _Feature(
          icon: Icons.fitness_center,
          title: 'Allenamento',
          text: 'Le tue schede, con video, consigli e i pesi che usi.',
        ),
        const _Feature(
          icon: Icons.monitor_weight_outlined,
          title: 'Pesata',
          text: 'Il promemoria settimanale e lo storico del tuo peso.',
        ),
        const _Feature(
          icon: Icons.restaurant_menu,
          title: 'Dieta e spesa',
          text: 'La settimana dei pasti e la lista della spesa.',
        ),
      ],
    );
  }
}

/// Una riga "icona + titolo + descrizione" del benvenuto.
class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({required this.controller, required this.onNext});

  final TextEditingController controller;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Tutta la pagina ascolta il testo: l'avatar mostra le iniziali mentre
    // scrivi e il pulsante si accende solo quando c'è un nome.
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasName = controller.text.trim().isNotEmpty;

        return _StepLayout(
          // onPressed null = pulsante spento.
          button: FilledButton(onPressed: hasName ? onNext : null, child: const Text('Avanti')),
          children: [
            const SizedBox(height: 32),
            Center(child: ProfileAvatar(size: 96, initials: initialsOf(controller.text))),
            const SizedBox(height: 32),
            Text('Come ti chiami?', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Le iniziali compaiono nel cerchio del profilo. Puoi cambiarlo quando vuoi.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              // Maiuscola automatica a inizio parola: "mario rossi" → "Mario Rossi".
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()),
              // Invio sulla tastiera = Avanti (se c'è un nome).
              onSubmitted: (_) {
                if (hasName) onNext();
              },
            ),
          ],
        );
      },
    );
  }
}

/// "Quando ti pesi?": il giorno della pesata settimanale.
class _WeighInStep extends StatelessWidget {
  const _WeighInStep({required this.day, required this.onChanged, required this.onNext});

  final int day;
  final ValueChanged<int> onChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return _StepLayout(
      button: FilledButton(onPressed: onNext, child: const Text('Avanti')),
      children: [
        const SizedBox(height: 32),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: colors.primaryContainer, shape: BoxShape.circle),
            child: Icon(Icons.monitor_weight_outlined, size: 48, color: colors.onPrimaryContainer),
          ),
        ),
        const SizedBox(height: 32),
        Text('Quando ti pesi?', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'Una volta a settimana, sempre lo stesso giorno, appena sveglio: '
          'la tab Pesata te lo ricorda e tiene lo storico.',
          style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Center(child: WeighInDayPicker(value: day, onChanged: onChanged)),
      ],
    );
  }
}

class _ReadyStep extends StatelessWidget {
  const _ReadyStep({required this.name, required this.draft, required this.weighInDay, required this.onDone});

  final String name;
  final PlanDraft draft;
  final int weighInDay;

  /// null mentre salva: il pulsante è spento.
  final VoidCallback? onDone;

  static const _days = ['lun', 'mar', 'mer', 'gio', 'ven', 'sab', 'dom'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // Solo il primo nome: "Tutto pronto, Mario!".
    final firstName = name.split(RegExp(r'\s+')).first;
    final workouts = draft.workouts;
    final days = [for (final d in draft.weekdays) _days[d - 1]].join(' · ');

    return _StepLayout(
      button: FilledButton(onPressed: onDone, child: const Text('Entra')),
      children: [
        const SizedBox(height: 32),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: colors.primaryContainer, shape: BoxShape.circle),
            child: Icon(Icons.check, size: 48, color: colors.onPrimaryContainer),
          ),
        ),
        const SizedBox(height: 32),
        Text('Tutto pronto, $firstName!', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(
          // Il riepilogo: "2 schede · lun · mer · ven".
          '${workouts.length == 1 ? '1 scheda' : '${workouts.length} schede'} · $days',
          style: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          [for (final w in workouts) w.name].join(', '),
          style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Pesata ogni ${formatWeekday(weighInDay)}',
          style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        // I due "da sapere", ognuno con disegnato accanto quello che
        // troverai nell'app, così lo riconosci subito.
        // 1. La matita accanto ai titoli delle tab.
        _TipCard(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: colors.primaryContainer, shape: BoxShape.circle),
            child: Icon(Icons.edit_outlined, color: colors.onPrimaryContainer),
          ),
          text: 'Scheda, dieta e giorno della pesata li cambi quando vuoi '
              'con la matita accanto al titolo della loro schermata.',
        ),
        const SizedBox(height: 8),
        // 2. Il cerchio del profilo in alto a destra, con le sue iniziali.
        _TipCard(
          leading: ProfileAvatar(size: 40, initials: initialsOf(name)),
          text: 'Tocca il cerchio con le tue iniziali, in alto a destra, per '
              'modificare il profilo. Presto da lì potrai anche salvare i tuoi '
              'dati su Google Drive e recuperarli.',
        ),
      ],
    );
  }
}

/// Una card "da sapere" della pagina finale: un'immagine a sinistra
/// (la matita, il cerchio del profilo) e una frase accanto.
class _TipCard extends StatelessWidget {
  const _TipCard({required this.leading, required this.text});

  final Widget leading;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 16),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

/// "Quando ti alleni?": i giorni e la data di fine (facoltativa).
class _DaysStep extends StatelessWidget {
  const _DaysStep({required this.draft, required this.onNext});

  final PlanDraft draft;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _StepLayout(
      // Il pulsante ascolta il draft: si accende appena scegli un giorno.
      button: ListenableBuilder(
        listenable: draft,
        builder: (context, _) => FilledButton(
          onPressed: draft.hasDays ? onNext : null,
          child: Text(draft.hasDays ? 'Avanti' : 'Scegli almeno un giorno'),
        ),
      ),
      children: [
        const SizedBox(height: 16),
        Text('Quando ti alleni?', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        DaysEditor(draft: draft),
      ],
    );
  }
}

/// "Le tue schede": i nomi e, per ognuna, gli esercizi dalla libreria.
class _WorkoutsStep extends StatelessWidget {
  const _WorkoutsStep({required this.draft, required this.library, required this.onNext});

  final PlanDraft draft;
  final Future<Map<String, Exercise>> library;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _StepLayout(
      button: ListenableBuilder(
        listenable: draft,
        builder: (context, _) => FilledButton(
          onPressed: draft.workoutsReady ? onNext : null,
          child: Text(draft.workoutsReady ? 'Avanti' : 'Ogni scheda ha bisogno di esercizi'),
        ),
      ),
      children: [
        const SizedBox(height: 16),
        Text('Le tue schede', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'Tocca una scheda per scegliere i suoi esercizi.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FutureBuilder<Map<String, Exercise>>(
          future: library,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('Non riesco a leggere la libreria:\n${snapshot.error}');
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            return WorkoutsEditor(draft: draft, library: snapshot.requireData);
          },
        ),
      ],
    );
  }
}
