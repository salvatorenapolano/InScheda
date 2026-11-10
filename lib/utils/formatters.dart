// Piccole funzioni per mostrare numeri, date e tempi come nella scheda cartacea.

const _weekdays = [
  'lunedì', 'martedì', 'mercoledì', 'giovedì', 'venerdì', 'sabato', 'domenica',
];

const _months = [
  'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
  'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
];

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
