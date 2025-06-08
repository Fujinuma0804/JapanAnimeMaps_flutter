import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart'; // 追加
import 'package:package_info_plus/package_info_plus.dart';
import 'package:parts/firebase_options.dart';
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

  // グローバルエラーハンドラーを設定（最初に設定）
  FlutterError.onError = (FlutterErrorDetails details) {
    print('=== FLUTTER ERROR CAUGHT ===');
    print('Error: ${details.exception}');
    print('Library: ${details.library}');
    print('Context: ${details.context}');
    print('Stack trace:');
    print('${details.stack}');
    print('===========================');

    // デバッグモードでは追加情報を表示
    if (kDebugMode) {
      print('Debug info: ${details.informationCollector?.call()}');
    }
  };

  // 非同期エラーもキャッチ
  PlatformDispatcher.instance.onError = (error, stack) {
    print('=== PLATFORM ERROR CAUGHT ===');
    print('Error: $error');
    print('Stack trace:');
    print('$stack');
    print('=============================');
    return true;
  };

  try {
    print('=== APP INITIALIZATION STARTED ===');

    // Stripeの初期化
    print('Initializing Stripe...');
    Stripe.publishableKey = 'pk_test_51QeIPUJR2jw9gpdILTofRSwaBs9pKKXfOse9EcwQTkfYNjtYb1rNsahb5uhm6QjcwzvGOhcZ0ZZgjW09HKtblHnH00Ps1dt4ZZ';

    // iOSのApple Pay設定
    if (Platform.isIOS) {
      Stripe.merchantIdentifier = 'merchant.com.sotakawakami.jam';
    }

    // 日本語ロケールデータの初期化
    print('Initializing date formatting...');
    await initializeDateFormatting('ja_JP');

    // Stripe設定の適用
    print('Applying Stripe settings...');
    await Stripe.instance.applySettings();
    print('✅ Stripe initialized successfully');

    // RevenueCatの初期化
    print('Initializing RevenueCat...');
    await initPlatformState();
    print('✅ RevenueCat initialized successfully');

    // Firebase の初期化
    print('Initializing Firebase...');
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
    print('Firebase apps count: ${Firebase.apps.length}');

    // Firebase Functionsの明示的な初期化
    print('Initializing Firebase Functions...');
    FirebaseFunctions.instanceFor(region: 'us-central1');
    FirebaseFunctions.instanceFor(region: 'asia-northeast1'); // MapSubscription用
    print('✅ Firebase Functions initialized successfully');

    // AdMobの初期化
    print('Initializing AdMob...');
    await MobileAds.instance.initialize();
    print('✅ AdMob initialized successfully');

    print('=== ALL INITIALIZATION COMPLETED ===');
    runApp(const MyApp());

  } catch (e, stackTrace) {
    print('=== CRITICAL INITIALIZATION ERROR ===');
    print('Error: $e');
    print('Error type: ${e.runtimeType}');
    print('Stack trace:');
    print('$stackTrace');
    print('=====================================');

    // エラー用の最小限のアプリを起動
    runApp(ErrorApp(error: e.toString(), stackTrace: stackTrace.toString()));
  }
}

// エラー用のアプリウィジェット
class ErrorApp extends StatelessWidget {
  final String error;
  final String stackTrace;

