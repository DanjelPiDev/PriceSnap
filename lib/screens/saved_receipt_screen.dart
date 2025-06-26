import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:price_snap/screens/receipt_detail_screen.dart';
import '../l10n/app_localizations.dart';
import '../models/receipt.dart';
import '../utils/store_utils.dart';

class SavedListScreen extends StatefulWidget {
  const SavedListScreen({super.key});

  @override
  State<SavedListScreen> createState() => _SavedListScreenState();
}

class _SavedListScreenState extends State<SavedListScreen> {
  static const _prefsKey = 'savedReceipts';
  static const _favKey   = 'favoriteReceipts';

  List<Receipt> _receipts = [];
  Set<String> _favorites = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? [];
    _receipts = list.map((e) => Receipt.fromJson(jsonDecode(e))).toList();
    final favList = prefs.getStringList(_favKey) ?? [];
    _favorites = favList.toSet();
    setState(() {});
  }

  Future<void> _saveReceipts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      _receipts.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favKey, _favorites.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.drawerSavedReceipts)),
      body: _receipts.isEmpty
          ? Center(child: Text(AppLocalizations.of(context)!.noShoppingListsYet))
          : ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        itemCount: _receipts.length,
        itemBuilder: (_, i) {
          final rec = _receipts[i];
          final name = rec.name;
          final items = rec.items;
          final isFav = _favorites.contains(name);

          final total = rec.total;
          final hasLimit = rec.limit > 0;
          final date = rec.date;
          final fmtDate = date != null
              ? DateFormat.yMMMd('de').add_Hm().format(date)
              : '-';

          IconData _storeIcon(String? storeName) {
            switch ((storeName ?? '').toLowerCase()) {
              case 'lidl': return Icons.shopping_basket;
              case 'rewe': return Icons.store;
              case 'aldi': return Icons.shopping_cart;
              case 'edeka': return Icons.local_grocery_store;
              case 'netto': return Icons.local_mall;
              case 'penny': return Icons.storefront;
              default: return Icons.shopping_bag;
            }
          }

          return Dismissible(
            key: ValueKey(name + i.toString()),
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
                  Text(
                    AppLocalizations.of(context)!.remove,
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ),
            onDismissed: (_) async {
              setState(() {
                _receipts.removeAt(i);
                _favorites.remove(name);
              });
              await _saveReceipts();
              await _saveFavorites();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              decoration: BoxDecoration(
                color: isFav
                    ? Colors.yellow.shade50
                    : Theme.of(context).colorScheme.surface,
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReceiptDetailScreen(
                        name: name,
                        items: items,
                      ),
                    ),
                  );
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  child: Icon(
                    _storeIcon(rec.store?.name),
                    color: Theme.of(context).colorScheme.primary,
                    size: 26,
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isFav ? Icons.star : Icons.star_border,
                        color: isFav ? Colors.orange : Colors.grey,
                        size: 24,
                      ),
                      tooltip: 'Favorit',
                      onPressed: () async {
                        setState(() {
                          if (isFav) {
                            _favorites.remove(name);
                          } else {
                            _favorites.add(name);
                          }
                        });
                        await _saveFavorites();
                      },
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 15, color: Colors.grey[600]),
                          const SizedBox(width: 3),
                          Text(fmtDate, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                          const SizedBox(width: 8),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.list_alt, size: 15, color: Colors.grey[600]),
                          const SizedBox(width: 3),
                          Text('${items.length} ${AppLocalizations.of(context)!.products}', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                          const SizedBox(width: 3),
                          Chip(
                            backgroundColor: Colors.blue.withOpacity(0.13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            label: Text(
                              '${total.toStringAsFixed(2)}€ / ${hasLimit ? '${rec.limit.toStringAsFixed(2)}€' : '-'}',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                            padding: EdgeInsets.zero,
                          ),
                          if (rec.store != null && rec.store != Store.none)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Chip(
                                backgroundColor: Colors.green.withOpacity(0.13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                label: Text(
                                  storeToDisplayName(rec.store),
                                  style: TextStyle(
                                    color: Colors.green[800],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              ),
            ),
          );
        },
      ),
    );
  }
}
