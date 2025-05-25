import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart'; // 追加
import 'package:package_info_plus/package_info_plus.dart';
import 'package:parts/shop/purchase_agency.dart';
import 'package:parts/shop/shop_product_detail.dart';
import 'package:parts/src/bottomnavigationbar.dart';
import 'package:parts/top_page/welcome_page.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:intl/date_symbol_data_local.dart'; // 日本語ロケールデータ初期化用
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestoreを追加
import 'package:cloud_functions/cloud_functions.dart'; // Cloud Functions追加

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

    // 日本語ロケールデータの初期化
    await initializeDateFormatting('ja_JP');

    // Stripe設定の適用
    await Stripe.instance.applySettings();

    print('Stripe initialized successfully'); // デバッグログ追加

    // RevenueCatの初期化
    await initPlatformState();

    // Firebase と AdMob の初期化
    await Firebase.initializeApp();

    // Firebase Functionsの明示的な初期化
    FirebaseFunctions.instanceFor(region: 'us-central1'); // us-central1リージョンを指定
    print('Firebase Functions initialized successfully');

    // AdMobの初期化
    await MobileAds.instance.initialize();

    runApp(const MyApp());
  } catch (e) {
    print('Initialization error: $e'); // エラーログ
    // エラーが発生してもアプリを起動
    runApp(const MyApp());
  }
}

// テストメール送信機能
Future<void> testSendMail(BuildContext context, String email) async {
  try {
    // Firebaseの初期化状態を確認
    print('Firebase apps: ${Firebase.apps.length}');
    if (Firebase.apps.isEmpty) {
      throw Exception('Firebaseが初期化されていません');
    }

    print('Initializing Firebase Functions...');

    // リージョン指定でFunctions初期化（us-central1に修正）
    final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
      region: 'us-central1',
    );

    print('Calling testSendMail function...');
    final HttpsCallable callable = functions.httpsCallable('testSendMail');

    final params = {'emailTo': email};
    print('Calling with params: $params');

    final result = await callable.call(params);
    print('Function result: ${result.data}');

    // 成功メッセージ
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$emailにテストメールを送信しました'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );

    return;
  } catch (e) {
    print('テストメール送信エラー: $e');

    // エラーメッセージ
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('エラー: $e'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
      ),
    );

    return;
  }
}

// テストメール送信ダイアログ
void showTestEmailDialog(BuildContext context) {
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;
  String statusMessage = 'メールアドレスを入力してください';
  Color statusColor = Colors.black;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('テストメール送信'),
            content: Container(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusMessage,
                      style: TextStyle(color: statusColor),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'メールアドレス',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isLoading,
                  ),
                  if (isLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () {
                  Navigator.of(context).pop();
                },
                child: Text('キャンセル'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00008b),
                ),
                onPressed: isLoading ? null : () async {
                  final email = emailController.text.trim();

                  if (email.isEmpty) {
                    setState(() {
                      statusMessage = 'メールアドレスを入力してください';
                      statusColor = Colors.red;
                    });
                    return;
                  }

                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
                    setState(() {
                      statusMessage = '有効なメールアドレスを入力してください';
                      statusColor = Colors.red;
                    });
                    return;
                  }

                  setState(() {
                    isLoading = true;
                    statusMessage = '送信処理を開始しています...';
                    statusColor = Colors.blue;
                  });

                  try {
                    // 別関数で実行
                    await testSendMail(context, email);

                    // 成功
                    setState(() {
                      statusMessage = '送信リクエストが完了しました';
                      statusColor = Colors.green;
                      isLoading = false;
                    });

                    // 少し待ってダイアログを閉じる
                    Future.delayed(Duration(seconds: 2), () {
                      if (Navigator.canPop(context)) {
                        Navigator.of(context).pop();
                      }
                    });
                  } catch (e) {
                    // エラー処理
                    setState(() {
                      statusMessage = 'エラー: $e';
                      statusColor = Colors.red;
                      isLoading = false;
                    });
                  }
                },
                child: Text('送信', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    },
  );
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

// 新規追加: ユーザーのログイン情報を更新する関数
Future<void> updateUserLoginInfo(String userId) async {
  try {
    // Firestoreの参照
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);

    // 現在の日時を日本時間で取得
    final now = DateTime.now();

    // ユーザードキュメントを取得
    final userDoc = await userRef.get();

    if (userDoc.exists) {
      // ドキュメントが存在する場合、ログイン回数を増やす
      final currentLoginCount = userDoc.data()?['loginCount'] ?? 0;

      await userRef.update({
        'lastLoginAt': now, // 最終ログイン日時を更新
        'loginCount': currentLoginCount + 1, // ログイン回数をインクリメント
      });
      print('User login info updated: $userId, count: ${currentLoginCount + 1}');
    } else {
      // ドキュメントが存在しない場合は新規作成
      await userRef.set({
        'lastLoginAt': now,
        'loginCount': 1,
        'createdAt': now, // 初回作成日時
      }, SetOptions(merge: true)); // 既存データとマージする
      print('New user login record created: $userId');
    }
  } catch (e) {
    print('Error updating user login info: $e');
  }
}

