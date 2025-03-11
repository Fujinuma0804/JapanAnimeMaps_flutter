import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:parts/shop/purchase_agency.dart';
import 'package:parts/shop/shop_product_detail.dart';
import 'package:parts/src/bottomnavigationbar.dart';
import 'package:parts/top_page/welcome_page.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  // Flutter binding初期化
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // デバッグ: アプリバージョンの取得と表示
    final packageInfo = await PackageInfo.fromPlatform();
    print('App version: ${packageInfo.version}');
    print('Build number: ${packageInfo.buildNumber}');

    // Stripeの初期化
    Stripe.publishableKey = 'pk_test_51QeIPUJR2jw9gpdILTofRSwaBs9pKKXfOse9EcwQTkfYNjtYb1rNsahb5uhm6QjcwzvGOhcZ0ZZgjW09HKtblHnH00Ps1dt4ZZ';

    // iOSのApple Pay設定
    if (Platform.isIOS) {
      Stripe.merchantIdentifier = 'merchant.com.sotakawakami.jam';
    }

    // Stripe設定の適用
    await Stripe.instance.applySettings();

    print('Stripe initialized successfully'); // デバッグログ追加

    // RevenueCatの初期化
    await initPlatformState();

    // Firebase と AdMob の初期化
    await Future.wait([
      Firebase.initializeApp(),
      MobileAds.instance.initialize(),
    ]);

    // Firebase Remote Configの初期化
    await initRemoteConfig();

    runApp(const MyApp());
  } catch (e) {
    print('Initialization error: $e'); // エラーログ
    // エラーが発生してもアプリを起動
    runApp(const MyApp());
  }
}

// Firebase Remote Configの初期化
Future<void> initRemoteConfig() async {
  final remoteConfig = FirebaseRemoteConfig.instance;
  await remoteConfig.setConfigSettings(RemoteConfigSettings(
    fetchTimeout: const Duration(minutes: 1),
    minimumFetchInterval: const Duration(hours: 1),
  ));

  // デフォルト値の設定
  await remoteConfig.setDefaults({
    'min_version_code': '1',
    'min_version_name': '1.0.0',
    'update_url_android': 'https://play.google.com/store/apps/details?id=com.sotakawakami.jam',
    'update_url_ios': 'https://apps.apple.com/app/japananimemaps/idXXXXXXXXXX',
    'update_message': 'アプリの新しいバージョンが利用可能です。アップデートしてください。',
    'update_title': 'アップデートのお知らせ',
    'force_update': false,
  });

  try {
    // リモート設定を取得
    await remoteConfig.fetchAndActivate();
    print('Remote config fetched successfully');
  } catch (e) {
    print('Remote config fetch failed: $e');
  }
}

Future<void> initPlatformState() async {
  await Purchases.setLogLevel(LogLevel.debug);

  try {
    // RevenueCatの設定
    final configuration =
    PurchasesConfiguration("appl_JfvzIYYEgsMeXVzavJRBnCnlKPS");

    await Purchases.configure(configuration);
    print('RevenueCat initialized successfully');

    // 設定の確認
    await _validateConfiguration();
  } catch (e) {
    print('RevenueCat initialization failed: $e');
  }
}

Future<void> _validateConfiguration() async {
  try {
    // オファリングの確認
    final offerings = await Purchases.getOfferings();
    print('\n=== RevenueCat Configuration Status ===');
    print('Current Offering: ${offerings.current?.identifier ?? "None"}');

    if (offerings.current != null) {
      print('\nAvailable Packages:');
      for (final package in offerings.current!.availablePackages) {
        print('- Package: ${package.identifier}');
        print('  Product: ${package.storeProduct.identifier}');
        print('  Price: ${package.storeProduct.priceString}');
      }
    } else {
      print('\n⚠️ No offerings available. Please check:');
      print('1. App Store Connect configuration');
      print('2. RevenueCat dashboard settings');
      print('3. Bundle ID matches');
      print('4. In-App Purchase capability is enabled');
    }

    // ユーザー情報の確認
    final customerInfo = await Purchases.getCustomerInfo();
    print('\nCustomer Info:');
    print('User ID: ${customerInfo.originalAppUserId}');
    print('Active Entitlements: ${customerInfo.entitlements.active.keys}');
  } catch (e) {
    print('Configuration validation failed: $e');
  }
}

