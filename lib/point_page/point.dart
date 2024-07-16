import 'package:flutter/material.dart';
import 'package:parts/point_page/user_point.dart';
import 'package:settings_ui/settings_ui.dart';

import '../manual_page/privacypolicy_screen.dart';
import '../manual_page/terms_screen.dart';

class PointPage extends StatelessWidget {
  const PointPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'ポイントについて',
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
            title: const Text('ポイント'),
            tiles: <SettingsTile>[
              SettingsTile.navigation(
                leading: const Icon(Icons.monetization_on_outlined),
                title: const Text('ポイント数'),
                onPressed: (context) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const UserPointPage()));
                  // 画面遷移処理
                },
              ),
            ],
          ),
          SettingsSection(
            title: const Text('利用について'),
            tiles: <SettingsTile>[
              SettingsTile.navigation(
                leading: const Icon(Icons.insert_chart_outlined),
                title: const Text('ポイントの貯め方'),
                onPressed: (context) {},
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.money),
                value: const Text(
                  '準備中…',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                onPressed: (context) {
                  // 画面遷移処理
                },
                title: const Text(
                  'ポイントの利用方法',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.book_outlined),
                title: const Text('ポイント利用規約'),
                onPressed: (context) {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => TermsScreen()));
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
            ],
          ),
        ],
      ),
    );
  }
}
