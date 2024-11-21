import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class CartState extends ChangeNotifier {
  final List<CartItem> _items = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<CartItem> get items => _items;

  Future<void> addToCart(Product product) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final existingIndex =
        _items.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      _items[existingIndex].quantity++;
    } else {
      _items.add(CartItem(product: product));
    }
    notifyListeners();

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('cart')
        .doc(product.id)
        .set({
      'productId': product.id,
      'quantity': existingIndex >= 0 ? _items[existingIndex].quantity : 1,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeFromCart(String productId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('cart')
        .doc(productId)
        .delete();
  }

  Future<void> updateQuantity(String productId, int quantity) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (quantity <= 0) {
        await removeFromCart(productId);
      } else {
        _items[index].quantity = quantity;
        notifyListeners();

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('cart')
            .doc(productId)
            .update({'quantity': quantity});
      }
    }
  }

  Future<void> loadCart() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final cartSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('cart')
        .get();

    final List<Future<CartItem>> futures = cartSnapshot.docs.map((doc) async {
      final productDoc = await _firestore
          .collection('products')
          .doc(doc.data()['productId'])
          .get();

      final product = Product.fromFirestore(productDoc);
      return CartItem(
        product: product,
        quantity: doc.data()['quantity'] ?? 1,
      );
    }).toList();

    _items.clear();
    _items.addAll(await Future.wait(futures));
    notifyListeners();
  }

  Future<void> clearCart() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _items.clear();
    notifyListeners();

    final cartRef =
        _firestore.collection('users').doc(userId).collection('cart');

    final cartItems = await cartRef.get();
    final batch = _firestore.batch();

    for (var doc in cartItems.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  double get totalAmount {
    return _items.fold(
      0.0,
      (sum, item) => sum + (item.product.price * item.quantity),
    );
  }
}

class FavoriteState extends ChangeNotifier {
  final Set<String> _favoriteIds = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Set<String> get favoriteIds => _favoriteIds;

  bool isFavorite(String productId) => _favoriteIds.contains(productId);

  Future<void> toggleFavorite(String productId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    if (_favoriteIds.contains(productId)) {
      _favoriteIds.remove(productId);
      await _firestore.collection('users').doc(userId).update({
        'favorites': FieldValue.arrayRemove([productId])
      });
    } else {
      _favoriteIds.add(productId);
      await _firestore.collection('users').doc(userId).update({
        'favorites': FieldValue.arrayUnion([productId])
      });
    }
    notifyListeners();
  }

  Future<void> loadFavorites() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final doc = await _firestore.collection('users').doc(userId).get();
    final favorites =
        (doc.data()?['favorites'] as List<dynamic>?)?.cast<String>() ?? [];

    _favoriteIds.clear();
    _favoriteIds.addAll(favorites);
    notifyListeners();
  }
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });
}

class Product {
  final String id;
  final String name;
  final double price;
  final List<String> imageUrls;
  final String description;
  final String category;
  final List<Review> reviews;
  final double rating;
  final bool isAvailable;
  final int stockCount;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrls = const [],
    required this.description,
    required this.category,
    this.reviews = const [],
    this.rating = 0.0,
    this.isAvailable = true,
    this.stockCount = 0,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    List<String> convertImageUrls() {
      dynamic urls = data['imageUrls'];
      if (urls == null) return [];
      if (urls is List) {
        return urls.map((url) => url.toString()).toList();
      }
      if (urls is String) {
        return [urls];
      }
      return [];
    }

    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      imageUrls: convertImageUrls(),
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      rating: (data['rating'] ?? 0).toDouble(),
      isAvailable: data['isAvailable'] ?? true,
      stockCount: data['stockCount'] ?? 0,
      reviews: ((data['reviews'] as List<dynamic>?) ?? []).map((review) {
        return Review.fromMap(review as Map<String, dynamic>);
      }).toList(),
    );
  }
}

class Review {
  final String userId;
  final String userName;
  final double rating;
  final String comment;
  final DateTime date;

  Review({
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.date,
  });

  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      rating: (map['rating'] ?? 0).toDouble(),
      comment: map['comment'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
    );
  }
}
