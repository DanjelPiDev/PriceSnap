import 'package:flutter/material.dart';
import '../models/item.dart';

class ReceiptDetailScreen extends StatefulWidget {
  final String name;
  final List<Item> items;

  const ReceiptDetailScreen({
    super.key,
    required this.name,
    required this.items,
  });

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  late List<Item> _items;
  final Set<int> _favorites = {};

  @override
  void initState() {
    super.initState();
    _items = List<Item>.from(widget.items);
  }

  double get total =>
      _items.fold(0.0, (sum, it) => sum + it.price * it.quantity);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),

      // BODY mit SafeArea, bottomPadding in ListView
      body: SafeArea(
        bottom: false,  // bottomNavigationBar kümmert sich um SafeArea
        child: Padding(
          padding: const EdgeInsets.only(bottom: 80), // genug Platz für die Leiste
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
      ),

      // summary in bottomNavigationBar mit SafeArea
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.grey.shade200,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sum:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
