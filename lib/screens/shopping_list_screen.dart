import 'package:flutter/material.dart';
import 'package:price_snap/l10n/app_localizations_de.dart';
import '../l10n/app_localizations.dart';
import '../services/shopping_list_sync.dart';
import '../storage/shopping_list_storage.dart';
import '../models/shopping_list.dart';
import 'shopping_list_detail_screen.dart';
import '../utils/store_utils.dart';

class ShoppingListsScreen extends StatefulWidget {
  const ShoppingListsScreen({super.key});

  @override
  State<ShoppingListsScreen> createState() => _ShoppingListsScreenState();
}

class _ShoppingListsScreenState extends State<ShoppingListsScreen> {
  List<ShoppingList> _lists = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await loadShoppingLists();
    setState(() => _lists = loaded);
  }

  Future<void> _save() async {
    await saveShoppingLists(_lists);
  }

  void _addNew() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ShoppingListDetailScreen()),
    );
    if (result is ShoppingList) {
      setState(() => _lists.add(result));
      await _save();
    }
    ShoppingListSync.needsRefresh = true;
  }

  void _editList(int idx) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ShoppingListDetailScreen(list: _lists[idx])),
    );
    if (result is ShoppingList) {
      setState(() => _lists[idx] = result);
      await _save();
    }
    ShoppingListSync.needsRefresh = true;
  }

  void _deleteList(int idx) async {
    _lists.removeAt(idx);
    setState(() {});
    await _save();
    ShoppingListSync.needsRefresh = true;
  }

  IconData _storeIcon(String storeName) {
    switch (storeName.toLowerCase()) {
      case 'lidl': return Icons.shopping_basket;
      case 'rewe': return Icons.store;
      case 'aldi': return Icons.shopping_cart;
      case 'edeka': return Icons.local_grocery_store;
      case 'netto': return Icons.local_mall;
      case 'penny': return Icons.storefront;
      default: return Icons.shopping_bag;
    }
  }

  void _cycleStatus(int idx) async {
    setState(() {
      final current = _lists[idx].status;
      ShoppingListStatus next;
      switch (current) {
        case ShoppingListStatus.inactive:
          next = ShoppingListStatus.active;
          for (var i = 0; i < _lists.length; i++) {
            if (i != idx && _lists[i].status == ShoppingListStatus.active) {
              _lists[i].status = ShoppingListStatus.inactive;
            }
          }
          break;
        case ShoppingListStatus.active:
          next = ShoppingListStatus.completed;
          break;
        case ShoppingListStatus.completed:
          next = ShoppingListStatus.inactive;
          break;
      }
      _lists[idx].status = next;
      if (next == ShoppingListStatus.active) {
        for (var i = 0; i < _lists.length; i++) {
          if (i != idx) _lists[i].status = ShoppingListStatus.inactive;
        }
      }
    });
    await _save();
    ShoppingListSync.needsRefresh = true;
  }

  String _statusText(ShoppingListStatus s) {
    switch (s) {
      case ShoppingListStatus.inactive: return AppLocalizations.of(context)!.inactiveShoppingList;
      case ShoppingListStatus.active: return AppLocalizations.of(context)!.activeShoppingList;
      case ShoppingListStatus.completed: return AppLocalizations.of(context)!.doneShoppingList;
    }
  }

  Color _statusColor(ShoppingListStatus status) {
    switch (status) {
      case ShoppingListStatus.inactive: return Colors.grey;
      case ShoppingListStatus.active: return Colors.blue;
      case ShoppingListStatus.completed: return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.drawerShoppingList)),
      body: _lists.isEmpty
          ? Center(child: Text(AppLocalizations.of(context)!.noShoppingListsYet))
          : ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        itemCount: _lists.length,
        itemBuilder: (_, i) {
          final l = _lists[i];
          final storeName = storeToDisplayName(l.store);
          final statusColor = _statusColor(l.status);

          return Dismissible(
            key: ValueKey(l.id),
            direction: DismissDirection.startToEnd,
            background: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 24),
              child: Row(
                children: [
                  Icon(Icons.delete_forever_rounded, color: Colors.red, size: 32),
                  SizedBox(width: 10),
                  Text(AppLocalizations.of(context)!.remove, style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ),
            onDismissed: (_) => _deleteList(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                onTap: () => _editList(i),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  child: Icon(
                    _storeIcon(storeName),
                    color: Theme.of(context).colorScheme.primary,
                    size: 26,
                  ),
                ),
                title: Text(
                  l.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Row(
                    children: [
                      Icon(Icons.storefront, size: 15, color: Colors.grey[600]),
                      const SizedBox(width: 3),
                      Text(storeName, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                      const SizedBox(width: 8),
                      Icon(Icons.list_alt, size: 15, color: Colors.grey[600]),
                      const SizedBox(width: 3),
                      Text('${l.items.length} ${AppLocalizations.of(context)!.products}', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                      const SizedBox(width: 8),
                      Chip(
                        backgroundColor: _statusColor(l.status).withOpacity(0.13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        label: Text(
                          _statusText(l.status),
                          style: TextStyle(
                            color: _statusColor(l.status),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    l.status == ShoppingListStatus.inactive
                        ? Icons.radio_button_unchecked
                        : l.status == ShoppingListStatus.active
                        ? Icons.radio_button_checked
                        : Icons.check_circle,
                    color: _statusColor(l.status),
                  ),
                  tooltip: AppLocalizations.of(context)!.changeStatus,
                  onPressed: () => _cycleStatus(i),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNew,
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.of(context)!.newShoppingList),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
