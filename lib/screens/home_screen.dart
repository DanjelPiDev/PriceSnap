import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/item.dart';
import '../services/rewe/rewe_product_match.dart';
import '../widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  // Services (Just Rewe for now)
  final ReweService _rewe = ReweService();

  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  final List<Item> _items = [];
  final _prefsKey = 'savedReceipts';

  final List<String> _stores = ['Lidl', 'Aldi', 'Rewe', 'Edeka', 'Netto', 'Penny'];
  String _selectedStore = 'Rewe';
  static const _storeApi = {
    'Lidl' : 'https://api.lidl.com/barcode',
    'Aldi' : 'https://api.aldi.com/barcode',
    'Rewe' : 'https://api.rewe.com/barcode',
    'Edeka': 'https://api.edeka.com/barcode',
    'Netto': 'https://api.netto.com/barcode',
    'Penny': 'https://api.penny.com/barcode',
  };

  final _limitController = TextEditingController();
  double _limit = 0.0;

  final _barcodeScanner = GoogleMlKit.vision.barcodeScanner();

  @override
  void dispose() {
    _ctrl.dispose();
    _limitController.dispose();
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadReceiptList();
    _loadSelectedStore();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 1.0, end: 1.1).animate(_ctrl);
  }

  double get _maxItemCost {
    if (_items.isEmpty) return 0.0;
    return _items
        .map((it) => it.price * it.quantity)
        .reduce((a, b) => a > b ? a : b);
  }

  Future<void> pickAndRecognizeText() async {
    final pickedImage = await ImagePicker().pickImage(
      source: ImageSource.camera,
    );
    if (pickedImage == null) return;

    final inputImage = InputImage.fromFilePath(pickedImage.path);
    final textRecognizer = GoogleMlKit.vision.textRecognizer();
    final recognized = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    final priceLineRegEx = RegExp(r'^€?\s*\d+(?:[.,]\d{2})?$');
    final weightRegEx   = RegExp(r'^\d+[.,]?\d*\s*(g|kg|ml|l)\b', caseSensitive: false);

    final linesList = recognized.blocks
        .expand((b) => b.lines)
        .map((l) => l.text.trim())
        .toList();

    print("_____________");
    print(linesList);

    List<String> nameBuffer = [];

    for (var line in linesList) {
      final unitPriceRegEx = RegExp(r'^(\d+[.,]?\d*)\s*(g|kg|ml|l)\s*=\s*(\d+[.,]\d{2})$', caseSensitive: false);
      final weightOnlyRegEx = RegExp(r'^\d+[.,]?\d*\s*(g|kg|ml|l)\b', caseSensitive: false);

      if (weightRegEx.hasMatch(line) || line.contains('=') || line.toLowerCase().startsWith('kg')) {
        continue;
      }

      var upMatch = unitPriceRegEx.firstMatch(line);
      if (upMatch != null) {

        final upRaw      = upMatch.group(3)!.replaceAll(',', '.');
        final unitPrice  = double.parse(upRaw);

        setState(() {
          _items.last.unitPrice = unitPrice;
        });
        continue;
      }

      if (weightOnlyRegEx.hasMatch(line)) continue;

      if (priceLineRegEx.hasMatch(line)) {
        var raw = line.replaceAll(RegExp(r'[^0-9.,]'), '');

        if (!raw.contains(RegExp(r'[.,]')) && raw.length > 2) {
          raw = '${raw.substring(0, raw.length - 2)}.${raw.substring(raw.length - 2)}';
        }
        raw = raw.replaceAll(',', '.');
        final price = double.parse(raw);

        if (nameBuffer.isNotEmpty) {
          final name = nameBuffer.join(' ');
          setState(() {
            _items.add(Item(name: name, price: price));
          });
          nameBuffer.clear();

          final match = await _rewe.matchProduct(name);

          if (match != null) {
            setState(() {
              final idx = _items.length - 1;
              _items[idx].name = match.name;
              _items[idx].imageUrl = match.imageUrl;
            });
          }
        }
      }
      else if (RegExp(r'[A-Za-zÄÖÜäöüß]').hasMatch(line)) {
        nameBuffer.add(line);
      }
    }
  }

  Future<void> scanBarcode(int index) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked == null) return;

    final input = InputImage.fromFilePath(picked.path);
    final barcodes = await _barcodeScanner.processImage(input);

    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue ?? '';
    final apiUrl = _storeApi[_selectedStore]!;
    try {
      final resp = await http.get(Uri.parse('$apiUrl?barcode=$code'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final name = data['productName'] ?? data['name'] ?? code;
        setState(() => _items[index].name = name);
      } else {
        setState(() => _items[index].name = code);
      }
    } catch (e) {
      setState(() => _items[index].name = code);
    }
  }


  void _incrementQuantity(int i) => setState(() => _items[i].quantity++);

  void _decrementQuantity(int i) => setState(() {
    if (_items[i].quantity > 1) _items[i].quantity--;
  });

  void _removeItem(int i) => setState(() => _items.removeAt(i));

  void _editName(int i) async {
    final controller = TextEditingController(text: _items[i].name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) setState(() => _items[i].name = name);
  }

  double get _total =>
      _items.fold(0.0, (sum, it) => sum + it.price * it.quantity);

  Future<void> _loadSelectedStore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('preferredStore');
    if (saved != null && _stores.contains(saved)) {
      setState(() => _selectedStore = saved);
    }
  }

  Future<void> _saveSelectedStore(String store) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferredStore', store);
  }

  Future<void> _saveReceipt() async {
    final prefs = await SharedPreferences.getInstance();
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Center(
          child: const Text(
            'Save Receipt',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Enter a name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context, controller.text.trim()),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    final entry = jsonEncode({
      'name': name,
      'items': _items.map((e) => e.toJson()).toList(),
      'limit': _limit,
      'date': DateTime.now().toIso8601String(),
    });
    final list = prefs.getStringList(_prefsKey) ?? [];
    list.add(entry);
    await prefs.setStringList(_prefsKey, list);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt Saved!')),
    );
  }

  Future<void> _loadReceiptList() async {
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shopping Cart')),
      drawer: const AppDrawer(),

      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text('Store:'),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _selectedStore,
                    items: _stores.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s),
                    )).toList(),
                    onChanged: (s) {
                      if (s == null) return;
                      setState(() => _selectedStore = s);
                      _saveSelectedStore(s);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _items.isEmpty
                  ? const Center(
                child: Text('No items. Scan an item sign.'),
              )
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 150),
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final it = _items[i];
                  final cost = it.price * it.quantity;
                  final over = _limit > 0 && _total > _limit;
                  final isMostExpensive = cost == _maxItemCost;

                  return Dismissible(
                    key: ValueKey(it.hashCode),
                    direction: DismissDirection.horizontal,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    secondaryBackground: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => setState(() => _items.removeAt(i)),
                    child: Card(
                      color: (over && isMostExpensive)
                          ? Colors.red.withOpacity(0.15)
                          : null,
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: it.imageUrl != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: it.imageUrl!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const SizedBox(
                              width: 40, height: 40,
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                            errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported),
                          ),
                        )
                            : const Icon(Icons.image, size: 40, color: Colors.grey),
                        title: GestureDetector(
                          onTap: () => _editName(i),
                          child: Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        subtitle: Text('${it.price.toStringAsFixed(2)}€'),
                        trailing: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: () => _decrementQuantity(i),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                              Text(it.quantity.toString()),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () => _incrementQuantity(i),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                              IconButton(
                                icon: const Icon(Icons.qr_code_scanner),
                                onPressed: () => scanBarcode(i),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save Receipt'),
                onPressed: _items.isEmpty ? null : _saveReceipt,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _limitController,
                decoration: const InputDecoration(
                  labelText: 'Spending limit (€)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (val) {
                  setState(() {
                    _limit = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                  });
                },
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.grey.shade200,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sum:', style: Theme.of(context).textTheme.titleLarge),
              Text(
                '${_total.toStringAsFixed(2)}€',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _limit > 0
                      ? (_total > _limit ? Colors.red : Colors.green)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      floatingActionButton: ScaleTransition(
        scale: _pulse,
        child: FloatingActionButton.extended(
          backgroundColor: Colors.amberAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onPressed: pickAndRecognizeText,
          icon: const Icon(Icons.camera_alt),
          label: const Text('Scan'),
          tooltip: 'Scan product price sign',
        ),
      ),
    );
  }
}