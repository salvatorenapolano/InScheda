# myWorkout — contesto del progetto

App Flutter **pubblica e open source** (licenza MIT) per la palestra: scheda di allenamento, dieta settimanale, pesata del venerdì e lista della spesa. Nasce dalla versione personale (repo privato `myWorkout_private`): per ora contiene ancora i miei dati come esempio; il prossimo obiettivo è far inserire a ogni utente i propri dati al primo avvio. Distribuzione: APK su GitHub Releases, poi Google Play (niente App Store: niente Apple Developer Program).
È anche un progetto **per imparare Flutter**: procediamo step by step.

## Come lavoriamo

- **Lingua**: rispondi in italiano. Spiega i concetti Flutter/Dart nuovi che ogni modifica introduce; commenti nel codice in italiano.
- **Ambiente**: Windows 11, VS Code + Android Studio, Flutter 3.47.9 (Dart 3.13). Provo l'app su un **emulatore Android** (la lancio io con F5); per iPhone compilo nel cloud (vedi "Build iPhone").
- **Verifica**: ogni modifica si chiude con `flutter analyze` (zero problemi) e `flutter test` (tutti verdi). Non installare/avviare l'app sul mio emulatore al posto mio.
- **Codice su GitHub**: https://github.com/salvatorenapolano/myWorkout (branch `main`, **pubblico**: mai committare chiavi, keystore o dati personali). La versione personale è in `salvatorenapolano/myWorkout_private`.

## Stato delle funzioni

| Tab | Stato |
|---|---|
| **Allenamento** | ✅ Fatto: Fase 2 Push/Pull/Legs, dettaglio esercizio con video, consigli e pesi salvati |
| **Dieta** | ✅ Fatto: settimana tipo, pranzo e cena |
| **Pesata** | ✅ Fatto: promemoria del venerdì, storico pesate con differenze |
| **Spesa** | ✅ Fatto: liste Settimanale / Mensile con spunte e Reset |

## Stack

- Flutter + Material 3, tema chiaro/scuro automatico. Colore seme **verde petrolio `0xFF0E7C86`** (il rosso non mi piace), variante `DynamicSchemeVariant.fidelity` per tenere il petrolio pieno.
- Stile "lavagna della sala pesi": font **Barlow Semi Condensed** (in `assets/fonts/`, licenza OFL) per titoli e numeri, font di sistema per il testo; raggi 28 (banner) / 20 (card) / 12 (riquadri interni); pagine grigio chiaro con card bianche (in scuro: card più chiare dello sfondo). Tutto in `lib/app_theme.dart`.
- Pacchetti: `flutter_svg` (anteprime), `shared_preferences` (pesi salvati), `youtube_player_iframe` (video), `http` + `path_provider` (dati da GitHub).
- Nessun backend: i contenuti sono **file JSON e immagini negli asset**, aggiornabili da GitHub senza ricompilare (vedi "Dati online"); i dati dell'utente (pesi) sono salvati sul telefono.
- Android: permesso `INTERNET` nel manifest (serve ai video). Nome app sotto l'icona: **myWorkout**. ID app (Android e iOS) `io.github.salvatorenapolano.myworkout`: definitivo, non cambiarlo dopo la pubblicazione su Google Play.
- Icona: dopo `dart run flutter_launcher_icons` **ripristinare** `ios/Runner.xcodeproj/project.pbxproj` (`git checkout -- …`): la v0.14.4 lo modifica per errore (mette `AppIcon` in `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS`).

## Struttura del codice

