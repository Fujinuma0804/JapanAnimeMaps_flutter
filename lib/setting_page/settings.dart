// settings.dart
import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';

import '../manual_page/privacypolicy_screen.dart';
import '../manual_page/terms_screen.dart';
import '../profile_page/profile.dart';

class Settings extends StatelessWidget {
  const Settings({Key? key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => ProfileScreen()));
                  // 画面遷移処理
                },
              ),
            ],
          ),
          SettingsSection(
            title: const Text('一般'),
            tiles: <SettingsTile>[
              SettingsTile.navigation(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('通知'),
                value: const Text('オン'),
                onPressed: (context) {
                  // 画面遷移処理
                },
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.language),
                title: const Text('言語設定'),
                value: const Text('日本語'),
                onPressed: (context) {
                  // 画面遷移処理
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
                  // 画面遷移処理
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
                  // 画面遷移処理
                },
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('アプリについて'),
                value: const Text(''),
                onPressed: (context) {
                  // 画面遷移処理
                },
              ),
            ],
          ),
          SettingsSection(
            tiles: <SettingsTile>[
              SettingsTile.navigation(
                leading: const Icon(Icons.waving_hand_sharp),
                title: const Text('サインアウト'),
                onPressed: (context) {
                  // 画面遷移処理
                },
              ),
              SettingsTile.navigation(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                ),
                title: const Text(
                  'アカウント削除',
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
                onPressed: (context) {
                  // 画面遷移処理
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
