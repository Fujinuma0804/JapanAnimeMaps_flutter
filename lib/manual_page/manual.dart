// manual.dart
import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';

import '../setting_page/settings.dart';

class Manual extends StatelessWidget {
  const Manual({Key? key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text(
            'その他',
            style: TextStyle(
              color: Color(0xFF00008b),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SettingsList(
          sections: [
            SettingsSection(
              title: const Text('設定'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('設定'),
                  value: const Text(''),
                  onPressed: (context) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => Settings()),
                    );
                  },
                ),
              ],
            ),
            SettingsSection(
              title: const Text('利用方法'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(Icons.bookmarks_sharp),
                  title: const Text('利用方法'),
                  value: const Text(''),
                  onPressed: (context) {
                    // 画面遷移処理
                  },
                ),
              ],
            ),
            SettingsSection(
              title: const Text('ポイント'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(Icons.monetization_on_outlined),
                  title: const Text('ポイントについて'),
                  value: const Text(''),
                  onPressed: (context) {
                    // 画面遷移処理
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
