import 'dart:convert';

import '../utils/store_utils.dart';
import 'product.dart';

class Receipt {
  String name;
  Store store;
  List<Product> items;
  double limit;
  DateTime date;
  double? latitude;
  double? longitude;

  Receipt({
    required this.name,
    required this.store,
    required this.items,
    required this.limit,
    required this.date,
    this.latitude,
    this.longitude,
  });

  double get total => items.fold(0.0, (sum, it) => sum + it.price * it.quantity);

  Map<String, dynamic> toJson() => {
    'name': name,
    'store': storeToJsonString(store),
    'items': items.map((e) => e.toJson()).toList(),
    'limit': limit,
    'date': date.toIso8601String(),
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };

  static Receipt fromJson(Map<String, dynamic> json) => Receipt(
    name: json['name'],
    store: json['store'] != null
        ? storeFromString(json['store'])
        : Store.none,
    items: (json['items'] as List).map((e) => Product.fromJson(e)).toList(),
    limit: (json['limit'] ?? 0.0).toDouble(),
    date: DateTime.parse(json['date']),
    latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
    longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
  );
}
