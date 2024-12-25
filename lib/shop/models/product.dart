import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final List<String> categories;
  final List<String> imageUrls;
  final double rating;
  final int? stockCount; // nullableに変更
  final String createdAt;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.categories,
    required this.imageUrls,
    required this.rating,
    this.stockCount, // required を削除
    required this.createdAt,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      categories: List<String>.from(data['categories'] ?? []),
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      rating: (data['rating'] ?? 0).toDouble(),
      stockCount: data['stockCount'], // nullを許容
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
      'stockCount': stockCount, // nullの場合はそのまま
      'createdAt': createdAt,
    };
  }

  // 在庫がnullの場合は在庫ありとして扱う
  bool get isInStock => stockCount == null || stockCount! > 0;
}
