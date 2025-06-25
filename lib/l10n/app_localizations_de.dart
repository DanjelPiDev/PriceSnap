// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'PriceSnap';

  @override
  String get drawerShoppingCart => 'Einkaufswagen';

  @override
  String get drawerShoppingList => 'Einkaufsliste';

  @override
  String get drawerSavedData => 'Gespeicherte Daten';

  @override
  String get drawerSavedReceipts => 'Gespeicherte Kassenbons';

  @override
  String get drawerSavedProducts => 'Gespeicherte Produkte';

  @override
  String get drawerSettingsHeader => 'Einstellungen';

  @override
  String get drawerSettings => 'Einstellungen';

  @override
  String get drawerAbout => 'Über PriceSnap';

  @override
  String drawerVersion(Object version) {
    return 'Version $version';
  }

  @override
  String get storeLabel => 'Markt:';

  @override
  String get clearList => 'Liste leeren:';

  @override
  String get clearListDialogTitle => 'Alle Artikel entfernen?';

  @override
  String get clearListDialogContent =>
      'Willst du wirklich alle Artikel aus der Liste entfernen?';

  @override
  String get clearListDialogCancel => 'Abbrechen';

  @override
  String get clearListDialogConfirm => 'Leeren';

  @override
  String get filterLabel => 'Filter:';

  @override
  String get filterSortTitle => 'Filtern & Sortieren';

  @override
  String get filterSpendingLimit => 'Ausgabenlimit';

  @override
  String get filterLimitLabel => 'Limit (€)';

  @override
  String get filterSortMostExpensive => 'Sortieren: Teuerste';

  @override
  String get filterSortCheapest => 'Sortieren: Günstigste';

  @override
  String get filterSortNone => 'Sortieren: Keine';

  @override
  String get filterApply => 'Anwenden';

  @override
  String get noItems => 'Keine Artikel. Scanne ein Preisschild.';

  @override
  String get sumLabel => 'Summe:';

  @override
  String get editProductTitle => 'Produkt bearbeiten';

  @override
  String get editProductName => 'Name';

  @override
  String get editProductPrice => 'Preis (€)';

  @override
  String get editProductStore => 'Markt';

  @override
  String get editProductCancel => 'Abbrechen';

  @override
  String get editProductOk => 'OK';

  @override
  String get takePhoto => 'Foto aufnehmen';

  @override
  String get selectPhotoFromGallery => 'Foto aus Galerie auswählen';

  @override
  String get alreadyExists => 'Produkt existiert bereits!';

  @override
  String get alreadyExistsDescription =>
      'Das Produkt existiert bereits in deinen Vorlagen.';

  @override
  String get remove => 'Entfernen';

  @override
  String get saveProduct => 'Produkt speichern';

  @override
  String get productSaved => 'Produkt gespeichert!';

  @override
  String get noSavedProducts => 'Keine gespeicherten Produkte gefunden!';

  @override
  String get saveReceiptTitle => 'Kassenbon speichern';

  @override
  String get saveReceiptNameLabel => 'Kassenbon speichern';

  @override
  String get saveReceiptSave => 'Speichern';

  @override
  String get saveReceiptCancel => 'Abbrechen';

  @override
  String get receiptSaved => 'Kassenbon gespeichert!';

  @override
  String get selectSavedProduct => 'Gespeichertes Produkt auswählen';

  @override
  String get addProduct => 'Produkt hinzufügen';

  @override
  String get scanProduct => 'Produkt scannen';

  @override
  String get addFromSaved => 'Aus gespeicherten Produkten';

  @override
  String get scanProductSign => 'Preisschild scannen';

  @override
  String get quantity => 'Menge';

  @override
  String get saved => 'Gespeichert';

  @override
  String get cheapest => 'Günstigste';

  @override
  String get mostExpensive => 'Teuerste';

  @override
  String get language => 'Sprache';

  @override
  String get theme => 'Theme';

  @override
  String get lightMode => 'Hell';

  @override
  String get darkMode => 'Dunkel';
}
