import 'package:flutter/material.dart';

import 'package:my_workout/models/shopping.dart';

/// I nomi delle icone dei reparti (quelli scritti nel JSON) e le icone vere.
///
/// Una mappa `const`: Flutter sa già al momento della build quali icone
/// usiamo, e può togliere dall'app tutte le altre del font Material.
const departmentIcons = <String, IconData>{
  'basket': Icons.shopping_basket,
  'eco': Icons.eco,
  'bakery': Icons.bakery_dining,
  'fish': Icons.set_meal,
  'fridge': Icons.kitchen,
  'pantry': Icons.inventory_2,
  'frozen': Icons.ac_unit,
  'drink': Icons.local_drink,
  'cleaning': Icons.cleaning_services,
  'egg': Icons.egg,
  'coffee': Icons.coffee,
  'pets': Icons.pets,
  'baby': Icons.child_care,
  'medication': Icons.medication,
  'wine': Icons.wine_bar,
  'label': Icons.label,
};

/// Il quadratino colorato con l'icona bianca del reparto, come i badge
/// degli esercizi. null = reparto sconosciuto: grigio, col cestino.
class DepartmentBadge extends StatelessWidget {
  const DepartmentBadge({super.key, required this.department, this.size = 36});

  final ShoppingDepartment? department;
  final double size;

  @override
  Widget build(BuildContext context) {
    final d = department ?? ShoppingDepartment.otherDepartment;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color(d.color),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(departmentIcons[d.icon] ?? Icons.shopping_basket, color: Colors.white, size: size * 0.58),
    );
  }
}
