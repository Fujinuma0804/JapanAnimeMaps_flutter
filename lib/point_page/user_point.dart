import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';

import '../profile_page/profile.dart';

class UserPointPage extends StatelessWidget {
  const UserPointPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'ポイント数',
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
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => ProfileScreen()));
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
