import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<UserProfile?> getUserProfile() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserProfile.fromFirestore(doc) : null);
  }

  Future<void> updateUserProfile({
    String? displayName,
    String? photoUrl,
    String? email,
    String? phoneNumber,
    String? address,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('ユーザーがログインしていません');

    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (email != null) updates['email'] = email;
    if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
    if (address != null) updates['address'] = address;
    updates['updatedAt'] = FieldValue.serverTimestamp();

    await _firestore.collection('users').doc(userId).set(
          updates,
          SetOptions(merge: true),
        );
  }

  Future<void> deleteAccount() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('ユーザーがログインしていません');

    // Firestoreのユーザーデータを削除
    await _firestore.collection('users').doc(userId).delete();

    // Firebaseユーザーを削除
    await _auth.currentUser?.delete();
  }
}

class UserProfile {
  final String id;
  final String? displayName;
  final String? photoUrl;
  final String? email;
  final String? phoneNumber;
  final String? address;
  final int coins;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile({
    required this.id,
    this.displayName,
    this.photoUrl,
    this.email,
    this.phoneNumber,
    this.address,
    this.coins = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      id: doc.id,
      displayName: data['displayName'],
      photoUrl: data['photoUrl'],
      email: data['email'],
      phoneNumber: data['phoneNumber'],
      address: data['address'],
      coins: data['coins'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
