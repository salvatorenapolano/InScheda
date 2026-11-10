/// Toglie maiuscole e accenti: "Alzate LATERALI" e "alzate laterali", oppure
/// "glutei" e "glùtei", diventano uguali e si trovano a vicenda.
String normalizeForSearch(String text) {
  const accents = {'à': 'a', 'á': 'a', 'è': 'e', 'é': 'e', 'ì': 'i', 'í': 'i', 'ò': 'o', 'ó': 'o', 'ù': 'u', 'ú': 'u'};
  return text.toLowerCase().split('').map((c) => accents[c] ?? c).join();
}

/// true se ogni parola di [query] compare in almeno uno dei [fields].
///
/// Le parole possono essere in qualsiasi ordine e anche a metà:
/// "press chest" trova "Chest press", "trici" trova "Tricipiti".
/// Una ricerca vuota trova tutto.
bool matchesSearch(String query, Iterable<String> fields) {
  final words = normalizeForSearch(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final haystack = normalizeForSearch(fields.join(' '));
  return words.every(haystack.contains);
}
