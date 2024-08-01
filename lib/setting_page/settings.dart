import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../apps_about/apps_about.dart';
import '../help_page/help.dart';
import '../manual_page/privacypolicy_screen.dart';
import '../manual_page/terms_screen.dart';
import '../notification/notification.dart';
import '../profile_page/profile.dart';
import '../src/analytics_repository.dart';
import '../top_page/welcome_page.dart';

class Settings extends StatefulWidget {
  const Settings({Key? key}) : super(key: key);

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  String _language = '日本語';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _language = prefs.getString('language') ?? '日本語';
    });
  }

  Future<void> _saveLanguagePreference(String language) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);
  }

  Future<void> _updateUserLanguageInFirestore(String language) async {
    User? user = _auth.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'language': language});
    }
  }

  void _changeLanguage(String language) {
    setState(() {
      _language = language;
    });
    _saveLanguagePreference(language);
    _updateUserLanguageInFirestore(language);
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Column(children: [
            Text('言語設定'),
            Text(
              '変更後はアプリを再起動してください。',
              style: TextStyle(
                color: Colors.black,
                fontSize: 15.0,
              ),
            )
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('日本語'),
                onTap: () {
                  _changeLanguage('日本語');
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('English'),
                onTap: () {
                  _changeLanguage('English');
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text(
            '設定',
            style: TextStyle(
              color: Color(0xFF00008b),
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        body: SettingsList(
          sections: [
            SettingsSection(
              title: const Text('個人情報'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(Icons.account_circle),
                  title: const Text('プロフィール'),
                  value: const Text(''),
                  onPressed: (context) {
                    AnalyticsService().logPage('ProfileScreen');
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ProfileScreen()));
                    // 画面遷移処理
                  },
                ),
              ],
            ),
            SettingsSection(
              title: const Text('一般'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(Icons.language),
                  title: const Text('言語設定'),
                  value: Text(_language),
                  onPressed: (context) {
                    _showLanguageDialog(context);
                  },
                ),
              ],
            ),
            SettingsSection(
              title: const Text('アプリ情報'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(Icons.circle_notifications),
                  title: const Text('お知らせ'),
                  value: const Text(''),
                  onPressed: (context) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => NotificationsPage()));
                  },
                ),
                SettingsTile.navigation(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('プライバシーポリシー'),
                  value: const Text(''),
                  onPressed: (context) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => PrivacyPolicyScreen()));
                    // 画面遷移処理
                  },
                ),
                SettingsTile.navigation(
                  leading: const Icon(Icons.book_outlined),
                  title: const Text('利用規約'),
                  value: const Text(''),
                  onPressed: (context) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => TermsScreen()));
                    // 画面遷移処理
                  },
                ),
                SettingsTile.navigation(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('ヘルプセンター'),
                  value: const Text(''),
                  onPressed: (context) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => HelpCenter()));
                    // 画面遷移処理
                  },
                ),
                SettingsTile.navigation(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('アプリについて'),
                  value: const Text(''),
                  onPressed: (context) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => AppsAbout()));
                    // 画面遷移処理
                  },
                ),
              ],
            ),
            SettingsSection(
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(
                    Icons.waving_hand_sharp,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'サインアウト',
                    style: TextStyle(
                      color: Colors.red,
                    ),
                  ),
                  onPressed: (context) async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => WelcomePage()),
                    );
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
