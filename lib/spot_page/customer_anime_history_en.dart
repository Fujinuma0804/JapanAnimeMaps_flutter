import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CustomerRequestHistoryEn extends StatefulWidget {
  @override
  _CustomerRequestHistoryEnState createState() =>
      _CustomerRequestHistoryEnState();
}

class _CustomerRequestHistoryEnState extends State<CustomerRequestHistoryEn> {
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
        return 'Request';
      case 'Processing':
        return 'Processing';
      case 'completion':
        return 'Completion';
      case 'Cancel':
        return 'Cancel';
      default:
        return 'Error';
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
          'Request History',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: user == null
          ? Center(child: Text('Not Login Now'))
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
                  return Center(child: Text('No Data'));
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
                              child: Center(child: Text('No Data')),
                            ),
                      title: Text(data['animeName'] ?? 'No Data'),
                      subtitle: Text(data['location'] ?? 'No Data'),
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
        return 'Request';
      case 'Processing':
        return 'Processing';
      case 'completion':
        return 'Completion';
      case 'Cancel':
        return 'Cancel';
      default:
        return 'Error';
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
          data['animeName'] ?? 'No Data',
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
                'Anime Name: ${data['animeName'] ?? 'No Data'}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Status: ${getStatusText(data['status'])}',
                style: TextStyle(
                  color: getStatusColor(data['status']),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                  'Request Date: ${data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate().toString() : 'No Data'}'),
              Text('Place: ${data['location'] ?? 'No Data'}'),
              Text('Scene: ${data['scene'] ?? 'No Data'}'),
              SizedBox(height: 8),
              data['animeImageUrl'] != null
                  ? Image.network(data['animeImageUrl'])
                  : Text('No Data'),
              SizedBox(height: 8),
              data['userImageUrl'] != null
                  ? Image.network(data['userImageUrl'])
                  : Text('No Data'),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
