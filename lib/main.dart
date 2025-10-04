// import 'dart:io';
// import 'dart:async';

import 'dart:io';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // FCM追加
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:parts/bloc/Customer_requestformbloc/Customer_requestformbloc.dart';
import 'package:parts/bloc/Userinfo_bloc/Userinfo_bloc.dart';
import 'package:parts/bloc/appintilize_bloc/appintilize_bloc.dart';
import 'package:parts/bloc/map_bloc/map_bloc.dart';
import 'package:parts/bloc/spotbloc/spot_event.dart';
import 'package:parts/bloc/spotbloc/spotbloc.dart';
import 'package:parts/firebase_options.dart';
import 'package:parts/shop/purchase_agency.dart';
import 'package:parts/shop/shop_product_detail.dart';
import 'package:parts/src/bottomnavigationbar.dart';
import 'package:parts/top_page/welcome_page.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

// FCM バックグラウンドメッセージハンドラー（トップレベル関数として定義）
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print('=== FCM Background Message ===');
    print('Message ID: ${message.messageId}');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Data: ${message.data}');
    print('=============================');
  }
}

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
    try {
      Stripe.publishableKey =
          'pk_test_51QeIPUJR2jw9gpdILTofRSwaBs9pKKXfOse9EcwQTkfYNjtYb1rNsahb5uhm6QjcwzvGOhcZ0ZZgjW09HKtblHnH00Ps1dt4ZZ';

      // iOSのApple Pay設定
      if (Platform.isIOS) {
        Stripe.merchantIdentifier = 'merchant.com.sotakawakami.jam';
      }

      // Stripe設定の適用
      print('Applying Stripe settings...');
      await Stripe.instance.applySettings();
      print('✅ Stripe initialized successfully');
    } catch (e) {
      print('⚠️ Stripe initialization failed: $e');
      print('Continuing without Stripe...');
    }

    // 英語ロケールデータの初期化
    print('Initializing date formatting...');
    await initializeDateFormatting('en_US');

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
    // await FirebaseFirestore.instance.enablePersistence();
    print('✅ Firebase initialized successfully');
    print('Firebase apps count: ${Firebase.apps.length}');

    // FCM の初期化（デバッグモードのみ）
    if (kDebugMode) {
      print('Initializing FCM (Debug Mode)...');
      await _initializeFCM();
      print('✅ FCM initialized successfully');
    }

    // Firebase Functionsの明示的な初期化
    print('Initializing Firebase Functions...');
    FirebaseFunctions.instanceFor(region: 'us-central1');
    FirebaseFunctions.instanceFor(
        region: 'asia-northeast1'); // MapSubscription用
    print('✅ Firebase Functions initialized successfully');

    // AdMobの初期化
    print('Initializing AdMob...');
    await MobileAds.instance.initialize();
    print('✅ AdMob initialized successfully');

    print('=== ALL INITIALIZATION COMPLETED ===');
    runApp(MultiBlocProvider(providers: [
      BlocProvider<MapBloc>(
        create: (context) => MapBloc()..add(MapInitialized()),
      ),
      BlocProvider<UserBloc>(
        create: (context) => UserBloc(),
      ),
      BlocProvider<SpotBloc>(
        create: (context) => SpotBloc()..add(SpotFetchInitial()),
      ),
      BlocProvider<AnimeRequestBloc>(
        create: (context) => AnimeRequestBloc()..add(CheckUserStatusEvent()),
      ),
    ], child: const MyApp()));
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

// FCM初期化関数（デバッグモードのみ）
Future<void> _initializeFCM() async {
  try {
    final FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

    // バックグラウンドメッセージハンドラーを設定
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 通知権限をリクエスト
    NotificationSettings settings = await firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (kDebugMode) {
      print('FCM Permission Status: ${settings.authorizationStatus}');
    }

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {

      // FCMトークンを取得して表示
      String? token = await firebaseMessaging.getToken();
      if (kDebugMode && token != null) {
        print('=== FCM TOKEN (Debug Only) ===');
        print(token);
        print('==============================');

        // トークンをFirestoreに保存（デバッグ用）
        await _saveFCMTokenToFirestore(token);
      }

      // フォアグラウンドでメッセージを受信
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('=== FCM Foreground Message ===');
          print('Title: ${message.notification?.title}');
          print('Body: ${message.notification?.body}');
          print('Data: ${message.data}');
          print('==============================');
        }
      });

      // 通知をタップしてアプリが開かれた時の処理
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('=== FCM App Opened from Notification ===');
          print('Title: ${message.notification?.title}');
          print('Body: ${message.notification?.body}');
          print('Data: ${message.data}');
          print('=======================================');
        }
      });

      // アプリが終了状態から通知で開かれた場合の初期メッセージを確認
      RemoteMessage? initialMessage = await firebaseMessaging.getInitialMessage();
      if (initialMessage != null && kDebugMode) {
        print('=== FCM Initial Message ===');
        print('Title: ${initialMessage.notification?.title}');
        print('Body: ${initialMessage.notification?.body}');
        print('Data: ${initialMessage.data}');
        print('===========================');
      }

      // トークンの更新を監視
      firebaseMessaging.onTokenRefresh.listen((String token) {
        if (kDebugMode) {
          print('=== FCM Token Refreshed (Debug Only) ===');
          print(token);
          print('=======================================');
        }
        // 新しいトークンをFirestoreに保存
        _saveFCMTokenToFirestore(token);
      });

      // iOS固有の設定
      if (Platform.isIOS) {
        await firebaseMessaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('FCM Initialization Error: $e');
    }
  }
}

