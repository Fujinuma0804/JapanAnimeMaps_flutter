import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parts/manual_page/usage_screen.dart';
import 'package:settings_ui/settings_ui.dart';

import '../setting_page/settings_en.dart';
import '../web_page/website.dart';
import '../web_page/website_en.dart';

class ManualEn extends StatefulWidget {
  const ManualEn({Key? key});

  @override
  _ManualEnState createState() => _ManualEnState();
}

class _ManualEnState extends State<ManualEn> {
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
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text(
            _language == '日本語' ? 'その他' : 'Others',
            style: TextStyle(
              color: Color(0xFF00008b),
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: SettingsList(
          lightTheme: SettingsThemeData(),
          sections: [
            SettingsSection(
              title: Text(_language == '日本語' ? '設定' : 'Settings'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(_language == '日本語' ? '設定' : 'Settings'),
                  value: const Text(''),
                  onPressed: (context) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SettingsEn()),
                    );
                  },
                ),
              ],
            ),
            SettingsSection(
              title: Text(_language == '日本語' ? '利用方法' : 'How to Use'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(Icons.bookmarks_sharp),
                  title: Text(_language == '日本語' ? '利用方法' : 'How to Use'),
                  value: const Text('現在調整中…'),
                  onPressed: (context) {
                    // Navigator.push(context,
                    //     MaterialPageRoute(builder: (context) => UsageScreen()));
                  },
                ),
              ],
            ),
            SettingsSection(
              title: Text(_language == '日本語' ? '公式' : 'Official'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(Icons.phonelink),
                  title: Text(_language == '日本語' ? '公式サイト' : 'Official Site'),
                  value: const Text(''),
                  onPressed: (context) {
                    // 現在のユーザーを取得
                    User? user = _auth.currentUser;
                    if (user != null) {
                      // Firestoreからユーザーのlanguage設定を取得
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .get()
                          .then((snapshot) {
                        if (snapshot.exists) {
                          String language =
                              snapshot.data()?['language'] ?? 'English';
                          // 言語に応じて適切な画面に遷移
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => language == 'Japanese'
                                  ? WebsiteScreen()
                                  : WebsiteEnScreen(),
                            ),
                          );
                        }
                      });
                    }
                  },
                ),
              ],
            ),
            // SettingsSection(
            //   title: Text(_language == '日本語' ? '有料プラン' : 'Paid plan'),
            //   tiles: <SettingsTile>[
            //     SettingsTile.navigation(
            //       leading: const Icon(Icons.payment_rounded),
            //       title: Text(_language == '日本語' ? '広告を非表示にする' : 'Hide ads'),
            //       value: const Text(''),
            //       onPressed: (context) {
            //         Navigator.push(
            //             context,
            //             MaterialPageRoute(
            //                 builder: (context) => PaymentScreen()));
            //       },
            //     ),
            //   ],
            // ),
          ],
        ),
      ),
    );
  }
}
