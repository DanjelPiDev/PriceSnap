import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/shopping_list.dart';

const _storageKey = 'savedShoppingLists';

Future<List<ShoppingList>> loadShoppingLists() async {
  final prefs = await SharedPreferences.getInstance();
  final List<String> raw = prefs.getStringList(_storageKey) ?? [];
  return raw.map((e) => ShoppingList.fromJson(jsonDecode(e))).toList();
}

Future<void> saveShoppingLists(List<ShoppingList> lists) async {
  final prefs = await SharedPreferences.getInstance();
  final List<String> raw = lists.map((e) => jsonEncode(e.toJson())).toList();
  await prefs.setStringList(_storageKey, raw);
}

Future<void> saveSingleShoppingList(ShoppingList list) async {
  final prefs = await SharedPreferences.getInstance();
  final key = _storageKey;

  final List<String> allRaw = prefs.getStringList(key) ?? [];
  List<ShoppingList> all = allRaw.map((e) => ShoppingList.fromJson(jsonDecode(e))).toList();

  final idx = all.indexWhere((l) => l.id == list.id);
  if (idx >= 0) {
    all[idx] = list;
  } else {
    all.add(list);
  }

  await prefs.setStringList(key, all.map((e) => jsonEncode(e.toJson())).toList());
}

Future<ShoppingList?> getActiveShoppingList() async {
  final lists = await loadShoppingLists();
  return lists.firstWhereOrNull((l) => l.status == ShoppingListStatus.active);
}

