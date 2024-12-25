import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parts/shop/services/cart_service.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

class ShoppingListService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<CartItem>> getShoppingListItems() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('shopping_list')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return CartItem.fromMap(data);
      }).toList();
    });
  }

  Stream<int> getShoppingListItemCount() {
    return getShoppingListItems().map((items) {
      return items.fold(0, (sum, item) => sum + item.quantity);
    });
  }

  Future<void> addToShoppingList(Product product) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('ユーザーがログインしていません');

    final listRef = _firestore.collection('shopping_list');

    // 既存のアイテムを確認
    final existingItems = await listRef
        .where('userId', isEqualTo: userId)
        .where('productId', isEqualTo: product.id)
        .get();

    if (existingItems.docs.isNotEmpty) {
      final existingItem = existingItems.docs.first;
      final currentQuantity = existingItem.data()['quantity'] as int;
      await existingItem.reference.update({
        'quantity': currentQuantity + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await listRef.add({
        'userId': userId,
        'productId': product.id,
        'productName': product.name,
        'price': product.price,
        'imageUrl': product.imageUrls.isNotEmpty ? product.imageUrls[0] : '',
        'quantity': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> updateQuantity(String itemId, int quantity) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('ユーザーがログインしていません');

    if (quantity <= 0) {
      await removeFromList(itemId);
      return;
    }

    final itemRef = _firestore.collection('shopping_list').doc(itemId);
    final item = await itemRef.get();

    if (!item.exists || item.data()?['userId'] != userId) {
      throw Exception('アイテムが見つかりません');
    }

    await itemRef.update({
      'quantity': quantity,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeFromList(String itemId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('ユーザーがログインしていません');

    final itemRef = _firestore.collection('shopping_list').doc(itemId);
    final item = await itemRef.get();

    if (!item.exists || item.data()?['userId'] != userId) {
      throw Exception('アイテムが見つかりません');
    }

    await itemRef.delete();
  }

  Future<void> clearList() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('ユーザーがログインしていません');

    final batch = _firestore.batch();
    final items = await _firestore
        .collection('shopping_list')
        .where('userId', isEqualTo: userId)
        .get();

    for (var doc in items.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  Future<void> moveToCart(String itemId, CartService cartService) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('ユーザーがログインしていません');

    final itemRef = _firestore.collection('shopping_list').doc(itemId);
    final item = await itemRef.get();

    if (!item.exists || item.data()?['userId'] != userId) {
      throw Exception('アイテムが見つかりません');
    }

    final itemData = item.data()!;

    // カートに追加
    await cartService.addToCart(Product(
      id: itemData['productId'],
      name: itemData['productName'],
      description: '',
      price: itemData['price'],
      categories: [],
      imageUrls: [itemData['imageUrl']],
      rating: 0,
      createdAt: '',
    ));

    // ショッピングリストから削除
    await itemRef.delete();
  }
}
