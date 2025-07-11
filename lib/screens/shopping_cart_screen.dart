import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:price_snap/screens/shopping_list_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/product.dart';
import '../models/receipt.dart';
import '../models/shopping_list.dart';
import '../services/shopping_list_sync.dart';
import '../storage/shopping_list_storage.dart';
import '../utils/update_data.dart';
import '../widgets/app_drawer.dart';
import '../utils/store_utils.dart';
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
    with SingleTickerProviderStateMixin, RouteAware {
  // Route observer to track navigation changes (If the user changes the shopping list etc.)
  RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  final List<Product> _products = [];
  final _prefsKey = 'savedReceipts';

  final List<Store> _stores = [
    Store.none,
    Store.lidl,
    Store.aldi,
    Store.rewe,
    Store.edeka,
    Store.netto,
    Store.penny,
  ];

  Store _selectedStore = Store.none;
  bool _shoppingListExpanded = false;

  ShoppingList? _activeList;
  Map<String, bool> _checked = {};

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ShoppingListSync.needsRefresh) {
      ShoppingListSync.needsRefresh = false;
      _loadActiveList();
    }
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void didPopNext() {
    _loadActiveList();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
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
    _loadActiveList();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 1.0, end: 1.1).animate(_ctrl);
  }

  void _clearList() {
    setState(() => _products.clear());
  }

  Future<void> _loadActiveList() async {
    final list = await getActiveShoppingList();
    setState(() {
      _activeList = list;
      _checked = {for (var p in list?.items ?? []) p.id: false};
    });
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
    final apiUrl = _storeApi[storeToJsonString(_selectedStore)]!;
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

  void _editProduct(String productId) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index == -1) return;

    final current = _products[index];

    final nameController = TextEditingController(text: current.name);
    final priceController = TextEditingController(
      text: current.price.toStringAsFixed(2),
    );

    Store selectedStore = current.store ?? Store.rewe;
    if (!_stores.contains(selectedStore)) {
      selectedStore = _stores.first;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.editProductTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.editProductName,
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.editProductPrice,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Store>(
              value: selectedStore,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.editProductStore,
              ),
              items: _stores
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(storeToDisplayName(s)),
                    ),
                  )
                  .toList(),
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
                'price':
                    double.tryParse(
                      priceController.text.replaceAll(',', '.').trim(),
                    ) ??
                    current.price,
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
        _products[index].name = result['name'];
        _products[index].price = result['price'];
        _products[index].store = result['store'];
      });
      final prefs = await SharedPreferences.getInstance();
      final updated = _products.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList('productTemplates', updated);
      await updateProductEverywhere(_products[index]);
      await _loadActiveList();
    }
  }

  double get _total =>
      _products.fold(0.0, (sum, it) => sum + it.price * it.quantity);

  Future<void> _loadSelectedStore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('preferredStore');
    if (saved != null) {
      setState(() => _selectedStore = storeFromString(saved));
    }
  }

  Future<void> _saveSelectedStore(Store store) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferredStore', storeToJsonString(store));
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
                    child: Text(
                      AppLocalizations.of(context)!.saveReceiptCancel,
                    ),
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
    final cartItems = List<Product>.of(_products);
    final checkedItems =
        _activeList?.items
            .where((item) => _checked[item.id] == true)
            .toList() ??
        [];

    final all = <String, Product>{};

    for (final p in cartItems) {
      all[p.id] = p.copyWith();
    }
    for (final p in checkedItems) {
      if (all.containsKey(p.id)) {
        final orig = all[p.id]!;
        all[p.id] = orig.copyWith(quantity: orig.quantity + p.quantity);
      } else {
        all[p.id] = p.copyWith();
      }
    }
    final mergedItems = all.values.toList();

    final receipt = Receipt(
      name: name,
      store: _selectedStore,
      items: mergedItems,
      limit: _limit,
      date: DateTime.now(),
      latitude: lat,
      longitude: lng,
    );

    final entry = jsonEncode(receipt.toJson());
    final list = prefs.getStringList('savedReceipts') ?? [];
    list.add(entry);
    await prefs.setStringList(_prefsKey, list);
  }

  Future<void> _addProductFromTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    final templates = prefs.getStringList('productTemplates') ?? [];
    if (templates.isEmpty) {
      return;
    }

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.selectSavedProduct),
          content: SizedBox(
            width: 350,
            height: 400,
            child: StatefulBuilder(
              builder: (dialogCtx, setDialogState) {
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: templates.length,
                  itemBuilder: (ctx, i) {
                    final item = Product.fromJson(jsonDecode(templates[i]));

                    final cartIndex = _products.indexWhere(
                      (p) =>
                          p.name == item.name &&
                          p.price == item.price &&
                          p.store == item.store,
                    );

                    final alreadyInCart = cartIndex != -1;
                    final quantity = alreadyInCart
                        ? _products[cartIndex].quantity
                        : 0;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (alreadyInCart) {
                            _products[cartIndex].quantity++;
                          } else {
                            _products.add(item.copyWith(quantity: 1));
                          }
                        });
                        setDialogState(() {});
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 2,
                        ),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading:
                              item.imageUrl != null && item.imageUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(item.imageUrl!),
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Icon(Icons.image, color: Colors.grey),
                                  ),
                                )
                              : Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.image,
                                    size: 24,
                                    color: Colors.grey,
                                  ),
                                ),
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${item.price.toStringAsFixed(2)}€ • ${item.store.name}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.add_circle_outline,
                                color: Colors.blueAccent,
                              ),
                              if (quantity > 0)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'x$quantity',
                                      style: const TextStyle(
                                        color: Colors.blueAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context)!.editProductCancel),
            ),
          ],
        );
      },
    );
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
                    title: Text(
                      AppLocalizations.of(context)!.filterSpendingLimit,
                    ),
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
                                labelText: AppLocalizations.of(
                                  context,
                                )!.filterLimitLabel,
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
                    title: Text(
                      AppLocalizations.of(context)!.filterSortMostExpensive,
                    ),
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
                    title: Text(
                      AppLocalizations.of(context)!.filterSortCheapest,
                    ),
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

  Future<void> _editActiveShoppingList() async {
    if (_activeList == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShoppingListDetailScreen(list: _activeList!),
      ),
    );
    if (result is ShoppingList) {
      await _loadActiveList();
    }
  }

  double get _checkedTotal {
    if (_activeList == null) return 0.0;
    double sum = 0.0;
    for (final item in _activeList!.items) {
      if (_checked[item.id] == true) {
        sum += item.price * item.quantity;
      }
    }
    return sum;
  }

  Future<void> _saveItemTemplate(Product item) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> templates =
        prefs.getStringList('productTemplates') ?? [];

    final itemToSave = item.copyWith(quantity: 1);

    final List<Product> savedProducts = templates
        .map((e) => Product.fromJson(jsonDecode(e)))
        .toList();

    final index = savedProducts.indexWhere((p) => p.id == item.id);

    if (index != -1) {
      if (mounted) {
        final overwrite = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.productExistsTitle),
            content: Text(
              AppLocalizations.of(context)!.productExistsDescription,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(AppLocalizations.of(context)!.productOverwrite),
              ),
            ],
          ),
        );
        if (overwrite == true) {
          templates[index] = jsonEncode(itemToSave.toJson());
          await prefs.setStringList('productTemplates', templates);
        }
        return;
      }
    } else {
      templates.add(jsonEncode(itemToSave.toJson()));
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
          selectedStore: _selectedStore,
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
            title: Text(AppLocalizations.of(context)!.filterSpendingLimit),
            content: TextField(
              controller: ctrl,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.filterLimitLabel,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppLocalizations.of(context)!.clearListDialogCancel,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    double.tryParse(ctrl.text.replaceAll(',', '.')),
                  );
                },
                child: Text(AppLocalizations.of(context)!.editProductOk),
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
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.drawerShoppingCart),
      ),
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
            if (_activeList != null) ...[
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${AppLocalizations.of(context)!.drawerShoppingList} (${storeToDisplayName(_activeList!.store)})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: AppLocalizations.of(context)!.editProductTitle,
                            onPressed: _editActiveShoppingList,
                            splashRadius: 22,
                          ),
                          IconButton(
                            icon: Icon(
                              _shoppingListExpanded ? Icons.expand_less : Icons.expand_more,
                            ),
                            tooltip: _shoppingListExpanded
                                ? AppLocalizations.of(context)!.editProductCancel
                                : AppLocalizations.of(context)!.more,
                            onPressed: () {
                              setState(() {
                                _shoppingListExpanded = !_shoppingListExpanded;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _shoppingListExpanded
                          ? SizedBox(
                        height: 260,
                        child: Scrollbar(
                          child: ListView(
                            children: _activeList!.items.map(
                                  (p) => CheckboxListTile(
                                value: _checked[p.id] ?? false,
                                title: Text(
                                  '${p.quantity}x ${p.name}   ${p.price.toStringAsFixed(2)}€',
                                ),
                                controlAffinity: ListTileControlAffinity.leading,
                                onChanged: (v) {
                                  setState(() {
                                    _checked[p.id] = v ?? false;
                                  });
                                },
                              ),
                            ).toList(),
                          ),
                        ),
                      )
                          : _activeList!.items.isEmpty
                          ? Text(AppLocalizations.of(context)!.noProductsYet)
                          : SizedBox(
                        height: 72 * (_activeList!.items.length > 3 ? 3 : _activeList!.items.length).toDouble(),
                        child: ListView.builder(
                          itemCount: _activeList!.items.length > 3 ? 3 : _activeList!.items.length,
                          itemBuilder: (ctx, i) {
                            final p = _activeList!.items[i];
                            return CheckboxListTile(
                              value: _checked[p.id] ?? false,
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${p.quantity}x ${p.name}   ${p.price.toStringAsFixed(2)}€',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (p.discount == true)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 6.0),
                                      child: Chip(
                                        backgroundColor: Colors.orange.withOpacity(0.13),
                                        label: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.percent, size: 15, color: Colors.orange),
                                            SizedBox(width: 2),
                                            Text(
                                              AppLocalizations.of(context)?.discount ?? "Angebot",
                                              style: TextStyle(
                                                color: Colors.orange,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        labelPadding: const EdgeInsets.symmetric(horizontal: 5),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                ],
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (v) {
                                setState(() {
                                  _checked[p.id] = v ?? false;
                                });
                              },
                            );
                          },
                        ),
                      ),
                      if (!_shoppingListExpanded && (_activeList!.items.length > 3))
                        Center(
                          child: Text(
                            '(${AppLocalizations.of(context)!.more}...)',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '✔ ${_checked.values.where((v) => v).length}/${_activeList!.items.length} ${AppLocalizations.of(context)!.doneShoppingList}',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${AppLocalizations.of(context)!.sumLabel} ${_activeList!.items.fold<double>(0.0, (sum, it) => sum + it.price * it.quantity).toStringAsFixed(2)}€',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(AppLocalizations.of(context)!.storeLabel),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<Store>(
                      value: _selectedStore,
                      items: _stores
                          .map(
                            (s) => DropdownMenuItem<Store>(
                              value: s,
                              child: Text(storeToDisplayName(s)),
                            ),
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
                                title: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.clearListDialogTitle,
                                ),
                                content: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.clearListDialogContent,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.clearListDialogCancel,
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.clearListDialogConfirm,
                                    ),
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
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 24),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_forever_rounded,
                                  color: Colors.red,
                                  size: 32,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  AppLocalizations.of(context)!.remove,
                                  style: TextStyle(
                                    color: Colors.red,
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
                                colors: [Color(0xa034d399), Color(0x91059669)],
                                begin: Alignment.centerRight,
                                end: Alignment.centerLeft,
                              ),
                              borderRadius: BorderRadius.all(
                                Radius.circular(18),
                              ),
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
                            } else if (direction ==
                                DismissDirection.endToStart) {
                              await _saveItemTemplate(it);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.of(context)!.productSaved,
                                  ),
                                ),
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey[400]!,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.image,
                                          size: 24,
                                          color: Colors.grey,
                                        ),
                                      ),
                              ),
                              title: GestureDetector(
                                onTap: () => _editProduct(it.id),
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
                                    if (it.discount)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8.0),
                                        child: Chip(
                                          backgroundColor: Colors.orange.withOpacity(0.13),
                                          label: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.percent, size: 15, color: Colors.orange),
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
                                          labelPadding: const EdgeInsets.symmetric(horizontal: 5),
                                          padding: EdgeInsets.zero,
                                        ),
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
              Text(
                '${AppLocalizations.of(context)!.drawerShoppingCart}: ${_total.toStringAsFixed(2)}€',
              ),
              Text(
                '${AppLocalizations.of(context)!.total}: ${(_total + _checkedTotal).toStringAsFixed(2)}€',
              ),
            ],
          ),
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 40.0),
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