// FCMトークンをFirestoreに保存（デバッグ用）
Future<void> _saveFCMTokenToFirestore(String token) async {
  try {
    if (!kDebugMode) return; // デバッグモードのみ

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('debug_info')
          .doc('fcm_token')
          .set({
        'token': token,
        'updatedAt': FieldValue.serverTimestamp(),
        'platform': Platform.isIOS ? 'iOS' : 'Android',
        'debugMode': true,
      }, SetOptions(merge: true));

      if (kDebugMode) {
        print('FCM Token saved to Firestore for user: ${user.uid}');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error saving FCM token to Firestore: $e');
    }
  }
}

// FCMトークンを表示する関数（デバッグ用）
Future<void> showFCMToken(BuildContext context) async {
  if (!kDebugMode) return;

  try {
    String? token = await FirebaseMessaging.instance.getToken();

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('FCM Token (Debug)'),
          content: Container(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Firebase Console でのテスト送信に使用してください:',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: SelectableText(
                    token ?? 'Token not available',
                    style: TextStyle(fontSize: 10, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('閉じる'),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error showing FCM token: $e');
    }
  }
}

// エラー用のアプリウィジェット
class ErrorApp extends StatelessWidget {
  final String error;
  final String stackTrace;

  const ErrorApp({Key? key, required this.error, required this.stackTrace})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
                          style:
                              TextStyle(fontSize: 10, fontFamily: 'monospace'),
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
                onPressed: isLoading
                    ? null
                    : () {
                        Navigator.of(context).pop();
                      },
                child: Text('キャンセル'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00008b),
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        final email = emailController.text.trim();

                        if (email.isEmpty) {
                          setState(() {
                            statusMessage = 'メールアドレスを入力してください';
                            statusColor = Colors.red;
                          });
                          return;
                        }

                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(email)) {
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
    final configuration =
        PurchasesConfiguration("appl_JfvzIYYEgsMeXVzavJRBnCnlKPS");

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

// 改善されたユーザーのログイン情報を更新する関数
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
        'lastOpenedAt': now, // アプリを最後に開いた日時を更新
        'loginCount': currentLoginCount + 1, // ログイン回数をインクリメント
        'lastSyncedAt': now, // 最終同期日時
      });
      print(
          '✅ User login info updated: $userId, count: ${currentLoginCount + 1}');
    } else {
      // ドキュメントが存在しない場合は新規作成
      await userRef.set({
        'lastLoginAt': now,
        'lastOpenedAt': now,
        'loginCount': 1,
        'createdAt': now, // 初回作成日時
        'lastSyncedAt': now,
      }, SetOptions(merge: true)); // 既存データとマージする
      print('✅ New user login record created: $userId');
    }

    // ログイン記録後、必ず課金状況を同期
    await _forceSyncBillingStatus(userId);
  } catch (e) {
    print('❌ Error updating user login info: $e');
    // ログイン情報更新の失敗は致命的ではないので処理を継続
  }
}

// 新規追加: 強制的な課金状況同期関数
Future<void> _forceSyncBillingStatus(String userId) async {
  try {
    print('🔄 Force syncing billing status for user: $userId');

    // RevenueCatから最新の課金情報を取得
    final customerInfo = await Purchases.getCustomerInfo();

    // Firestoreに同期
    await syncBillingInfoToFirestore(userId, customerInfo);

    // ユーザードキュメントにも課金状況を保存
    await _updateUserPremiumStatus(userId, customerInfo);

    print('✅ Billing status force sync completed for user: $userId');
  } catch (e) {
    print('❌ Error in force billing sync: $e');
  }
}

