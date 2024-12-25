class CartItem {
  final String id;
  final String productId;
  final String productName;
  final double price;
  final String imageUrl;
  final int quantity;

  CartItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.price,
    required this.imageUrl,
    this.quantity = 1,
  });

  double get totalPrice => price * quantity;

  CartItem copyWith({
    String? id,
    String? productId,
    String? productName,
    double? price,
    String? imageUrl,
    int? quantity,
  }) {
    return CartItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'price': price,
      'imageUrl': imageUrl,
      'quantity': quantity,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'],
      productId: map['productId'],
      productName: map['productName'],
      price: map['price'],
      imageUrl: map['imageUrl'],
      quantity: map['quantity'],
    );
  }
}
