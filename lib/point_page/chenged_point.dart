import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'present_detail_screen.dart';

class PresentListScreen extends StatefulWidget {
  @override
  _PresentListScreenState createState() => _PresentListScreenState();
}

class _PresentListScreenState extends State<PresentListScreen> {
  String _language = 'English';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late StreamSubscription<DocumentSnapshot> _languageSubscription;
  bool _showHistory = false;

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _monitorLanguageChange();
  }

  @override
  void dispose() {
    _languageSubscription.cancel();
    super.dispose();
  }

  void _monitorLanguageChange() {
    User? user = _auth.currentUser;
    if (user != null) {
      _languageSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          final newLanguage = snapshot.data()?['language'] as String?;
          if (newLanguage != null) {
            setState(() {
              _language = newLanguage == 'Japanese' ? '日本語' : 'English';
            });
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _language == '日本語' ? 'ポイント交換' : 'Point Exchange',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _showHistory = !_showHistory;
              });
            },
            icon: Icon(
              Icons.update,
              color: Color(0xFF00008b),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ユーザーのポイント数を表示
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_auth.currentUser?.uid)
                .snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator();
              }
              final currentPoints = userSnapshot.data?['Point'] ?? 0;
              return Container(
                padding: EdgeInsets.all(16),
                color: Colors.grey[200],
                child: Text(
                  _language == '日本語'
                      ? 'あなたの保有ポイント数は $currentPoints ポイントです。'
                      : 'Your points: $currentPoints',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: _showHistory ? _buildHistoryList() : _buildPresentGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('requestPresents')
          .where('email', isEqualTo: _auth.currentUser?.email)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Text(
                  _language == '日本語' ? 'エラーが発生しました' : 'An error occurred'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!.docs;

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final data = requests[index].data() as Map<String, dynamic>;
            final requestDate =
                _dateFormat.format((data['requestTime'] as Timestamp).toDate());
            return ListTile(
              title: Text(data['presentName'] ?? ''),
              subtitle: Text(requestDate),
              trailing: Text(data['status'] ?? ''),
              onTap: () {
                _showRequestDetails(data);
              },
            );
          },
        );
      },
    );
  }

  void _showRequestDetails(Map<String, dynamic> data) {
    final requestDate =
        _dateFormat.format((data['requestTime'] as Timestamp).toDate());
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_language == '日本語' ? '申請詳細' : 'Request Details'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                    '${_language == '日本語' ? '景品名: ' : 'Present Name: '}${data['presentName']}'),
                Text(
                    '${_language == '日本語' ? 'ポイント: ' : 'Points: '}${data['points']}'),
                Text(
                    '${_language == '日本語' ? '申請日時: ' : 'Request Time: '}$requestDate'),
                Text(
                    '${_language == '日本語' ? 'ステータス: ' : 'Status: '}${data['status']}'),
                Text(
                    '${_language == '日本語' ? 'メールアドレス: ' : 'Email: '}${data['email']}'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(_language == '日本語' ? '閉じる' : 'Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildPresentGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('presents').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              _language == '日本語' ? 'エラーが発生しました' : 'An error occurred',
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final presents = snapshot.data!.docs;

        return GridView.builder(
          padding: EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: presents.length,
          itemBuilder: (context, index) {
            final present = presents[index].data() as Map<String, dynamic>;
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PresentDetailScreen(presentId: presents[index].id),
                  ),
                );
              },
              child: Card(
                elevation: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Image.network(
                        present['imageUrl'],
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            present['presentName'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${present['points']} ${_language == '日本語' ? 'ポイント' : 'Points'}',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
