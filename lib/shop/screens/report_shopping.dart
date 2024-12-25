import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class InquiryFormPage extends StatefulWidget {
  @override
  _InquiryFormPageState createState() => _InquiryFormPageState();
}

class _InquiryFormPageState extends State<InquiryFormPage> {
  final TextEditingController _orderNumberController = TextEditingController();
  final TextEditingController _additionalInfoController =
      TextEditingController();

  Future<void> _submitInquiry() async {
    final String orderNumber = _orderNumberController.text.trim();
    final String additionalInfo = _additionalInfoController.text.trim();

    if (orderNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('注文番号を入力してください。')),
      );
      return;
    }

    try {
      // 現在のユーザーIDを取得
      final User? user = FirebaseAuth.instance.currentUser;
      final String userId = user?.uid ?? 'unknown_user';

      // Firebase Firestore にデータを格納
      await FirebaseFirestore.instance.collection('shopping_contact').add({
        'orderNumber': orderNumber,
        'additionalInfo': additionalInfo,
        'userId': userId, // ユーザーIDを追加
        'timestamp': FieldValue.serverTimestamp(),
      });

      // お礼のダイアログを表示
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('お問い合わせありがとうございます'),
            content: Text('3営業日以内に返信いたします。'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // フォーム画面を閉じる
                },
                child: Text('閉じる'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('送信中にエラーが発生しました。再度お試しください。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('お問い合わせフォーム'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _orderNumberController,
              decoration: InputDecoration(
                labelText: '注文番号',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16.0),
            TextField(
              controller: _additionalInfoController,
              decoration: InputDecoration(
                labelText: '追加情報 (任意)',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _submitInquiry,
              child: Text('送信'),
            ),
          ],
        ),
      ),
    );
  }
}
