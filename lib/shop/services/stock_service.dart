import 'package:cloud_firestore/cloud_firestore.dart';

class StockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 在庫数を取得
  Future<int> getStockCount(String productId) async {
    final doc = await _firestore.collection('products').doc(productId).get();
    return doc.data()?['stockCount'] ?? 0;
  }

  // 在庫数をリアルタイムで監視
  Stream<int> watchStockCount(String productId) {
    return _firestore
        .collection('products')
        .doc(productId)
        .snapshots()
        .map((doc) => doc.data()?['stockCount'] ?? 0);
  }

  // 購入時の在庫数減少処理
  Future<bool> decreaseStock(String productId, int quantity) async {
    try {
      return await _firestore.runTransaction<bool>((transaction) async {
        final docRef = _firestore.collection('products').doc(productId);
        final doc = await transaction.get(docRef);

        if (!doc.exists) {
          throw Exception('商品が見つかりません');
        }

        final currentStock = doc.data()?['stockCount'] ?? 0;
        if (currentStock < quantity) {
          throw Exception('在庫が不足しています');
        }

        transaction.update(docRef, {
          'stockCount': currentStock - quantity,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // 在庫履歴を記録
        final historyRef = docRef.collection('stockHistory').doc();
        transaction.set(historyRef, {
          'type': 'decrease',
          'quantity': quantity,
          'remainingStock': currentStock - quantity,
          'timestamp': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      print('在庫減少処理でエラーが発生しました: $e');
      return false;
    }
  }

  // 在庫補充処理
  Future<bool> increaseStock(String productId, int quantity) async {
    try {
      return await _firestore.runTransaction<bool>((transaction) async {
        final docRef = _firestore.collection('products').doc(productId);
        final doc = await transaction.get(docRef);

        if (!doc.exists) {
          throw Exception('商品が見つかりません');
        }

        final currentStock = doc.data()?['stockCount'] ?? 0;

        transaction.update(docRef, {
          'stockCount': currentStock + quantity,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // 在庫履歴を記録
        final historyRef = docRef.collection('stockHistory').doc();
        transaction.set(historyRef, {
          'type': 'increase',
          'quantity': quantity,
          'remainingStock': currentStock + quantity,
          'timestamp': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      print('在庫増加処理でエラーが発生しました: $e');
      return false;
    }
  }

  // 在庫アラートの設定値を取得
  Future<Map<String, dynamic>> getStockAlertSettings(String productId) async {
    final doc = await _firestore.collection('products').doc(productId).get();
    return {
      'lowStockThreshold': doc.data()?['lowStockThreshold'] ?? 5,
      'alertEnabled': doc.data()?['stockAlertEnabled'] ?? false,
    };
  }

  // 在庫履歴を取得
  Stream<List<StockHistoryEntry>> getStockHistory(String productId) {
    return _firestore
        .collection('products')
        .doc(productId)
        .collection('stockHistory')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StockHistoryEntry.fromFirestore(doc))
            .toList());
  }
}

class StockHistoryEntry {
  final String id;
  final String type;
  final int quantity;
  final int remainingStock;
  final DateTime timestamp;

  StockHistoryEntry({
    required this.id,
    required this.type,
    required this.quantity,
    required this.remainingStock,
    required this.timestamp,
  });

  factory StockHistoryEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StockHistoryEntry(
      id: doc.id,
      type: data['type'] ?? '',
      quantity: data['quantity'] ?? 0,
      remainingStock: data['remainingStock'] ?? 0,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }
}
