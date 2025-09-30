import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UsageScreen extends StatefulWidget {
  const UsageScreen({super.key});

  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen> {
  late Stream<DocumentSnapshot> _languageStream;
  late String _language;
  late StreamSubscription<DocumentSnapshot> _languageSubscription;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _language = 'English'; // デフォルト言語を設定
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          _language == '日本語' ? '使い方' : 'Usage',
          style: const TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20.0),
              Center(
                child: Text(
                  _language == '日本語'
                      ? '獲得ポイントをランキング形式で毎週発表！\n'
                      : 'Weekly rankings for earned points are announced!',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10.0),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(_language == '日本語'
                    ? '日々追加されるスポットへたくさんチェックインしよう。'
                    : 'Check-in at the new spots added daily.'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(_language == '日本語'
                    ? 'チェックインすると画像投稿が可能に！！'
                    : 'Check-in to be able to post images!!'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(_language == '日本語'
                    ? '投稿して同じアニメの好きな友達をフォローしよう！'
                    : 'Post and follow friends who like the same anime!'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(_language == '日本語'
                    ? 'チェックインや投稿で溜めたポイントを豪華景品へ交換！'
                    : 'Exchange points accumulated from check-ins and posts for luxurious prizes!'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(_language == '日本語'
                    ? '景品については、数に限りがあります。'
                    : 'Prizes are limited in quantity.'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(_language == '日本語'
                    ? '景品の一部は告知なしで終了する可能性があります。'
                    : 'Some prizes may end without notice.'),
              ),
              const SizedBox(height: 15.0),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _language == '日本語' ? '■ 参加方法' : '■ How to Participate',
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                    color: Color(0xFF00008b),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 10.0),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(_language == '日本語'
                    ? '本アプリに登録し、ログインした状態でチェックイン'
                    : 'Register in the app and check-in while logged in'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(_language == '日本語'
                    ? '利用方法を参考に、たくさんチェックイン・投稿をしよう'
                    : 'Check-in and post a lot by referring to the usage instructions'),
              ),
              const SizedBox(height: 15.0),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _language == '日本語' ? '■ 利用方法' : '■ How to Use',
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                    color: Color(0xFF00008b),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 10.0),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(_language == '日本語'
                    ? '①スポット付近でチェックインができるようになります。'
                    : '① You can check-in near the spot.'),
              ),
              const SizedBox(height: 10.0),
              Center(
                child: SizedBox(
                  height: 400,
                  width: 300,
                  child: Image.asset('assets/images/sample_images.png'),
                ),
              ),
              const SizedBox(height: 10.0),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(_language == '日本語'
                    ? '②チェックインを押し、アニメの題名を入力します。'
                    : '② Press check-in and enter the anime title.'),
              ),
              const SizedBox(height: 10.0),
              Center(
                child: SizedBox(
                  height: 400,
                  width: 300,
                  child: Image.asset('assets/images/sample_checkin.png'),
                ),
              ),
              const SizedBox(height: 10.0),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(_language == '日本語'
                    ? '③アニメの題名が正しければチェックイン完了です！！'
                    : '③ If the anime title is correct, the check-in is complete!!'),
              ),
              const SizedBox(height: 15.0),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _language == '日本語' ? '■ ポイント情報' : '■ Points Information',
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                    color: Color(0xFF00008b),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 10.0),
              Table(
                border: TableBorder.all(
                  color: Colors.black,
                  width: 1.0,
                  style: BorderStyle.solid,
                ),
                children: [
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(_language == '日本語' ? 'チェックイン' : 'Check-in'),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(_language == '日本語' ? '１ポイント' : '1 point'),
                      ),
                    ],
                  ),
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(_language == '日本語' ? '投稿' : 'Post'),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(_language == '日本語' ? '２ポイント' : '2 points'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10.0),
            ],
          ),
        ),
      ),
    );
  }
}
