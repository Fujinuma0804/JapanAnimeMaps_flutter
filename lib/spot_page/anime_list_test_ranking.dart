import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:parts/components/ad_mob.dart';
import 'package:parts/event_tab/event_section.dart';
import 'package:parts/spot_page/check_in.dart';
import 'package:parts/spot_page/customer_animename_request.dart';
import 'package:parts/spot_page/user_activity_logger.dart';
import 'package:parts/subscription/payment_subscription.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../map_page/prefecture_tab/prefecture_tab.dart';
import 'anime_list_detail.dart';
import 'customer_anime_request.dart';
import 'liked_post.dart';

// RevenueCatを使用したサブスクリプション管理クラス
class SubscriptionManager {
  static const String _premiumEntitlementId =
      'premium'; // RevenueCatで設定したEntitlement ID
  static const String _subscriptionProductId = 'premium_monthly'; // プロダクトID
  static bool _isInitialized = false;

  // main.dartから取得した実際のAPI Key
  static const String _revenueCatApiKeyIOS = 'appl_JfvzIYYEgsMeXVzavJRBnCnlKPS';
  // Androidの場合は別途設定が必要（main.dartにはAndroid用のキーが記載されていないため）
  static const String _revenueCatApiKeyAndroid =
      'goog_xxxxxxxxxxxxxxx'; // Android用API Keyを設定してください

  // RevenueCatの初期化
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // RevenueCatの設定（copyWithは使用せず、直接設定）
      PurchasesConfiguration configuration;

      if (Platform.isAndroid) {
        configuration = PurchasesConfiguration(_revenueCatApiKeyAndroid);
      } else if (Platform.isIOS) {
        configuration = PurchasesConfiguration(_revenueCatApiKeyIOS);
      } else {
        throw UnsupportedError('Platform not supported');
      }

      await Purchases.configure(configuration);

      // デバッグログを有効にする（開発時のみ）
      await Purchases.setLogLevel(LogLevel.debug);

      _isInitialized = true;

      print('✅RevenueCat initialized successfully');

