# myWorkout — contesto del progetto

App Flutter **pubblica e open source** (licenza MIT) per la palestra: scheda di allenamento, dieta settimanale, pesata settimanale (giorno a scelta) e lista della spesa. Nasce dalla versione personale (repo privato `myWorkout_private`). Ogni utente parte **senza dati**: al primo avvio crea la sua scheda (onboarding), la dieta la scrive dalla tab Dieta; nell'app c'è solo la libreria esercizi. Distribuzione: APK su GitHub Releases, poi Google Play (niente App Store: niente Apple Developer Program).
È anche un progetto **per imparare Flutter**: procediamo step by step.

## Come lavoriamo

- **Lingua**: rispondi in italiano. Spiega i concetti Flutter/Dart nuovi che ogni modifica introduce; commenti nel codice in italiano.
- **Ambiente**: Windows 11, VS Code + Android Studio, Flutter 3.47.9 (Dart 3.13). Provo l'app su un **emulatore Android** (la lancio io con F5). Questa versione si distribuisce solo per Android (vedi "Build e distribuzione").
- **Verifica**: ogni modifica si chiude con `flutter analyze` (zero problemi) e `flutter test` (tutti verdi). Non installare/avviare l'app sul mio emulatore al posto mio.
- **Codice su GitHub**: https://github.com/salvatorenapolano/myWorkout (branch `main`, **pubblico**: mai committare chiavi, keystore o dati personali). La versione personale è in `salvatorenapolano/myWorkout_private`.

## Stato delle funzioni

| Tab | Stato |
|---|---|
| **Allenamento** | ✅ Fatto: Fase 2 Push/Pull/Legs, dettaglio esercizio con video, consigli e pesi salvati |
| **Dieta** | ✅ Fatto: settimana tipo, pranzo e cena |
| **Pesata** | ✅ Fatto: promemoria nel giorno scelto (default venerdì), storico pesate con differenze |
| **Spesa** | ✅ Fatto: liste Settimanale / Mensile con spunte e Reset |

## Stack

