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
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _receipts.length,
        itemBuilder: (ctx, i) {
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

          return Dismissible(
            key: ValueKey(name + i.toString()),
            direction: DismissDirection.horizontal,
            background: Container(color: Colors.red, alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            secondaryBackground: Container(color: Colors.red, alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) async {
              setState(() {
                _receipts.removeAt(i);
                _favorites.remove(name);
              });
              await _saveReceipts();
              await _saveFavorites();
            },
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              color: isFav ? Colors.yellow.shade50 : null,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReceiptDetailScreen(name: name, items: items),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.star : Icons.star_border,
                          color: isFav ? Colors.orange : Colors.grey,
                        ),
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

                      const SizedBox(width: 8),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  fmtDate,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Chip(
                                  label: Text('${items.length} Items'),
                                  visualDensity: VisualDensity.compact,
                                ),
                                Chip(
                                  label: Text(
                                    '${total.toStringAsFixed(2)}€ / ${hasLimit ? '${rec.limit.toStringAsFixed(2)}€' : '-'}',
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                if (rec.store != null && rec.store != Store.none)
                                  Chip(
                                    label: Text(storeToDisplayName(rec.store)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
