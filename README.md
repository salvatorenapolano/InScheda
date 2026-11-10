# myWorkout

App Flutter per la palestra: scheda di allenamento, dieta settimanale, pesata settimanale e lista della spesa, tutto in un'unica app, senza account e senza server.

> **Stato:** in sviluppo. Al momento l'app contiene una scheda e una dieta di esempio; il prossimo passo è permettere a ogni utente di inserire i propri dati al primo avvio.

## Cosa fa

- **Allenamento** — le tue schede (A/B/C, Push/Pull/Legs o i nomi che vuoi) con il giorno di turno. Ogni esercizio ha video, istruzioni, consigli, i muscoli coinvolti e il peso che usi (salvato sul telefono).
- **Dieta** — la settimana dei pasti, giorno per giorno: la scrivi tu nell'app (pasti, alimenti e quantità).
- **Pesata** — promemoria nel giorno che scegli e storico delle pesate con le differenze.
- **Spesa** — liste settimanale e mensile con le spunte.

Al primo avvio l'app ti chiede il nome e ti fa creare la tua scheda: giorni, schede con il nome che vuoi ed esercizi scelti dalla libreria, divisa per gruppo muscolare. Tutti i tuoi dati (scheda, dieta, pesi, pesate, spunte) restano **solo sul telefono**.

## Installazione

- **Android**: scarica l'APK dalla pagina [Releases](../../releases) e installalo (serve consentire l'installazione da "origini sconosciute").
- Google Play: in arrivo.
- **iOS**: l'app non è sull'App Store. La cartella `ios/` c'è, quindi chi ha un Mac (o un servizio di build nel cloud) può compilarla per il proprio iPhone.

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
├── data/       # lettura dei JSON e salvataggi sul telefono
├── models/     # esercizi, scheda, dieta, spesa, pesate
├── features/   # una cartella per tab: workout, diet, weigh_in, shopping, profile
└── widgets/    # componenti condivisi
assets/data/    # exercises.json, workout_plan.json, diet.json, shopping.json
tool/           # script Python per anteprime, icona e immagini dei muscoli
```

Più dettagli su dati e interfaccia in [docs/CONTESTO_PROGETTO.md](docs/CONTESTO_PROGETTO.md).

## Crediti

- Font [Barlow Semi Condensed](https://fonts.google.com/specimen/Barlow+Semi+Condensed), licenza SIL Open Font License ([assets/fonts/OFL.txt](assets/fonts/OFL.txt)).
- Font del logo [Russo One](https://fonts.google.com/specimen/Russo+One) di Jovanny Lemonad, licenza SIL Open Font License ([assets/fonts/RussoOne-OFL.txt](assets/fonts/RussoOne-OFL.txt)).
- Icona, anteprime degli esercizi e illustrazioni dei muscoli: realizzate per questo progetto.
- I video degli esercizi sono contenuti di terze parti (YouTube e gym80.de), incorporati e non inclusi nel repository.

## Licenza

[MIT](LICENSE)
