import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PresentDetailScreen extends StatelessWidget {
  final String presentId;

  PresentDetailScreen({required this.presentId});

  Future<void> _exchangePresent(
      BuildContext context, Map<String, dynamic> present) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ユーザーがログインしていません')),
      );
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final currentPoints = userDoc.data()?['correctCount'] ?? 0;
    final requiredPoints = present['points'];

    if (currentPoints < requiredPoints) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('ポイント数が不足しています。現在の残りのポイント数は、$currentPointsポイントです。')),
      );
      return;
    }

    // トランザクションを使用してポイントを減らし、リクエストを作成
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // ユーザーのポイントを減らす
      transaction.update(userDoc.reference, {
        'correctCount': FieldValue.increment(-requiredPoints),
      });

      // リクエストを作成
      final requestPresentsRef =
          FirebaseFirestore.instance.collection('requestPresents');
      transaction.set(requestPresentsRef.doc(), {
        'userName': user.email,
        'email': user.email,
        'requestTime': FieldValue.serverTimestamp(),
        'presentId': presentId,
        'presentName': present['presentName'],
        'points': requiredPoints,
        'status': 'リクエスト', // ここでstatusフィールドを追加
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('プレゼントの交換リクエストが完了しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('プレゼント詳細'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('presents')
            .doc(presentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final present = snapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.network(
                  present['imageUrl'],
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        present['presentName'],
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${present['points']} ポイント',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Center(
                        child: SizedBox(
                          height: 50.0,
                          width: 200.0,
                          child: ElevatedButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text('確認'),
                                    content: Text('この操作は取り消せません。'),
                                    actions: <Widget>[
                                      TextButton(
                                        child: Text('キャンセル'),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                      TextButton(
                                        child: Text('OK'),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          _exchangePresent(context, present);
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            child: Text('交換する'),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 10.0,
                      ),
                      Text(
                        present['description'],
                        style: TextStyle(
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