// 新規追加: ユーザードキュメントのプレミアム状況を更新
Future<void> _updateUserPremiumStatus(
    String userId, CustomerInfo customerInfo) async {
  try {
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);

    // 課金状態の判定
    final isPremium = customerInfo.entitlements.active.isNotEmpty;
    final hasActiveSubscription = customerInfo.activeSubscriptions.isNotEmpty;
    final activeSubscriptions = customerInfo.activeSubscriptions.toList();

    // プレミアムプランの種類を判定
    String? subscriptionType;
    if (hasActiveSubscription) {
      for (String productId in activeSubscriptions) {
        if (productId.toLowerCase().contains('year') ||
            productId.toLowerCase().contains('annual')) {
          subscriptionType = 'yearly';
          break;
        } else if (productId.toLowerCase().contains('month')) {
          subscriptionType = 'monthly';
          break;
        }
      }
    }

    // ユーザードキュメントを更新
    await userRef.update({
      'isPremiumUser': isPremium,
      'hasActiveSubscription': hasActiveSubscription,
      'subscriptionType': subscriptionType,
      'activeSubscriptions': activeSubscriptions,
      'revenueCatCustomerId': customerInfo.originalAppUserId,
      'billingLastSyncedAt': DateTime.now(),
      'billingLastSyncedTimestamp': FieldValue.serverTimestamp(),
    });

    print(
        '✅ User premium status updated: isPremium=$isPremium, type=$subscriptionType');
  } catch (e) {
    print('❌ Error updating user premium status: $e');
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
Future<void> syncBillingInfoToFirestore(
    String userId, CustomerInfo customerInfo) async {
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
        'latestPurchaseDate':
            _safeDateTimeToString(entitlement.latestPurchaseDate),
        'originalPurchaseDate':
            _safeDateTimeToString(entitlement.originalPurchaseDate),
        'expirationDate': _safeDateTimeToString(entitlement.expirationDate),
        'store': entitlement.store.toString(),
        'periodType': entitlement.periodType.toString(),
      };
    }

    // アクティブなサブスクリプション情報を収集
    List<String> activeSubscriptions =
        customerInfo.activeSubscriptions.toList();

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
      'originalPurchaseDate':
          _safeDateTimeToString(customerInfo.originalPurchaseDate),
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
    print(
        'Active entitlements: ${customerInfo.entitlements.active.keys.toList()}');
  } catch (e) {
    print('❌ Error syncing billing info to Firestore: $e');
    // 課金情報同期の失敗は致命的ではないので処理を継続
  }
}

// 改善されたRevenueCatの課金状態をリアルタイムで監視開始
void startBillingMonitoring(String userId) {
  try {
    print('🔄 Starting enhanced billing monitoring for user: $userId');

    // CustomerInfoの変更を監視
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      print('📱 CustomerInfo updated for user: $userId');

      // 非同期でFirestoreに同期（エラーハンドリング強化）
      _handleBillingInfoUpdate(userId, customerInfo);
    });

    print('✅ Billing monitoring started successfully');
  } catch (e) {
    print('❌ Error starting billing monitoring: $e');
  }
}

// 新規追加: 課金情報更新のハンドラー
Future<void> _handleBillingInfoUpdate(
    String userId, CustomerInfo customerInfo) async {
  try {
    // Firestoreの課金情報を更新
    await syncBillingInfoToFirestore(userId, customerInfo);

    // ユーザードキュメントのプレミアム状況も更新
    await _updateUserPremiumStatus(userId, customerInfo);

    print('✅ Billing info update handled successfully');
  } catch (e) {
    print('❌ Error handling billing info update: $e');
  }
}

// アプリ利用状況を記録する新規関数
Future<void> recordAppUsage(String userId) async {
  try {
    final now = DateTime.now();

    // アプリ利用履歴コレクションに記録
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('usage_history')
        .add({
      'openedAt': now,
      'timestamp': FieldValue.serverTimestamp(),
      'platform': Platform.isIOS ? 'iOS' : 'Android',
      'appVersion': await _getAppVersion(),
    });

    // 今日の利用回数を更新
    final today = DateTime(now.year, now.month, now.day);
    final todayDocId =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final dailyUsageRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('daily_usage')
        .doc(todayDocId);

    final dailyUsageDoc = await dailyUsageRef.get();

    if (dailyUsageDoc.exists) {
      final currentCount = dailyUsageDoc.data()?['openCount'] ?? 0;
      await dailyUsageRef.update({
        'openCount': currentCount + 1,
        'lastOpenedAt': now,
      });
    } else {
      await dailyUsageRef.set({
        'date': today,
        'openCount': 1,
        'firstOpenedAt': now,
        'lastOpenedAt': now,
      });
    }

    print('✅ App usage recorded for user: $userId');
  } catch (e) {
    print('❌ Error recording app usage: $e');
  }
}

