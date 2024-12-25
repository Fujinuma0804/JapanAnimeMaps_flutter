import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

class CartService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<CartItem>> getCartItems() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('shopping_cart')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return CartItem.fromMap(data);
      }).toList();
    });
  }

  Stream<int> getCartItemCount() {
    return getCartItems().map((items) {
      return items.fold(0, (sum, item) => sum + item.quantity);
    });
  }

  Future<void> addToCart(Product product) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('ユーザーがログインしていません');

    final cartRef =
        _firestore.collection('users').doc(userId).collection('shopping_cart');

    await _firestore.runTransaction((transaction) async {
      // 既存のカートアイテムを確認
      final existingItems =
          await cartRef.where('productId', isEqualTo: product.id).get();

      if (product.stockCount != null) {
        // 在庫確認
        final productDoc = await transaction
            .get(_firestore.collection('products').doc(product.id));
        final currentStock = productDoc.data()?['stockCount'] as int?;

        if (currentStock != null && currentStock <= 0) {
          throw Exception('申し訳ありません。この商品は現在在庫切れです。');
        }

        if (existingItems.docs.isNotEmpty) {
          final currentQuantity =
              existingItems.docs.first.data()['quantity'] as int;
          if (currentStock != null && currentQuantity + 1 > currentStock) {
            throw Exception('申し訳ありません。在庫が不足しています。');
          }
        }

        transaction.update(
          _firestore.collection('products').doc(product.id),
          {
            'stockCount': currentStock! - 1,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
        );
      }

      if (existingItems.docs.isNotEmpty) {
        final existingItem = existingItems.docs.first;
        final currentQuantity = existingItem.data()['quantity'] as int;
        transaction.update(existingItem.reference, {
          'quantity': currentQuantity + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.set(cartRef.doc(), {
          'productId': product.id,
          'productName': product.name,
          'price': product.price,
          'imageUrl': product.imageUrls.isNotEmpty ? product.imageUrls[0] : '',
          'quantity': 1,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> updateQuantity(String cartItemId, int quantity) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('ユーザーがログインしていません');

    if (quantity <= 0) {
      await removeFromCart(cartItemId);
      return;
    }

    final cartItemRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('shopping_cart')
        .doc(cartItemId);

    await _firestore.runTransaction((transaction) async {
      final cartItem = await transaction.get(cartItemRef);
      if (!cartItem.exists) {
        throw Exception('カートアイテムが見つかりません');
      }

      final productId = cartItem.data()?['productId'] as String;
      final productRef = _firestore.collection('products').doc(productId);
      final productDoc = await transaction.get(productRef);

      if (!productDoc.exists) {
        throw Exception('商品が見つかりません');
      }

      final stockCount = productDoc.data()?['stockCount'] as int?;

      if (stockCount != null && quantity > stockCount) {
        throw Exception('申し訳ありません。在庫が不足しています。');
      }

      transaction.update(cartItemRef, {
        'quantity': quantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> removeFromCart(String cartItemId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('ユーザーがログインしていません');

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('shopping_cart')
        .doc(cartItemId)
        .delete();
  }

  Future<void> clearCart() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('ユーザーがログインしていません');

    final cartRef =
        _firestore.collection('users').doc(userId).collection('shopping_cart');

    final cartItems = await cartRef.get();
    final batch = _firestore.batch();

    for (var doc in cartItems.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}
