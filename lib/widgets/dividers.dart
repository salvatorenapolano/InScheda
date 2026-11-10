import 'package:flutter/material.dart';

/// Mette un Divider (linea sottile) tra una riga e l'altra di una lista.
///
/// È una funzione "libera", fuori da ogni classe: in Dart si può.
/// [indent] è il rientro a sinistra della linea: nella scheda è 80, così
/// la linea parte dopo l'anteprima dell'esercizio, come su iOS.
List<Widget> withDividers(List<Widget> rows, {double indent = 16}) {
  return [
    for (final (index, row) in rows.indexed) ...[
      if (index > 0) Divider(indent: indent),
      row,
    ],
  ];
}
