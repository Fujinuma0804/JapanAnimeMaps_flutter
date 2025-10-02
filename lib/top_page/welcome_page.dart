import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:parts/login_page/login_page.dart';
import 'package:parts/login_page/mail_sign_up1.dart';
import 'package:parts/login_page/sign_up.dart';
import 'package:parts/src/bottomnavigationbar.dart';
import 'package:url_launcher/url_launcher.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({Key? key}) : super(key: key);

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _forceUpdateMessage = '';
  String _updateUrl = '';
  bool _isMaintenanceMode = false;
  String _maintenanceMessage = '';
  bool _needsUpdate = false;
  bool _isLoading = true;

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

    if (_isMaintenanceMode) {
      _showMaintenanceDialog();
    } else if (_needsUpdate) {
      _showUpdateDialog();
    } else {
      _checkAuthState();
    }
  }

  Future<void> _checkAuthState() async {
    User? user = _auth.currentUser;

    setState(() {
      _isLoading = false;
    });

    if (user != null) {
      _navigateToMainScreen();
    } else {
      _navigateToSignUpPage();
    }
  }

  void _navigateToMainScreen() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MainScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return child;
        },
      ),
    );
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
    try {
      // バージョン文字列が空ではないことを確認
      if (minRequiredVersion.isEmpty) {
        print('Warning: minRequiredVersion is empty');
        return false;
      }

      // デバッグ情報の出力
      print('Comparing versions - Current: "$currentVersion", Required: "$minRequiredVersion"');

      // バージョンを分割
      List<String> currentParts = currentVersion.split('.');
      List<String> requiredParts = minRequiredVersion.split('.');

      // 各部分を整数に変換（安全に）
      List<int> current = [];
      List<int> required = [];

      // 現在のバージョンを処理
      for (String part in currentParts) {
        if (int.tryParse(part) != null) {
          current.add(int.parse(part));
        } else {
          current.add(0);
          print('Warning: Non-numeric version part in currentVersion: $part');
        }
      }

      // 必要なバージョンを処理
      for (String part in requiredParts) {
        if (int.tryParse(part) != null) {
          required.add(int.parse(part));
        } else {
          required.add(0);
          print('Warning: Non-numeric version part in minRequiredVersion: $part');
        }
      }

      // 長さを確保（足りない場合は0で埋める）
      while (current.length < 3) current.add(0);
      while (required.length < 3) required.add(0);

      // バージョン比較（最大3要素まで）
      for (int i = 0; i < 3; i++) {
        if (current[i] < required[i]) return true;
        if (current[i] > required[i]) return false;
      }

      return false;
    } catch (e) {
      print('Error in version comparison: $e');
      // エラーが発生した場合はアップデートなしと判断
      return false;
    }
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

  void _navigateToSignUpPage() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return child;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            Center(
              child: LoadingAnimationWidget.staggeredDotsWave(
                color: const Color(0xFF00008b),
                size: 100,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
