import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parts/point_page/point_manual.dart';

import '../manual_page/privacypolicy_screen.dart';
import '../manual_page/terms_screen.dart';
import 'chenged_point.dart';

class UserPointUpdatePage extends StatefulWidget {
  const UserPointUpdatePage({Key? key}) : super(key: key);

  @override
  _UserPointUpdatePageState createState() => _UserPointUpdatePageState();
}

class _UserPointUpdatePageState extends State<UserPointUpdatePage> {
  String _language = 'English';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late StreamSubscription<DocumentSnapshot> _languageSubscription;
  late StreamSubscription<DocumentSnapshot> _pointSubscription;

  @override
  void initState() {
    super.initState();
    _monitorLanguageChange();
    _monitorPointChange();
  }

  @override
  void dispose() {
    _languageSubscription.cancel();
    _pointSubscription.cancel();
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

  void _monitorPointChange() {
    User? user = _auth.currentUser;
    if (user != null) {
      _pointSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) async {
        if (snapshot.exists) {
          final correctCount = snapshot.data()?['correctCount'] as int?;
          final lastCorrectCount = snapshot.data()?['lastCorrectCount'] as int?;
          final point = snapshot.data()?['Point'] as int?;

          if (correctCount != null) {
            if (lastCorrectCount == null) {
              // 初回の場合、現在のcorrectCountをPointとして設定
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({
                'Point': correctCount,
                'lastCorrectCount': correctCount
              });
            } else if (correctCount > lastCorrectCount) {
              // correctCountが増加した場合、増加分をPointに追加
              int increase = correctCount - lastCorrectCount;
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({
                'Point': FieldValue.increment(increase),
                'lastCorrectCount': correctCount
              });
            }
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
                final point = snapshot.data!.get('Point') ?? 0;
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
                          '$point pt',
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
      drawer: Drawer(
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.insert_chart_outlined),
              title: const Text("ポイントの貯め方"),
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => PointManual()));
                // ここにメニュータップ時の処理を記述
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text("ポイント獲得履歴"),
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => PointManual()));
                // ここにメニュータップ時の処理を記述
              },
            ),
            ListTile(
              leading: const Icon(Icons.money),
              title: const Text("ポイント交換"),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => PresentListScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.book_outlined),
              title: const Text("ポイント利用規約"),
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => TermsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text("プライバシーポリシー"),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => PrivacyPolicyScreen()));
              },
            )
          ],
        ),
      ),
    );
  }
}