```
lib/
├── main.dart                 # carica gli store (pesi, pesate, spesa, DataStore) poi runApp
├── app.dart                  # MaterialApp, gli Scope sopra tutto, DefaultAssetBundle = bundle dei dati
├── app_theme.dart            # AppTheme.light()/dark(): colori, font, raggi, componenti
├── home_shell.dart           # NavigationBar 3 tab + IndexedStack
├── models/                   # exercise.dart, workout_plan.dart, diet.dart (fromJson)
├── data/                     # workout_repository, diet_repository (leggono e validano i JSON)
│                             # weight_store.dart (ChangeNotifier + InheritedNotifier WeightScope)
│                             # remote_data.dart: DataBundle, DataStore (download da GitHub), DataScope
├── utils/formatters.dart     # formatRest (120→2', 90→90"), formatWeight (22,5 kg), date in italiano
└── features/
    ├── workout/              # workout_page, exercise_detail_page, widgets/ (today_banner,
    │                         #   planned_exercise_tile, exercise_block_tile, exercise_media, exercise_preview, step_number)
    ├── diet/                 # diet_page (TabBar Lun…Dom), widgets/ (diet_day_view, meal_card)
    ├── weigh_in/             # weigh_in_page (storico, +), widgets/weigh_in_banner
    └── shopping/             # shopping_page (schede Settimanale/Mensile, checkbox, Reset)
│   └── profile/              # profile_avatar (cerchio "SN"), profile_sheet (pannello dati)
lib/widgets/                  # condivisi: main_app_bar (header), status_banner, weight_input_dialog, dividers
assets/data/                  # exercises.json, workout_plan.json, diet.json, shopping.json
assets/images/exercises/      # <id>.svg, una anteprima per esercizio
assets/images/muscles/        # illustrazioni muscoli (.webp scontornati, sfondo trasparente), scelte con "muscleImage"
tool/generate_exercise_previews.py   # genera tutti gli SVG (pose + colori)
tool/prepare_muscle_images.py        # ritaglia e scontorna le illustrazioni dei muscoli (python … <cartella_originali>)
tool/sync_data_repo.py               # copia JSON e immagini nel repo pubblico ../myWorkout-data
tool/generate_app_icon.py            # icona: manubrio su gradiente petrolio (+ varianti iOS scura e colorata) → assets/icon/
flutter_launcher_icons.yaml          # poi `dart run flutter_launcher_icons` crea tutte le misure iOS/Android
test/                         # test su JSON, calendario, banner, pesi, widget
codemagic.yaml                # build iOS nel cloud
```

## I dati

### `exercises.json` — libreria esercizi (il "come")
Ogni esercizio: `id`, `name`, `category` (`warmup` | `weights` | `abs`), `muscles[]`, `description`, `tips[]`, `images[]`, `videoUrl`. 39 esercizi, tutti usati nella scheda (un test lo controlla).
- Solo `weights` ha il riquadro "Il tuo peso".
- `description`: per i pesi è il "Come si fa" della scheda Fase 2. `tips[]` ("Consigli" nel dettaglio): 2–3 consigli per esercizio, **scritti da Claude**, non dal PT.
- `videoUrl`: tutti tranne il cardio leggero. **Macchine** → video delle pagine prodotto **gym80.de** (es. leg press 3030, butterfly 3022, butterfly reverse 3025, adduction 3029, abduction 3028, calf 3018, triceps 3011, biceps 3010, seated row 3040, 45° back extension 4119). **Manubri, corpo libero, riscaldamento, addominali** → tutorial YouTube in italiano (Project inVictus, Umberto Miletto, Marcello Chiapponi…). Verificati con l'oEmbed di YouTube (esistono e si possono incorporare).
- L'anteprima è `assets/images/exercises/<id>.svg` (ricavata dall'id).
- `muscleImage` (facoltativo, solo pesi): nome dell'illustrazione in `assets/images/muscles/` (petto, dorsali, femorali, spalle, bicipiti, tricipiti, glutei, retto_addominale, quadricipiti; addome_obliqui per ora non usata). 20 esercizi coi pesi su 23: mancano iperestensioni, adductor e calf (non ci sono illustrazioni di lombari, adduttori e polpacci).

