import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../l10n/app_localizations.dart';
import '../models/product.dart';
import '../services/shopping_list_sync.dart';
import '../storage/shopping_list_storage.dart';
import '../utils/store_utils.dart';
import '../models/shopping_list.dart';


Future<List<Product>> loadProductTemplates() async {
  final prefs = await SharedPreferences.getInstance();
  final templates = prefs.getStringList('productTemplates') ?? [];
  return templates.map((e) => Product.fromJson(jsonDecode(e))).toList();
}

class ShoppingListDetailScreen extends StatefulWidget {
  final ShoppingList? list;

  const ShoppingListDetailScreen({super.key, this.list});

  @override
  State<ShoppingListDetailScreen> createState() => _ShoppingListDetailScreenState();
}

class _ShoppingListDetailScreenState extends State<ShoppingListDetailScreen> {
  late TextEditingController _nameCtrl;
  Store _selectedStore = Store.none;
  List<Product> _items = [];
  bool _editing = false;

  double get _total => _items.fold(0.0, (sum, it) => sum + it.price * it.quantity);

  @override
  void initState() {
    super.initState();
    final l = widget.list;
    _editing = l != null;
    _nameCtrl = TextEditingController(text: l?.name ?? '');
    _selectedStore = l?.store ?? Store.none;
    _items = List<Product>.from(l?.items ?? []);
  }

  void _addProductDialog() async {
    final templates = await loadProductTemplates();
    if (templates.isEmpty) {
      return;
    }
    Product? selected;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.addProduct),
        content: DropdownButtonFormField<Product>(
          items: templates.map((p) =>
              DropdownMenuItem(value: p, child: Text('${p.name} (${storeToDisplayName(p.store)})'))).toList(),
          onChanged: (p) => selected = p,
          decoration: InputDecoration(labelText: AppLocalizations.of(context)!.selectTemplateProduct),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.editProductCancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (selected != null) {
                setState(() {
                  final idx = _items.indexWhere((it) => it.id == selected!.id);
                  if (idx >= 0) {
                    _items[idx].quantity++;
                  } else {
                    _items.add(selected!.copyWith(quantity: 1));
                  }
                });
              }
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.addProduct),
          ),
        ],
      ),
    );
  }

  void _increment(int i) => setState(() => _items[i].quantity++);
  void _decrement(int i) => setState(() { if (_items[i].quantity > 1) _items[i].quantity--; });
  void _remove(int i) => setState(() => _items.removeAt(i));

  void _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      return;
    }
    final newList = ShoppingList(
      id: widget.list?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      store: _selectedStore,
      items: List<Product>.from(_items),
      status: widget.list?.status ?? ShoppingListStatus.inactive,
      created: widget.list?.created,
      completedAt: widget.list?.completedAt,
    );

    await saveSingleShoppingList(newList);

    ShoppingListSync.needsRefresh = true;
    Navigator.pop(context, newList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? AppLocalizations.of(context)!.editShoppingList : AppLocalizations.of(context)!.newShoppingList),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(AppLocalizations.of(context)!.save, style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.nameOfShoppingList),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Store>(
                value: _selectedStore,
                items: Store.values
                    .map((s) => DropdownMenuItem(value: s, child: Text(storeToDisplayName(s))))
                    .toList(),
                onChanged: (s) => setState(() => _selectedStore = s!),
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.storeTitle),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(AppLocalizations.of(context)!.products, style: TextStyle(fontWeight: FontWeight.bold)),
                  Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addProductDialog,
                    tooltip: AppLocalizations.of(context)!.addProduct,
                  ),
                ],
              ),
              ..._items.map((it) => Card(
                child: ListTile(
                  title: Text(it.name),
                  subtitle: Text('${it.price.toStringAsFixed(2)} € • ${AppLocalizations.of(context)!.amount}: ${it.quantity}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () => _decrement(_items.indexOf(it))),
                      Text(it.quantity.toString()),
                      IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => _increment(_items.indexOf(it))),
                      IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _remove(_items.indexOf(it))),
                    ],
                  ),
                ),
              )),
              if (_items.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(AppLocalizations.of(context)!.noProductsYet),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: Text(AppLocalizations.of(context)!.save),
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              color: Colors.grey.shade200,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.sumLabel,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${_total.toStringAsFixed(2)}€',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
