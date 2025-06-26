import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:price_snap/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import '../models/product.dart';

class ReceiptDetailScreen extends StatefulWidget {
  final String name;
  final List<Product> items;

  const ReceiptDetailScreen({
    super.key,
    required this.name,
    required this.items,
  });

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  late List<Product> _items;
  final Set<int> _favorites = {};

  @override
  void initState() {
    super.initState();
    _items = List<Product>.from(widget.items);
  }

  Future<void> _exportAsCSV() async {
    final buffer = StringBuffer();
    buffer.writeln('${AppLocalizations.of(context)!.name};${AppLocalizations.of(context)!.amount};${AppLocalizations.of(context)!.price};${AppLocalizations.of(context)!.sumLabel}');
    for (final p in _items) {
      buffer.writeln(
          '${p.name.replaceAll(';', ',')};${p.quantity};${p.price.toStringAsFixed(2)};${(p.price * p.quantity).toStringAsFixed(2)}'
      );
    }
    buffer.writeln(';;${AppLocalizations.of(context)!.sumLabel};${total.toStringAsFixed(2)}');

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${widget.name.replaceAll(' ', '_')}.csv');
    await file.writeAsString(buffer.toString(), flush: true);

    await Share.shareXFiles([XFile(file.path)], text: 'CSV-Export: ${widget.name}');
  }

  double get total =>
      _items.fold(0.0, (sum, it) => sum + it.price * it.quantity);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),

      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Export as CSV'),
                  onPressed: _exportAsCSV,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (ctx, i) {
                  final it = _items[i];
                  final isFav = _favorites.contains(i);

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: isFav ? Colors.yellow.shade100 : null,
                    child: ListTile(
                      title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${it.quantity} × ${it.price.toStringAsFixed(2)}€'),
                      trailing: Text(
                        '${(it.price * it.quantity).toStringAsFixed(2)}€',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        )
      ),

      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.grey.shade200,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context)!.sumLabel, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                '${total.toStringAsFixed(2)}€',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