      // main.dartと同様の設定確認を実行
      await _validateConfiguration();
    } catch (e) {
      print('❌Error initializing RevenueCat: $e');
      _isInitialized = false;
      // API Keyエラーの場合は具体的なメッセージを出力
      if (e.toString().contains('Invalid API Key') ||
          e.toString().contains('credentials')) {
        print('⚠️ RevenueCat API Key error. Please check:');
        print('1. API Key is correct');
        print('2. Project settings in RevenueCat console');
        print('3. Bundle ID/Package name matches');
      }
    }
  }

  static Future<void> initializeWithDebug() async {
    await initialize();
    if (_isInitialized) {
      await debugSubscriptionStatus();
    }
  }

  // main.dartから移植した設定確認機能
  static Future<void> _validateConfiguration() async {
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

  // サブスクリプション状態を確認（フォールバック付き）
  static Future<bool> isSubscriptionActive() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // 初期化に失敗した場合はローカルストレージから確認
      if (!_isInitialized) {
        return await _checkLocalSubscriptionStatus();
      }

      final CustomerInfo customerInfo = await Purchases.getCustomerInfo();

      //修正：複数の判定条件を追加して確実にチェックするようにする
      bool isPremium = false;

      //1.　エンタイトルメントによる判定
      final entitlement = customerInfo.entitlements.all[_premiumEntitlementId];
      if (entitlement != null && entitlement.isActive) {
        isPremium = true;
        print(
            '✅Premium active via entitlement: ${entitlement.productIdentifier}');
      }

      //2.　アクティブサブスクリプションによる判定
      if (!isPremium && customerInfo.activeSubscriptions.isNotEmpty) {
        isPremium = true;
        print(
            '✅Premium active via entitlements: ${customerInfo.entitlements.active.keys}');
      }

      //3.　エンタイトルメント全体での判定
      if (!isPremium && customerInfo.entitlements.active.isNotEmpty) {
        isPremium = true;
        print(
            '✅Premium active via entitlements: ${customerInfo.entitlements.active.keys}');
      }

      print('🔍 Final subscription status: $isPremium');
      print('🔍 Entitlement keys: ${customerInfo.entitlements.all.keys}');
      print('🔍 Active entitlements: ${customerInfo.entitlements.active.keys}');
      print('🔍 Active subscriptions: ${customerInfo.activeSubscriptions}');

      // ローカルストレージにも保存（フォールバック用）
      await _saveLocalSubscriptionStatus(isPremium);

      // main.dartのsyncBillingInfoToFirestore機能を統合
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _syncBillingInfoToFirestore(user.uid, customerInfo);
      }

      return isPremium;
    } catch (e) {
      print('❌Error checking subscription status: $e');

      // API Keyエラーやネットワークエラーの場合はローカルから確認
      if (e.toString().contains('Invalid API Key') ||
          e.toString().contains('network') ||
          e.toString().contains('credentials')) {
        print('🔄Using local subscription status as fallback');
        return await _checkLocalSubscriptionStatus();
      }

      return false;
    }
  }

  // main.dartのsyncBillingInfoToFirestore機能を統合
  static Future<void> _syncBillingInfoToFirestore(
      String userId, CustomerInfo customerInfo) async {
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

      //課金状態の判定ロジックを統一
      bool isPremium = false;

      //エンタイトルメントによる判定
      final entitlement = customerInfo.entitlements.all[_premiumEntitlementId];
      if (entitlement != null && entitlement.isActive) {
        isPremium = true;
      }

      //アクティブサブスクリプションによる判定
      if (!isPremium && customerInfo.activeSubscriptions.isNotEmpty) {
        isPremium = true;
      }

      //アクティブエンタイトルメントによる判定
      if (!isPremium && customerInfo.entitlements.active.isNotEmpty) {
        isPremium = true;
      }

      bool hasActiveSubscription = customerInfo.activeSubscriptions.isNotEmpty;

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
        'entitlements': entitlementsData,
        'lastUpdated': now,
        'lastUpdatedTimestamp': FieldValue.serverTimestamp(),
        //【追加】デバック情報
        'debugInfo': {
          'entitlementExists':
              customerInfo.entitlements.all.containsKey(_premiumEntitlementId),
          'entitlementActive':
              customerInfo.entitlements.all[_premiumEntitlementId]?.isActive ??
                  false,
          'activeEntitlementCount': customerInfo.activeSubscriptions.length,
          'activeSubscriptionCount': customerInfo.activeSubscriptions.length,
        }
      };

      // Firestoreに保存
      await billingRef.set(billingData, SetOptions(merge: true));

      print('✅ Billing info synced to Firestore for user: $userId');
      print('💰Premium status: $isPremium');
      print(
          '🔍 Debug - Entitlement active: ${customerInfo.entitlements.all[_premiumEntitlementId]?.isActive}');
      print('🔍 Debug - Active subscriptions: $hasActiveSubscription');
    } catch (e) {
      print('❌ Error syncing billing info to Firestore: $e');
    }
  }

  // 【追加】デバッグ用のメソッド
  static Future<void> debugSubscriptionStatus() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      if (!_isInitialized) {
        print('❌ RevenueCat not initialized');
        return;
      }

      final CustomerInfo customerInfo = await Purchases.getCustomerInfo();

      print('\n=== 🔍 DEBUG: Subscription Status ===');
      print('User ID: ${customerInfo.originalAppUserId}');
      print('All entitlements: ${customerInfo.entitlements.all.keys}');
      print('Active entitlements: ${customerInfo.entitlements.active.keys}');
      print('Active subscriptions: ${customerInfo.activeSubscriptions}');

      if (customerInfo.entitlements.all.containsKey(_premiumEntitlementId)) {
        final entitlement =
            customerInfo.entitlements.all[_premiumEntitlementId]!;
        print('Premium entitlement found:');
        print('  - Active: ${entitlement.isActive}');
        print('  - Product: ${entitlement.productIdentifier}');
        print('  - Will renew: ${entitlement.willRenew}');
        print('  - Expiration: ${entitlement.expirationDate}');
        print('  - Latest purchase: ${entitlement.latestPurchaseDate}');
      } else {
        print('❌ Premium entitlement not found');
      }

      print('=====================================\n');
    } catch (e) {
      print('❌ Debug error: $e');
    }
  }

  // 安全なDateTime変換関数（main.dartから移植）
  static String? _safeDateTimeToString(dynamic dateTime) {
    try {
      if (dateTime == null) return null;
      if (dateTime is DateTime) return dateTime.toIso8601String();
      if (dateTime is String) return dateTime;
      return dateTime.toString();
    } catch (e) {
      print('Date conversion error: $e');
      return null;
    }
  }

  // ローカルストレージからサブスクリプション状態を確認
  static Future<bool> _checkLocalSubscriptionStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isSubscribed =
          prefs.getBool('local_subscription_active') ?? false;
      final String? expiryString = prefs.getString('local_subscription_expiry');

      if (!isSubscribed || expiryString == null) return false;

      final DateTime expiry = DateTime.parse(expiryString);
      final bool isStillValid = DateTime.now().isBefore(expiry);

      if (!isStillValid) {
        // 期限切れの場合はローカル状態をクリア
        await _clearLocalSubscriptionStatus();
        return false;
      }

      return true;
    } catch (e) {
      print('Error checking local subscription status: $e');
      return false;
    }
  }

  // ローカルストレージにサブスクリプション状態を保存
  static Future<void> _saveLocalSubscriptionStatus(bool isActive) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('local_subscription_active', isActive);

      if (isActive) {
        // 1ヶ月後の有効期限を設定（実際のアプリでは正確な有効期限を使用）
        final expiry = DateTime.now().add(Duration(days: 30));
        await prefs.setString(
            'local_subscription_expiry', expiry.toIso8601String());
      } else {
        await _clearLocalSubscriptionStatus();
      }
    } catch (e) {
      print('Error saving local subscription status: $e');
    }
  }

  // ローカルサブスクリプション状態をクリア
  static Future<void> _clearLocalSubscriptionStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('local_subscription_active');
      await prefs.remove('local_subscription_expiry');
    } catch (e) {
      print('Error clearing local subscription status: $e');
    }
  }

  // サブスクリプション購入
  static Future<bool> purchaseSubscription() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      if (!_isInitialized) {
        throw Exception(
            'RevenueCat initialization failed. Cannot proceed with purchase.');
      }

      final Offerings offerings = await Purchases.getOfferings();
      final Package? package = offerings.current?.monthly;

      if (package != null) {
        final CustomerInfo customerInfo =
            await Purchases.purchasePackage(package);
        final bool isPremium =
            customerInfo.entitlements.all[_premiumEntitlementId]?.isActive ??
                false;

        // ローカルストレージにも保存
        await _saveLocalSubscriptionStatus(isPremium);

        // Firestoreにも同期
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _syncBillingInfoToFirestore(user.uid, customerInfo);
        }

        print('Purchase completed. Premium status: $isPremium');
        return isPremium;
      } else {
        print('No monthly package available');
        return false;
      }
    } catch (e) {
      // PlatformExceptionの処理を簡略化
      if (e is PlatformException) {
        if (e.code == 'purchase_cancelled') {
          print('Purchase was cancelled');
        } else if (e.code == 'payment_pending') {
          print('Payment is pending');
        } else if (e.toString().contains('Invalid API Key')) {
          print(
              'API Key error during purchase. Please check RevenueCat configuration.');
        } else {
          print('Purchase error: ${e.message}');
        }
      } else {
        print('Unexpected purchase error: $e');
      }
      return false;
    }
  }

  // サブスクリプション復元
  static Future<bool> restoreSubscription() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      if (!_isInitialized) {
        throw Exception(
            'RevenueCat initialization failed. Cannot proceed with restore.');
      }

      final CustomerInfo customerInfo = await Purchases.restorePurchases();
      final bool isPremium =
          customerInfo.entitlements.all[_premiumEntitlementId]?.isActive ??
              false;

      // ローカルストレージにも保存
      await _saveLocalSubscriptionStatus(isPremium);

      // Firestoreにも同期
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _syncBillingInfoToFirestore(user.uid, customerInfo);
      }

      print('Restore completed. Premium status: $isPremium');
      return isPremium;
    } catch (e) {
      print('Error restoring subscription: $e');

      if (e.toString().contains('Invalid API Key')) {
        print(
            'API Key error during restore. Please check RevenueCat configuration.');
      }

      return false;
    }
  }

  // 顧客情報を取得
  static Future<CustomerInfo?> getCustomerInfo() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      if (!_isInitialized) {
        return null;
      }

      return await Purchases.getCustomerInfo();
    } catch (e) {
      print('Error getting customer info: $e');
      return null;
    }
  }

  // サブスクリプション有効期限を取得
  static Future<DateTime?> getSubscriptionExpiry() async {
    try {
      // まずローカルストレージから確認
      final prefs = await SharedPreferences.getInstance();
      final String? localExpiryString =
          prefs.getString('local_subscription_expiry');

      if (localExpiryString != null) {
        final DateTime localExpiry = DateTime.parse(localExpiryString);
        if (DateTime.now().isBefore(localExpiry)) {
          return localExpiry;
        }
      }

      // RevenueCatから取得を試行
      final CustomerInfo? customerInfo = await getCustomerInfo();
      final EntitlementInfo? entitlement =
          customerInfo?.entitlements.all[_premiumEntitlementId];

      if (entitlement == null || !entitlement.isActive) {
        return null;
      }

      // 有効なサブスクリプションがある場合は推定有効期限を返す
      return DateTime.now().add(Duration(days: 30));
    } catch (e) {
      print('Error getting subscription expiry: $e');
      return null;
    }
  }

  // 利用可能なプロダクトを取得
  static Future<Offerings?> getOfferings() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      if (!_isInitialized) {
        return null;
      }

      return await Purchases.getOfferings();
    } catch (e) {
      print('Error getting offerings: $e');
      return null;
    }
  }

  // ユーザーIDを設定（ログイン時に呼び出す）
  static Future<void> setUserId(String userId) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      if (!_isInitialized) {
        print('RevenueCat not initialized. Cannot set user ID.');
        return;
      }

      await Purchases.logIn(userId);
      print('User logged in to RevenueCat: $userId');
    } catch (e) {
      print('Error setting user ID: $e');
    }
  }

  // ログアウト
  static Future<void> logout() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      if (_isInitialized) {
        await Purchases.logOut();
        print('User logged out from RevenueCat');
      }

      // ローカルストレージもクリア
      await _clearLocalSubscriptionStatus();
    } catch (e) {
      print('Error logging out: $e');
    }
  }

  // テスト用: ローカルサブスクリプションを手動で有効化（開発・テスト時のみ使用）
  static Future<void> enableTestSubscription() async {
    print(
        '⚠️ Test subscription enabled. This should only be used for development/testing.');
    await _saveLocalSubscriptionStatus(true);
  }

  // テスト用: ローカルサブスクリプションを無効化
  static Future<void> disableTestSubscription() async {
    print('Test subscription disabled.');
    await _clearLocalSubscriptionStatus();
  }
}

// AdManagerクラスの実装（サブスクリプション対応）
class AdManager {
  static final Map<int, BannerAd?> _gridBannerAds = {};
  static final Map<int, bool> _isGridBannerAdReady = {};
  static final Map<int, DateTime> _lastAdLoadAttempt = {};
  static final Map<int, int> _failureCount = {};
  static const Duration _initialBackoff = Duration(seconds: 5);
  static const int _maxRetries = 3;

