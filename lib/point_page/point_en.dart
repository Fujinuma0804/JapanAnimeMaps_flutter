import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parts/point_page/point_manual.dart';
import 'package:parts/point_page/user_point.dart';
import 'package:settings_ui/settings_ui.dart';

import '../login_page/sign_up.dart';
import '../manual_page/privacypolicy_screen.dart';
import '../manual_page/terms_screen.dart';
import 'chenged_point.dart';

class PointEnPage extends StatefulWidget {
  const PointEnPage({Key? key}) : super(key: key);

  @override
  _PointEnPageState createState() => _PointEnPageState();
}

class _PointEnPageState extends State<PointEnPage> {
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
    User? user = _auth.currentUser;

    // 匿名ユーザ向け
    if (user != null && user.isAnonymous) {
      return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.white,
            title: Text(
              _language == '日本語' ? '登録が必要です' : 'SignUp Required',
              style: const TextStyle(
                color: Color(0xFF00008b),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: Container(
            width: double.infinity, // 横幅を全体に適用
            height: double.infinity, // 高さを全体に適用
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueAccent.shade100, Colors.blue.shade200],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 100,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _language == '日本語'
                        ? '現在、ゲストログインでご利用いただいております。\nそのため、ポイントをお貯めいただけません。\n以下より登録をお願いします。'
                        : 'You are currently logged in as a guest.\nTherefore, you cannot accumulate points.\nPlease sign up using the button below.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 15),
                      backgroundColor: Colors.orangeAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SignUpPage()),
                      );
                    },
                    child: Text(
                      _language == '日本語' ? '登録はこちら' : 'Sign Up Here',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ログイン中
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text(
            _language == '日本語' ? 'ポイントについて' : 'About Points',
            style: const TextStyle(
              color: Color(0xFF00008b),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SettingsList(
          sections: [
            SettingsSection(
              title: Text(_language == '日本語' ? 'ポイント' : 'Point'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(Icons.monetization_on_outlined),
                  title: Text(_language == '日本語' ? 'あなたのポイント' : 'Your Points'),
                  onPressed: (context) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const UserPointPage()));
                  },
                ),
              ],
            ),
            SettingsSection(
              title: Text(_language == '日本語' ? '利用について' : 'About usage'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(Icons.insert_chart_outlined),
                  title: Text(
                      _language == '日本語' ? 'ポイントの貯め方' : 'How to save points'),
                  onPressed: (context) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => PointManual()));
                  },
                ),
                SettingsTile.navigation(
                  leading: const Icon(Icons.money),
                  onPressed: (context) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => PresentListScreen()));
                  },
                  title: Text(
                    _language == '日本語' ? 'ポイント交換' : 'Change of points',
                  ),
                ),
                SettingsTile.navigation(
                  leading: const Icon(Icons.book_outlined),
                  title: Text(_language == '日本語'
                      ? 'ポイント利用規約'
                      : 'Terms of use for points'),
                  onPressed: (context) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => TermsScreen()));
                  },
                ),
                SettingsTile.navigation(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(
                      _language == '日本語' ? 'プライバシーポリシー' : 'Privacy Policy'),
                  value: const Text(''),
                  onPressed: (context) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => PrivacyPolicyScreen()));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
