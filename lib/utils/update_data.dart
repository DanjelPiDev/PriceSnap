import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../storage/shopping_list_storage.dart';


Future<void> updateProductEverywhere(Product updatedProduct) async {
  final prefs = await SharedPreferences.getInstance();
  final templates = prefs.getStringList('productTemplates') ?? [];
  final List<Product> products = templates.map((e) => Product.fromJson(jsonDecode(e))).toList();

  final idx = products.indexWhere((p) => p.id == updatedProduct.id);
  if (idx != -1) {
    products[idx] = updatedProduct.copyWith(quantity: products[idx].quantity);
    await prefs.setStringList('productTemplates', products.map((e) => jsonEncode(e.toJson())).toList());
  }

  final lists = await loadShoppingLists();
  for (final list in lists) {
    bool changed = false;
    final newItems = list.items.map((p) {
      if (p.id == updatedProduct.id) {
        changed = true;
        return p.copyWith(
          name: updatedProduct.name,
          price: updatedProduct.price,
          store: updatedProduct.store,
          discount: updatedProduct.discount,
        );
      }
      return p;
    }).toList();
    if (changed) {
      final updatedList = list.copyWith(items: newItems);
      await saveSingleShoppingList(updatedList);
    }
  }
}
