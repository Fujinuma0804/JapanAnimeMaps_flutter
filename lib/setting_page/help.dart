import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';

import '../help_page/mail_sender.dart';

class HelpCenter extends StatelessWidget {
  const HelpCenter({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'ヘルプセンター',
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
            title: const Text('お問い合わせ方法'),
            tiles: <SettingsTile>[
              SettingsTile.navigation(
                leading: const Icon(Icons.mail_outline_rounded),
                title: const Text('メールで問い合わせ'),
                value: const Text(''),
                onPressed: (context) {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => MailScreen()));
                  // 画面遷移処理
                },
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.chat_outlined),
                title: const Text('チャットで問い合わせ'),
                value: const Text(''),
                onPressed: (context) {
                  // 画面遷移処理
                },
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.phone),
                title: const Text('電話で問い合わせ'),
                value: const Text(''),
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
