class Item {
  String name;
  double price;
  int quantity;
  double? unitPrice;
  String? imageUrl;
  String store = 'Alle';

  Item({required this.name, required this.price, this.quantity = 1, this.unitPrice, this.imageUrl, this.store = 'Alle'});

  Map<String, dynamic> toJson() => {
    'name': name,
    'price': price,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'imageUrl': imageUrl,
    'store': 'Alle',
  };

  factory Item.fromJson(Map<String, dynamic> json) => Item(
    name: json['name'],
    price: json['price'],
    quantity: json['quantity'],
    unitPrice: (json['unitPrice'] as num?)?.toDouble(),
    imageUrl: json['imageUrl'] as String?,
    store: json['store'] as String? ?? 'Alle', // Default value if not provided
  );
}