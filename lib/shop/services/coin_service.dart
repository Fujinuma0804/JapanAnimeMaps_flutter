import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CoinService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<int> getCoinBalance() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(0);

    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.data()?['coins'] as int? ?? 0);
  }

  Future<void> addCoins(int amount) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('ユーザーがログインしていません');

    await _firestore.collection('users').doc(userId).set({
      'coins': FieldValue.increment(amount),
      'lastCoinUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // トランザクション履歴の記録
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('coinTransactions')
        .add({
      'amount': amount,
      'type': 'charge',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> useCoins(int amount) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('ユーザーがログインしていません');

    final userDoc = await _firestore.collection('users').doc(userId).get();
    final currentBalance = userDoc.data()?['coins'] as int? ?? 0;

    if (currentBalance < amount) {
      throw Exception('コインが不足しています');
    }

    await _firestore.collection('users').doc(userId).set({
      'coins': FieldValue.increment(-amount),
      'lastCoinUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // トランザクション履歴の記録
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('coinTransactions')
        .add({
      'amount': -amount,
      'type': 'use',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<CoinTransaction>> getTransactionHistory() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('coinTransactions')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CoinTransaction.fromFirestore(doc))
          .toList();
    });
  }
}

class CoinTransaction {
  final String id;
  final int amount;
  final String type;
  final DateTime timestamp;

  CoinTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.timestamp,
  });

  factory CoinTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CoinTransaction(
      id: doc.id,
      amount: data['amount'] ?? 0,
      type: data['type'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  String get typeText {
    switch (type) {
      case 'charge':
        return 'チャージ';
      case 'use':
        return '使用';
      default:
        return type;
    }
  }

  bool get isCharge => type == 'charge';
}
