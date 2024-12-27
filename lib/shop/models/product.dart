import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final List<String> categories;
  final List<String> imageUrls;
  final double rating;
  final int? stockCount;
  final String createdAt;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.categories,
    required this.imageUrls,
    required this.rating,
    this.stockCount,
    required this.createdAt,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id, // idはdoc.idを使用し、これが商品IDとなる
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      categories: List<String>.from(data['categories'] ?? []),
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      rating: (data['rating'] ?? 0).toDouble(),
      stockCount: data['stockCount'],
      createdAt: data['createdAt'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'categories': categories,
      'imageUrls': imageUrls,
      'rating': rating,
      'stockCount': stockCount,
      'createdAt': createdAt,
    };
  }

  bool get isInStock => stockCount == null || stockCount! > 0;
}
