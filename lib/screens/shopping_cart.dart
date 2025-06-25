import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/item.dart';
import '../models/receipt.dart';
import '../widgets/app_drawer.dart';
import 'camera_ocr_screen.dart';

enum ItemFilter { spendingLimit, mostExpensive, cheapest }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  final List<Item> _items = [];
  final _prefsKey = 'savedReceipts';

  final List<String> _stores = [
    'Lidl',
    'Aldi',
    'Rewe',
    'Edeka',
    'Netto',
    'Penny',
  ];
  String _selectedStore = 'Rewe';

  // Just placeholders...
  static const _storeApi = {
    'Lidl': 'https://api.lidl.com/barcode',
    'Aldi': 'https://api.aldi.com/barcode',
    'Rewe': 'https://api.rewe.com/barcode',
    'Edeka': 'https://api.edeka.com/barcode',
    'Netto': 'https://api.netto.com/barcode',
    'Penny': 'https://api.penny.com/barcode',
  };

  final _limitController = TextEditingController();
  double _limit = 0.0;

  final _barcodeScanner = GoogleMlKit.vision.barcodeScanner();

  bool _pendingShowLimitDialog = false;
  Set<ItemFilter> _activeFilters = {};
  double? _filterSpendingLimit;

  String filterName(ItemFilter f) {
    switch (f) {
      case ItemFilter.spendingLimit:
        return 'Spending Limit';
      case ItemFilter.mostExpensive:
        return 'Most Expensive';
      case ItemFilter.cheapest:
        return 'Cheapest';
    }
  }

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

  void _clearList() {
    setState(() => _items.clear());
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

    if (result == null) return;

    final XFile? image = await picker.pickImage(
      source: result == "camera" ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() {
      _items[index].imageUrl = image.path;
    });
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

  void _editItem(int i) async {
    final nameController = TextEditingController(text: _items[i].name);
    final priceController = TextEditingController(text: _items[i].price.toStringAsFixed(2));
    String selectedStore = _items[i].store;

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
              items: _stores.where((s) => s != 'Alle').map((s) =>
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    onPressed: () =>
                        Navigator.pop(context, controller.text.trim()),
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

    double? lat, lng; // For later...
    final receipt = Receipt(
      name: name,
      store: _selectedStore,
      items: List.of(_items),
      limit: _limit,
      date: DateTime.now(),
      latitude: lat,
      longitude: lng,
    );

    final entry = jsonEncode(receipt.toJson());
    final list = prefs.getStringList('savedReceipts') ?? [];
    list.add(entry);
    await prefs.setStringList(_prefsKey, list);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt Saved!')),
    );
  }

  Future<void> _loadReceiptList() async {}

  Future<void> _openFilterDialog() async {
    final tmpFilters = Set<ItemFilter>.from(_activeFilters);
    double? tmpLimit = _filterSpendingLimit;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Filter & Sort',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    value: tmpFilters.contains(ItemFilter.spendingLimit),
                    title: const Text('Spending Limit'),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          tmpFilters.add(ItemFilter.spendingLimit);
                        } else {
                          tmpFilters.remove(ItemFilter.spendingLimit);
                          tmpLimit = null;
                        }
                      });
                    },
                    secondary: tmpFilters.contains(ItemFilter.spendingLimit)
                        ? SizedBox(
                            width: 100,
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Limit (€)',
                              ),
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              controller: TextEditingController(
                                text: tmpLimit?.toString() ?? '',
                              ),
                              onChanged: (val) {
                                setState(() {
                                  tmpLimit = double.tryParse(
                                    val.replaceAll(',', '.'),
                                  );
                                });
                              },
                            ),
                          )
                        : null,
                  ),
                  const Divider(),
                  RadioListTile<ItemFilter>(
                    value: ItemFilter.mostExpensive,
                    groupValue: tmpFilters.contains(ItemFilter.mostExpensive)
                        ? ItemFilter.mostExpensive
                        : tmpFilters.contains(ItemFilter.cheapest)
                        ? ItemFilter.cheapest
                        : null,
                    title: const Text('Sort: Most Expensive'),
                    onChanged: (val) {
                      setState(() {
                        tmpFilters.remove(ItemFilter.cheapest);
                        tmpFilters.add(ItemFilter.mostExpensive);
                      });
                    },
                  ),
                  RadioListTile<ItemFilter>(
                    value: ItemFilter.cheapest,
                    groupValue: tmpFilters.contains(ItemFilter.mostExpensive)
                        ? ItemFilter.mostExpensive
                        : tmpFilters.contains(ItemFilter.cheapest)
                        ? ItemFilter.cheapest
                        : null,
                    title: const Text('Sort: Cheapest'),
                    onChanged: (val) {
                      setState(() {
                        tmpFilters.remove(ItemFilter.mostExpensive);
                        tmpFilters.add(ItemFilter.cheapest);
                      });
                    },
                  ),
                  RadioListTile<ItemFilter?>(
                    value: null,
                    groupValue: tmpFilters.contains(ItemFilter.mostExpensive)
                        ? ItemFilter.mostExpensive
                        : tmpFilters.contains(ItemFilter.cheapest)
                        ? ItemFilter.cheapest
                        : null,
                    title: const Text('Sort: None'),
                    onChanged: (_) {
                      setState(() {
                        tmpFilters.remove(ItemFilter.mostExpensive);
                        tmpFilters.remove(ItemFilter.cheapest);
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text('Apply'),
              onPressed: () {
                setState(() {
                  _activeFilters = tmpFilters;
                  _filterSpendingLimit = tmpLimit;
                });
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveItemTemplate(Item item) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> templates = prefs.getStringList('itemTemplates') ?? [];
    final itemJson = jsonEncode(item.toJson());
    if (!templates.contains(itemJson)) {
      templates.add(itemJson);
      await prefs.setStringList('itemTemplates', templates);
    }
  }

  void _openCameraOCRScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CameraOCRScreen(
          onItemDetected: (item) {
            item.store = _selectedStore;
            setState(() {
              _items.add(item);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingShowLimitDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final ctrl = TextEditingController(
          text: _filterSpendingLimit?.toString() ?? '',
        );
        final limit = await showDialog<double>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Set Spending Limit'),
            content: TextField(
              controller: ctrl,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Limit (€)'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    double.tryParse(ctrl.text.replaceAll(',', '.')),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
        setState(() {
          _pendingShowLimitDialog = false;
          if (limit != null) {
            _activeFilters.add(ItemFilter.spendingLimit);
            _filterSpendingLimit = limit;
          } else {
            _activeFilters.remove(ItemFilter.spendingLimit);
            _filterSpendingLimit = null;
          }
        });
      });
    }

    List<Item> _filteredItems = _items.where((it) {
      // Spending Limit Filter
      if (_activeFilters.contains(ItemFilter.spendingLimit) &&
          _filterSpendingLimit != null) {
        if (it.price * it.quantity > _filterSpendingLimit!) return false;
      }
      return true;
    }).toList();

    if (_activeFilters.contains(ItemFilter.mostExpensive)) {
      _filteredItems.sort(
        (a, b) => (b.price * b.quantity).compareTo(a.price * a.quantity),
      );
    } else if (_activeFilters.contains(ItemFilter.cheapest)) {
      _filteredItems.sort(
        (a, b) => (a.price * a.quantity).compareTo(b.price * b.quantity),
      );
    }

    final bool limitActive =
        _activeFilters.contains(ItemFilter.spendingLimit) &&
        _filterSpendingLimit != null;
    final bool overLimit = limitActive && _total > _filterSpendingLimit!;

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
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedStore,
                      items: _stores
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (s) {
                        if (s == null) return;
                        setState(() => _selectedStore = s);
                        _saveSelectedStore(s);
                      },
                    ),
                  ),
                  Text(
                    "Clear List:",
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.highlight_remove_sharp),
                    tooltip: "Clear List",
                    onPressed: _items.isEmpty
                        ? null
                        : () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Clear all items?"),
                                content: const Text(
                                  "Are you sure you want to remove all items from the list?",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text("Cancel"),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text("Clear"),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) _clearList();
                          },
                  ),
                  Text(
                    "Filter:",
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  DropdownButtonHideUnderline(
                    child: IconButton(
                      icon: const Icon(Icons.filter_list),
                      tooltip: "Filter & Sort",
                      onPressed: _openFilterDialog,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _items.isEmpty
                  ? const Center(child: Text('No items. Scan an item sign.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 150),
                      itemCount: _filteredItems.length,
                      itemBuilder: (_, i) {
                        final it = _filteredItems[i];

                        final double maxCost = _filteredItems.isEmpty
                            ? 0.0
                            : _filteredItems
                                  .map((it) => it.price * it.quantity)
                                  .reduce((a, b) => a > b ? a : b);

                        return Dismissible(
                          key: ValueKey(it.hashCode),
                          direction: DismissDirection.horizontal,
                          background: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFEA4D5A),
                                  Color(0xFFD7263D),
                                  Color(0xFFB71C1C),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x55B71C1C),
                                  blurRadius: 16,
                                  offset: Offset(4, 2),
                                ),
                              ],
                            ),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 24),
                            child: Row(
                              children: const [
                                Icon(Icons.delete_forever_rounded, color: Colors.white, size: 32),
                                SizedBox(width: 10),
                                Text(
                                  "Remove",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          secondaryBackground: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF34d399), Color(0xFF059669)],
                                begin: Alignment.centerRight,
                                end: Alignment.centerLeft,
                              ),
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: const [
                                Icon(Icons.save, color: Colors.white, size: 32),
                                SizedBox(width: 10),
                                Text(
                                  "Speichern",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              return true;
                            } else if (direction == DismissDirection.endToStart) {
                              await _saveItemTemplate(it);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Item Saved!")),
                              );
                              return false;
                            }
                            return false;
                          },
                          onDismissed: (direction) {
                            if (direction == DismissDirection.startToEnd) {
                              setState(() => _items.remove(it));
                            }
                          },
                          child: Card(
                            color:
                                (overLimit &&
                                    (it.price * it.quantity == maxCost))
                                ? Colors.red.withOpacity(0.15)
                                : null,
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 8,
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
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
                  color: limitActive
                      ? (_total > _filterSpendingLimit!
                            ? Colors.red
                            : Colors.green)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: ScaleTransition(
          scale: _pulse,
          child: FloatingActionButton.extended(
            backgroundColor: Colors.amberAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onPressed: _openCameraOCRScreen,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Scan Product'),
            tooltip: 'Scan product price sign',
          ),
        ),
      ),
    );
  }
}
