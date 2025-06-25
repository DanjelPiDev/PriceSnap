import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/item.dart';

class SavedItemsScreen extends StatefulWidget {
  const SavedItemsScreen({super.key});

  @override
  State<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen> {
  List<Item> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> saved = prefs.getStringList('itemTemplates') ?? [];
    setState(() {
      _items = saved.map((e) => Item.fromJson(jsonDecode(e))).toList();
      _loading = false;
    });
  }

  Future<void> _removeItem(int idx) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> saved = prefs.getStringList('itemTemplates') ?? [];
    saved.removeAt(idx);
    await prefs.setStringList('itemTemplates', saved);
    await _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Saved Items Templates")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(child: Text("No saved items."))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        itemBuilder: (ctx, i) {
          final it = _items[i];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              leading: it.imageUrl != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(it.imageUrl!,
                    width: 40, height: 40, fit: BoxFit.cover),
              )
                  : const Icon(Icons.shopping_basket, size: 36),
              title: Text(it.name,
                  style:
                  const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${it.price.toStringAsFixed(2)} €"),
              trailing: IconButton(
                icon: const Icon(Icons.delete_forever_outlined,
                    color: Colors.red),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Remove saved item?"),
                      content: Text(
                          'Do you really want to remove "${it.name}"?'),
                      actions: [
                        TextButton(
                          child: const Text("Cancel"),
                          onPressed: () => Navigator.pop(ctx, false),
                        ),
                        ElevatedButton(
                          child: const Text("Remove"),
                          onPressed: () => Navigator.pop(ctx, true),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) _removeItem(i);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
