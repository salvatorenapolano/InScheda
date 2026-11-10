/// "Petto di pollo" → "petto_di_pollo": un id leggibile e senza spazi né
/// accenti, ricavato da un nome scritto dall'utente.
String slugify(String name, {String fallback = 'voce'}) {
  const accents = {'à': 'a', 'á': 'a', 'è': 'e', 'é': 'e', 'ì': 'i', 'í': 'i', 'ò': 'o', 'ó': 'o', 'ù': 'u', 'ú': 'u'};
  final plain = name.toLowerCase().split('').map((c) => accents[c] ?? c).join();
  final slug = plain.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  return slug.isEmpty ? fallback : slug;
}

/// [base] se [isTaken] dice che è libero, altrimenti base_2, base_3...
String uniqueId(String base, bool Function(String id) isTaken) {
  if (!isTaken(base)) return base;
  var n = 2;
  while (isTaken('${base}_$n')) {
    n++;
  }
  return '${base}_$n';
}
