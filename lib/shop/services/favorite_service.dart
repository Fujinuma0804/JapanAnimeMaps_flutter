import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/product.dart';

class FavoritesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<String>> getFavoriteIds() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  Stream<List<Product>> getFavoriteProducts() {
    return getFavoriteIds().asyncMap((favoriteIds) async {
      if (favoriteIds.isEmpty) return [];

      final productsSnapshot = await _firestore
          .collection('products')
          .where(FieldPath.documentId, whereIn: favoriteIds)
          .get();

      return productsSnapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();
    });
  }

  Future<void> toggleFavorite(String productId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('ユーザーがログインしていません');

    final favoriteRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(productId);

    final doc = await favoriteRef.get();
    if (doc.exists) {
      await favoriteRef.delete();
    } else {
      await favoriteRef.set({'addedAt': FieldValue.serverTimestamp()});
    }
  }

  Future<bool> isFavorite(String productId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(productId)
        .get();

    return doc.exists;
  }
}
