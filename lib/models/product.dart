import 'package:uuid/uuid.dart';

import '../utils/store_utils.dart';


class Product {
  final String id;
  String name;
  double price;
  int quantity;
  double? unitPrice;
  String? imageUrl;
  Store store;
  bool discount = false;

  Product({
    String? id,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.unitPrice,
    this.imageUrl,
    required this.store,
    this.discount = false,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'imageUrl': imageUrl,
    'store': store != null ? store.toString().split('.').last : null,
    'discount': discount,
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'],
    name: json['name'],
    price: json['price'],
    quantity: json['quantity'],
    unitPrice: (json['unitPrice'] as num?)?.toDouble(),
    imageUrl: json['imageUrl'] as String?,
    store: Store.values.firstWhere(
      (s) => s.toString() == 'Store.${json['store']}',
      orElse: () => Store.none,
    ),
    discount: json['discount'] ?? false,
  );

  Product copyWith({
    String? id,
    String? name,
    double? price,
    int? quantity,
    double? unitPrice,
    String? imageUrl,
    Store? store,
    bool? discount,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      store: store ?? this.store,
      discount: discount ?? this.discount,
    );
  }
}