  const ErrorApp({Key? key, required this.error, required this.stackTrace}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JapanAnimeMaps - Error',
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 64),
                SizedBox(height: 16),
                Text(
                  'アプリ初期化エラー',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    error,
                    style: TextStyle(color: Colors.red[800]),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // アプリを再起動
                    main();
                  },
                  child: Text('再試行'),
                ),
                if (kDebugMode) ...[
                  SizedBox(height: 16),
                  ExpansionTile(
                    title: Text('詳細なエラー情報'),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(8),
                        child: Text(
                          stackTrace,
                          style: TextStyle(fontSize: 10, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// テストメール送信機能
Future<void> testSendMail(BuildContext context, String email) async {
  try {
    // Firebaseの初期化状態を確認
    print('Testing mail send - Firebase apps: ${Firebase.apps.length}');
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
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$emailにテストメールを送信しました'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }

    return;
  } catch (e) {
    print('テストメール送信エラー: $e');

    // エラーメッセージ
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラー: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }

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
  try {
    await Purchases.setLogLevel(LogLevel.debug);

    // RevenueCatの設定
    final configuration = PurchasesConfiguration("appl_JfvzIYYEgsMeXVzavJRBnCnlKPS");

    await Purchases.configure(configuration);
    print('RevenueCat configured successfully');

    // 設定の確認
    await _validateConfiguration();
  } catch (e) {
    print('RevenueCat initialization failed: $e');
    rethrow; // エラーを再度投げて上位でキャッチできるようにする
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
    // バリデーション失敗は致命的ではないのでエラーを投げない
  }
}

// 新規追加: ユーザーのログイン情報を更新する関数
Future<void> updateUserLoginInfo(String userId) async {
  try {
    // Firebase初期化確認
    if (Firebase.apps.isEmpty) {
      print('Firebase not initialized for user login update');
      return;
    }

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
    // ログイン情報更新の失敗は致命的ではないので処理を継続
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
    // Firebase初期化確認
    if (Firebase.apps.isEmpty) {
      print('Firebase not initialized for billing sync');
      return;
    }

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
    // 課金情報同期の失敗は致命的ではないので処理を継続
  }
}

// RevenueCatの課金状態をリアルタイムで監視開始
void startBillingMonitoring(String userId) {
  try {
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
  } catch (e) {
    print('❌ Error starting billing monitoring: $e');
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

  // ローディングアニメーションウィジェットの定数
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
      print('SplashScreen: Starting app initialization...');

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
        await _navigateToNextScreen();
      }
    } catch (e, stackTrace) {
      print('SplashScreen initialization error: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _initError = e.toString();
      });
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
      // RevenueCat同期失敗は致命的ではないので処理を継続
    }
  }

  Future<void> _requestTrackingPermission() async {
    if (Platform.isIOS) {
      try {
        final status = await AppTrackingTransparency.trackingAuthorizationStatus;

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
        // トラッキング許可失敗は致命的ではないので処理を継続
      }
    }
  }

  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;

    try {
      // Firebase初期化確認
      if (Firebase.apps.isEmpty) {
        throw Exception('Firebase not initialized');
      }

      // 認証状態を確認
      final user = FirebaseAuth.instance.currentUser;
      print('Current user: ${user?.uid ?? "No user"}');

      if (user != null) {
        // ユーザーがログインしている場合はログイン情報を更新
        await updateUserLoginInfo(user.uid);

        // 課金状態の監視を開始
        startBillingMonitoring(user.uid);

        print('Navigating to MainScreen');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => MainScreen()),
          );
        }
      } else {
        print('Navigating to WelcomePage');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const WelcomePage()),
          );
        }
      }
    } catch (e, stackTrace) {
      print('Navigation error: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _initError = 'ナビゲーションエラー: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 64),
                  SizedBox(height: 16),
                  Text(
                    '初期化エラー',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(
                      _initError!,
                      style: TextStyle(color: Colors.red[800]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _initError = null;
                        _isInitialized = false;
                      });
                      _initializeApp();
                    },
                    child: Text('再試行'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 通常のスプラッシュ画面
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              loadingWidget,
              SizedBox(height: 20),
              Text(
                _isInitialized ? '起動中...' : '初期化中...',
                style: TextStyle(fontSize: 16),
              ),
              if (kDebugMode) ...[
                SizedBox(height: 20),
                Text(
                  '動作モード: ${Platform.isIOS ? 'iOS Sandbox' : 'Android Test'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Firebase Apps: ${Firebase.apps.length}',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}