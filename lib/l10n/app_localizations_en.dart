// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PriceSnap';

  @override
  String get drawerShoppingCart => 'Shopping Cart';

  @override
  String get drawerShoppingList => 'Shopping List';

  @override
  String get drawerSavedData => 'Saved Data';

  @override
  String get drawerSavedReceipts => 'Saved Receipts';

  @override
  String get drawerSavedProducts => 'Saved Products';

  @override
  String get drawerSettingsHeader => 'Settings';

  @override
  String get drawerSettings => 'Settings';

  @override
  String get drawerAbout => 'About PriceSnap';

  @override
  String drawerVersion(Object version) {
    return 'Version $version';
  }

  @override
  String get storeLabel => 'Store:';

  @override
  String get storeTitle => 'Store';

  @override
  String get clearList => 'Clear List:';

  @override
  String get clearListDialogTitle => 'Clear all items?';

  @override
  String get clearListDialogContent =>
      'Are you sure you want to remove all items from the list?';

  @override
  String get clearListDialogCancel => 'Cancel';

  @override
  String get clearListDialogConfirm => 'Clear';

  @override
  String get filterLabel => 'Filter:';

  @override
  String get filterSortTitle => 'Filter & Sort';

  @override
  String get filterSpendingLimit => 'Spending Limit';

  @override
  String get filterLimitLabel => 'Limit (€)';

  @override
  String get filterSortMostExpensive => 'Sort: Most Expensive';

  @override
  String get filterSortCheapest => 'Sort: Cheapest';

  @override
  String get filterSortNone => 'Sort: None';

  @override
  String get filterApply => 'Apply';

  @override
  String get productExistsTitle => 'Product already exists';

  @override
  String get productExistsDescription =>
      'Do you really want to overwrite the saved product?';

  @override
  String get productOverwrite => 'Overwrite';

  @override
  String get productOverwritten => 'Product overwritten.';

  @override
  String get noItems => 'No items. Scan an item sign.';

  @override
  String get sumLabel => 'Sum:';

  @override
  String get editProductTitle => 'Edit Product';

  @override
  String get editProductName => 'Name';

  @override
  String get editProductPrice => 'Price (€)';

  @override
  String get editProductStore => 'Store';

  @override
  String get editProductCancel => 'Cancel';

  @override
  String get editProductOk => 'OK';

  @override
  String get takePhoto => 'Take a Photo';

  @override
  String get selectPhotoFromGallery => 'Select from Gallery';

  @override
  String get alreadyExists => 'Product already exists!';

  @override
  String get alreadyExistsDescription =>
      'The product already exists in your templates.';

  @override
  String get remove => 'Remove';

  @override
  String get saveProduct => 'Save Product';

  @override
  String get save => 'Save';

  @override
  String get productSaved => 'Product Saved!';

  @override
  String get noSavedProducts => 'No saved products found!';

  @override
  String get saveReceiptTitle => 'Save Receipt';

  @override
  String get saveReceiptNameLabel => 'Save Receipt';

  @override
  String get saveReceiptSave => 'Save';

  @override
  String get saveReceiptCancel => 'Cancel';

  @override
  String get receiptSaved => 'Receipt Saved!';

  @override
  String get selectSavedProduct => 'Select Saved Product';

  @override
  String get addProduct => 'Add Product';

  @override
  String get scanProduct => 'Scan Product';

  @override
  String get addFromSaved => 'Add from saved products';

  @override
  String get scanProductSign => 'Scan product price sign';

  @override
  String get quantity => 'Quantity';

  @override
  String get saved => 'Saved';

  @override
  String get cheapest => 'Cheapest';

  @override
  String get mostExpensive => 'Most Expensive';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get lightMode => 'Light';

  @override
  String get darkMode => 'Dark';

  @override
  String get activeShoppingList => 'Active';

  @override
  String get inactiveShoppingList => 'Inactive';

  @override
  String get doneShoppingList => 'Done';

  @override
  String get amount => 'Amount';

  @override
  String get noShoppingListsYet => 'No shopping lists yet!';

  @override
  String get noProductsYet => 'No products yet!';

  @override
  String get products => 'Products';

  @override
  String get changeStatus => 'Change Status';

  @override
  String get newShoppingList => 'New Shopping List';

  @override
  String get editShoppingList => 'Edit Shopping List';

  @override
  String get nameOfShoppingList => 'Name of Shopping List';

  @override
  String get selectTemplateProduct => 'Select Template';

  @override
  String get total => 'Total';
}
