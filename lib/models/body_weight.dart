/// Una pesata: il giorno e il peso in kg.
class BodyWeightEntry {
  const BodyWeightEntry({required this.date, required this.kg});

  /// Solo il giorno (ore, minuti e secondi a zero).
  final DateTime date;
  final double kg;

  /// Salvata come {"date": "2026-11-13", "kg": 78.4}.
  factory BodyWeightEntry.fromJson(Map<String, dynamic> json) {
    return BodyWeightEntry(
      date: DateTime.parse(json['date'] as String),
      // `num` accetta sia 78 sia 78.4; toDouble() li rende entrambi double.
      kg: (json['kg'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        // toIso8601String() dà "2026-11-13T00:00:00.000": ci basta la data.
        'date': date.toIso8601String().substring(0, 10),
        'kg': kg,
      };
}

/// Il giorno della pesata se l'utente non ne sceglie un altro: venerdì.
/// Quello vero sta nel profilo (ProfileStore.weighInWeekday).
const defaultWeighInWeekday = DateTime.friday;

/// Toglie ore e minuti: due pesate dello stesso giorno diventano uguali.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Cosa dire nel riquadro in cima alla pagina della pesata.
///
/// `sealed`: le sottoclassi possibili sono SOLO queste quattro, scritte
/// in questo file. Così uno `switch` che le elenca tutte è "completo" e,
/// se un giorno ne aggiungiamo una, Dart ci segnala ogni switch da aggiornare.
sealed class WeighInStatus {
  const WeighInStatus();
}

/// È il giorno della pesata e non ti sei ancora pesato.
final class WeighInDueToday extends WeighInStatus {
  const WeighInDueToday();
}

/// È il giorno della pesata e la pesata di oggi c'è già.
final class WeighInDoneToday extends WeighInStatus {
  const WeighInDoneToday(this.kg);
  final double kg;
}

/// L'ultimo giorno della pesata è passato e da allora non hai segnato niente.
final class WeighInMissed extends WeighInStatus {
  const WeighInMissed();
}

/// Tutto in regola: la prossima pesata è il [date].
final class WeighInUpcoming extends WeighInStatus {
  const WeighInUpcoming(this.date);
  final DateTime date;
}

/// Calcola lo stato a partire dalle pesate (dalla più recente), da oggi e
/// dal giorno della pesata ([weekday], 1 = lunedì … 7 = domenica).
WeighInStatus weighInStatusFor(
  List<BodyWeightEntry> entries,
  DateTime now, {
  int weekday = defaultWeighInWeekday,
}) {
  final today = dateOnly(now);
  // firstOrNull: il primo elemento, oppure null se la lista è vuota.
  final latest = entries.firstOrNull;

  if (today.weekday == weekday) {
    return latest != null && latest.date == today
        ? WeighInDoneToday(latest.kg)
        : const WeighInDueToday();
  }

  // Quanti giorni fa è stato il giorno della pesata. Col venerdì:
  // sabato 1, domenica 2 … giovedì 6.
  // In Dart `%` con un divisore positivo dà sempre un risultato >= 0.
  final daysSince = (today.weekday - weekday) % 7;
  final lastWeighInDay = DateTime(today.year, today.month, today.day - daysSince);

  // Se non hai ancora nessuna pesata non ti "sei perso" niente:
  // semplicemente si parte dal prossimo giorno della pesata.
  if (latest != null && latest.date.isBefore(lastWeighInDay)) {
    return const WeighInMissed();
  }
  return WeighInUpcoming(DateTime(today.year, today.month, today.day + 7 - daysSince));
}
