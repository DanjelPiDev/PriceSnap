import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'PriceSnap'**
  String get appTitle;

  /// No description provided for @drawerShoppingCart.
  ///
  /// In en, this message translates to:
  /// **'Shopping Cart'**
  String get drawerShoppingCart;

  /// No description provided for @drawerShoppingList.
  ///
  /// In en, this message translates to:
  /// **'Shopping List'**
  String get drawerShoppingList;

  /// No description provided for @drawerSavedData.
  ///
  /// In en, this message translates to:
  /// **'Saved Data'**
  String get drawerSavedData;

  /// No description provided for @drawerSavedReceipts.
  ///
  /// In en, this message translates to:
  /// **'Saved Receipts'**
  String get drawerSavedReceipts;

  /// No description provided for @drawerSavedProducts.
  ///
  /// In en, this message translates to:
  /// **'Saved Products'**
  String get drawerSavedProducts;

  /// No description provided for @drawerSettingsHeader.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get drawerSettingsHeader;

  /// No description provided for @drawerSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get drawerSettings;

  /// No description provided for @drawerAbout.
  ///
  /// In en, this message translates to:
  /// **'About PriceSnap'**
  String get drawerAbout;

  /// No description provided for @drawerVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String drawerVersion(Object version);

  /// No description provided for @storeLabel.
  ///
  /// In en, this message translates to:
  /// **'Store:'**
  String get storeLabel;

  /// No description provided for @storeTitle.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get storeTitle;

  /// No description provided for @clearList.
  ///
  /// In en, this message translates to:
  /// **'Clear List:'**
  String get clearList;

  /// No description provided for @clearListDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all items?'**
  String get clearListDialogTitle;

  /// No description provided for @clearListDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove all items from the list?'**
  String get clearListDialogContent;

  /// No description provided for @clearListDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get clearListDialogCancel;

  /// No description provided for @clearListDialogConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearListDialogConfirm;

  /// No description provided for @filterLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter:'**
  String get filterLabel;

  /// No description provided for @filterSortTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter & Sort'**
  String get filterSortTitle;

  /// No description provided for @filterSpendingLimit.
  ///
  /// In en, this message translates to:
  /// **'Spending Limit'**
  String get filterSpendingLimit;

  /// No description provided for @filterLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Limit (€)'**
  String get filterLimitLabel;

  /// No description provided for @filterSortMostExpensive.
  ///
  /// In en, this message translates to:
  /// **'Sort: Most Expensive'**
  String get filterSortMostExpensive;

  /// No description provided for @filterSortCheapest.
  ///
  /// In en, this message translates to:
  /// **'Sort: Cheapest'**
  String get filterSortCheapest;

  /// No description provided for @filterSortNone.
  ///
  /// In en, this message translates to:
  /// **'Sort: None'**
  String get filterSortNone;

  /// No description provided for @filterApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get filterApply;

  /// No description provided for @productExistsTitle.
  ///
  /// In en, this message translates to:
  /// **'Product already exists'**
  String get productExistsTitle;

  /// No description provided for @productExistsDescription.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to overwrite the saved product?'**
  String get productExistsDescription;

  /// No description provided for @productOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get productOverwrite;

  /// No description provided for @productOverwritten.
  ///
  /// In en, this message translates to:
  /// **'Product overwritten.'**
  String get productOverwritten;

  /// No description provided for @noItems.
  ///
  /// In en, this message translates to:
  /// **'No items. Scan an item sign.'**
  String get noItems;

  /// No description provided for @sumLabel.
  ///
  /// In en, this message translates to:
  /// **'Sum:'**
  String get sumLabel;

  /// No description provided for @editProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Product'**
  String get editProductTitle;

  /// No description provided for @editProductName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get editProductName;

  /// No description provided for @editProductPrice.
  ///
  /// In en, this message translates to:
  /// **'Price (€)'**
  String get editProductPrice;

  /// No description provided for @editProductStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get editProductStore;

  /// No description provided for @editProductCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get editProductCancel;

  /// No description provided for @editProductOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get editProductOk;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a Photo'**
  String get takePhoto;

  /// No description provided for @selectPhotoFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Select from Gallery'**
  String get selectPhotoFromGallery;

  /// No description provided for @alreadyExists.
  ///
  /// In en, this message translates to:
  /// **'Product already exists!'**
  String get alreadyExists;

  /// No description provided for @alreadyExistsDescription.
  ///
  /// In en, this message translates to:
  /// **'The product already exists in your templates.'**
  String get alreadyExistsDescription;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @saveProduct.
  ///
  /// In en, this message translates to:
  /// **'Save Product'**
  String get saveProduct;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @productSaved.
  ///
  /// In en, this message translates to:
  /// **'Product Saved!'**
  String get productSaved;

  /// No description provided for @noSavedProducts.
  ///
  /// In en, this message translates to:
  /// **'No saved products found!'**
  String get noSavedProducts;

  /// No description provided for @saveReceiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Save Receipt'**
  String get saveReceiptTitle;

  /// No description provided for @saveReceiptNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Save Receipt'**
  String get saveReceiptNameLabel;

  /// No description provided for @saveReceiptSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveReceiptSave;

  /// No description provided for @saveReceiptCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get saveReceiptCancel;

  /// No description provided for @receiptSaved.
  ///
  /// In en, this message translates to:
  /// **'Receipt Saved!'**
  String get receiptSaved;

  /// No description provided for @selectSavedProduct.
  ///
  /// In en, this message translates to:
  /// **'Select Saved Product'**
  String get selectSavedProduct;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get addProduct;

  /// No description provided for @scanProduct.
  ///
  /// In en, this message translates to:
  /// **'Scan Product'**
  String get scanProduct;

  /// No description provided for @addFromSaved.
  ///
  /// In en, this message translates to:
  /// **'Add from saved products'**
  String get addFromSaved;

  /// No description provided for @scanProductSign.
  ///
  /// In en, this message translates to:
  /// **'Scan product price sign'**
  String get scanProductSign;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @cheapest.
  ///
  /// In en, this message translates to:
  /// **'Cheapest'**
  String get cheapest;

  /// No description provided for @mostExpensive.
  ///
  /// In en, this message translates to:
  /// **'Most Expensive'**
  String get mostExpensive;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightMode;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkMode;

  /// No description provided for @activeShoppingList.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeShoppingList;

  /// No description provided for @inactiveShoppingList.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactiveShoppingList;

  /// No description provided for @doneShoppingList.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneShoppingList;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @noShoppingListsYet.
  ///
  /// In en, this message translates to:
  /// **'No shopping lists yet!'**
  String get noShoppingListsYet;

  /// No description provided for @noProductsYet.
  ///
  /// In en, this message translates to:
  /// **'No products yet!'**
  String get noProductsYet;

  /// No description provided for @products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// No description provided for @changeStatus.
  ///
  /// In en, this message translates to:
  /// **'Change Status'**
  String get changeStatus;

  /// No description provided for @newShoppingList.
  ///
  /// In en, this message translates to:
  /// **'New Shopping List'**
  String get newShoppingList;

  /// No description provided for @editShoppingList.
  ///
  /// In en, this message translates to:
  /// **'Edit Shopping List'**
  String get editShoppingList;

  /// No description provided for @nameOfShoppingList.
  ///
  /// In en, this message translates to:
  /// **'Name of Shopping List'**
  String get nameOfShoppingList;

  /// No description provided for @selectTemplateProduct.
  ///
  /// In en, this message translates to:
  /// **'Select Template'**
  String get selectTemplateProduct;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
