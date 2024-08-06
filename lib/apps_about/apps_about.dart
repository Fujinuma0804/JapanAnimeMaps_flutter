import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:parts/apps_about/license.dart';
import 'package:settings_ui/settings_ui.dart';

class AppsAbout extends StatefulWidget {
  const AppsAbout({Key? key}) : super(key: key);

  @override
  _AppsAboutState createState() => _AppsAboutState();
}

class _AppsAboutState extends State<AppsAbout> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _getAppVersion();
  }

  Future<void> _getAppVersion() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
    });
  }

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
                value: Text(_version),
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
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
