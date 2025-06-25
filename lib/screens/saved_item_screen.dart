import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

  final List<String> filterStores = ['Alle', 'REWE', 'Lidl', 'Aldi', 'Edeka', 'Netto', 'Penny'];
  final List<String> itemStores = ['REWE', 'Lidl', 'Aldi', 'Edeka', 'Netto', 'Penny'];
  String _selectedFilterStore = 'Alle';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> saved = prefs.getStringList('itemTemplates') ?? [];
    setState(() {
      _items = saved.map((e) {
        final item = Item.fromJson(jsonDecode(e));
        if (!itemStores.contains(item.store)) {
          item.store = itemStores.first;
        }
        return item;
      }).toList();
      _loading = false;
    });
  }

  void _editItem(int i) async {
    final nameController = TextEditingController(text: _items[i].name);
    final priceController = TextEditingController(text: _items[i].price.toStringAsFixed(2));
    String selectedStore = _items[i].store;
    if (!itemStores.contains(selectedStore)) {
      selectedStore = itemStores.first;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Price (€)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedStore,
              decoration: const InputDecoration(labelText: "Store"),
              items: itemStores.map((s) =>
                  DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (s) => selectedStore = s!,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'name': nameController.text.trim(),
                'price': double.tryParse(
                    priceController.text.replaceAll(',', '.').trim()) ?? _items[i].price,
                'store': selectedStore,
              });
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (result != null && result['name'].isNotEmpty) {
      setState(() {
        _items[i].name = result['name'];
        _items[i].price = result['price'];
        _items[i].store = result['store'];
      });
      final prefs = await SharedPreferences.getInstance();
      final updated = _items.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList('itemTemplates', updated);
    }
  }

  Future<void> _removeItem(int idx) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> saved = prefs.getStringList('itemTemplates') ?? [];
    saved.removeAt(idx);
    await prefs.setStringList('itemTemplates', saved);
    await _loadItems();
  }

  Future<void> _pickImageForItem(int index) async {
    final picker = ImagePicker();
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) =>
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text("Take a Photo"),
                  onTap: () => Navigator.pop(ctx, "camera"),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text("Select from Gallery"),
                  onTap: () => Navigator.pop(ctx, "gallery"),
                ),
              ],
            ),
          ),
    );
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
              leading: GestureDetector(
                onTap: () => _pickImageForItem(i),
                child: _items[i].imageUrl != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_items[i].imageUrl!),
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                )
                    : Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: const Icon(Icons.image, size: 24, color: Colors.grey),
                ),
              ),
              title: GestureDetector(
                onTap: () => _editItem(i),
                child: Text(
                  it.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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
