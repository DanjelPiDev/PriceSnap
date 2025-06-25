import 'item.dart';

class Receipt {
  String name;
  String store;
  List<Item> items;
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
    'store': store,
    'items': items.map((e) => e.toJson()).toList(),
    'limit': limit,
    'date': date.toIso8601String(),
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };

  static Receipt fromJson(Map<String, dynamic> json) => Receipt(
    name: json['name'],
    store: json['store'],
    items: (json['items'] as List).map((e) => Item.fromJson(e)).toList(),
    limit: (json['limit'] ?? 0.0).toDouble(),
    date: DateTime.parse(json['date']),
    latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
    longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
  );
}