// iOS Sandbox環境の設定
Future<void> _configureIOSSandbox() async {
  try {
    // サンドボックス環境用の設定
    print('Configuring iOS Sandbox environment');

    // アプリのバージョンとビルド番号を取得
    final packageInfo = await PackageInfo.fromPlatform();
    print('App version: ${packageInfo.version}');
    print('Build number: ${packageInfo.buildNumber}');

    // サンドボックステスト用の情報を出力
    print('⚠️ Running in iOS Sandbox mode');
    print('Make sure to:');
    print('1. Use a Sandbox tester account');
    print('2. Sign out of regular Apple ID in Settings');
    print('3. Clean install the app if needed');
  } catch (e) {
    print('Error configuring iOS Sandbox: $e');
  }
}

// Android Test環境の設定
Future<void> _configureAndroidTest() async {
  try {
    print('Configuring Android Test environment');

    // アプリのバージョンとビルド番号を取得
    final packageInfo = await PackageInfo.fromPlatform();
    print('App version: ${packageInfo.version}');
    print('Build number: ${packageInfo.buildNumber}');

    // テスト用の情報を出力
    print('⚠️ Running in Android Test mode');
    print('Make sure to:');
    print('1. Use a test account');
    print('2. Install app from internal test track');
    print('3. Clear Play Store cache if needed');
  } catch (e) {
    print('Error configuring Android Test: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: {
        '/product_purchase_agency': (context) => ConfirmationScreen(),
        '/product_detail': (context) => ProductDetailScreen(),
      },
      debugShowCheckedModeBanner: false,
      title: 'JapanAnimeMaps',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _authStatus = 'Unknown';
  bool _isInitialized = false;
  String? _initError;
  bool _updateRequired = false;
  String _updateMessage = '';
  String _updateTitle = '';
  String _updateUrl = '';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // デバッグ: アプリバージョンの取得と表示
      final packageInfo = await PackageInfo.fromPlatform();
      if (kDebugMode) {
        print('Debug - App version: ${packageInfo.version}');
        print('Debug - Build number: ${packageInfo.buildNumber}');
      }

      // バージョンチェック
      final shouldUpdate = await _checkForceUpdate(
        currentVersion: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
      );

      if (shouldUpdate) {
        setState(() {
          _updateRequired = true;
        });
        return;
      }

      // ATTダイアログの表示
      await _requestTrackingPermission();

      // RevenueCatとFirebaseの同期
      await _syncRevenueCatUser();

      setState(() {
        _isInitialized = true;
      });

      await _navigateToNextScreen();
    } catch (e) {
      setState(() {
        _initError = e.toString();
      });
      print('Initialization error: $e');
    }
  }

  Future<bool> _checkForceUpdate({
    required String currentVersion,
    required String buildNumber,
  }) async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;

      // 必要なバージョン情報を取得
      final minVersionName = remoteConfig.getString('min_version_name');
      final minVersionCode = remoteConfig.getString('min_version_code');
      final forceUpdate = remoteConfig.getBool('force_update');

      // 更新メッセージを取得
      _updateTitle = remoteConfig.getString('update_title');
      _updateMessage = remoteConfig.getString('update_message');

      // プラットフォーム別のURLを取得
      _updateUrl = Platform.isIOS
          ? remoteConfig.getString('update_url_ios')
          : remoteConfig.getString('update_url_android');

      if (kDebugMode) {
        print('Current version: $currentVersion (build $buildNumber)');
        print('Minimum version: $minVersionName (build $minVersionCode)');
        print('Force update: $forceUpdate');
      }

      // バージョンコードで比較（ビルド番号）
      if (forceUpdate && int.parse(buildNumber) < int.parse(minVersionCode)) {
        print('Update required: Current build $buildNumber < Required build $minVersionCode');
        return true;
      }

      // バージョン名で比較（例: 1.0.0 < 1.0.1）
      if (forceUpdate && _compareVersions(currentVersion, minVersionName) < 0) {
        print('Update required: Current version $currentVersion < Required version $minVersionName');
        return true;
      }

      return false;
    } catch (e) {
      print('Error checking for update: $e');
      return false;
    }
  }

  // セマンティックバージョニング比較用のヘルパーメソッド
  int _compareVersions(String version1, String version2) {
    List<int> v1Parts = version1.split('.').map(int.parse).toList();
    List<int> v2Parts = version2.split('.').map(int.parse).toList();

    // パディングして同じ長さにする
    while (v1Parts.length < v2Parts.length) v1Parts.add(0);
    while (v2Parts.length < v1Parts.length) v2Parts.add(0);

    // 各セグメントを比較
    for (int i = 0; i < v1Parts.length; i++) {
      if (v1Parts[i] < v2Parts[i]) return -1;
      if (v1Parts[i] > v2Parts[i]) return 1;
    }
    return 0;
  }

  Future<void> _syncRevenueCatUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // RevenueCatにユーザーIDを同期
        await Purchases.logIn(user.uid);
        if (kDebugMode) {
          print('RevenueCat user synced: ${user.uid}');
        }

        // 購読状態を確認
        final customerInfo = await Purchases.getCustomerInfo();
        if (kDebugMode) {
          print('Customer Info: ${customerInfo.originalAppUserId}');
          print('Active subscriptions: ${customerInfo.activeSubscriptions}');
          print('Active entitlements: ${customerInfo.entitlements.active}');
        }
      }
    } catch (e) {
      print('RevenueCat user sync failed: $e');
    }
  }

  Future<void> _requestTrackingPermission() async {
    if (Platform.isIOS) {
      try {
        final status =
        await AppTrackingTransparency.trackingAuthorizationStatus;

        if (status == TrackingStatus.notDetermined) {
          await Future.delayed(const Duration(milliseconds: 200));
          final TrackingStatus newStatus =
          await AppTrackingTransparency.requestTrackingAuthorization();
          setState(() {
            _authStatus = newStatus.toString();
          });
          if (kDebugMode) {
            print('Tracking authorization status: $newStatus');
          }
        }
      } catch (e) {
        print('Tracking permission request failed: $e');
      }
    }
  }

  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;

    await Future.delayed(const Duration(seconds: 1));
    _checkAuthState();
  }

  void _checkAuthState() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (!mounted) return;

      if (user != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => MainScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const WelcomePage()),
        );
      }
    });
  }

  Future<void> _launchAppStore() async {
    if (_updateUrl.isEmpty) return;

    final Uri uri = Uri.parse(_updateUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        print('Could not launch $uri');
      }
    } catch (e) {
      print('Error launching URL: $e');
    }
  }

  // iOSスタイルのアップデートダイアログを表示
  void _showIOSStyleUpdateDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(
            _updateTitle.isNotEmpty ? _updateTitle : 'アップデートが必要です',
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _updateMessage.isNotEmpty ? _updateMessage : 'アプリの新しいバージョンが利用可能です。ストアからアップデートしてください。',
            ),
          ),
          actions: <Widget>[
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.of(context).pop();
                _launchAppStore();
              },
              child: const Text('今すぐアップデート'),
            ),
            if (kDebugMode)
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _updateRequired = false;
                  });
                  _initializeApp();
                },
                child: const Text('デバッグ: スキップ'),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // アップデートが必要な場合のiOSスタイルダイアログ
    if (_updateRequired) {
      // ビルド後にダイアログを表示するためのポストフレームコールバック
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showIOSStyleUpdateDialog(context);
      });

      // 基本的なスプラッシュ画面を背景として表示
      return Scaffold(
        body: WillPopScope(
          onWillPop: () async => false, // 戻るボタンを無効化
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('初期化中...'),
              ],
            ),
          ),
        ),
      );
    }

    // 初期化エラーの場合
    if (_initError != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('初期化エラー'),
              Text(_initError!, style: const TextStyle(color: Colors.red)),
              ElevatedButton(
                onPressed: _initializeApp,
                child: const Text('再試行'),
              ),
            ],
          ),
        ),
      );
    }

    // 通常のスプラッシュ画面
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            if (!_isInitialized) ...[
              const SizedBox(height: 20),
              const Text('初期化中...'),
              if (kDebugMode) ...[
                const SizedBox(height: 10),
                Text('動作モード: ${Platform.isIOS ? 'iOS Sandbox' : 'Android Test'}'),
              ],
            ],
          ],
        ),
      ),
    );
  }
}