// アプリバージョンを取得する関数
Future<String> _getAppVersion() async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  } catch (e) {
    print('Error getting app version: $e');
    return 'Unknown';
  }
}

// 課金状況の定期チェック機能（オプション）
Future<void> schedulePeriodicBillingSync(String userId) async {
  try {
    // 24時間ごとに課金状況をチェック
    Timer.periodic(Duration(hours: 24), (timer) async {
      try {
        print('⏰ Performing scheduled billing sync for user: $userId');
        await _forceSyncBillingStatus(userId);
      } catch (e) {
        print('❌ Error in scheduled billing sync: $e');
      }
    });

    print('✅ Periodic billing sync scheduled');
  } catch (e) {
    print('❌ Error scheduling periodic billing sync: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<MapBloc>(
          create: (context) => MapBloc()..add(MapInitialized()),
        ),
        BlocProvider<AnimeRequestBloc>(
          create: (context) => AnimeRequestBloc()..add(CheckUserStatusEvent()),
        ),
        BlocProvider<UserBloc>(
          create: (context) => UserBloc()..add(InitializeUser()),
        ),
        BlocProvider<AppInitializationBloc>(
          create: (context) =>
              AppInitializationBloc()..add(StartInitialization()),
        ),
        BlocProvider<SpotBloc>(
          create: (context) => SpotBloc()..add(SpotFetchInitial()),
        ),
      ],
      child: MaterialApp(
        routes: {
          '/product_purchase_agency': (context) => ConfirmationScreen(),
          '/product_detail': (context) => ProductDetailScreen(),
        },
        debugShowCheckedModeBanner: false,
        title: 'JapanAnimeMaps',
        // theme: ThemeData(
        // シンプルに白ベースのテーマを作成
        //   brightness: Brightness.light,
        //   primaryColor: const Color(0xFF4CAF50),
        //   scaffoldBackgroundColor: Colors.white,
        //   canvasColor: Colors.white,
        //   cardColor: Colors.white,
        //   dialogBackgroundColor: Colors.white,
        //
        //   // AppBarテーマ
        //   appBarTheme: const AppBarTheme(
        //     backgroundColor: Colors.white,
        //     foregroundColor: Colors.black,
        //     elevation: 0,
        //     iconTheme: IconThemeData(color: Colors.black),
        //     titleTextStyle: TextStyle(
        //       color: Colors.black,
        //       fontSize: 20,
        //       fontWeight: FontWeight.w500,
        //     ),
        //   ),
        //
        //   // BottomNavigationBarテーマ
        //   bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        //     backgroundColor: Colors.white,
        //     selectedItemColor: Color(0xFF4CAF50),
        //     unselectedItemColor: Colors.grey,
        //   ),
        //
        //   // Material 3を無効にして従来のMaterial 2を使用
        //   useMaterial3: false, colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.green).copyWith(background: Colors.white),
        // ),
        //
        // // ダークテーマを無効にして常にライトテーマを使用
        // themeMode: ThemeMode.light,

        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
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
  String? _initError;

  // ローディングアニメーションウィジェットの定数
  static final loadingWidget = LoadingAnimationWidget.discreteCircle(
    color: Colors.blue,
    size: 50,
  );

  @override
  void initState() {
    super.initState();
    // AppInitializationBloc will handle initialization automatically
  }

  Future<void> _navigateBasedOnAuth(BuildContext context, User? user) async {
    try {
      if (user != null) {
        // User is logged in, navigate to main screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => MainScreen()),
        );
      } else {
        // User is not logged in, navigate to welcome screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => WelcomePage()),
        );
      }
    } catch (e) {
      print('Navigation error: $e');
      setState(() {
        _initError = 'ナビゲーションエラー: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppInitializationBloc, AppInitializationState>(
      listener: (context, state) {
        if (state is InitializationSuccess) {
          // Navigate to appropriate screen based on auth status
          _navigateBasedOnAuth(context, state.user);
        } else if (state is InitializationError) {
          setState(() {
            _initError = state.error;
          });
        }
      },
      builder: (context, state) {
        if (state is InitializationError || _initError != null) {
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
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Text(
                          state is InitializationError
                              ? state.error
                              : _initError!,
                          style: TextStyle(color: Colors.red[800]),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _initError = null;
                          });
                          context
                              .read<AppInitializationBloc>()
                              .add(StartInitialization());
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

        // Show loading state
        String statusText = '初期化中...';
        if (state is InitializationLoading) {
          statusText = state.currentStep;
        }

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  loadingWidget,
                  SizedBox(height: 20),
                  Text(
                    statusText,
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
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
                    SizedBox(height: 8),
                    Text(
                      'Auth Status: $_authStatus',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}