import 'package:flutter/material.dart';
import 'package:parts/apps_about/license.dart';
import 'package:settings_ui/settings_ui.dart';

class AppsAbout extends StatelessWidget {
  const AppsAbout({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'アプリについて',
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
            title: Text(
              'アプリについて',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            tiles: <SettingsTile>[
              SettingsTile(
                title: const Text('バージョン'),
                leading: const Icon(Icons.info_outline),
                value: Text(''),
              ),
            ],
          ),
          SettingsSection(
            title: const Text('アプリについて'),
            tiles: <SettingsTile>[
              SettingsTile.navigation(
                leading: const Icon(Icons.payment_rounded),
                title: const Text('ライセンス'),
                value: const Text(''),
                onPressed: (context) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MyLicensePage()),
                  );
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
