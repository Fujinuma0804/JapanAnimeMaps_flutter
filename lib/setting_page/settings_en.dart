import 'dart:async';

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
import '../profile_page/profile_en.dart';
import '../top_page/welcome_page.dart';

class SettingsEn extends StatefulWidget {
  const SettingsEn({Key? key}) : super(key: key);

  @override
  _SettingsEnState createState() => _SettingsEnState();
}

class _SettingsEnState extends State<SettingsEn> {
  String _language = '日本語';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late StreamSubscription<DocumentSnapshot> _languageSubscription;

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    _monitorLanguageChange();
  }

  @override
  void dispose() {
    _languageSubscription.cancel();
    super.dispose();
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
      _language = language == 'Japanese' ? '日本語' : 'English';
    });
    _saveLanguagePreference(_language);
    _updateUserLanguageInFirestore(language);
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Column(children: [
            Text(_language == '日本語' ? '言語設定' : 'Language Settings'),
            Text(
              _language == '日本語'
                  ? '変更後はアプリを再起動してください。'
                  : 'Please restart the app after making changes.',
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
                  _changeLanguage('Japanese');
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

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => WelcomePage(),
        settings: RouteSettings(name: '/welcome'),
      ),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
              _language == '日本語' ? 'アカウント削除の確認' : 'Confirm Account Deletion'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(_language == '日本語'
                    ? '本当にアカウントを削除しますか？'
                    : 'Are you sure you want to delete your account?'),
                Text(_language == '日本語'
                    ? 'この操作は取り消すことができません。'
                    : 'This action cannot be undone.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(_language == '日本語' ? 'キャンセル' : 'Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text(_language == '日本語' ? '削除' : 'Delete'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();
    }
  }

  Future<void> _deleteUserAuth() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.delete();
    }
  }

  Future<void> _deleteAccount() async {
    try {
      await _deleteUserData();
      await _deleteUserAuth();

      // コンテキストが有効かチェック
      if (!mounted) return;

      // 削除成功後、ウェルカームページへ遷移
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => WelcomePage()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      // コンテキストが有効かチェック
      if (!mounted) return;

      // エラーハンドリング
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_language == '日本語'
              ? 'アカウントの削除に失敗しました。再度お試しください。'
              : 'Failed to delete account. Please try again.'),
        ),
      );
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
            _language == '日本語' ? '設定' : 'Settings',
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
              title: Text(_language == '日本語' ? '個人情報' : 'Personal Information'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(Icons.account_circle),
                  title: Text(_language == '日本語' ? 'プロフィール' : 'Profile'),
                  value: const Text(''),
                  onPressed: (context) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ProfileEnScreen()));
                  },
                ),
              ],
            ),
            SettingsSection(
              title: Text(_language == '日本語' ? '一般' : 'General'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(Icons.language),
                  title:
                      Text(_language == '日本語' ? '言語設定' : 'Language Settings'),
                  value: Text(_language),
                  onPressed: (context) {
                    _showLanguageDialog(context);
                  },
                ),
              ],
            ),
            SettingsSection(
              title: Text(_language == '日本語' ? 'このアプリについて' : 'About This App'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(Icons.circle_notifications),
                  title: Text(_language == '日本語' ? 'お知らせ' : 'Notice'),
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
                SettingsTile.navigation(
                  leading: const Icon(Icons.book_outlined),
                  title: Text(_language == '日本語' ? '利用規約' : 'Terms of Service'),
                  value: const Text(''),
                  onPressed: (context) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => TermsScreen()));
                  },
                ),
                SettingsTile.navigation(
                  leading: const Icon(Icons.help_outline),
                  title: Text(_language == '日本語' ? 'ヘルプセンター' : 'Help Center'),
                  value: const Text(''),
                  onPressed: (context) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => HelpCenter()));
                  },
                ),
                SettingsTile.navigation(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(
                      _language == '日本語' ? 'このアプリについて' : 'About This Apps'),
                  value: const Text(''),
                  onPressed: (context) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => AppsAbout()));
                  },
                ),
              ],
            ),
            SettingsSection(
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(
                    Icons.logout,
                    color: Colors.black,
                  ),
                  title: Text(
                    _language == '日本語' ? 'サインアウト' : 'Sign Out',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: (context) async {
                    await _signOut(context);
                  },
                ),
                SettingsTile.navigation(
                  leading: const Icon(
                    Icons.waving_hand_sharp,
                    color: Colors.red,
                  ),
                  title: Text(
                    _language == '日本語' ? 'アカウント削除' : 'Delete Account',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: (context) {
                    _showDeleteAccountDialog();
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