### `workout_plan.json` — la scheda (il "quanto")
Fase 2 · Push/Pull/Legs (sostituisce la Fase 1, che resta nella storia git).
- `schedule`: lunedì, mercoledì, venerdì alle 15:00, rotazione **push, pull, legs** dal **16/11/2026** al **23/12/2026** (17 sedute: ogni settimana lun Push, mer Pull, ven Legs). Il calendario si calcola, non è scritto riga per riga.
- `workouts[]`: ogni giorno ha `id`, `name`, `focus` (i muscoli, sotto il banner), `intro` ("21 serie…", sotto il titolo dei pesi), **il suo** `warmup` ed `exercises` (i pesi). Serie: Push 21, Pull 20, Legs 23.
- Seduta = **1 Riscaldamento** (5' cardio + mobilità del giorno) → **2 Pesi** → **3 Addominali** (uguali tutti i giorni: crunch alla macchina 3×12–15 + circuito plank, plank laterale, leg raise, heel touch) → **4 Cardio** fisso: 30 min, pendenza 10%, 5,5 km/h, senza note. **Niente stretching** (tolto apposta, anche se è nella scheda del PT).
- Ogni esercizio in scheda: `exerciseId`, `sets?`, `reps` (testo: "10–12", "30\"", "12 per lato"), `restSeconds?`, `notes?`, `alternatives[]` ("se è occupato", solo quelle date dal PT nella Fase 1).
- Macchinari nuovi: nota "Settimana 1: prima una serie leggera da 10…" sulla riga. French press solo settimane 1, 3, 5 (nella nota).
- `generalNotes` (non mostrata): doppia progressione e regola dei macchinari nuovi.

### `diet.json` — la settimana tipo
- Catalogo `foods` (id, nome, **reparto**: Frutta e verdura, Carne e pesce, Frigo, Pane, Dispensa). La spesa NON è calcolata da qui: ha il suo `shopping.json`.
- `days`: 7 giorni, `training` true lun/mer/ven, ognuno con pasti `pranzo` (13:00) e `cena` (19:30–20:00). Domenica un unico slot "Pranzo e cena" libero con 3 regole.
- Ingredienti: `foodId`, `quantity?`, `quantityMax?` (intervalli 250–300 g), `unit`, `note`.
- Extra: riquadro "legumi a scelta" (solo mar/gio), note "Da sapere".
- `alternative` di un pasto = riquadro "se manca": martedì cena "Se manca il salmone…", lunedì cena "Se mancano le patate: 250–300 g di verdure." (le verdure non sono tra gli ingredienti). Mercoledì cena senza insalata (l'alimento resta nel catalogo, per ora non usato).
- Colazione e spuntini **mancano** (sono in un altro PDF, "La mia giornata", non ancora fornito).

### `shopping.json` — la lista della spesa
Due liste (`Settimanale` · fresco, `Mensile` · dispensa), ognuna con sezioni e prodotti `{id, name, quantity?}`, trascritte dal PDF del nutrizionista. Gli `id` devono essere unici (il repository lo controlla) e non vanno cambiati: servono a ricordare le spunte.

### Dati dell'utente (tutti in `shared_preferences`)
- Pesi per esercizio: chiave `weight_<exerciseId>`, in kg (anche decimali). Non è una checklist delle serie: è solo un promemoria del peso usato.
- Pesate: chiave `body_weights`, testo JSON `[{"date": "2026-11-06", "kg": 78.4}, …]`, una per giorno (`BodyWeightStore`).
- Spunte della spesa: chiave `shopping_checked`, lista degli id spuntati (`ShoppingStore`).

## Com'è fatta l'interfaccia

**Header** (tutte e 4 le tab, `MainAppBar`): "my**Workout**" (Workout nel colore principale) a sinistra, a destra il cerchio grigio sfumato con le iniziali **SN**. Tocco sul cerchio → pannello dal basso: quali dati sta usando l'app, **Scarica gli ultimi dati** (barra "File 3 di 40"), **Torna ai dati dell'app**. Le pagine non hanno più un titolo loro.

**Allenamento**
- In alto `TodayBanner`: "Oggi: Push" + muscoli del giorno (colorato, con "PUSH" in filigrana) / "Oggi riposo · prossimo allenamento domani: Pull" / "Scheda terminata". Senza orario (resta nel JSON).
- Selettore Push / Pull / Legs: parte sul giorno di turno, che ha un'icona calendario.
- Sotto "2 · Pesi" la riga `intro` del giorno; niente nota generale (resta nel JSON).
- Righe esercizio: anteprima SVG (con **numero d'ordine** nell'angolo, solo nei pesi), nome, "3 × 10–12 · rec. 90\"", peso salvato a destra.
- Riscaldamento e addominali sono blocchi espandibili.

**Dettaglio esercizio** (tap su una riga): video YouTube al posto dell'anteprima se c'è, nome, card "in scheda" (serie, recupero, note), card **Il tuo peso** (− / + di 1 kg, tap per scriverlo), card **Muscoli** (illustrazione anatomica con muscolo in rosso + elenco; tap = schermo intero con zoom), "Come si esegue", consigli, "Se è occupato". Senza illustrazione i muscoli restano chip sotto il nome.

**Dieta**: schede Lun…Dom (si apre su oggi), chip **Palestra giallo** / Riposo bianco, una card per pasto: **☀️ Pranzo (13:00) con sfondo giallo tenue, 🌙 Cena (20:00) con sfondo blu tenue**. Intestazione del pasto centrata con divisore sotto, ingredienti a pallini. Niente riquadro "Da sapere" (le note restano nel JSON).

**Pesata** (tab con la bilancia): banner in cima solo col titolo, senza descrizione: "Oggi ti devi pesare" il venerdì (petrolio), "Pesata fatta: 78,4 kg", "Pesata di venerdì da fare" se l'hai saltata, altrimenti "Prossima pesata …". Storico dalla più recente: data, differenza dalla precedente (+0,4 / −0,6 / ±0), peso. **+** = pesata di oggi (se c'è già la sostituisce), tocco = correggi, trascina a sinistra = cancella (con Annulla).

**Spesa**: schede Settimanale / Mensile, sezioni con contatore "3/7", prodotto con checkbox e quantità; spuntato = barrato. Tasto **Reset** sempre in basso a destra: toglie le spunte **della scheda aperta** (la mensile non si azzera col reset settimanale), con Annulla.

**Anteprime esercizi**: stile "badge colorato" — omino bianco su quadrato arrotondato colorato per gruppo muscolare (gambe blu, petto rosa, schiena indaco, spalle viola, braccia arancio, core verde, riscaldamento corallo). Si rigenerano con `python tool/generate_exercise_previews.py`.

## Decisioni già prese (non riproporle)

- Niente card grande "prossimo allenamento": c'è il banner del giorno.
- Niente pulsante "avvia recupero" / timer per ora.
- Niente stretching finale (nemmeno in Fase 2).
- Cardio fisso 30 min / 10% / 5,5 km/h, senza note.
- Dieta generica: giorni della settimana senza date.
- Video: macchine da gym80 (pagine prodotto gym80.de), il resto da tutorial YouTube in italiano.

## Dati online (GitHub)

- Repo **pubblico** `salvatorenapolano/myWorkout-data` (cartella locale `../myWorkout-data`), con la stessa struttura degli asset: `assets/data/*.json`, `assets/images/exercises/*.svg`, `assets/images/muscles/*.webp`. Pubblico = niente dati personali (pesi e pesate restano sul telefono). Costanti in `RemoteDataConfig`.
- Aggiornare: modificare i file sul sito di GitHub, oppure qui `python tool/sync_data_repo.py` e poi commit + push nel repo dei dati. Nell'app: cerchio SN → **Scarica gli ultimi dati**.
- Come funziona (`lib/data/remote_data.dart`): API GitHub `commits/main` (ultimo commit) → `git/trees/<tree>?recursive=1` (file + hash) → scarica da `raw.githubusercontent.com/<owner>/<repo>/<commit>/<path>` **solo i file con hash cambiato** (gli altri li copia). Salva in `<support>/remote_data/<commit>/assets/...` e `current.json`. Prima di usarli li **valida** (scheda, dieta, spesa si leggono; ogni esercizio ha anteprima e illustrazione): se qualcosa non va tiene i dati vecchi e mostra l'errore.
- `DataBundle` (CachingAssetBundle): cerca il file tra quelli scaricati, se non c'è usa `rootBundle`. Sta in `DefaultAssetBundle` (app.dart), quindi Image.asset, SvgPicture.asset e i repository leggono da lì. Dopo un aggiornamento `revision` cambia, `HomeShell` ha una Key nuova e le pagine si ricaricano; le cache di immagini e SVG vengono svuotate.
- Limite: l'API GitHub senza login permette 60 richieste/ora (ogni aggiornamento ne usa 2). I dati scaricati vincono sempre su quelli dell'app, anche se l'app viene reinstallata con dati più nuovi: in quel caso "Torna ai dati dell'app".

## Build iPhone (da Windows)

1. Push su GitHub → **Codemagic** usa `codemagic.yaml` (workflow "iOS per Sideloadly"): `flutter test`, poi `flutter build ios --release --no-codesign`, poi crea `myWorkout.ipa`.
2. **Sideloadly** su Windows (con iTunes/iCloud dal sito Apple) firma l'ipa con il mio Apple ID gratuito e lo installa via cavo.
3. Sull'iPhone: Modalità sviluppatore + "Autorizza" lo sviluppatore.
4. La firma gratuita **scade ogni 7 giorni**: si reinstalla sopra, i pesi restano. Alternativa futura: Apple Developer Program (99 €/anno) + TestFlight.

## Figma

File "myWorkout" con wireframe iniziali (pagine Wireframe/Componenti/Design, variabili colore e stili testo iOS). Il piano Starter ha esaurito le chiamate MCP, quindi il file non riflette le ultime modifiche: oggi **il riferimento è l'app**, non Figma.

## Da fare / idee

1. **Colazione e spuntini** quando arriva il PDF "La mia giornata".
2. ~~Icona dell'app~~ ✅ fatta: manubrio inclinato su gradiente petrolio (disegnato con Claude), con varianti iOS 18 scura e colorata.
3. Possibili: timer di recupero, storico dei pesi degli esercizi, grafico delle pesate, schede future dopo il 27/11.
4. Le descrizioni di plank laterale, leg raise, heel touch e del riscaldamento nuovo, e tutti i "Consigli", sono state scritte da Claude, non dal PT: da verificare.
6. Nei test `ExerciseMedia.videoEnabled = false` (in `widget_test.dart`): senza WebView il player YouTube non può partire.