- Flutter + Material 3, tema chiaro/scuro automatico. App **in italiano** anche nei pezzi di Flutter (`flutter_localizations`, `locale: it`): calendario, tooltip. Nei test quindi `tester.pageBack()` non funziona (cerca "Back"): si tocca `find.byType(BackButton)`.
- Colore seme **viola intenso `0xFF5B3FD1`** (scelto il 10/11/2026; provati prima verde petrolio `0xFF0E7C86` e arancio energia `0xFFD9590B`; il rosso non mi piace), variante `DynamicSchemeVariant.fidelity` per tenere il colore pieno. Si cambia solo `AppTheme.seedColor` (+ i colori in `tool/generate_app_icon.py` per l'icona). Nota: è vicino ai badge di schiena (`#5E5CE6`) e spalle (`#BF5AF2`). Anche l'icona dell'app è viola.
- Logo "my**Workout**" nell'header in **Russo One** (`AppTheme.logoFont`, `assets/fonts/RussoOne-Regular.ttf`, licenza OFL in `RussoOne-OFL.txt`), solo lì.
- Stile "lavagna della sala pesi": font **Barlow Semi Condensed** (in `assets/fonts/`, licenza OFL) per titoli e numeri, font di sistema per il testo; raggi 28 (banner) / 20 (card) / 12 (riquadri interni); pagine grigio chiaro con card bianche (in scuro: card più chiare dello sfondo). Tutto in `lib/app_theme.dart`.
- Pacchetti: `flutter_svg` (anteprime), `shared_preferences` (pesi salvati), `youtube_player_iframe` (video), `path_provider` (cartella dei dati dell'utente), `flutter_localizations` (Flutter in italiano).
- Nessun backend e niente download: la libreria (esercizi e immagini) è **negli asset**; scheda e dieta dell'utente sono JSON sul telefono (`UserDataStore`), pesi, pesate e spunte in `shared_preferences`.
- Android: permesso `INTERNET` nel manifest (serve ai video). Nome app sotto l'icona: **myWorkout**. ID app (Android e iOS) `io.github.salvatorenapolano.myworkout`: definitivo, non cambiarlo dopo la pubblicazione su Google Play.
- Icona: dopo `dart run flutter_launcher_icons` **ripristinare** `ios/Runner.xcodeproj/project.pbxproj` (`git checkout -- …`): la v0.14.4 lo modifica per errore (mette `AppIcon` in `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS`).

## Struttura del codice

```
lib/
├── main.dart                 # carica gli store (pesi, pesate, spesa, profilo, dati utente) poi runApp
├── app.dart                  # MaterialApp, gli Scope sopra tutto, DefaultAssetBundle = bundle dei dati
├── app_theme.dart            # AppTheme.light()/dark(): colori, font, raggi, componenti
├── home_shell.dart           # NavigationBar 3 tab + IndexedStack
├── models/                   # exercise.dart, workout_plan.dart, diet.dart (fromJson)
├── data/                     # workout_repository, diet_repository (leggono e validano i JSON)
│                             # weight_store.dart (ChangeNotifier + InheritedNotifier WeightScope)
│                             # data_bundle.dart: DataBundle, l'AssetBundle "a piani" (cartella → piano di sotto)
│                             # profile_store.dart: nome, iniziali, onboarding fatto (ProfileScope)
│                             # user_data_store.dart: la scheda creata dall'utente, piano più alto del DataBundle
├── utils/formatters.dart     # formatRest (120→2', 90→90"), formatWeight (22,5 kg), date in italiano
└── features/
    ├── workout/              # workout_page, exercise_detail_page, widgets/ (today_banner,
    │                         #   planned_exercise_tile, exercise_block_tile, exercise_media, exercise_preview, step_number)
    ├── diet/                 # diet_page (TabBar Lun…Dom), widgets/ (diet_day_view, meal_card)
    ├── weigh_in/             # weigh_in_page (storico, +), widgets/weigh_in_banner
    └── shopping/             # shopping_page (schede Settimanale/Mensile, checkbox, Reset)
    ├── onboarding/           # onboarding_page: PageView benvenuto → nome → giorni → schede → tutto pronto
    ├── plan_editor/          # l'editor della scheda, usato dall'onboarding e da "Modifica la scheda":
    │                         #   plan_draft (ChangeNotifier con la scheda in modifica), days_editor,
    │                         #   workouts_editor, workout_editor_page (esercizi, riordino), exercise_picker_page
    │                         #   (libreria per gruppi), planned_exercise_dialog (serie/rip./recupero), plan_editor_page
    ├── diet_editor/          # diet_draft (la dieta in modifica), diet_editor_page (giorni, pasti, "Copia il giorno"),
    │                         #   food_item_dialog (alimento, quantità "250-300", unità, nota)
    └── profile/              # profile_avatar (iniziali dal ProfileStore), profile_sheet (nome + pannello dati)
lib/widgets/                  # condivisi: main_app_bar (header), status_banner, weight_input_dialog, dividers
assets/data/                  # SOLO exercises.json (la libreria): l'app parte senza scheda, dieta e spesa
test/fixtures/                # workout_plan.json, diet.json, shopping.json: i miei dati, ora solo dati di prova dei test
test/helpers/fixtures.dart    # fixture('diet.json') e FixtureBundle (i dati di prova come se fossero asset)
assets/images/exercises/      # <id>.svg, una anteprima per esercizio
assets/images/muscles/        # illustrazioni muscoli (.webp scontornati, sfondo trasparente), scelte con "muscleImage"
tool/generate_exercise_previews.py   # genera tutti gli SVG (pose + colori)
tool/prepare_muscle_images.py        # ritaglia e scontorna le illustrazioni dei muscoli (python … <cartella_originali>)
tool/generate_app_icon.py            # icona: manubrio su gradiente viola (+ varianti iOS scura e colorata) → assets/icon/
flutter_launcher_icons.yaml          # poi `dart run flutter_launcher_icons` crea tutte le misure iOS/Android
test/                         # test su JSON, calendario, banner, pesi, widget
codemagic.yaml                # build Android (APK) nel cloud
```

## I dati

**Primo avvio senza dati**: nell'app c'è solo la libreria esercizi (con anteprime e muscoli). Scheda, dieta e spesa mancano finché l'utente non le crea: i repository restituiscono null (`loadStringOrNull`, extension su AssetBundle in `lib/data/optional_asset.dart`) e le tab mostrano `EmptyState` ("Nessuna scheda", "Nessuna dieta", "Nessuna lista della spesa"). I file qui sotto descrivono il formato; i miei dati veri stanno in `test/fixtures/`.
Dopo aver tolto un asset serve `flutter clean`: la cache `build/` tiene i file vecchi (e i test li vedrebbero ancora).

### `exercises.json` — libreria esercizi (il "come")
Ogni esercizio: `id`, `name`, `category` (`warmup` | `weights` | `abs`), `group` (gruppo muscolare per l'editor: `petto` | `schiena` | `spalle` | `braccia` | `gambe` | `core` → "Addominali" | `riscaldamento`; enum `MuscleGroup`, l'ordine dell'enum è l'ordine delle sezioni), `muscles[]`, `description`, `tips[]`, `images[]`, `videoUrl`, `custom` (solo negli esercizi creati dall'utente). **46 esercizi**: i 39 della scheda del PT ("Cardio leggero" è diventato **Tapis roulant**, id `tapis_roulant`) + **Cyclette** e **Stair climber (scale, detto anche StairMaster)** nel gruppo **Cardio** + 5 ai macchinari aggiunti per la libreria pubblica (croci ai cavi, alzate laterali al cavo, trazioni assistite alla macchina, squat al multipower, leg curl sdraiato), scelti incrociando le classifiche di Jefit, StrengthLog e Skelcore; descrizioni e consigli scritti da Claude, video YouTube in italiano verificati con l'oEmbed.
- Solo `weights` ha il riquadro "Il tuo peso".
- `description`: per i pesi è il "Come si fa" della scheda Fase 2. `tips[]` ("Consigli" nel dettaglio): 2–3 consigli per esercizio, **scritti da Claude**, non dal PT.
- `videoUrl`: tutti tranne il cardio leggero. **Macchine** → video delle pagine prodotto **gym80.de** (es. leg press 3030, butterfly 3022, butterfly reverse 3025, adduction 3029, abduction 3028, calf 3018, triceps 3011, biceps 3010, seated row 3040, 45° back extension 4119). **Manubri, corpo libero, riscaldamento, addominali** → tutorial YouTube in italiano (Project inVictus, Umberto Miletto, Marcello Chiapponi…). Verificati con l'oEmbed di YouTube (esistono e si possono incorporare).
- L'anteprima è `assets/images/exercises/<id>.svg` (ricavata dall'id).
- `muscleImage` (facoltativo, solo pesi): nome dell'illustrazione in `assets/images/muscles/` (petto, dorsali, femorali, spalle, bicipiti, tricipiti, glutei, retto_addominale, quadricipiti; addome_obliqui per ora non usata). 25 esercizi coi pesi su 28: mancano iperestensioni, adductor e calf (non ci sono illustrazioni di lombari, adduttori e polpacci).

### `workout_plan.json` — la scheda (il "quanto")
**Facoltativi** (per le schede create nell'app): `version`, `endDate` (senza = sedute infinite, `sessions` è un generatore `sync*`), `schedule.time`, `schedule.rotation` (senza = ordine delle schede), `generalNotes`, `warmup` di ogni scheda, `abs`, `cardio`. Le parti mancanti non compaiono e i numeri 1, 2, 3… si ricontano.
Fase 2 · Push/Pull/Legs (sostituisce la Fase 1, che resta nella storia git).
- `schedule`: lunedì, mercoledì, venerdì alle 15:00, rotazione **push, pull, legs** dal **16/11/2026** al **23/12/2026** (17 sedute: ogni settimana lun Push, mer Pull, ven Legs). Il calendario si calcola, non è scritto riga per riga.
- `workouts[]`: ogni giorno ha `id`, `name`, `focus` (i muscoli, sotto il banner), `intro` ("21 serie…", sotto il titolo dei pesi), **il suo** `warmup` ed `exercises` (i pesi). Serie: Push 21, Pull 20, Legs 23.
- Seduta = **1 Riscaldamento** (5' cardio + mobilità del giorno) → **2 Pesi** → **3 Addominali** (uguali tutti i giorni: crunch alla macchina 3×12–15 + circuito plank, plank laterale, leg raise, heel touch) → **4 Cardio** fisso: 30 min, pendenza 10%, 5,5 km/h, senza note. **Niente stretching** (tolto apposta, anche se è nella scheda del PT).
- Ogni esercizio in scheda: `exerciseId`, `sets?`, `reps` (testo: "10–12", "30\"", "12 per lato"), `restSeconds?`, `notes?`, `alternatives[]` ("se è occupato", solo quelle date dal PT nella Fase 1).
- Macchinari nuovi: nota "Settimana 1: prima una serie leggera da 10…" sulla riga. French press solo settimane 1, 3, 5 (nella nota).
- `generalNotes` (non mostrata): doppia progressione e regola dei macchinari nuovi.

### `diet.json` — la settimana tipo
**Facoltativi** (per le diete scritte nell'editor): `version`, `categories`, `category` degli alimenti, `title` dei pasti, `training` dei giorni, `legumes`, `notes`.
- Catalogo `foods` (id, nome, **reparto**: Frutta e verdura, Carne e pesce, Frigo, Pane, Dispensa). La spesa NON è calcolata da qui: ha il suo `shopping.json`.
- `days`: 7 giorni, `training` true lun/mer/ven, ognuno con pasti `pranzo` (13:00) e `cena` (19:30–20:00). Domenica un unico slot "Pranzo e cena" libero con 3 regole.
- Ingredienti: `foodId`, `quantity?`, `quantityMax?` (intervalli 250–300 g), `unit`, `note`.
- Extra: riquadro "legumi a scelta" (solo mar/gio), note "Da sapere".
- `alternative` di un pasto = riquadro "se manca": martedì cena "Se manca il salmone…", lunedì cena "Se mancano le patate: 250–300 g di verdure." (le verdure non sono tra gli ingredienti). Mercoledì cena senza insalata (l'alimento resta nel catalogo, per ora non usato).
- Colazione e spuntini **mancano** (sono in un altro PDF, "La mia giornata", non ancora fornito).

### `shopping.json` — la lista della spesa
Due liste (`Settimanale` · fresco, `Mensile` · dispensa), ognuna con sezioni e prodotti `{id, name, quantity?}`, trascritte dal PDF del nutrizionista. Gli `id` devono essere unici (il repository lo controlla) e non vanno cambiati: servono a ricordare le spunte.

### Come si misura un esercizio
`Exercise.measure` (`ExerciseMeasure`): **reps** (serie × ripetizioni; senza serie per la mobilità del riscaldamento), **time** (serie × secondi, anche "per lato": plank e plank laterale, `"measure": "time"` nel JSON), **cardio** (categoria e gruppo `cardio`: minuti + `cardioSettings` della macchina: `speed`/`incline` per il tapis, `level` per cyclette e stair climber; niente serie, recupero, peso né video). Nella scheda il cardio usa `durationMinutes`, `speedKmh`, `inclinePercent`, `level` di `PlannedExercise` (`reps` vuoto). Valori di partenza (`PlanDraft.defaultsFor`): cardio 20 min (5,5 km/h, 5%, livello 5), tempo 3 × 30" rec. 60", riscaldamento solo "10", il resto 3 × 10 rec. 90". Il dialog dell'esercizio mostra solo i campi della sua misura (serie e recupero possono essere "nessuna/nessuno"). Esercizi personali: gruppo Cardio → minuti e livello; gli altri "Si misura in" Ripetizioni o Tempo. Il blocco `cardio` del piano del PT (camminata finale) resta a parte.

### Scelta esercizi (onboarding e Modifica la scheda)
`ExercisePickerPage`: **barra di ricerca** (SearchBar nell'AppBar) che filtra per nome, muscoli e gruppo, senza maiuscole né accenti, parole in qualsiasi ordine e anche a metà (`lib/utils/search.dart`). Restano le sezioni per gruppo, solo quelle con risultati; le spunte restano anche cambiando ricerca. Senza risultati: messaggio + pulsante **Crea "<testo cercato>"**, che apre il dialog col nome già scritto.

### Esercizi personali
Nella scelta esercizi, **Crea un esercizio**: nome, gruppo muscolare (decide anche la famiglia: Addominali → abs, Riscaldamento → warmup, il resto pesi con "Il tuo peso"), muscoli e spiegazione facoltativi. Id `personale_<nome>`. Salvati in `<support>/user_data/assets/data/custom_exercises.json` (`UserDataStore.addCustomExercise`), letti da `WorkoutRepository` in fondo alla libreria. Niente SVG: `ExercisePreview` disegna il quadrato col colore del gruppo (`MuscleGroup.color`) e l'iniziale del nome. Per ora non si modificano né si cancellano.

### Dati dell'utente (tutti in `shared_preferences`)
- Profilo: `profile_name` (testo), `onboarding_done` (bool) e `weigh_in_weekday` (int, 1 = lunedì … 7 = domenica; senza = venerdì, `defaultWeighInWeekday`). Finché `onboarding_done` è false l'app mostra `OnboardingPage` invece delle tab (`ProfileStore`).
- Pesi per esercizio: chiave `weight_<exerciseId>`, in kg (anche decimali). Non è una checklist delle serie: è solo un promemoria del peso usato.
- Pesate: chiave `body_weights`, testo JSON `[{"date": "2026-11-06", "kg": 78.4}, …]`, una per giorno (`BodyWeightStore`).
- Spunte della spesa: chiave `shopping_checked`, lista degli id spuntati (`ShoppingStore`).

## Com'è fatta l'interfaccia

**Header** (tutte e 4 le tab, `MainAppBar`): "my**Workout**" (Workout nel colore principale) a sinistra, a destra il cerchio grigio sfumato con le **iniziali del nome** (icona persona se manca). Tocco sul cerchio → pannello dal basso: avatar e nome con matita per cambiarlo. Il pulsante **Scarica gli ultimi dati** è stato tolto (non serve nella versione pubblica). Le pagine non hanno più un titolo loro.

**Allenamento**
- In alto `TodayBanner`: "Oggi: Push" + muscoli del giorno (colorato, con "PUSH" in filigrana) / "Oggi riposo · prossimo allenamento domani: Pull" / "Scheda terminata". Senza orario (resta nel JSON).
- Selettore Push / Pull / Legs: parte sul giorno di turno, che ha un'icona calendario.
- Sotto "2 · Pesi" la riga `intro` del giorno; niente nota generale (resta nel JSON).
- Righe esercizio: anteprima SVG (con **numero d'ordine** nell'angolo, solo nei pesi), nome, "3 × 10–12 · rec. 90\"", peso salvato a destra.
- Riscaldamento e addominali sono blocchi espandibili.

**Dettaglio esercizio** (tap su una riga): video YouTube al posto dell'anteprima se c'è, nome, card "in scheda" (serie, recupero, note), card **Il tuo peso** (− / + di 1 kg, tap per scriverlo), card **Muscoli** (illustrazione anatomica con muscolo in rosso + elenco; tap = schermo intero con zoom), "Come si esegue", consigli, "Se è occupato". Senza illustrazione i muscoli restano chip sotto il nome.

**Dieta**: schede Lun…Dom (si apre su oggi), chip **Palestra giallo** / Riposo bianco, una card per pasto: **☀️ Pranzo (13:00) con sfondo giallo tenue, 🌙 Cena (20:00) con sfondo blu tenue**. Intestazione del pasto centrata con divisore sotto, ingredienti a pallini. Niente riquadro "Da sapere" (le note restano nel JSON).

**Pesata** (tab con la bilancia): banner in cima solo col titolo, senza descrizione: "Oggi ti devi pesare" nel giorno della pesata (colore principale; `weighInStatusFor(..., weekday:)`), "Pesata fatta: 78,4 kg", "Pesata di venerdì da fare" se l'hai saltata, altrimenti "Prossima pesata …". Storico dalla più recente: data, differenza dalla precedente (+0,4 / −0,6 / ±0), peso. **+** = pesata di oggi (se c'è già la sostituisce), tocco = correggi, trascina a sinistra = cancella (con Annulla).

**Spesa**: schede Settimanale / Mensile, sezioni con contatore "3/7", prodotto con checkbox e quantità; spuntato = barrato. Tasto **Reset** sempre in basso a destra: toglie le spunte **della scheda aperta** (la mensile non si azzera col reset settimanale), con Annulla.

**Anteprime esercizi**: stile "badge colorato" — omino bianco su quadrato arrotondato colorato per gruppo muscolare (gambe blu, petto rosa, schiena indaco, spalle viola, braccia arancio, core verde, riscaldamento corallo). Si rigenerano con `python tool/generate_exercise_previews.py`.

## Decisioni già prese (non riproporle)

- Niente card grande "prossimo allenamento": c'è il banner del giorno.
- Niente pulsante "avvia recupero" / timer per ora.
- Niente stretching finale (nemmeno in Fase 2).
- Cardio fisso 30 min / 10% / 5,5 km/h, senza note.
- Dieta generica: giorni della settimana senza date.
- Video: macchine da gym80 (pagine prodotto gym80.de), il resto da tutorial YouTube in italiano.

## Dati online

Nella versione pubblica **non c'è nessun download**: tolti il pulsante "Scarica gli ultimi dati", `DataStore`, `RemoteDataConfig`, `tool/sync_data_repo.py` e il pacchetto `http` (step 5). Le immagini restano dentro l'app (libreria < 1 MB). Il repo `myWorkout-data` serve solo alla versione privata.

## Build e distribuzione

- **Android** (l'unica piattaforma distribuita): `flutter build apk --release` sul PC, oppure Codemagic col workflow "Android" di `codemagic.yaml` (analyze, test, APK). Prima l'APK nelle **Releases di GitHub**, poi **Google Play** (25 $ una tantum, test chiuso con almeno 12 tester per 14 giorni).
- **Firma di release**: upload key in `C:\Users\salva\keys\myworkout-upload.jks` (alias `upload`, fuori dal repo, con backup), letta da `android/key.properties` (ignorato da git). Senza `key.properties` (Codemagic, altri PC) `build.gradle.kts` firma con la chiave di debug. Verifica: `apksigner verify --print-certs` deve dire `CN=myWorkout, O=salvatorenapolano`.
- **Versioni**: `version` in `pubspec.yaml` (nome+build). 0.1.0+1 = prima Release su GitHub (tag `v0.1.0`, 10/11/2026, APK separati per processore con `--split-per-abi`: `myWorkout-0.1.0-arm64.apk` ~21 MB per quasi tutti i telefoni, `-arm32.apk` ~19 MB per i vecchi; niente x86, che serve solo agli emulatori. L'APK universale pesava ~58 MB perché ha tre copie del motore Flutter. Flutter aggiunge al versionCode 1000 × ABI: arm32 = 1001, arm64 = 2001). minSdk 24 = **Android 7.0**. Il numero dopo il `+` deve crescere a ogni APK/AAB pubblicato. Per il Play Store servirà `flutter build appbundle`.
- **iOS**: la cartella `ios/` resta (icone, bundle id, Info.plist) così chi ha un Mac può compilarla per sé, ma l'app **non va sull'App Store** (niente Apple Developer Program). La mia installazione personale con Sideloadly è descritta nel repo privato.

## Figma

File "myWorkout" con wireframe iniziali (pagine Wireframe/Componenti/Design, variabili colore e stili testo iOS). Il piano Starter ha esaurito le chiamate MCP, quindi il file non riflette le ultime modifiche: oggi **il riferimento è l'app**, non Figma.

## Onboarding (versione pubblica)

Primo avvio: **Benvenuto → Come ti chiami? → Quando ti alleni? → Le tue schede → Quando ti pesi? → Tutto pronto** (`lib/features/onboarding/`). Si avanza solo coi pulsanti (niente swipe); "Avanti" è spento senza nome, senza giorni, o se una scheda non ha esercizi. La scheda vive in un `PlanDraft` e si salva solo con "Entra" (prima `savePlan`, poi `completeOnboarding`). "Quando ti pesi?": un giorno solo (`WeighInDayPicker`, venerdì preselezionato). "Tutto pronto" riassume schede, giorni e pesata, e in una card con l'avatar spiega che **scheda, dieta e giorno della pesata si cambiano dal cerchio del profilo**. Nel pannello del profilo: Modifica la scheda, Modifica la dieta, "Pesata: ogni venerdì" (dialog coi 7 giorni).
Piano deciso:
1. ✅ Benvenuto + nome (iniziali nell'avatar, nome modificabile dal profilo). Immagine del profilo: in futuro, non prioritaria.
2. ✅ Strato **dati utente** (`UserDataStore`): la scheda dell'utente è salvata in `<support>/user_data/assets/data/workout_plan.json`, stesso formato e percorso degli asset. `DataBundle(cartella, below)` si impila: utente → app (`userData.bundleOver(assets ?? rootBundle)` in app.dart, memoizzato; `MyWorkoutApp.assets` serve ai test per i dati di prova). La libreria esercizi e le immagini arrivano sempre dal piano di sotto. Tutti i modelli di scheda e dieta hanno `toJson()`. Da sapere: se una versione nuova dell'app toglie un esercizio usato nella scheda dell'utente, la tab Allenamento mostra l'errore.
3. ✅ **Crea la mia scheda** (unica opzione, niente "usa l'esempio"): giorni della settimana, **niente orario**, **solo data di fine** (facoltativa), numero di schede con **nome a scelta**, per ogni scheda esercizi dalla libreria **divisa per gruppi muscolari** con serie, ripetizioni e recupero. L'editor resta poi nel profilo per modificarla (cerchio → **Modifica la scheda** → `PlanEditorPage`, con Salva; senza Salva non cambia niente).
   - Esercizio aggiunto: **3 × 10, rec. 90"**; serie 1–10, recupero a passi di 15" (15"–5'). Schede nuove "Scheda A, B, C…" con id `scheda_N` che non cambia rinominando. Le schede si alternano nell'ordine scritto (niente `rotation`). Una scheda modificata tiene il suo `startDate`.
   - Le immagini restano **dentro l'app** (libreria < 1 MB): deciso di non scaricarle al bisogno.
4. ✅ **Editor della dieta** (`lib/features/diet_editor/`): si apre da "Crea la dieta" nella tab vuota o dal profilo ("Modifica la dieta"); l'onboarding resta solo per la scheda. Una scheda per giorno (Lun … Dom); in alto i **pasti da segnare**, uguali per tutti i giorni (Colazione ☕, Spuntino 🍎, Pranzo ☀️, Merenda 🥪, Cena 🌙; di default pranzo e cena). Ogni pasto: nome del piatto facoltativo + alimenti (nome, quantità anche come intervallo "250-300", unità, nota). **Copia il giorno** su altri giorni. Spunta **Uguale tutti i giorni** su un pasto: i 7 giorni condividono lo STESSO `MealDraft` (cambi in un giorno → cambia in tutti); accendendola, il pasto del giorno aperto sostituisce gli altri (con conferma se erano diversi); spegnendola ogni giorno prende una sua copia. Copia il giorno non tocca i pasti condivisi. Riaprendo una dieta, un pasto identico (stessa `signature`) in tutti e 7 i giorni ritrova la spunta accesa. Salva → `UserDataStore.saveDiet` (`<support>/user_data/assets/data/diet.json`). Il catalogo `foods` si costruisce dai nomi scritti (id "petto_di_pollo"; stesso nome = stessa voce). I giorni "Palestra" vengono dai giorni della scheda **al momento del salvataggio** (se cambi i giorni della scheda, risalva la dieta). Modificando una dieta completa (quella del nutrizionista) restano legumi, note, regole, alternative e id degli alimenti.
   - **Spesa**: editor ancora da fare (ci pensiamo più avanti); la tab mostra "Nessuna lista della spesa".
5. ✅ Pulizia: tolto tutto il download da GitHub (vedi "Dati online").

## Da fare / idee

1. **Colazione e spuntini** quando arriva il PDF "La mia giornata".
2. ~~Icona dell'app~~ ✅ fatta: manubrio inclinato su gradiente viola (disegnato con Claude; prima petrolio, poi arancio), con varianti iOS 18 scura e colorata.
3. Possibili: timer di recupero, storico dei pesi degli esercizi, grafico delle pesate, schede future dopo il 27/11.
4. Le descrizioni di plank laterale, leg raise, heel touch e del riscaldamento nuovo, e tutti i "Consigli", sono state scritte da Claude, non dal PT: da verificare.
6. Nei test `ExerciseMedia.videoEnabled = false` (in `widget_test.dart`): senza WebView il player YouTube non può partire.