// 安全なDateTime変換関数
String? _safeDateTimeToString(dynamic dateTime) {
  try {
    if (dateTime == null) return null;
    if (dateTime is DateTime) return dateTime.toIso8601String();
    if (dateTime is String) return dateTime; // 既に文字列の場合
    return dateTime.toString(); // その他の場合は文字列化
  } catch (e) {
    print('Date conversion error: $e');
    return null;
  }
}

// RevenueCatの課金状態をFirestoreに同期する関数
Future<void> syncBillingInfoToFirestore(String userId, CustomerInfo customerInfo) async {
  try {
    final billingRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('billing')
        .doc('subscription_status');

    final now = DateTime.now();

    // エンタイトルメント情報を収集
    Map<String, dynamic> entitlementsData = {};
    for (var entry in customerInfo.entitlements.all.entries) {
      final entitlement = entry.value;
      entitlementsData[entry.key] = {
        'isActive': entitlement.isActive,
        'willRenew': entitlement.willRenew,
        'productIdentifier': entitlement.productIdentifier,
        'isSandbox': entitlement.isSandbox,
        'latestPurchaseDate': _safeDateTimeToString(entitlement.latestPurchaseDate),
        'originalPurchaseDate': _safeDateTimeToString(entitlement.originalPurchaseDate),
        'expirationDate': _safeDateTimeToString(entitlement.expirationDate),
        'store': entitlement.store.toString(),
        'periodType': entitlement.periodType.toString(),
      };
    }

    // アクティブなサブスクリプション情報を収集
    List<String> activeSubscriptions = customerInfo.activeSubscriptions.toList();

    // 課金状態の判定
    bool isPremium = customerInfo.entitlements.active.isNotEmpty;
    bool hasActiveSubscription = customerInfo.activeSubscriptions.isNotEmpty;

    // Map型の日時フィールドを安全に変換
    Map<String, String?> safeExpirationDates = {};
    Map<String, String?> safePurchaseDates = {};

    try {
      customerInfo.allExpirationDates.forEach((key, value) {
        safeExpirationDates[key] = _safeDateTimeToString(value);
      });
    } catch (e) {
      print('Error converting expiration dates: $e');
    }

    try {
      customerInfo.allPurchaseDates.forEach((key, value) {
        safePurchaseDates[key] = _safeDateTimeToString(value);
      });
    } catch (e) {
      print('Error converting purchase dates: $e');
    }

    // Firestoreに保存するデータ
    final billingData = {
      'isPremium': isPremium,
      'hasActiveSubscription': hasActiveSubscription,
      'originalAppUserId': customerInfo.originalAppUserId,
      'requestDate': _safeDateTimeToString(customerInfo.requestDate),
      'firstSeen': _safeDateTimeToString(customerInfo.firstSeen),
      'originalApplicationVersion': customerInfo.originalApplicationVersion,
      'originalPurchaseDate': _safeDateTimeToString(customerInfo.originalPurchaseDate),
      'managementURL': customerInfo.managementURL,
      'activeSubscriptions': activeSubscriptions,
      'allExpirationDates': safeExpirationDates,
      'allPurchaseDates': safePurchaseDates,
      'entitlements': entitlementsData,
      'lastUpdated': now,
      'lastUpdatedTimestamp': FieldValue.serverTimestamp(),
    };

    // Firestoreに保存
    await billingRef.set(billingData, SetOptions(merge: true));

    print('✅ Billing info synced to Firestore for user: $userId');
    print('Premium status: $isPremium');
    print('Active subscriptions: $activeSubscriptions');
    print('Active entitlements: ${customerInfo.entitlements.active.keys.toList()}');

  } catch (e) {
    print('❌ Error syncing billing info to Firestore: $e');
  }
}

// RevenueCatの課金状態をリアルタイムで監視開始
void startBillingMonitoring(String userId) {
  print('🔄 Starting billing monitoring for user: $userId');

  // CustomerInfoの変更を監視
  Purchases.addCustomerInfoUpdateListener((customerInfo) {
    print('📱 CustomerInfo updated for user: $userId');

    // 非同期でFirestoreに同期
    syncBillingInfoToFirestore(userId, customerInfo).catchError((error) {
      print('❌ Error in billing sync listener: $error');
    });
  });

  // 初回の課金状態を即座に同期
  Purchases.getCustomerInfo().then((customerInfo) {
    print('📋 Initial billing sync for user: $userId');
    return syncBillingInfoToFirestore(userId, customerInfo);
  }).catchError((error) {
    print('❌ Error in initial billing sync: $error');
  });
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

  // ローディングアニメーションウィジェットの定数
  // アプリ全体で統一したローディングウィジェットを使用するために定数として定義
  static final loadingWidget = LoadingAnimationWidget.discreteCircle(
    color: Colors.blue,
    size: 50,
  );

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
          // ユーザーがログインしている場合はログイン情報を更新
          await updateUserLoginInfo(user.uid);

          // 課金状態の監視を開始
          startBillingMonitoring(user.uid);

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
        // ユーザーがログインしている場合はログイン情報を更新
        await updateUserLoginInfo(user.uid);

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
            // CircularProgressIndicator() を LoadingAnimationWidget に置き換え
            loadingWidget,
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