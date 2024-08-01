import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'present_detail_screen.dart';

class PresentListScreen extends StatefulWidget {
  @override
  _PresentListScreenState createState() => _PresentListScreenState();
}

class _PresentListScreenState extends State<PresentListScreen> {
  String _language = 'English';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late StreamSubscription<DocumentSnapshot> _languageSubscription;

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
          _language == '日本語' ? 'プレゼント一覧' : 'Present List',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
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
      ),
    );
  }
}
