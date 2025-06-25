import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/product.dart';
import '../models/receipt.dart';
import '../widgets/app_drawer.dart';
import 'camera_ocr_screen.dart';

enum ProductFilter { spendingLimit, mostExpensive, cheapest }

class ShoppingCart extends StatefulWidget {
  final ThemeMode themeMode;
  final void Function(ThemeMode) onThemeChanged;
  final Locale locale;
  final void Function(Locale) onLocaleChanged;
  final VoidCallback? onOpenSettings;

  const ShoppingCart({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    required this.locale,
    required this.onLocaleChanged,
    this.onOpenSettings,
  });

  @override
  State<ShoppingCart> createState() => _ShoppingCartState();
}

class _ShoppingCartState extends State<ShoppingCart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  final List<Product> _products = [];
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
  Set<ProductFilter> _activeFilters = {};
  double? _filterSpendingLimit;

  String filterName(ProductFilter f) {
    switch (f) {
      case ProductFilter.spendingLimit:
        return AppLocalizations.of(context)!.filterSpendingLimit;
      case ProductFilter.mostExpensive:
        return AppLocalizations.of(context)!.mostExpensive;
      case ProductFilter.cheapest:
        return AppLocalizations.of(context)!.cheapest;
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
    setState(() => _products.clear());
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
        setState(() => _products[index].name = name);
      } else {
        setState(() => _products[index].name = code);
      }
    } catch (e) {
      setState(() => _products[index].name = code);
    }
  }

  void _incrementQuantity(int i) => setState(() => _products[i].quantity++);

  void _decrementQuantity(int i) => setState(() {
    if (_products[i].quantity > 1) _products[i].quantity--;
  });

  void _editItem(int i) async {
    final nameController = TextEditingController(text: _products[i].name);
    final priceController = TextEditingController(text: _products[i].price.toStringAsFixed(2));
    String selectedStore = _products[i].store;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.editProductTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.editProductName),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.editProductPrice),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedStore,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.editProductStore),
              items: _stores.where((s) => s != 'Alle').map((s) =>
                  DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (s) => selectedStore = s!,
            ),
          ],
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
                'price': double.tryParse(
                    priceController.text.replaceAll(',', '.').trim()) ?? _products[i].price,
                'store': selectedStore,
              });
            },
            child: Text(AppLocalizations.of(context)!.editProductOk),
          ),
        ],
      ),
    );

    if (result != null && result['name'].isNotEmpty) {
      setState(() {
        _products[i].name = result['name'];
        _products[i].price = result['price'];
        _products[i].store = result['store'];
      });
      final prefs = await SharedPreferences.getInstance();
      final updated = _products.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList('productTemplates', updated);
    }
  }

  double get _total =>
      _products.fold(0.0, (sum, it) => sum + it.price * it.quantity);

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
          child: Text(
            AppLocalizations.of(context)!.saveReceiptTitle,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.saveReceiptNameLabel,
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
                    child: Text(AppLocalizations.of(context)!.saveReceiptCancel),
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
                    child: Text(AppLocalizations.of(context)!.saveReceiptSave),
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
      items: List.of(_products),
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
      SnackBar(content: Text(AppLocalizations.of(context)!.receiptSaved)),
    );
  }

  Future<void> _addProductFromTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    final templates = prefs.getStringList('productTemplates') ?? [];
    if (templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.noSavedProducts)),
      );
      return;
    }

    Product? selected;
    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.selectSavedProduct),
          content: SizedBox(
            width: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: templates.length,
              itemBuilder: (ctx, i) {
                final item = Product.fromJson(jsonDecode(templates[i]));
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text('${item.price.toStringAsFixed(2)} € • ${item.store}'),
                  onTap: () {
                    selected = item;
                    Navigator.of(ctx).pop();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (selected != null) {
      setState(() {
        _products.add(selected!.copyWith());
      });
    }
  }

  Future<void> _loadReceiptList() async {}

  Future<void> _openFilterDialog() async {
    final tmpFilters = Set<ProductFilter>.from(_activeFilters);
    double? tmpLimit = _filterSpendingLimit;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context)!.filterSortTitle,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    value: tmpFilters.contains(ProductFilter.spendingLimit),
                    title: Text(AppLocalizations.of(context)!.filterSpendingLimit),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          tmpFilters.add(ProductFilter.spendingLimit);
                        } else {
                          tmpFilters.remove(ProductFilter.spendingLimit);
                          tmpLimit = null;
                        }
                      });
                    },
                    secondary: tmpFilters.contains(ProductFilter.spendingLimit)
                        ? SizedBox(
                            width: 100,
                            child: TextField(
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(context)!.filterLimitLabel,
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
                  RadioListTile<ProductFilter>(
                    value: ProductFilter.mostExpensive,
                    groupValue: tmpFilters.contains(ProductFilter.mostExpensive)
                        ? ProductFilter.mostExpensive
                        : tmpFilters.contains(ProductFilter.cheapest)
                        ? ProductFilter.cheapest
                        : null,
                    title: Text(AppLocalizations.of(context)!.filterSortMostExpensive),
                    onChanged: (val) {
                      setState(() {
                        tmpFilters.remove(ProductFilter.cheapest);
                        tmpFilters.add(ProductFilter.mostExpensive);
                      });
                    },
                  ),
                  RadioListTile<ProductFilter>(
                    value: ProductFilter.cheapest,
                    groupValue: tmpFilters.contains(ProductFilter.mostExpensive)
                        ? ProductFilter.mostExpensive
                        : tmpFilters.contains(ProductFilter.cheapest)
                        ? ProductFilter.cheapest
                        : null,
                    title: Text(AppLocalizations.of(context)!.filterSortCheapest),
                    onChanged: (val) {
                      setState(() {
                        tmpFilters.remove(ProductFilter.mostExpensive);
                        tmpFilters.add(ProductFilter.cheapest);
                      });
                    },
                  ),
                  RadioListTile<ProductFilter?>(
                    value: null,
                    groupValue: tmpFilters.contains(ProductFilter.mostExpensive)
                        ? ProductFilter.mostExpensive
                        : tmpFilters.contains(ProductFilter.cheapest)
                        ? ProductFilter.cheapest
                        : null,
                    title: Text(AppLocalizations.of(context)!.filterSortNone),
                    onChanged: (_) {
                      setState(() {
                        tmpFilters.remove(ProductFilter.mostExpensive);
                        tmpFilters.remove(ProductFilter.cheapest);
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              child: Text(AppLocalizations.of(context)!.editProductCancel),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: Text(AppLocalizations.of(context)!.filterApply),
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

  Future<void> _saveItemTemplate(Product item) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> templates = prefs.getStringList('productTemplates') ?? [];
    final itemJson = jsonEncode(item.toJson());
    if (!templates.contains(itemJson)) {
      templates.add(itemJson);
      await prefs.setStringList('productTemplates', templates);
    }
  }

  void _openCameraOCRScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CameraOCRScreen(
          onItemDetected: (item) {
            item.store = _selectedStore;
            setState(() {
              _products.add(item);
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
            _activeFilters.add(ProductFilter.spendingLimit);
            _filterSpendingLimit = limit;
          } else {
            _activeFilters.remove(ProductFilter.spendingLimit);
            _filterSpendingLimit = null;
          }
        });
      });
    }

    List<Product> _filteredItems = _products.where((it) {
      // Spending Limit Filter
      if (_activeFilters.contains(ProductFilter.spendingLimit) &&
          _filterSpendingLimit != null) {
        if (it.price * it.quantity > _filterSpendingLimit!) return false;
      }
      return true;
    }).toList();

    if (_activeFilters.contains(ProductFilter.mostExpensive)) {
      _filteredItems.sort(
        (a, b) => (b.price * b.quantity).compareTo(a.price * a.quantity),
      );
    } else if (_activeFilters.contains(ProductFilter.cheapest)) {
      _filteredItems.sort(
        (a, b) => (a.price * a.quantity).compareTo(b.price * b.quantity),
      );
    }

    final bool limitActive =
        _activeFilters.contains(ProductFilter.spendingLimit) &&
        _filterSpendingLimit != null;
    final bool overLimit = limitActive && _total > _filterSpendingLimit!;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.drawerShoppingCart)),
      drawer: AppDrawer(
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
        locale: widget.locale,
        onLocaleChanged: widget.onLocaleChanged,
        onOpenSettings: widget.onOpenSettings,
      ),

      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(AppLocalizations.of(context)!.storeLabel),
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
                    AppLocalizations.of(context)!.clearList,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.highlight_remove_sharp),
                    tooltip: AppLocalizations.of(context)!.clearList,
                    onPressed: _products.isEmpty
                        ? null
                        : () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(AppLocalizations.of(context)!.clearListDialogTitle),
                                content: Text(
                                  AppLocalizations.of(context)!.clearListDialogContent,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text(AppLocalizations.of(context)!.clearListDialogCancel),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text(AppLocalizations.of(context)!.clearListDialogConfirm),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) _clearList();
                          },
                  ),
                  Text(
                    AppLocalizations.of(context)!.filterLabel,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  DropdownButtonHideUnderline(
                    child: IconButton(
                      icon: const Icon(Icons.filter_list),
                      tooltip: AppLocalizations.of(context)!.filterSortTitle,
                      onPressed: _openFilterDialog,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _products.isEmpty
                  ? Center(child: Text(AppLocalizations.of(context)!.noItems))
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
                              children: [
                                Icon(Icons.delete_forever_rounded, color: Colors.white, size: 32),
                                SizedBox(width: 10),
                                Text(
                                  AppLocalizations.of(context)!.remove,
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
                              children: [
                                Icon(Icons.save, color: Colors.white, size: 32),
                                SizedBox(width: 10),
                                Text(
                                  AppLocalizations.of(context)!.saveProduct,
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
                                SnackBar(content: Text(AppLocalizations.of(context)!.productSaved)),
                              );
                              return false;
                            }
                            return false;
                          },
                          onDismissed: (direction) {
                            if (direction == DismissDirection.startToEnd) {
                              setState(() => _products.remove(it));
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
                label: Text(AppLocalizations.of(context)!.saveReceiptNameLabel),
                onPressed: _products.isEmpty ? null : _saveReceipt,
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
              Text(AppLocalizations.of(context)!.sumLabel, style: Theme.of(context).textTheme.titleLarge),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                icon: const Icon(Icons.add_box),
                label: Text(AppLocalizations.of(context)!.addProduct),
                tooltip: AppLocalizations.of(context)!.addFromSaved,
                onPressed: _addProductFromTemplate,
                heroTag: 'fab_add_product',
              ),
              const SizedBox(height: 16),
              FloatingActionButton.extended(
                backgroundColor: Colors.amberAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                icon: const Icon(Icons.camera_alt),
                label: Text(AppLocalizations.of(context)!.scanProductSign),
                tooltip: AppLocalizations.of(context)!.scanProductSign,
                onPressed: _openCameraOCRScreen,
                heroTag: 'fab_scan',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
