import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:parts/login_page/sign_up.dart';
import 'package:url_launcher/url_launcher.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({Key? key}) : super(key: key);

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _forceUpdateMessage = '';
  String _updateUrl = '';
  bool _isMaintenanceMode = false;
  String _maintenanceMessage = '';
  bool _needsUpdate = false;

  @override
  void initState() {
    super.initState();
    _initializeRemoteConfig();
  }

  Future<void> _initializeRemoteConfig() async {
    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));

    await _remoteConfig.fetchAndActivate();

    setState(() {
      _forceUpdateMessage = _remoteConfig.getString('force_update_message');
      _updateUrl = Theme.of(context).platform == TargetPlatform.iOS
          ? _remoteConfig.getString('update_url_ios')
          : _remoteConfig.getString('update_url_android');
      _isMaintenanceMode = _remoteConfig.getBool('is_maintenance_mode');
      _maintenanceMessage = _remoteConfig.getString('maintenance_message');
    });

    await _checkForUpdate();

    // Remote Configの設定に基づいてダイアログを表示
    if (_isMaintenanceMode) {
      _showMaintenanceDialog();
    } else if (_needsUpdate) {
      _showUpdateDialog();
    }
  }

  Future<void> _checkForUpdate() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String currentVersion = packageInfo.version;

    String minRequiredVersion = _remoteConfig.getString('min_required_version');

    setState(() {
      _needsUpdate = _isUpdateRequired(currentVersion, minRequiredVersion);
    });
  }

  bool _isUpdateRequired(String currentVersion, String minRequiredVersion) {
    List<int> current = currentVersion.split('.').map(int.parse).toList();
    List<int> required = minRequiredVersion.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      if (current[i] < required[i]) return true;
      if (current[i] > required[i]) return false;
    }

    return false;
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('アップデートが必要です'),
          content: Text(_forceUpdateMessage),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'アップデートする',
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
              onPressed: () {
                _launchAppStore();
              },
            ),
          ],
        );
      },
    );
  }

  void _showMaintenanceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('メンテナンス中'),
          content: Text(_maintenanceMessage),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _launchAppStore() async {
    if (await canLaunch(_updateUrl)) {
      await launch(_updateUrl);
    } else {
      throw 'Could not launch $_updateUrl';
    }
  }

  void _handleStartButtonPress() {
    if (_isMaintenanceMode) {
      _showMaintenanceDialog();
    } else if (_needsUpdate) {
      _showUpdateDialog();
    } else {
      _navigateToSignUpPage();
    }
  }

  void _navigateToSignUpPage() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SignUpPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return child; // No transition animation
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/welcome.png',
                fit: BoxFit.cover,
              ),
            ),
            Center(
              child: TextButton(
                onPressed: _handleStartButtonPress,
                child: const Text(
                  'start',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
