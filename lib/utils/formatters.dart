import 'package:my_workout/models/workout_plan.dart';

// Piccole funzioni per mostrare numeri, date e tempi come nella scheda cartacea.

const _weekdays = [
  'lunedì', 'martedì', 'mercoledì', 'giovedì', 'venerdì', 'sabato', 'domenica',
];

const _months = [
  'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
  'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
];

/// 5 → "venerdì" (1 = lunedì … 7 = domenica, come DateTime.weekday).
String formatWeekday(int weekday) => _weekdays[weekday - 1];

/// "lunedì 9 novembre". In Dart weekday e month partono da 1, le liste da 0.
String formatDayMonth(DateTime date) {
  return '${_weekdays[date.weekday - 1]} ${date.day} ${_months[date.month - 1]}';
}

/// "oggi", "domani" oppure "lunedì 9 novembre" (minuscolo: va dentro una frase).
String formatRelativeDay(DateTime date, {required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  if (day == today) return 'oggi';
  if (day == DateTime(today.year, today.month, today.day + 1)) return 'domani';
  return formatDayMonth(day);
}

/// La riga sotto il nome di un esercizio: "3 × 10–12 · rec. 90"".
/// Senza serie (riscaldamento) solo le ripetizioni: "10 per lato".
/// Per il cardio la durata e la macchina: "20 min · 5,5 km/h · pendenza 10%".
String formatPlanned(PlannedExercise planned) {
  if (planned.isCardio) return formatCardio(planned);
  final sets = planned.sets;
  final rest = planned.restSeconds;
  return [
    if (sets == null) planned.reps else '$sets × ${planned.reps}',
    if (rest != null) 'rec. ${formatRest(rest)}',
  ].join(' · ');
}

/// "20 min · 5,5 km/h · pendenza 10%" oppure "15 min · livello 8".
String formatCardio(PlannedExercise planned) =>
    ['${planned.durationMinutes} min', ?formatCardioSettings(planned)].join(' · ');

/// Solo come impostare la macchina: "5,5 km/h · pendenza 10%", "livello 8",
/// oppure null se non c'è niente da impostare.
String? formatCardioSettings(PlannedExercise planned) {
  final speed = planned.speedKmh;
  final incline = planned.inclinePercent;
  final level = planned.level;
  final parts = [
    if (speed != null) '${formatNumber(speed)} km/h',
    if (incline != null) 'pendenza ${formatNumber(incline)}%',
    if (level != null) 'livello $level',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Una durata in secondi come nelle schede: 30 → 30"   60 → 1'   90 → 1'30"
String formatSeconds(int seconds) {
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  if (minutes == 0) return '$rest"';
  return rest == 0 ? "$minutes'" : "$minutes'$rest\"";
}

/// Recupero come nel PDF: 120 → 2'   90 → 90"   60 → 60"
String formatRest(int seconds) {
  if (seconds > 60 && seconds % 60 == 0) return "${seconds ~/ 60}'";
  return '$seconds"';
}

/// Numero all'italiana, senza decimali inutili: 16.0 → "16", 2.5 → "2,5".
String formatNumber(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString().replaceAll('.', ',');
}

/// 16.0 → "16 kg"
String formatWeight(double kg) => '${formatNumber(kg)} kg';

/// Il contrario di formatNumber: accetta sia "2,5" che "2.5".
/// Restituisce null se il testo non è un numero.
double? parseNumber(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

/// Prima lettera maiuscola: "venerdì 13 novembre" → "Venerdì 13 novembre".
String capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// Differenza tra due pesate, col segno: 0.4 → "+0,4", -0.6 → "−0,6", 0 → "±0".
/// Arrotondiamo a un decimale perché coi double 78.4 - 79.0 fa -0.6000000000000085.
String formatWeightChange(double diff) {
  final rounded = (diff * 10).round() / 10;
  if (rounded == 0) return '±0';
  // "−" è il vero segno meno tipografico, più largo del trattino "-".
  return '${rounded > 0 ? '+' : '−'}${formatNumber(rounded.abs())}';
}

/// Il cronometro: 75 s → "1:15", 3725 s → "1:02:05".
/// padLeft(2, '0') aggiunge lo zero davanti: 5 → "05".
String formatClock(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  if (hours == 0) return '$minutes:$seconds';
  return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
}

/// Una durata da leggere: 42 min → "42 min", 65 min → "1 h 05 min".
String formatDurationShort(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (hours == 0) return '$minutes min';
  return '$hours h ${minutes.toString().padLeft(2, '0')} min';
}

/// Le kcal arrotondate, con la tilde perché sono una stima: "~245 kcal".
String formatKcal(double kcal) => '~${kcal.round()} kcal';

/// "11 nov" per le date brevi dello storico.
String formatShortDate(DateTime date) => '${date.day} ${_months[date.month - 1].substring(0, 3)}';

/// La lettera di una scheda per i bollini: "Scheda A" → "A", "Push" → "P",
/// "Scheda 2" → "2". Se l'ultima parola è corta (1-2 caratteri) è quella
/// la "lettera"; altrimenti l'iniziale del nome.
String workoutInitial(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  final last = words.last;
  if (words.length > 1 && last.length <= 2) return last.toUpperCase();
  return words.first[0].toUpperCase();
}