  static void dispose() {
    _gridBannerAds.forEach((_, ad) => ad?.dispose());
    _gridBannerAds.clear();
    _isGridBannerAdReady.clear();
    _lastAdLoadAttempt.clear();
    _failureCount.clear();
  }

  static Duration _getBackoffDuration(int index) {
    final failures = _failureCount[index] ?? 0;
    return Duration(seconds: _initialBackoff.inSeconds * (1 << failures));
  }

  static bool canLoadAdForIndex(int index) {
    final lastAttempt = _lastAdLoadAttempt[index];
    if (lastAttempt == null) return true;

    final backoff = _getBackoffDuration(index);
    return DateTime.now().difference(lastAttempt) >= backoff;
  }

  static Future<void> loadGridBannerAd(int index) async {
    // サブスクリプションチェック
    if (await SubscriptionManager.isSubscriptionActive()) {
      return; // サブスクリプション有効時は広告を読み込まない
    }

    if (_gridBannerAds[index] != null && _isGridBannerAdReady[index] == true) {
      return;
    }

    if (!canLoadAdForIndex(index)) {
      return;
    }

    if ((_failureCount[index] ?? 0) >= _maxRetries) {
      return;
    }

    _lastAdLoadAttempt[index] = DateTime.now();
    _gridBannerAds[index]?.dispose();

    _gridBannerAds[index] = BannerAd(
      adUnitId: 'ca-app-pub-1580421227117187/3454220382',
      request: AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _isGridBannerAdReady[index] = true;
          _failureCount[index] = 0;
        },
        onAdFailedToLoad: (ad, err) {
          print('Grid banner ad failed to load: ${err.message}');
          _isGridBannerAdReady[index] = false;
          _failureCount[index] = (_failureCount[index] ?? 0) + 1;
          ad.dispose();
          _gridBannerAds[index] = null;
        },
      ),
    );

    try {
      await _gridBannerAds[index]?.load();
    } catch (e) {
      print('Exception while loading ad: $e');
      _isGridBannerAdReady[index] = false;
      _failureCount[index] = (_failureCount[index] ?? 0) + 1;
      _gridBannerAds[index]?.dispose();
      _gridBannerAds[index] = null;
    }
  }

  static Future<bool> isAdReadyForIndex(int index) async {
    // サブスクリプションチェック
    if (await SubscriptionManager.isSubscriptionActive()) {
      return false; // サブスクリプション有効時は広告を表示しない
    }
    return _isGridBannerAdReady[index] == true && _gridBannerAds[index] != null;
  }

  static BannerAd? getAdForIndex(int index) {
    return _gridBannerAds[index];
  }

  static void resetFailureCount(int index) {
    _failureCount[index] = 0;
  }
}

class AnimeListTestRanking extends StatefulWidget {
  @override
  _AnimeListTestRankingState createState() => _AnimeListTestRankingState();
}

