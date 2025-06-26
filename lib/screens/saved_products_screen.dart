import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:price_snap/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../utils/store_utils.dart';
import '../utils/update_data.dart';

class SavedProductsScreen extends StatefulWidget {
  const SavedProductsScreen({super.key});

  @override
  State<SavedProductsScreen> createState() => _SavedProductsScreenState();
}

class _SavedProductsScreenState extends State<SavedProductsScreen> {
  List<Product> _products = [];
  bool _loading = true;

  final List<Store> filterStores = [
    Store.none,
    Store.rewe,
    Store.lidl,
    Store.aldi,
    Store.edeka,
    Store.netto,
    Store.penny,
  ];
  final List<Store> itemStores = [
    Store.rewe,
    Store.lidl,
    Store.aldi,
    Store.edeka,
    Store.netto,
    Store.penny,
  ];
  Store _selectedFilterStore = Store.none;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> saved = prefs.getStringList('productTemplates') ?? [];
    setState(() {
      _products = saved.map((e) {
        final item = Product.fromJson(jsonDecode(e));
        if (!itemStores.contains(item.store)) {
          item.store = itemStores.first;
        }
        return item;
      }).toList();
      _loading = false;
    });
  }

  void _editItem(int i) async {
    final nameController = TextEditingController(text: _products[i].name);
    final priceController = TextEditingController(text: _products[i].price.toStringAsFixed(2));

    Store selectedStore = _products[i].store ?? Store.rewe;
    bool discount = _products[i].discount;

    if (!itemStores.contains(selectedStore)) {
      selectedStore = itemStores.first;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.editProductTitle),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
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
              DropdownButtonFormField<Store>(
                value: selectedStore,
                decoration: const InputDecoration(labelText: "Store"),
                items: itemStores.map((s) =>
                    DropdownMenuItem(value: s, child: Text(storeToDisplayName(s)))
                ).toList(),
                onChanged: (s) => setDialogState(() { selectedStore = s!; }),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: discount,
                onChanged: (v) => setDialogState(() => discount = v ?? false),
                title: Text(AppLocalizations.of(context)!.discount),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.editProductCancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'name': nameController.text.trim(),
                'price': double.tryParse(priceController.text.replaceAll(',', '.').trim()) ?? _products[i].price,
                'store': selectedStore,
                'discount': discount,
              });
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (result != null && result['name'].isNotEmpty) {
      setState(() {
        _products[i].name = result['name'];
        _products[i].price = result['price'];
        _products[i].store = result['store'];
        _products[i].discount = result['discount'] ?? false;
      });
      final prefs = await SharedPreferences.getInstance();
      final updated = _products.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList('productTemplates', updated);
      await updateProductEverywhere(_products[i]);
    }
  }

  Future<void> _removeItem(int idx) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> saved = prefs.getStringList('productTemplates') ?? [];
    saved.removeAt(idx);
    await prefs.setStringList('productTemplates', saved);
    await _loadItems();
  }

  Future<void> _pickImageForItem(int index) async {
    final picker = ImagePicker();
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text(AppLocalizations.of(context)!.takePhoto),
              onTap: () => Navigator.pop(ctx, "camera"),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(AppLocalizations.of(context)!.selectPhotoFromGallery),
              onTap: () => Navigator.pop(ctx, "gallery"),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    final XFile? image = await picker.pickImage(
      source: result == "camera" ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() {
      _products[index].imageUrl = image.path;
    });

    final prefs = await SharedPreferences.getInstance();
    final updated = _products.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('productTemplates', updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.savedProductsTemplates)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
          ? const Center(child: Text("No saved products."))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _products.length,
              itemBuilder: (ctx, i) {
                final it = _products[i];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: GestureDetector(
                      onTap: () => _pickImageForItem(i),
                      child: _products[i].imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_products[i].imageUrl!),
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
                              child: const Icon(
                                Icons.image,
                                size: 24,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _editItem(i),
                            child: Text(
                              it.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        if (it.discount)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Chip(
                              backgroundColor: Colors.orange.withOpacity(0.13),
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.percent,
                                    size: 16,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    AppLocalizations.of(context)!.discount,
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text("${it.price.toStringAsFixed(2)} €"),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_forever_outlined,
                        color: Colors.red,
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Remove saved product?"),
                            content: Text(
                              'Do you really want to remove "${it.name}"?',
                            ),
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
