enum Store {
  none,
  rewe,
  lidl,
  aldi,
  edeka,
  netto,
  penny,
}

String storeToDisplayName(Store store) {
  switch (store) {
    case Store.rewe: return 'Rewe';
    case Store.lidl: return 'Lidl';
    case Store.aldi: return 'Aldi';
    case Store.edeka: return 'Edeka';
    case Store.netto: return 'Netto';
    case Store.penny: return 'Penny';
    case Store.none: return 'No Store';
  }
}

String storeToJsonString(Store? store) {
  return store?.toString().split('.').last ?? 'none';
}

Store storeFromString(String s) {
  return Store.values.firstWhere(
          (e) => e.toString().split('.').last.toLowerCase() == s.toLowerCase(),
      orElse: () => Store.none);
}