class _AnimeListTestRankingState extends State<AnimeListTestRanking>
    with SingleTickerProviderStateMixin {
  final UserActivityLogger _logger = UserActivityLogger();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  late rtdb.DatabaseReference databaseReference;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  bool _isRankingExpanded = true;
  List<Map<String, dynamic>> _allAnimeData = [];
  List<Map<String, dynamic>> _sortedAnimeData = [];
  List<Map<String, dynamic>> _topRankedAnime = [];
  List<Map<String, dynamic>> _eventData = [];
  Map<String, List<Map<String, dynamic>>> _prefectureSpots = {};
  List<String> _activeEvents = [];
  bool _isEventsLoaded = false;
  bool _isEventsExpanded = false;
  final AdMob _adMob = AdMob();

  int _dailySpotClickCount = 0;
  bool _showSubscriptionPrompt = false; //テスト用；常にtrueに設定
  String? _todayDate;

  BannerAd? _bottomBannerAd;
  bool _isBottomBannerAdReady = false;
  bool _isSubscriptionActive = false; // サブスクリプション状態

  late TabController _tabController;
  int _currentTabIndex = 0;
  bool _isPrefectureDataFetched = false;

  GlobalKey searchKey = GlobalKey();
  GlobalKey addKey = GlobalKey();
  GlobalKey favoriteKey = GlobalKey();
  GlobalKey checkInKey = GlobalKey();
  GlobalKey firstItemKey = GlobalKey();
  GlobalKey rankingKey = GlobalKey();

  bool _hasShownOpenCountPrompt = false; // 今日既にプロンプトを表示したかのフラグ
  StreamSubscription<DocumentSnapshot>? _dailyUsageSubscription;

  final FirebaseInAppMessaging fiam = FirebaseInAppMessaging.instance;

  final Map<String, Map<String, double>> prefectureBounds = {
    '北海道': {'minLat': 41.3, 'maxLat': 45.6, 'minLng': 139.3, 'maxLng': 148.9},
    '青森県': {'minLat': 40.2, 'maxLat': 41.6, 'minLng': 139.5, 'maxLng': 141.7},
    '岩手県': {'minLat': 38.7, 'maxLat': 40.5, 'minLng': 140.6, 'maxLng': 142.1},
    '宮城県': {'minLat': 37.8, 'maxLat': 39.0, 'minLng': 140.3, 'maxLng': 141.7},
    '秋田県': {'minLat': 38.8, 'maxLat': 40.5, 'minLng': 139.7, 'maxLng': 141.0},
    '山形県': {'minLat': 37.8, 'maxLat': 39.0, 'minLng': 139.5, 'maxLng': 140.6},
    '福島県': {'minLat': 36.8, 'maxLat': 38.0, 'minLng': 139.2, 'maxLng': 141.0},
    '茨城県': {'minLat': 35.8, 'maxLat': 36.9, 'minLng': 139.7, 'maxLng': 140.9},
    '栃木県': {'minLat': 36.2, 'maxLat': 37.2, 'minLng': 139.3, 'maxLng': 140.3},
    '群馬県': {'minLat': 36.0, 'maxLat': 37.0, 'minLng': 138.4, 'maxLng': 139.7},
    '埼玉県': {'minLat': 35.7, 'maxLat': 36.3, 'minLng': 138.8, 'maxLng': 139.9},
    '千葉県': {'minLat': 34.9, 'maxLat': 36.1, 'minLng': 139.7, 'maxLng': 140.9},
    '東京都': {'minLat': 35.5, 'maxLat': 35.9, 'minLng': 138.9, 'maxLng': 139.9},
    '神奈川県': {'minLat': 35.1, 'maxLat': 35.7, 'minLng': 139.0, 'maxLng': 139.8},
    '新潟県': {'minLat': 36.8, 'maxLat': 38.6, 'minLng': 137.6, 'maxLng': 139.8},
    '富山県': {'minLat': 36.2, 'maxLat': 36.9, 'minLng': 136.8, 'maxLng': 137.7},
    '石川県': {'minLat': 36.0, 'maxLat': 37.6, 'minLng': 136.2, 'maxLng': 137.4},
    '福井県': {'minLat': 35.3, 'maxLat': 36.3, 'minLng': 135.4, 'maxLng': 136.8},
    '山梨県': {'minLat': 35.2, 'maxLat': 35.9, 'minLng': 138.2, 'maxLng': 139.1},
    '長野県': {'minLat': 35.2, 'maxLat': 37.0, 'minLng': 137.3, 'maxLng': 138.7},
    '岐阜県': {'minLat': 35.2, 'maxLat': 36.5, 'minLng': 136.3, 'maxLng': 137.6},
    '静岡県': {'minLat': 34.6, 'maxLat': 35.7, 'minLng': 137.4, 'maxLng': 139.1},
    '愛知県': {'minLat': 34.6, 'maxLat': 35.4, 'minLng': 136.7, 'maxLng': 137.8},
    '三重県': {'minLat': 33.7, 'maxLat': 35.3, 'minLng': 135.9, 'maxLng': 136.9},
    '滋賀県': {'minLat': 34.8, 'maxLat': 35.7, 'minLng': 135.8, 'maxLng': 136.4},
    '京都府': {'minLat': 34.7, 'maxLat': 35.8, 'minLng': 134.8, 'maxLng': 136.0},
    '大阪府': {'minLat': 34.2, 'maxLat': 35.0, 'minLng': 135.1, 'maxLng': 135.7},
    '兵庫県': {'minLat': 34.2, 'maxLat': 35.7, 'minLng': 134.2, 'maxLng': 135.4},
    '奈良県': {'minLat': 33.8, 'maxLat': 34.7, 'minLng': 135.6, 'maxLng': 136.2},
    '和歌山県': {'minLat': 33.4, 'maxLat': 34.3, 'minLng': 135.0, 'maxLng': 136.0},
    '鳥取県': {'minLat': 35.1, 'maxLat': 35.6, 'minLng': 133.1, 'maxLng': 134.4},
    '島根県': {'minLat': 34.3, 'maxLat': 35.6, 'minLng': 131.6, 'maxLng': 133.4},
    '岡山県': {'minLat': 34.3, 'maxLat': 35.4, 'minLng': 133.3, 'maxLng': 134.4},
    '広島県': {'minLat': 34.0, 'maxLat': 35.1, 'minLng': 132.0, 'maxLng': 133.5},
    '山口県': {'minLat': 33.8, 'maxLat': 34.8, 'minLng': 130.8, 'maxLng': 132.4},
    '徳島県': {'minLat': 33.5, 'maxLat': 34.2, 'minLng': 133.6, 'maxLng': 134.8},
    '香川県': {'minLat': 34.0, 'maxLat': 34.6, 'minLng': 133.5, 'maxLng': 134.4},
    '愛媛県': {'minLat': 32.9, 'maxLat': 34.3, 'minLng': 132.0, 'maxLng': 133.7},
    '高知県': {'minLat': 32.7, 'maxLat': 33.9, 'minLng': 132.5, 'maxLng': 134.3},
    '福岡県': {'minLat': 33.1, 'maxLat': 34.0, 'minLng': 129.9, 'maxLng': 131.0},
    '佐賀県': {'minLat': 32.9, 'maxLat': 33.6, 'minLng': 129.7, 'maxLng': 130.5},
    '長崎県': {'minLat': 32.6, 'maxLat': 34.7, 'minLng': 128.6, 'maxLng': 130.4},
    '熊本県': {'minLat': 32.1, 'maxLat': 33.2, 'minLng': 129.9, 'maxLng': 131.2},
    '大分県': {'minLat': 32.7, 'maxLat': 33.7, 'minLng': 130.7, 'maxLng': 132.1},
    '宮崎県': {'minLat': 31.3, 'maxLat': 32.9, 'minLng': 130.7, 'maxLng': 131.9},
    '鹿児島県': {'minLat': 30.4, 'maxLat': 32.2, 'minLng': 129.5, 'maxLng': 131.1},
    '沖縄県': {'minLat': 24.0, 'maxLat': 27.9, 'minLng': 122.9, 'maxLng': 131.3},
  };

  final List<String> _allPrefectures = [
    '北海道',
    '青森県',
    '岩手県',
    '宮城県',
    '秋田県',
    '山形県',
    '福島県',
    '茨城県',
    '栃木県',
    '群馬県',
    '埼玉県',
    '千葉県',
    '東京都',
    '神奈川県',
    '新潟県',
    '富山県',
    '石川県',
    '福井県',
    '山梨県',
    '長野県',
    '岐阜県',
    '静岡県',
    '愛知県',
    '三重県',
    '滋賀県',
    '京都府',
    '大阪府',
    '兵庫県',
    '奈良県',
    '和歌山県',
    '鳥取県',
    '島根県',
    '岡山県',
    '広島県',
    '山口県',
    '徳島県',
    '香川県',
    '愛媛県',
    '高知県',
    '福岡県',
    '佐賀県',
    '長崎県',
    '熊本県',
    '大分県',
    '宮崎県',
    '鹿児島県',
    '沖縄県'
  ];

  final ScrollController _scrollController = ScrollController();
  bool _showRanking = true;

  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  // アプリ初期化（RevenueCat含む）
  Future<void> _initializeApp() async {
    // RevenueCatを初期化（main.dartと同じAPI Keyを使用）
    await SubscriptionManager.initializeWithDebug();

    _initializeTabController();
    //【修正】初期化後にサブスクリプション状態をチェック
    await _checkSubscriptionStatusWithRetry();

    //【修正】Firebase openCount監視を開始
    await _startOpenCountMonitoring();

    //【追加】スポット押下回数の初期化
    await _initializeDailyClickCount();

    databaseReference =
        rtdb.FirebaseDatabase.instance.ref().child('anime_rankings');
    _fetchAnimeData();
    _fetchEventData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorial());
    _listenToRankingChanges();
    _setupInAppMessaging();

    //サブスクリプション状態を確認してから広告をロード
    _loadBottomBannerAdIfNeeded();

    _scrollController.addListener(_onScroll);

    // main.dartと同様にFirebaseAuthのユーザー情報でRevenueCatを同期
    await _syncRevenueCatUser();
  }

  Future<void> _startOpenCountMonitoring() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ User not logged in - cannot monitor openCount');
        return;
      }

      // 今日の日付を取得
      final today = DateTime.now();
      final dateString =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      print('🔍 Starting openCount monitoring for date: $dateString');

      // Firestore daily_usage/{userId}/daily_usage/{date} のパスを監視
      final dailyUsageRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('daily_usage')
          .doc(dateString);

      // リアルタイムリスナーを設定
      _dailyUsageSubscription = dailyUsageRef.snapshots().listen(
        (DocumentSnapshot snapshot) async {
          if (snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>?;
            final openCount = data?['openCount'] as int? ?? 0;

            print('📊 OpenCount updated: $openCount');

            // 10回に達した場合の処理
            if (openCount >= 4 && !_hasShownOpenCountPrompt) {
              await _handleOpenCountThresholdReached(openCount);
            }
          } else {
            print('📄 Daily usage document does not exist yet');
          }
        },
        onError: (error) {
          print('❌ Error listening to daily usage: $error');
        },
      );

      print('✅ OpenCount monitoring started successfully');
    } catch (e) {
      print('❌ Error starting openCount monitoring: $e');
    }
  }

  // 【新規追加】openCount 10回到達時の処理
  Future<void> _handleOpenCountThresholdReached(int openCount) async {
    try {
      print('🎯 OpenCount threshold reached: $openCount');

      // サブスクリプションが既に有効な場合は何もしない
      if (_isSubscriptionActive) {
        print('🚫 Subscription already active - skipping prompt');
        return;
      }

      // 今日既にプロンプトを表示した場合は何もしない
      if (_hasShownOpenCountPrompt) {
        print('🚫 Prompt already shown today - skipping');
        return;
      }

      // SharedPreferencesで今日の表示状態を確認
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toString().split(' ')[0];
      final promptShownKey = 'opencount_prompt_shown_$today';
      final alreadyShown = prefs.getBool(promptShownKey) ?? false;

      if (alreadyShown) {
        print('🚫 Prompt already shown today (from SharedPreferences)');
        _hasShownOpenCountPrompt = true;
        return;
      }

      // フラグを設定してプロンプト表示
      _hasShownOpenCountPrompt = true;
      await prefs.setBool(promptShownKey, true);

      // ユーザーアクティビティログ
      await _logger.logUserActivity('opencount_threshold_reached', {
        'openCount': openCount,
        'timestamp': DateTime.now().toIso8601String(),
        'subscriptionActive': _isSubscriptionActive,
      });

      // UI更新でプロンプトを表示
      if (mounted) {
        setState(() {
          _showSubscriptionPrompt = true;
        });

        print('✅ Subscription prompt displayed due to openCount: $openCount');

        // 追加のハプティックフィードバック（オプション）
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      print('❌ Error handling openCount threshold: $e');
    }
  }

  // 【新規追加】今日のプロンプト表示状態をリセット（デバッグ用）
  Future<void> _resetTodayPromptStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toString().split(' ')[0];
      final promptShownKey = 'opencount_prompt_shown_$today';

      await prefs.remove(promptShownKey);
      _hasShownOpenCountPrompt = false;

      print('🔄 Today\'s prompt status reset');
    } catch (e) {
      print('❌ Error resetting prompt status: $e');
    }
  }

  // 【新規追加】手動でopenCountをインクリメント（デバッグ用）
  Future<void> _debugIncrementOpenCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final today = DateTime.now();
      final dateString =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final dailyUsageRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('daily_usage')
          .doc(dateString);

      await dailyUsageRef.update({
        'openCount': FieldValue.increment(1),
        'lastOpenedAt': FieldValue.serverTimestamp(),
      });

      print('🔧 Debug: openCount incremented');
    } catch (e) {
      print('❌ Error incrementing openCount: $e');
    }
  }

  //【追加】日次スポット押下回数の初期化
  Future<void> _initializeDailyClickCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toString().split(' ')[0];
      _todayDate = today;

      //保存されている日付を確認
      final savedDate = prefs.getString('spot_click_date');

      if (savedDate != today) {
        //日付が変わっている場合はカウントをリセット
        _dailySpotClickCount = 0;
        await prefs.setInt('daily_spot_click_count', 0);
        await prefs.setString('spot_click_date', today);
      } else {
        _dailySpotClickCount = prefs.getInt('daily_spot_click_count') ?? 0;
      }

      //テスト用
      //テストをする際には、こちらのコメントアウトをはずしてください。
      // setState(() {
      //   _showSubscriptionPrompt = true;
      // });

      print('Daily spot click count initialized: $_dailySpotClickCount');
    } catch (e) {
      print('Error initializing daily click count: $e');
      _dailySpotClickCount = 0;
    }
  }

  //【追加】スポット押下回数を増加
  Future<void> _incrementSpotClickCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dailySpotClickCount++;

      await prefs.setInt('daily_spot_click_count', _dailySpotClickCount);

      print('Spot click count: $_dailySpotClickCount');

      //10回に達した場合の処理
      if (_dailySpotClickCount >= 10) {
        //サブスクリプションが有効でない場合のみプロンプトを表示
        if (!_isSubscriptionActive) {
          setState(() {
            _showSubscriptionPrompt = true;
          });
          print('Subscription prompt should be shown');
        } else {
          print('Subscription prompt skipped (already subscribed)');
        }
      }
    } catch (e) {
      print('Error incrementing spot click count: $e');
    }
  }

  // 【修正】リトライ機能付きのサブスクリプション状態チェック
  Future<void> _checkSubscriptionStatusWithRetry() async {
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        final isActive = await SubscriptionManager.isSubscriptionActive();
        print('🔍 Subscription check attempt ${retryCount + 1}: $isActive');

        if (mounted) {
          setState(() {
            _isSubscriptionActive = isActive;
          });
        }

        // 成功したら抜ける
        break;
      } catch (e) {
        retryCount++;
        print('❌ Subscription check failed (attempt $retryCount): $e');

        if (retryCount < maxRetries) {
          // 指数バックオフで待機
          await Future.delayed(Duration(seconds: 2 * retryCount));
        } else {
          // 最終的に失敗した場合はローカルから確認
          print('🔄 Final attempt: checking local status');
          final localStatus = await _checkLocalSubscriptionFallback();
          if (mounted) {
            setState(() {
              _isSubscriptionActive = localStatus;
            });
          }
        }
      }
    }

    print('🎯 Final subscription status: $_isSubscriptionActive');
  }

  // 【追加】ローカルフォールバック確認
  Future<bool> _checkLocalSubscriptionFallback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('local_subscription_active') ?? false;
    } catch (e) {
      print('❌ Local fallback check failed: $e');
      return false;
    }
  }

  // 【修正】サブスクリプション状態チェック（シンプル版）
  Future<void> _checkSubscriptionStatus() async {
    try {
      final isActive = await SubscriptionManager.isSubscriptionActive();
      if (mounted) {
        setState(() {
          _isSubscriptionActive = isActive;
        });
      }
      print('🎯 Subscription status updated: $isActive');
    } catch (e) {
      print('❌ Subscription status check error: $e');
    }
  }

  // 【修正】広告ロード（サブスクリプション状態確認付き）
  void _loadBottomBannerAdIfNeeded() async {
    // サブスクリプションチェック
    if (_isSubscriptionActive) {
      print('🚫 Skipping ad load - subscription active');
      return;
    }

    try {
      // Dispose existing ad before creating new one
      _bottomBannerAd?.dispose();
      _bottomBannerAd = null;
      _isBottomBannerAdReady = false;

      _bottomBannerAd = BannerAd(
        adUnitId: 'ca-app-pub-1580421227117187/2839937902',
        request: AdRequest(),
        size: AdSize.banner,
        listener: BannerAdListener(
          onAdLoaded: (_) {
            print('✅ Bottom banner ad loaded');
            if (mounted) {
              setState(() {
                _isBottomBannerAdReady = true;
              });
            }
          },
          onAdFailedToLoad: (ad, err) {
            print('❌ Bottom banner ad failed to load: ${err.message}');
            if (mounted) {
              setState(() {
                _isBottomBannerAdReady = false;
              });
            }
            ad.dispose();
            _bottomBannerAd = null;
          },
        ),
      );
      await _bottomBannerAd?.load();
    } catch (e) {
      print('❌ Exception loading bottom banner ad: $e');
      _bottomBannerAd?.dispose();
      _bottomBannerAd = null;
    }
  }

  // main.dartから移植したRevenueCatユーザー同期機能
  Future<void> _syncRevenueCatUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // RevenueCatにユーザーIDを同期
        await SubscriptionManager.setUserId(user.uid);
        print('RevenueCat user synced: ${user.uid}');

        // 購読状態を確認してFirestoreに同期
        final customerInfo = await SubscriptionManager.getCustomerInfo();
        if (customerInfo != null) {
          print('Customer Info: ${customerInfo.originalAppUserId}');
          print('Active subscriptions: ${customerInfo.activeSubscriptions}');
          print('Active entitlements: ${customerInfo.entitlements.active}');
        }
      }
    } catch (e) {
      print('RevenueCat user sync failed: $e');
    }
  }

  void _loadBottomBannerAd() async {
    // サブスクリプションチェック
    if (await SubscriptionManager.isSubscriptionActive()) {
      return; // サブスクリプション有効時は広告を読み込まない
    }

    // Dispose existing ad before creating new one
    _bottomBannerAd?.dispose();
    _bottomBannerAd = null;
    _isBottomBannerAdReady = false;

    _bottomBannerAd = BannerAd(
      adUnitId: 'ca-app-pub-1580421227117187/2839937902',
      request: AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBottomBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          print('Bottom banner ad failed to load: ${err.message}');
          setState(() {
            _isBottomBannerAdReady = false;
          });
          ad.dispose();
          _bottomBannerAd = null;
        },
      ),
    );
    _bottomBannerAd?.load();
  }

  Future<void> _initializeTabController() async {
    await _checkActiveEvents();
    int tabCount = 3; // Always 3 tabs: Anime, Events, Location
    _tabController = TabController(length: tabCount, vsync: this);
    _tabController.addListener(_handleTabChange);
    setState(() {
      _isEventsLoaded = true;
    });
  }

  Future<void> _checkActiveEvents() async {
    try {
      final eventSnapshot = await firestore.collection('events').get();
      final activeEvents = eventSnapshot.docs
          .where((doc) => doc.data()['isEnabled'] == true)
          .map((doc) => doc.data()['title'] as String? ?? '')
          .toList();

      setState(() {
        _activeEvents = activeEvents;
      });
    } catch (e) {
      print('Error fetching events: $e');
      _activeEvents = [];
    }
  }

  void _loadBannerAd() async {
    // サブスクリプションチェック
    if (await SubscriptionManager.isSubscriptionActive()) {
      return; // サブスクリプション有効時は広告を読み込まない
    }

    _bannerAd = BannerAd(
      adUnitId: '',
      request: AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          print('Failed to load a banner ad: ${err.message}');
          _isBannerAdReady = false;
          ad.dispose();
        },
      ),
    );

    _bannerAd?.load();
  }

  void _setupInAppMessaging() {
    fiam.triggerEvent('app_open');
    fiam.setMessagesSuppressed(false);
  }

  void _listenToRankingChanges() {
    databaseReference.onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> rankings =
            event.snapshot.value as Map<dynamic, dynamic>;
        _updateRankings(rankings);
      }
    });
  }

  void _updateRankings(Map<dynamic, dynamic> rankings) {
    List<MapEntry<String, int>> sortedRankings = rankings.entries
        .map((entry) =>
            MapEntry(entry.key.toString(), (entry.value as num).toInt()))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    setState(() {
      _topRankedAnime = sortedRankings.take(10).map((entry) {
        return _allAnimeData.firstWhere(
          (anime) => anime['name'] == entry.key,
          orElse: () =>
              {'name': entry.key, 'imageUrl': '', 'count': entry.value},
        );
      }).toList();

      for (var anime in _allAnimeData) {
        anime['count'] = rankings[anime['name']] != null
            ? (rankings[anime['name']] as num).toInt()
            : 0;
      }

      _allAnimeData
          .sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    _bannerAd?.dispose();
    _bottomBannerAd?.dispose();
    _dailyUsageSubscription?.cancel();
    AdManager.dispose();
    super.dispose();
    _adMob.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels > 0 && _showRanking) {
      setState(() {
        _showRanking = false;
        _isRankingExpanded = false;
      });
    } else if (_scrollController.position.pixels == 0 && !_showRanking) {
      setState(() {
        _showRanking = true;
        _isRankingExpanded = true;
      });
    }
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });

      _logger.logUserActivity('tab_change', {
        'from_tab': _currentTabIndex == 0 ? 'anime' : 'location',
        'to_tab': _tabController.index == 0 ? 'anime' : 'location',
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (_currentTabIndex == 2 && !_isPrefectureDataFetched) {
        _fetchPrefectureData();
      }
    }
  }

  Future<void> _showTutorial() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool showTutorial = prefs.getBool('showTutorial') ?? true;

    if (showTutorial) {
      ShowCaseWidget.of(context).startShowCase([
        rankingKey,
        searchKey,
        addKey,
        favoriteKey,
        checkInKey,
        firstItemKey,
      ]);
      await prefs.setBool('showTutorial', false);
    }
  }

  Future<void> _fetchAnimeData() async {
    try {
      QuerySnapshot animeSnapshot = await firestore.collection('animes').get();
      _allAnimeData = animeSnapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return {
          'name': data['name'] ?? '',
          'imageUrl': data['imageUrl'] ?? '',
          'count': 0,
          'sortKey': _getSortKey(data['name'] ?? ''),
        };
      }).toList();

      _sortedAnimeData = List.from(_allAnimeData);
      _sortedAnimeData
          .sort((a, b) => _compareNames(a['sortKey'], b['sortKey']));

      DatabaseEvent event = await databaseReference.once();
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> rankings =
            event.snapshot.value as Map<dynamic, dynamic>;
        _updateRankings(rankings);
      }

      setState(() {});
    } catch (e) {
      print("Error fetching anime data: $e");
    }
  }

  Future<void> _fetchEventData() async {
    try {
      final eventSnapshot = await firestore.collection('events').get();
      final events = eventSnapshot.docs
          .where((doc) => doc.data()['isEnabled'] == true)
          .map((doc) {
        final data = doc.data();
        return {
          'title': data['title'] as String? ?? '',
          'imageUrl': data['imageUrl'] as String? ?? '',
          'description': data['description'] as String? ?? '',
          'startDate': data['startDate'],
          'htmlContent': data['html'] as String? ?? '',
          'endDate': data['endDate'],
        };
      }).toList();

      setState(() {
        _eventData = events;
      });
    } catch (e) {
      print('Error fetching event data: $e');
    }
  }

  String _getSortKey(String name) {
    if (name.isEmpty) return '';

    String hiragana = _katakanaToHiragana(name);

    if (RegExp(r'^[A-Za-z]').hasMatch(name)) {
      return 'ん' + name.toLowerCase();
    }

    return hiragana;
  }

  String _katakanaToHiragana(String kata) {
    const Map<String, String> katakanaToHiragana = {
      'ア': 'あ',
      'イ': 'い',
      'ウ': 'う',
      'エ': 'え',
      'オ': 'お',
      'カ': 'か',
      'キ': 'き',
      'ク': 'く',
      'ケ': 'け',
      'コ': 'こ',
      'サ': 'さ',
      'シ': 'し',
      'ス': 'す',
      'セ': 'せ',
      'ソ': 'そ',
      'タ': 'た',
      'チ': 'ち',
      'ツ': 'つ',
      'テ': 'て',
      'ト': 'と',
      'ナ': 'な',
      'ニ': 'に',
      'ヌ': 'ぬ',
      'ネ': 'ね',
      'ノ': 'の',
      'ハ': 'は',
      'ヒ': 'ひ',
      'フ': 'ふ',
      'ヘ': 'へ',
      'ホ': 'ほ',
      'マ': 'ま',
      'ミ': 'み',
      'ム': 'む',
      'メ': 'め',
      'モ': 'も',
      'ヤ': 'や',
      'ユ': 'ゆ',
      'ヨ': 'よ',
      'ラ': 'ら',
      'リ': 'り',
      'ル': 'る',
      'レ': 'れ',
      'ロ': 'ろ',
      'ワ': 'わ',
      'ヲ': 'を',
      'ン': 'ん',
      'ガ': 'が',
      'ギ': 'ぎ',
      'グ': 'ぐ',
      'ゲ': 'げ',
      'ゴ': 'ご',
      'ザ': 'ざ',
      'ジ': 'じ',
      'ズ': 'ず',
      'ゼ': 'ぜ',
      'ゾ': 'ぞ',
      'ダ': 'だ',
      'ヂ': 'ぢ',
      'ヅ': 'づ',
      'デ': 'で',
      'ド': 'ど',
      'バ': 'ば',
      'ビ': 'び',
      'ブ': 'ぶ',
      'ベ': 'べ',
      'ボ': 'ぼ',
      'パ': 'ぱ',
      'ピ': 'ぴ',
      'プ': 'ぷ',
      'ペ': 'ぺ',
      'ポ': 'ぽ',
      'ャ': 'ゃ',
      'ュ': 'ゅ',
      'ョ': 'ょ',
      'ッ': 'っ',
      'ー': '-',
    };

    String result = kata;
    katakanaToHiragana.forEach((k, v) {
      result = result.replaceAll(k, v);
    });
    return result;
  }

  int _compareNames(String a, String b) {
    if (a.startsWith('ん') && !b.startsWith('ん')) {
      return 1;
    } else if (!a.startsWith('ん') && b.startsWith('ん')) {
      return -1;
    } else if (a.startsWith('ん') && b.startsWith('ん')) {
      return a.substring(1).compareTo(b.substring(1));
    }
    return a.compareTo(b);
  }

  Future<void> _fetchPrefectureData() async {
    if (_isPrefectureDataFetched) return;

    try {
      QuerySnapshot spotSnapshot =
          await firestore.collection('locations').get();
      print("Fetched ${spotSnapshot.docs.length} documents in total");

      for (String prefecture in _allPrefectures) {
        List<Map<String, dynamic>> prefSpots = spotSnapshot.docs
            .map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              return {
                'name': data['sourceTitle'] ?? '',
                'imageUrl': data['imageUrl'] ?? '',
                'anime': data['anime'] ?? '',
                'latitude': (data['latitude'] is num)
                    ? (data['latitude'] as num).toDouble()
                    : 0.0,
                'longitude': (data['longitude'] is num)
                    ? (data['longitude'] as num).toDouble()
                    : 0.0,
                'locationID': doc.id,
              };
            })
            .where((spot) => _isInPrefecture(spot, prefecture))
            .toList();

        _prefectureSpots[prefecture] = prefSpots;
        print("${prefSpots.length} spots added to $prefecture");
      }

      setState(() {
        _isPrefectureDataFetched = true;
      });
    } catch (e) {
      print("Error fetching prefecture data: $e");
    }
  }

  bool _isInPrefecture(Map<String, dynamic> spot, String prefecture) {
    var bounds = prefectureBounds[prefecture];
    if (bounds == null) {
      print("No bounds found for $prefecture");
      return false;
    }

    double lat = spot['latitude'];
    double lng = spot['longitude'];

    bool result = lat >= bounds['minLat']! &&
        lat <= bounds['maxLat']! &&
        lng >= bounds['minLng']! &&
        lng <= bounds['maxLng']!;

    return result;
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });

    if (query.isNotEmpty) {
      _logger.logUserActivity('search', {
        'query': query,
        'currentTab': _currentTabIndex,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  Future<void> _navigateAndVote(BuildContext context, String animeName) async {
    await _logger.logUserActivity('anime_view', {
      'animeName': animeName,
      'timestamp': DateTime.now().toIso8601String(),
    });

    await _incrementSpotClickCount();

    try {
      final String today = DateTime.now().toString().split(' ')[0];
      final prefs = await SharedPreferences.getInstance();
      final String? lastVoteDate = prefs.getString('lastVote_$animeName');

      Map<String, dynamic> voteActivityData = {
        'animeName': animeName,
        'timestamp': DateTime.now().toIso8601String(),
        'isFirstVoteToday': lastVoteDate == null || lastVoteDate != today,
      };

      if (lastVoteDate == null || lastVoteDate != today) {
        final List<String> votedAnimeToday =
            prefs.getStringList('votedAnime_$today') ?? [];

        if (votedAnimeToday.length < 1) {
          rtdb.DatabaseReference animeRef = databaseReference.child(animeName);
          rtdb.TransactionResult result =
              await animeRef.runTransaction((Object? currentValue) {
            if (currentValue == null) {
              return rtdb.Transaction.success(1);
            }
            return rtdb.Transaction.success((currentValue as int) + 1);
          });

          if (result.committed) {
            await prefs.setString('lastVote_$animeName', today);
            votedAnimeToday.add(animeName);
            await prefs.setStringList('votedAnime_$today', votedAnimeToday);

            voteActivityData['status'] = 'success';
            voteActivityData['newCount'] = result.snapshot.value;
            await _logger.logUserActivity('vote_success', voteActivityData);

            print("Incremented count for $animeName");
          } else {
            voteActivityData['status'] = 'failed';
            voteActivityData['error'] = 'Transaction not committed';
            await _logger.logUserActivity('vote_failure', voteActivityData);

            print("Failed to increment count for $animeName");
          }
        } else {
          voteActivityData['status'] = 'limited';
          voteActivityData['reason'] = 'daily_limit_reached';
          await _logger.logUserActivity('vote_limit_reached', voteActivityData);

          print("Daily vote limit reached");
        }
      } else {
        voteActivityData['status'] = 'already_voted';
        voteActivityData['lastVoteDate'] = lastVoteDate;
        await _logger.logUserActivity('vote_already_cast', voteActivityData);

        print("Already voted for this anime today");
      }
    } catch (e) {
      await _logger.logUserActivity('vote_error', {
        'animeName': animeName,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });

      print("Error incrementing anime count: $e");
    }

    await _logger.logUserActivity('navigation', {
      'from': 'anime_list',
      'to': 'anime_details',
      'animeName': animeName,
      'timestamp': DateTime.now().toIso8601String(),
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnimeDetailsPage(animeName: animeName),
      ),
    );
  }

  Widget _buildAnimeList() {
    List<Map<String, dynamic>> filteredAnimeData = _sortedAnimeData
        .where((anime) =>
            anime['name'].toLowerCase().contains(_searchQuery) ||
            _allPrefectures.any((prefecture) =>
                prefecture.toLowerCase().contains(_searchQuery) &&
                (_prefectureSpots[prefecture]?.any((spot) =>
                        spot['anime'].toLowerCase() ==
                        anime['name'].toLowerCase()) ??
                    false)))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExpansionTile(
          title: Text(
            key: rankingKey,
            '■ ランキング (Top 10)',
            style: TextStyle(
              color: Color(0xFF00008b),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          initiallyExpanded: _isRankingExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _isRankingExpanded = expanded;
            });
          },
          children: _showRanking
              ? [
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      scrollDirection: Axis.horizontal,
                      itemCount: _topRankedAnime.length,
                      itemBuilder: (context, index) {
                        final anime = _topRankedAnime[index];
                        return GestureDetector(
                          onTap: () => _navigateAndVote(context, anime['name']),
                          child: Container(
                            width: 160,
                            margin: EdgeInsets.only(right: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: anime['imageUrl'],
                                        height: 150,
                                        width: 250,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Center(
                                            child: CircularProgressIndicator()),
                                        errorWidget: (context, url, error) =>
                                            Icon(Icons.error),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.7),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  anime['name'],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ]
              : [],
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            '■ アニメ一覧',
            style: TextStyle(
              color: Color(0xFF00008b),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        Expanded(
          child: _allAnimeData.isEmpty
              ? Center(child: CircularProgressIndicator())
              : filteredAnimeData.isEmpty
                  ? Center(
                      child: Text('何も見つかりませんでした。。'),
                    )
                  : GridView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.only(bottom: 16.0),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.3,
                        mainAxisSpacing: 1.0,
                        crossAxisSpacing: 3.0,
                      ),
                      itemCount: filteredAnimeData.length,
                      itemBuilder: (context, index) {
                        // サブスクリプション有効時は広告を表示しない
                        if (!_isSubscriptionActive &&
                            index != 0 &&
                            index % 6 == 0) {
                          if (AdManager.canLoadAdForIndex(index)) {
                            Future.microtask(
                                () => AdManager.loadGridBannerAd(index));
                          }

                          return FutureBuilder<bool>(
                            future: AdManager.isAdReadyForIndex(index),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data == true) {
                                final ad = AdManager.getAdForIndex(index);
                                if (ad != null) {
                                  return Container(
                                    width: ad.size.width.toDouble(),
                                    height: ad.size.height.toDouble(),
                                    child: AdWidget(ad: ad),
                                  );
                                }
                              }
                              return Container(
                                height: 50,
                                child: Center(
                                    child: Text(
                                  '広告',
                                  style: TextStyle(
                                    color: Colors.grey,
                                  ),
                                )),
                              );
                            },
                          );
                        }

                        // サブスクリプション有効時、または広告表示位置でない場合のアニメアイテム表示
                        final adjustedIndex = _isSubscriptionActive
                            ? index
                            : index - (index ~/ 6);
                        if (adjustedIndex >= filteredAnimeData.length) {
                          return SizedBox();
                        }

                        final animeName =
                            filteredAnimeData[adjustedIndex]['name'];
                        final imageUrl =
                            filteredAnimeData[adjustedIndex]['imageUrl'];
                        final key = adjustedIndex == 0 ? firstItemKey : null;

                        return GestureDetector(
                          key: key,
                          onTap: () => _navigateAndVote(context, animeName),
                          child: AnimeGridItem(
                            animeName: animeName,
                            imageUrl: imageUrl,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // サブスクリプション購入ダイアログを表示
  void _showSubscriptionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'プレミアムプラン',
            style: TextStyle(
              color: Color(0xFF00008b),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('プレミアムプランの特典:'),
              SizedBox(height: 8),
              Text('• 全ての広告を非表示'),
              Text('• 快適な巡礼体験'),
              Text('• アプリ開発のサポート'),
              SizedBox(height: 16),
              Text(
                '月額料金でプレミアム体験をお楽しみください',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('キャンセル'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _handleSubscriptionPurchase();
              },
              child: Text(
                'プレミアムに登録',
                style: TextStyle(
                  color: Color(0xFF00008b),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _handleSubscriptionRestore();
              },
              child: Text(
                '復元',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        );
      },
    );
  }

  // サブスクリプション復元処理
  Future<void> _handleSubscriptionRestore() async {
    try {
      // ローディング表示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      final bool success = await SubscriptionManager.restoreSubscription();

      // ローディング非表示
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (success) {
        await _checkSubscriptionStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('プレミアムプランを復元しました！'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('復元できるプレミアムプランがありません。'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      // ローディング非表示
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('復元エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 【追加】サブスクリプションプロンプトオーバーレイ
  Widget _buildSubscriptionPromptOverlay() {
    //サブスクリプションが有効な場合は何も表示しない
    if (_isSubscriptionActive) {
      return SizedBox.shrink();
    }

    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              // メインコンテンツ
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 画像部分（サンプル画像）
                    Container(
                      width: 200,
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[200],
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.star,
                            size: 40,
                            color: Color(0xFF00008b),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'プレミアムプラン',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00008b),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'たくさんのご利用\nありがとうございます！',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'プレミアムプランで広告なしの\n快適な聖地巡礼をお楽しみください',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 20),
                    // プレミアムプランボタン
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          // プロンプトを閉じる
                          setState(() {
                            _showSubscriptionPrompt = false;
                          });

                          // ユーザーアクティビティログ
                          await _logger
                              .logUserActivity('subscription_prompt_clicked', {
                            'source': 'opencount_threshold',
                            'timestamp': DateTime.now().toIso8601String(),
                          });

                          // サブスクリプション画面を表示
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) =>
                                const PaymentSubscriptionScreen(),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF00008b),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'プレミアムプランを見る',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // 【追加】後で見るボタン
                    SizedBox(height: 8),
                    TextButton(
                      onPressed: () async {
                        setState(() {
                          _showSubscriptionPrompt = false;
                        });

                        // ユーザーアクティビティログ
                        await _logger
                            .logUserActivity('subscription_prompt_dismissed', {
                          'source': 'opencount_threshold',
                          'action': 'later',
                          'timestamp': DateTime.now().toIso8601String(),
                        });
                      },
                      child: Text(
                        '後で見る',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 閉じるボタン（右上）
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () async {
                    setState(() {
                      _showSubscriptionPrompt = false;
                    });

                    // ユーザーアクティビティログ
                    await _logger
                        .logUserActivity('subscription_prompt_dismissed', {
                      'source': 'opencount_threshold',
                      'action': 'close_button',
                      'timestamp': DateTime.now().toIso8601String(),
                    });
                  },
                  icon: Icon(
                    Icons.close,
                    color: Colors.grey[600],
                    size: 24,
                  ),
                  padding: EdgeInsets.all(4),
                  constraints: BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // サブスクリプション購入処理
  Future<void> _handleSubscriptionPurchase() async {
    try {
      // ローディング表示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      final bool success = await SubscriptionManager.purchaseSubscription();

      // ローディング非表示
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (success) {
        await _checkSubscriptionStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('プレミアムプランに登録しました！'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('購入に失敗しました。もう一度お試しください。'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // ローディング非表示
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEventsLoaded) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('アプリを終了しますか？'),
                content: Text('アプリを閉じてもよろしいですか？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('キャンセル'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text('終了'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: _currentTabIndex == 0
                        ? 'アニメで検索...'
                        : _currentTabIndex == 1
                            ? '都道府県で検索...'
                            : 'イベントで検索...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                  style: TextStyle(color: Colors.black),
                )
              : Row(
                  children: [
                    Text(
                      '巡礼スポット',
                      style: TextStyle(
                        color: Color(0xFF00008b),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // サブスクリプション状態表示
                    if (_isSubscriptionActive)
                      Container(
                        margin: EdgeInsets.only(left: 8),
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Premium',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
          actions: [
            IconButton(
              key: checkInKey,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SpotTestScreen()),
              ),
              icon: const Icon(Icons.check_circle, color: Color(0xFF00008b)),
            ),
            IconButton(
              key: favoriteKey,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => FavoriteLocationsPage()),
              ),
              icon: const Icon(Icons.favorite, color: Color(0xFF00008b)),
            ),
            // プレミアム購入・管理ボタン追加
            // if (!_isSubscriptionActive)
            //   IconButton(
            //     icon: Icon(Icons.star, color: Color(0xFF00008b)),
            //     onPressed: () => _showSubscriptionDialog(),
            //   ),
            IconButton(
              key: addKey,
              icon: Icon(Icons.add, color: Color(0xFF00008b)),
              onPressed: () {
                showCupertinoModalPopup(
                  context: context,
                  builder: (BuildContext context) => CupertinoActionSheet(
                    title: Text(
                      'リクエストを選択',
                      style: TextStyle(
                        color: Colors.black,
                      ),
                    ),
                    message: Text(
                      '新しく追加したいコンテンツを選択してください',
                      style: TextStyle(
                        color: Colors.black,
                      ),
                    ),
                    actions: <CupertinoActionSheetAction>[
                      CupertinoActionSheetAction(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    AnimeRequestCustomerForm()),
                          );
                        },
                        child: Text(
                          '聖地をリクエストする',
                          style: TextStyle(
                            color: Color(0xFF00008b),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      CupertinoActionSheetAction(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    AnimeNameRequestCustomerForm()),
                          );
                        },
                        child: Text(
                          'アニメをリクエストする',
                          style: TextStyle(
                            color: Color(0xFF00008b),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    cancelButton: CupertinoActionSheetAction(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        'キャンセル',
                        style: TextStyle(
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            IconButton(
              key: searchKey,
              icon: Icon(
                _isSearching ? Icons.close : Icons.search,
                color: Color(0xFF00008b),
              ),
              onPressed: _toggleSearch,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: 'アニメから探す'),
              Tab(
                text: 'イベント情報',
              ),
              Tab(text: '場所から探す'),
            ],
            labelColor: Color(0xFF00008b),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF00008b),
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: TabBarView(
                    physics: NeverScrollableScrollPhysics(),
                    controller: _tabController,
                    children: [
                      _buildAnimeList(),
                      EventSection(),
                      _currentTabIndex == 2
                          ? PrefectureListPage(
                              prefectureSpots: _prefectureSpots,
                              searchQuery: _searchQuery,
                              onFetchPrefectureData: _fetchPrefectureData,
                            )
                          : Container(),
                    ],
                  ),
                ),
                // サブスクリプション有効時は底部広告を非表示
                if (!_isSubscriptionActive &&
                    _isBottomBannerAdReady &&
                    _bottomBannerAd != null)
                  Container(
                    width: _bottomBannerAd!.size.width.toDouble(),
                    height: _bottomBannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bottomBannerAd!),
                  ),
              ],
            ),
            // 【追加】サブスクリプションプロンプトオーバーレイ
            if (_showSubscriptionPrompt) _buildSubscriptionPromptOverlay(),
          ],
        ),
      ),
    );
  }
}

class AnimeGridItem extends StatelessWidget {
  final String animeName;
  final String imageUrl;

  const AnimeGridItem({
    Key? key,
    required this.animeName,
    required this.imageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Center(
                child: CircularProgressIndicator(),
              ),
              errorWidget: (context, url, error) => Icon(Icons.error),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              animeName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
