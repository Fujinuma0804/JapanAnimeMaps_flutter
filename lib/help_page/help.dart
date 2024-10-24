import 'package:flutter/material.dart';
import 'package:parts/setting_page/q_a.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../loading_code/loading_code_top.dart';
import 'mail_sender.dart';

class HelpCenter extends StatelessWidget {
  const HelpCenter({Key? key}) : super(key: key);

  Future<void> _launchURL() async {
    const url = 'https://page.line.me/446sszel';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

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
            title: const Text('よくあるご質問'),
            tiles: <SettingsTile>[
              SettingsTile.navigation(
                leading: const Icon(Icons.question_mark),
                title: const Text('よくあるご質問を確認'),
                value: const Text(''),
                onPressed: (context) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => QA()),
                  );
                  // 画面遷移処理
                },
              ),
            ],
          ),
          SettingsSection(
            title: const Text('お問い合わせ方法'),
            tiles: <SettingsTile>[
              SettingsTile.navigation(
                leading: const Icon(Icons.mail_outline_rounded),
                title: const Text('メールで問い合わせ'),
                value: const Text(''),
                onPressed: (context) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MailScreen()),
                  );
                  // 画面遷移処理
                },
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.question_answer_outlined),
                title: const Text(
                  'チャットで問い合わせ',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                value: const Text(
                  '準備中…',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                onPressed: (context) {
                  // final User? currentUser = FirebaseAuth.instance.currentUser;
                  // if (currentUser != null) {
                  //   Navigator.push(
                  //     context,
                  //     MaterialPageRoute(
                  //       builder: (context) => ChatRoom(
                  //         userId: currentUser.uid,
                  //       ),
                  //     ),
                  //   );
                  // } else {
                  //   ScaffoldMessenger.of(context).showSnackBar(
                  //     const SnackBar(
                  //       content: Text('ログインが必要です'),
                  //     ),
                  //   );
                  // }
                  // 画面遷移処理
                },
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.chat),
                title: const Text('LINEで問い合わせ'),
                value: const Text(''),
                onPressed: (context) {
                  _launchURL();
                  // 画面遷移処理
                },
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.phone),
                title: const Text(
                  '電話で問い合わせ',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                value: const Text(
                  '準備中…',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                onPressed: (context) {
                  // 画面遷移処理
                },
              ),
            ],
          ),
          SettingsSection(
            title: const Text('その他'),
            tiles: <SettingsTile>[
              SettingsTile.navigation(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('コード読み込み'),
                value: const Text(''),
                onPressed: (context) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoadingCodeTop()),
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
