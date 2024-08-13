import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CustomerRequestHistory extends StatefulWidget {
  @override
  _CustomerRequestHistoryState createState() => _CustomerRequestHistoryState();
}

class _CustomerRequestHistoryState extends State<CustomerRequestHistory> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? user;

  @override
  void initState() {
    super.initState();
    _checkUserLoggedIn();
  }

  void _checkUserLoggedIn() {
    user = _auth.currentUser;
    if (user == null) {
      // ユーザーがログインしていない場合の処理
      Navigator.of(context).pushReplacementNamed('/login');
    } else {
      setState(() {}); // ログインユーザーが見つかった場合、画面を更新
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'リクエスト履歴',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: user == null
          ? Center(child: Text('ユーザーがログインしていません'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('customer_animerequest')
                  .where('userEmail', isEqualTo: user!.email)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('データがありません'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var data = snapshot.data!.docs[index];
                    return ListTile(
                      leading: data['animeImageUrl'] != null
                          ? Image.network(data['animeImageUrl'])
                          : Text('未入力'),
                      title: Text(data['animeName'] ?? '未入力'),
                      subtitle: Text(data['location'] ?? '未入力'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailScreen(data: data),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

class DetailScreen extends StatelessWidget {
  final QueryDocumentSnapshot data;

  DetailScreen({required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          data['animeName'] ?? '未入力',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'アニメ名: ${data['animeName'] ?? '未入力'}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                  'リクエスト日時: ${data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate().toString() : '未入力'}'),
              SizedBox(height: 8),
              Text('場所: ${data['location'] ?? '未入力'}'),
              Text('シーン: ${data['scene'] ?? '未入力'}'),
              SizedBox(height: 8),
              data['animeImageUrl'] != null
                  ? Image.network(data['animeImageUrl'])
                  : Text('未入力'),
              SizedBox(height: 8),
              data['userImageUrl'] != null
                  ? Image.network(data['userImageUrl'])
                  : Text('未入力'),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
