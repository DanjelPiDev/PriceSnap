import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../utils/store_utils.dart';

enum ShoppingListStatus { inactive, active, completed }

class ShoppingList {
  String id;
  String name;
  Store store;
  List<Product> items;
  ShoppingListStatus status;
  DateTime created;
  DateTime? completedAt;

  ShoppingList({
    required this.id,
    required this.name,
    this.store = Store.none,
    List<Product>? items,
    this.status = ShoppingListStatus.active,
    DateTime? created,
    this.completedAt,
  })  : items = items ?? [],
        created = created ?? DateTime.now();

  void addProduct(Product product, {int quantity = 1}) {
    final idx = items.indexWhere((p) => p.id == product.id);
    if (idx >= 0) {
      items[idx].quantity += quantity;
    } else {
      items.add(product.copyWith(quantity: quantity));
    }
  }

  void incrementProduct(String productId) {
    final idx = items.indexWhere((p) => p.id == productId);
    if (idx >= 0) items[idx].quantity++;
  }

  void decrementProduct(String productId) {
    final idx = items.indexWhere((p) => p.id == productId);
    if (idx >= 0 && items[idx].quantity > 1) items[idx].quantity--;
  }

  void removeProduct(String productId) {
    items.removeWhere((p) => p.id == productId);
  }

  void markCompleted() {
    status = ShoppingListStatus.completed;
    completedAt = DateTime.now();
  }

  void markActive() {
    status = ShoppingListStatus.active;
    completedAt = null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'store': storeToJsonString(store),
    'items': items.map((e) => e.toJson()).toList(),
    'status': describeEnum(status),
    'created': created.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  factory ShoppingList.fromJson(Map<String, dynamic> json) => ShoppingList(
    id: json['id'],
    name: json['name'],
    store: storeFromString(json['store']),
    items: (json['items'] as List<dynamic>)
        .map((e) => Product.fromJson(e))
        .toList(),
    status: ShoppingListStatus.values.firstWhere(
            (s) => describeEnum(s) == (json['status'] ?? 'active')),
    created: DateTime.parse(json['created']),
    completedAt: json['completedAt'] != null
        ? DateTime.parse(json['completedAt'])
        : null,
  );

  ShoppingList copyWith({
    String? id,
    String? name,
    Store? store,
    List<Product>? items,
    ShoppingListStatus? status,
    DateTime? created,
    DateTime? completedAt,
  }) {
    return ShoppingList(
      id: id ?? this.id,
      name: name ?? this.name,
      store: store ?? this.store,
      items: items ?? List<Product>.from(this.items),
      status: status ?? this.status,
      created: created ?? this.created,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
