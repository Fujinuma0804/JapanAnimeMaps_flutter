import 'package:flutter/material.dart';
import 'package:parts/point_page/point_manual.dart';
import 'package:parts/point_page/user_point.dart';
import 'package:settings_ui/settings_ui.dart';

import '../manual_page/privacypolicy_screen.dart';
import '../manual_page/terms_screen.dart';
import 'chenged_point.dart';

class PointEnPage extends StatelessWidget {
  const PointEnPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text(
            'About Points',
            style: TextStyle(
              color: Color(0xFF00008b),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SettingsList(
          sections: [
            SettingsSection(
              title: const Text('Point'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(Icons.monetization_on_outlined),
                  title: const Text('Your Points'),
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
              title: const Text('About usage'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(Icons.insert_chart_outlined),
                  title: const Text('How to save points'),
                  onPressed: (context) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => PointManual()));
                  },
                ),
                SettingsTile.navigation(
                  leading: const Icon(Icons.money),
                  onPressed: (context) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => PresentListScreen()));
                  },
                  title: const Text(
                    'Use of points',
                  ),
                ),
                SettingsTile.navigation(
                  leading: const Icon(Icons.book_outlined),
                  title: const Text('Terms of use for points'),
                  onPressed: (context) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => TermsScreen()));
                    // 画面遷移処理
                  },
                ),
                SettingsTile.navigation(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
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
      ),
    );
  }
}
