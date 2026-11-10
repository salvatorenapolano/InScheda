# myWorkout

App Flutter per la palestra: scheda di allenamento, dieta settimanale, pesata del venerdì e lista della spesa, tutto in un'unica app, senza account e senza server.

> **Stato:** in sviluppo. Al momento l'app contiene una scheda e una dieta di esempio; il prossimo passo è permettere a ogni utente di inserire i propri dati al primo avvio.

## Cosa fa

- **Allenamento** — scheda Push / Pull / Legs con il giorno di turno, riscaldamento, pesi, addominali e cardio. Ogni esercizio ha video, istruzioni, consigli, i muscoli coinvolti e il peso che usi (salvato sul telefono).
- **Dieta** — la settimana tipo, pranzo e cena giorno per giorno.
- **Pesata** — promemoria del venerdì e storico delle pesate con le differenze.
- **Spesa** — liste settimanale e mensile con le spunte.
- **Dati aggiornabili** — scheda, dieta e immagini sono file JSON/immagini che l'app può scaricare da un repository GitHub, senza ricompilare.

I dati personali (pesi, pesate, spunte) restano **solo sul telefono**.

## Installazione

- **Android**: scarica l'APK dalla pagina [Releases](../../releases) e installalo (serve consentire l'installazione da "origini sconosciute").
- Google Play: in arrivo.

## Sviluppo

Serve [Flutter](https://docs.flutter.dev/get-started/install) (Dart 3.13 o successivo).

```bash
flutter pub get
flutter run
```

Prima di ogni commit:

```bash
flutter analyze
flutter test
```

### Struttura

```
lib/
├── data/       # lettura dei JSON, salvataggi sul telefono, download da GitHub
├── models/     # esercizi, scheda, dieta, spesa, pesate
├── features/   # una cartella per tab: workout, diet, weigh_in, shopping, profile
└── widgets/    # componenti condivisi
assets/data/    # exercises.json, workout_plan.json, diet.json, shopping.json
tool/           # script Python per anteprime, icona e immagini dei muscoli
```

Più dettagli su dati e interfaccia in [docs/CONTESTO_PROGETTO.md](docs/CONTESTO_PROGETTO.md).

## Crediti

- Font [Barlow Semi Condensed](https://fonts.google.com/specimen/Barlow+Semi+Condensed), licenza SIL Open Font License ([assets/fonts/OFL.txt](assets/fonts/OFL.txt)).
- Icona, anteprime degli esercizi e illustrazioni dei muscoli: realizzate per questo progetto.
- I video degli esercizi sono contenuti di terze parti (YouTube e gym80.de), incorporati e non inclusi nel repository.

## Licenza

[MIT](LICENSE)
