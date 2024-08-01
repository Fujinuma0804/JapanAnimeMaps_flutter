import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parts/point_page/point_manual.dart';
import 'package:parts/point_page/user_point.dart';
import 'package:settings_ui/settings_ui.dart';

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
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text(
            _language == '日本語' ? 'ポイントについて' : 'About Points',
            style: TextStyle(
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
                    _language == '日本語' ? 'ポイントの使い方' : 'Use of points',
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
