import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserPointPage extends StatefulWidget {
  const UserPointPage({Key? key}) : super(key: key);

  @override
  _UserPointPageState createState() => _UserPointPageState();
}

class _UserPointPageState extends State<UserPointPage> {
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
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          _language == '日本語' ? 'ポイント数' : 'Your Points',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF00008b)),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: currentUser == null
          ? Center(
              child: Text(
                _language == '日本語' ? 'ログインしていません' : 'Not logged in',
              ),
            )
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Center(
                    child: Text(
                      _language == '日本語' ? 'データが見つかりません' : 'No data found',
                    ),
                  );
                }
                final correctCount = snapshot.data!.get('correctCount') ?? 0;
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _language == '日本語' ? 'あなたのポイント数' : 'Your Points',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00008b),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00008b),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              spreadRadius: 5,
                              blurRadius: 7,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          '$correctCount pt',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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
