import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  String getStatusText(String? status) {
    switch (status) {
      case 'request':
        return 'リクエスト';
      case 'Processing':
        return '処理中';
      case 'completion':
        return '完了';
      case 'Cancel':
        return 'キャンセル';
      default:
        return 'エラー';
    }
  }

  Color getStatusColor(String? status) {
    switch (status) {
      case 'request':
        return Colors.blue;
      case 'Processing':
        return Colors.orange;
      case 'completion':
        return Colors.green;
      case 'Cancel':
        return Colors.red;
      default:
        return Colors.grey;
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
                          ? SizedBox(
                              width: 50,
                              height: 50,
                              child: Image.network(
                                data['animeImageUrl'],
                                fit: BoxFit.cover,
                              ),
                            )
                          : SizedBox(
                              width: 50,
                              height: 50,
                              child: Center(child: Text('未入力')),
                            ),
                      title: Text(data['animeName'] ?? '未入力'),
                      subtitle: Text(data['location'] ?? '未入力'),
                      trailing: Text(
                        getStatusText(data['status']),
                        style: TextStyle(
                          color: getStatusColor(data['status']),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  String getStatusText(String? status) {
    switch (status) {
      case 'request':
        return 'リクエスト';
      case 'Processing':
        return '処理中';
      case 'completion':
        return '完了';
      case 'Cancel':
        return 'キャンセル';
      default:
        return 'エラー';
    }
  }

  Color getStatusColor(String? status) {
    switch (status) {
      case 'request':
        return Colors.blue;
      case 'Processing':
        return Colors.orange;
      case 'completion':
        return Colors.green;
      case 'Cancel':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          data['animeName'] ?? '',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (data['animeImageUrl'] != null)
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              data['animeImageUrl'],
                              fit: BoxFit.cover,
                              height: 150,
                            ),
                          ),
                        ),
                      SizedBox(width: 8),
                      if (data['userImageUrl'] != null)
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              data['userImageUrl'],
                              fit: BoxFit.cover,
                              height: 150,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    data['animeName'] ?? '',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: getStatusColor(data['status']),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      getStatusText(data['status']),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  InfoTile(
                    icon: Icons.calendar_today,
                    title: 'リクエスト日時',
                    content: data['timestamp'] != null
                        ? DateFormat('yyyy/MM/dd HH:mm')
                            .format((data['timestamp'] as Timestamp).toDate())
                        : '',
                  ),
                  SizedBox(height: 8),
                  InfoTile(
                    icon: Icons.movie,
                    title: 'シーン',
                    content: data['scene'] ?? '',
                  ),
                  SizedBox(height: 8),
                  InfoTile(
                    icon: Icons.location_on,
                    title: '場所',
                    content: data['location'] ?? '',
                  ),
                  if (data['latitude'] != null && data['longitude'] != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 28.0),
                      child: Text(
                        '緯度: ${data['latitude']}\n経度: ${data['longitude']}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ),
                  SizedBox(height: 32),
                  Text(
                    'コメント',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      (data.data() as Map<String, dynamic>?)
                                  ?.containsKey('comment') ==
                              true
                          ? data['comment']
                          : 'コメントはありません',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const InfoTile({
    Key? key,
    required this.icon,
    required this.title,
    required this.content,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
