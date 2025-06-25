import 'package:uuid/uuid.dart';

class Product {
  final String id;
  String name;
  double price;
  int quantity;
  double? unitPrice;
  String? imageUrl;
  String store = 'None';

  Product({
    String? id,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.unitPrice,
    this.imageUrl,
    this.store = 'None',
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'imageUrl': imageUrl,
    'store': 'None',
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'],
    name: json['name'],
    price: json['price'],
    quantity: json['quantity'],
    unitPrice: (json['unitPrice'] as num?)?.toDouble(),
    imageUrl: json['imageUrl'] as String?,
    store: json['store'] as String? ?? 'None', // Default value if not provided
  );

  Product copyWith({
    String? id,
    String? name,
    double? price,
    int? quantity,
    double? unitPrice,
    String? imageUrl,
    String? store,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      store: store ?? this.store,
    );
  }
}
