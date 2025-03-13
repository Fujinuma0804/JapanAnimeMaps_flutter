import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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

void main() async {
  // Flutter binding初期化
  WidgetsFlutterBinding.ensureInitialized();

  try {
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

    runApp(const MyApp());
  } catch (e) {
    print('Initialization error: $e'); // エラーログ
    // エラーが発生してもアプリを起動
    runApp(const MyApp());
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

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // ATTダイアログの表示
      await _requestTrackingPermission();

      // RevenueCatとFirebaseの同期
      await _syncRevenueCatUser();

      setState(() {
        _isInitialized = true;
      });

      // 少し待機して確実に初期化を完了させる
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        // 直接認証状態を確認
        final user = FirebaseAuth.instance.currentUser;
        print('Current user: ${user?.uid ?? "No user"}');

        if (user != null) {
          print('Navigating to MainScreen');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => MainScreen()),
          );
        } else {
          print('Navigating to WelcomePage');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const WelcomePage()),
          );
        }
      }
    } catch (e) {
      setState(() {
        _initError = e.toString();
      });
      print('Initialization error: $e');
    }
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

    // より長い待機時間を設定して初期化が確実に完了するようにする
    await Future.delayed(const Duration(seconds: 2));

    // 直接currentUserを確認する方法に変更
    final user = FirebaseAuth.instance.currentUser;
    if (mounted) {
      if (user != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => MainScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const WelcomePage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {

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