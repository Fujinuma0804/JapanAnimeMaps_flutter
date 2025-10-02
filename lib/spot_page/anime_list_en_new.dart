import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:parts/components/ad_mob.dart';
import 'package:parts/spot_page/anime_list_en_detail.dart';
import 'package:parts/spot_page/check_in_en_screen.dart';
import 'package:parts/spot_page/customer_anime_request_en.dart';
import 'package:parts/spot_page/liked_post_en.dart';
import 'package:parts/spot_page/prefecture_list_en.dart';
import 'package:parts/spot_page/user_activity_logger.dart';
import 'package:parts/spot_page/anime_list_test_ranking.dart';
import 'package:parts/subscription/payment_subscription.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:parts/components/shimmer_loading.dart';

import 'anime_list_detail.dart';
import 'anime_list_en_ranking.dart';
import 'customer_anime_request.dart';
import 'liked_post.dart';

// 【修正】AdManagerクラスにサブスクリプション対応を追加
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

  // 【修正】サブスクリプションチェックを追加
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

  // 【修正】サブスクリプションチェックを追加
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

class PrefectureListPage2 extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> prefectureSpots;
  final String searchQuery;
  final Function onFetchPrefectureData;

  // 画像ファイル名用の英語から日本語への都道府県名マッピング
  final Map<String, String> prefectureImageMapping = {
    'Hokkaido': '北海道',
    'Aomori': '青森県',
    'Iwate': '岩手県',
    'Miyagi': '宮城県',
    'Akita': '秋田県',
    'Yamagata': '山形県',
    'Fukushima': '福島県',
    'Ibaraki': '茨城県',
    'Tochigi': '栃木県',
    'Gunma': '群馬県',
    'Saitama': '埼玉県',
    'Chiba': '千葉県',
    'Tokyo': '東京都',
    'Kanagawa': '神奈川県',
    'Nigata': '新潟県',
    'Toyama': '富山県',
    'Ishikawa': '石川県',
    'Fukui': '福井県',
    'Yamanashi': '山梨県',
    'Nagano': '長野県',
    'Gifu': '岐阜県',
    'Shizuoka': '静岡県',
    'Aichi': '愛知県',
    'Mie': '三重県',
    'Shiga': '滋賀県',
    'Kyoto': '京都府',
    'Osaka': '大阪府',
    'Hyogo': '兵庫県',
    'Nara': '奈良県',
    'Wakayama': '和歌山県',
    'Tottori': '鳥取県',
    'Shimane': '島根県',
    'Okayama': '岡山県',
    'Hiroshima': '広島県',
    'Yamaguchi': '山口県',
    'Tokushima': '徳島県',
    'Kagawa': '香川県',
    'Ehime': '愛媛県',
    'Kochi': '高知県',
    'Fukuoka': '福岡県',
    'Saga': '佐賀県',
    'Nagasaki': '長崎県',
    'Kumamoto': '熊本県',
    'Oita': '大分県',
    'Miyazaki': '宮崎県',
    'Kagoshima': '鹿児島県',
    'Okinawa': '沖縄県',
  };

  PrefectureListPage2({
    required this.prefectureSpots,
    required this.searchQuery,
    required this.onFetchPrefectureData,
  });

  String _getPrefectureImagePath(String englishName) {
    final japaneseName = prefectureImageMapping[englishName] ?? '';
    return 'assets/images/prefectures/$japaneseName.jpg';
  }

  @override
  Widget build(BuildContext context) {
    List<String> filteredPrefectures = prefectureImageMapping.keys
        .where((prefecture) =>
            prefecture.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return GridView.builder(
      padding: EdgeInsets.all(8.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: filteredPrefectures.length,
      itemBuilder: (context, index) {
        final prefecture = filteredPrefectures[index];
        final spots = prefectureSpots[prefecture] ?? [];

        return Card(
          elevation: 2,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PrefectureDetailPage(
                    prefecture: prefecture,
                    spots: spots,
                  ),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Image.asset(
                    _getPrefectureImagePath(prefecture),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Icon(Icons.image_not_supported, size: 40),
                      );
                    },
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(8),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prefecture,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${spots.length} spots',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class PrefectureDetailPage extends StatelessWidget {
  final String prefecture;
  final List<Map<String, dynamic>> spots;

  PrefectureDetailPage({
    required this.prefecture,
    required this.spots,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(prefecture),
      ),
      body: ListView.builder(
        itemCount: spots.length,
        itemBuilder: (context, index) {
          final spot = spots[index];
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: CachedNetworkImage(
                imageUrl: spot['imageUrl'] ?? '',
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                placeholder: (context, url) => ShimmerLoading.imageShimmer(
                  width: double.infinity,
                  height: 60,
                  borderRadius: BorderRadius.circular(8),
                ),
                errorWidget: (context, url, error) => Icon(Icons.error),
              ),
              title: Text(spot['nameEn'] ?? ''),
              subtitle: Text(spot['animeEn'] ?? ''),
              onTap: () {
                // スポットの詳細ページへの遷移処理
              },
            ),
          );
        },
      ),
    );
  }
}

class AnimeListEnNew extends StatefulWidget {
  @override
  _AnimeListEnNewState createState() => _AnimeListEnNewState();
}

class _AnimeListEnNewState extends State<AnimeListEnNew>
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

  // 【追加】サブスクリプション関連変数
  bool _isSubscriptionActive = false;
  int _dailySpotClickCount = 0;
  bool _showSubscriptionPrompt = false;
  String? _todayDate;

  BannerAd? _bottomBannerAd;
  bool _isBottomBannerAdReady = false;

  late TabController _tabController;
  int _currentTabIndex = 0;
  bool _isPrefectureDataFetched = false;

  GlobalKey searchKey = GlobalKey();
  GlobalKey addKey = GlobalKey();
  GlobalKey favoriteKey = GlobalKey();
  GlobalKey checkInKey = GlobalKey();
  GlobalKey firstItemKey = GlobalKey();
  GlobalKey rankingKey = GlobalKey();

  final FirebaseInAppMessaging fiam = FirebaseInAppMessaging.instance;

  final Map<String, Map<String, double>> prefectureBounds = {
    'Hokkaido': {
      'minLat': 41.3,
      'maxLat': 45.6,
      'minLng': 139.3,
      'maxLng': 148.9
    },
    'Aomori': {
      'minLat': 40.2,
      'maxLat': 41.6,
      'minLng': 139.5,
      'maxLng': 141.7
    },
    'Iwate': {'minLat': 38.7, 'maxLat': 40.5, 'minLng': 140.6, 'maxLng': 142.1},
    'Miyagi': {
      'minLat': 37.8,
      'maxLat': 39.0,
      'minLng': 140.3,
      'maxLng': 141.7
    },
    'Akita': {'minLat': 38.8, 'maxLat': 40.5, 'minLng': 139.7, 'maxLng': 141.0},
    'Yamagata': {
      'minLat': 37.8,
      'maxLat': 39.0,
      'minLng': 139.5,
      'maxLng': 140.6
    },
    'Fukushima': {
      'minLat': 36.8,
      'maxLat': 38.0,
      'minLng': 139.2,
      'maxLng': 141.0
    },
    'Ibaraki': {
      'minLat': 35.8,
      'maxLat': 36.9,
      'minLng': 139.7,
      'maxLng': 140.9
    },
    'Tochigi': {
      'minLat': 36.2,
      'maxLat': 37.2,
      'minLng': 139.3,
      'maxLng': 140.3
    },
    'Gunma': {'minLat': 36.0, 'maxLat': 37.0, 'minLng': 138.4, 'maxLng': 139.7},
    'Saitama': {
      'minLat': 35.7,
      'maxLat': 36.3,
      'minLng': 138.8,
      'maxLng': 139.9
    },
    'Chiba': {'minLat': 34.9, 'maxLat': 36.1, 'minLng': 139.7, 'maxLng': 140.9},
    'Tokyo': {'minLat': 35.5, 'maxLat': 35.9, 'minLng': 138.9, 'maxLng': 139.9},
    'Kanagawa': {
      'minLat': 35.1,
      'maxLat': 35.7,
      'minLng': 139.0,
      'maxLng': 139.8
    },
    'Nigata': {
      'minLat': 36.8,
      'maxLat': 38.6,
      'minLng': 137.6,
      'maxLng': 139.8
    },
    'Toyama': {
      'minLat': 36.2,
      'maxLat': 36.9,
      'minLng': 136.8,
      'maxLng': 137.7
    },
    'Ishikawa': {
      'minLat': 36.0,
      'maxLat': 37.6,
      'minLng': 136.2,
      'maxLng': 137.4
    },
    'Fukui': {'minLat': 35.3, 'maxLat': 36.3, 'minLng': 135.4, 'maxLng': 136.8},
    'Yamanashi': {
      'minLat': 35.2,
      'maxLat': 35.9,
      'minLng': 138.2,
      'maxLng': 139.1
    },
    'Nagano': {
      'minLat': 35.2,
      'maxLat': 37.0,
      'minLng': 137.3,
      'maxLng': 138.7
    },
    'Gifu': {'minLat': 35.2, 'maxLat': 36.5, 'minLng': 136.3, 'maxLng': 137.6},
    'Shizuoka': {
      'minLat': 34.6,
      'maxLat': 35.7,
      'minLng': 137.4,
      'maxLng': 139.1
    },
    'Aichi': {'minLat': 34.6, 'maxLat': 35.4, 'minLng': 136.7, 'maxLng': 137.8},
    'Mie': {'minLat': 33.7, 'maxLat': 35.3, 'minLng': 135.9, 'maxLng': 136.9},
    'Shiga': {'minLat': 34.8, 'maxLat': 35.7, 'minLng': 135.8, 'maxLng': 136.4},
    'Kyoto': {'minLat': 34.7, 'maxLat': 35.8, 'minLng': 134.8, 'maxLng': 136.0},
    'Osaka': {'minLat': 34.2, 'maxLat': 35.0, 'minLng': 135.1, 'maxLng': 135.7},
    'Hyogo': {'minLat': 34.2, 'maxLat': 35.7, 'minLng': 134.2, 'maxLng': 135.4},
    'Nara': {'minLat': 33.8, 'maxLat': 34.7, 'minLng': 135.6, 'maxLng': 136.2},
    'Wakayama': {
      'minLat': 33.4,
      'maxLat': 34.3,
      'minLng': 135.0,
      'maxLng': 136.0
    },
    'Tottori': {
      'minLat': 35.1,
      'maxLat': 35.6,
      'minLng': 133.1,
      'maxLng': 134.4
    },
    'Shimane': {
      'minLat': 34.3,
      'maxLat': 35.6,
      'minLng': 131.6,
      'maxLng': 133.4
    },
    'Okayama': {
      'minLat': 34.3,
      'maxLat': 35.4,
      'minLng': 133.3,
      'maxLng': 134.4
    },
    'Hiroshima': {
      'minLat': 34.0,
      'maxLat': 35.1,
      'minLng': 132.0,
      'maxLng': 133.5
    },
    'Yamaguchi': {
      'minLat': 33.8,
      'maxLat': 34.8,
      'minLng': 130.8,
      'maxLng': 132.4
    },
    'Tokushima': {
      'minLat': 33.5,
      'maxLat': 34.2,
      'minLng': 133.6,
      'maxLng': 134.8
    },
    'Kagawa': {
      'minLat': 34.0,
      'maxLat': 34.6,
      'minLng': 133.5,
      'maxLng': 134.4
    },
    'Ehime': {'minLat': 32.9, 'maxLat': 34.3, 'minLng': 132.0, 'maxLng': 133.7},
    'Kochi': {'minLat': 32.7, 'maxLat': 33.9, 'minLng': 132.5, 'maxLng': 134.3},
    'Fukuoka': {
      'minLat': 33.1,
      'maxLat': 34.0,
      'minLng': 129.9,
      'maxLng': 131.0
    },
    'Saga': {'minLat': 32.9, 'maxLat': 33.6, 'minLng': 129.7, 'maxLng': 130.5},
    'Nagasaki': {
      'minLat': 32.6,
      'maxLat': 34.7,
      'minLng': 128.6,
      'maxLng': 130.4
    },
    'Kumamoto': {
      'minLat': 32.1,
      'maxLat': 33.2,
      'minLng': 129.9,
      'maxLng': 131.2
    },
    'Oita': {'minLat': 32.7, 'maxLat': 33.7, 'minLng': 130.7, 'maxLng': 132.1},
    'Miyazaki': {
      'minLat': 31.3,
      'maxLat': 32.9,
      'minLng': 130.7,
      'maxLng': 131.9
    },
    'Kagoshima': {
      'minLat': 30.4,
      'maxLat': 32.2,
      'minLng': 129.5,
      'maxLng': 131.1
    },
    'Okinawa': {
      'minLat': 24.0,
      'maxLat': 27.9,
      'minLng': 122.9,
      'maxLng': 131.3
    },
  };

  final List<String> _allPrefectures = [
    'Hokkaido',
    'Aomori',
    'Iwate',
    'Miyagi',
    'Akita',
    'Yamagata',
    'Fukushima',
    'Ibaraki',
    'Tochigi',
    'Gunma',
    'Saitama',
    'Chiba',
    'Tokyo',
    'Kanagawa',
    'Nigata',
    'Toyama',
    'Ishikawa',
    'Fukui',
    'Yamanashi',
    'Nagano',
    'Gihu',
    'Shizuoka',
    'Aichi',
    'Mie',
    'Shiga',
    'Kyoto',
    'Osaka',
    'Hyogo',
    'Nara',
    'Wakayama',
    'Tottori',
    'Shimane',
    'Okayama',
    'Hiroshima',
    'Yamaguchi',
    'Tokushima',
    'Kagawa',
    'Ehime',
    'Kochi',
    'Fukuoka',
    'Saga',
    'Nagasaki',
    'Kumamoto',
    'Oita',
    'Miyazaki',
    'Kagoshima',
    'Okinawa'
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

  // 【追加】アプリ初期化（RevenueCat含む）
  Future<void> _initializeApp() async {
    // RevenueCatを初期化
    await SubscriptionManager.initializeWithDebug();

    // サブスクリプション状態をチェック
    await _checkSubscriptionStatusWithRetry();

    // スポット押下回数の初期化
    await _initializeDailyClickCount();

    // RevenueCatユーザー同期
    await _syncRevenueCatUser();

    _initializeTabController();
    databaseReference =
        rtdb.FirebaseDatabase.instance.ref().child('anime_rankings');
    _fetchAnimeData();
    _fetchEventData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorial());
    _listenToRankingChanges();
    _setupInAppMessaging();

    // サブスクリプション状態を確認してから広告をロード
    _loadBottomBannerAdIfNeeded();

    _scrollController.addListener(_onScroll);
  }

  // 【追加】日次スポット押下回数の初期化
  Future<void> _initializeDailyClickCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toString().split(' ')[0];
      _todayDate = today;

      // 保存されている日付を確認
      final savedDate = prefs.getString('spot_click_date');

      if (savedDate != today) {
        // 日付が変わっている場合はカウントをリセット
        _dailySpotClickCount = 0;
        await prefs.setInt('daily_spot_click_count', 0);
        await prefs.setString('spot_click_date', today);
      } else {
        _dailySpotClickCount = prefs.getInt('daily_spot_click_count') ?? 0;
      }

      print('Daily spot click count initialized: $_dailySpotClickCount');
    } catch (e) {
      print('Error initializing daily click count: $e');
      _dailySpotClickCount = 0;
    }
  }

  // 【追加】スポット押下回数を増加
  Future<void> _incrementSpotClickCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dailySpotClickCount++;

      await prefs.setInt('daily_spot_click_count', _dailySpotClickCount);

      print('Spot click count: $_dailySpotClickCount');

      // 10回に達した場合の処理
      if (_dailySpotClickCount >= 10) {
        // サブスクリプションが有効でない場合のみプロンプトを表示
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

  // 【追加】リトライ機能付きのサブスクリプション状態チェック
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

  // 【追加】サブスクリプション状態チェック（シンプル版）
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

  // 【追加】RevenueCatユーザー同期機能
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

  // 【修正】広告ロード（サブスクリプション状態確認付き）
  void _loadBottomBannerAdIfNeeded() async {
    // サブスクリプションチェック
    if (_isSubscriptionActive) {
      print('🚫 Skipping ad load - subscription active');
      return;
    }

    try {
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
          },
        ),
      );
      await _bottomBannerAd?.load();
    } catch (e) {
      print('❌ Exception loading bottom banner ad: $e');
    }
  }

  void _loadBottomBannerAd() async {
    // サブスクリプションチェック
    if (await SubscriptionManager.isSubscriptionActive()) {
      return; // サブスクリプション有効時は広告を読み込まない
    }

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
        },
      ),
    );
    _bottomBannerAd?.load();
  }

  Future<void> _initializeTabController() async {
    await _checkActiveEvents();
    int tabCount = _activeEvents.isNotEmpty ? 3 : 2;
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
          .map((doc) => doc.data()['title'] as String)
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

      if (_currentTabIndex == 1 && !_isPrefectureDataFetched) {
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
          'nameEn': data['nameEn'] ?? '',
          'imageUrl': data['imageUrl'] ?? '',
          'count': 0,
          'sortKey': _getSortKey(data['nameEn'] ?? ''),
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
          'title': data['title'] as String,
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

    return lat >= bounds['minLat']! &&
        lat <= bounds['maxLat']! &&
        lng >= bounds['minLng']! &&
        lng <= bounds['maxLng']!;
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

  Future<void> _navigateAndVote2(
      BuildContext context, String animeNameEn) async {
    await _logger.logUserActivity('anime_view', {
      'animeNameEn': animeNameEn,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // 【追加】スポット押下回数を増加
    await _incrementSpotClickCount();

    try {
      final String today = DateTime.now().toString().split(' ')[0];
      final prefs = await SharedPreferences.getInstance();
      final String? lastVoteDate = prefs.getString('lastVote_$animeNameEn');

      Map<String, dynamic> voteActivityData = {
        'animeNameEn': animeNameEn,
        'timestamp': DateTime.now().toIso8601String(),
        'isFirstVoteToday': lastVoteDate == null || lastVoteDate != today,
      };

      if (lastVoteDate == null || lastVoteDate != today) {
        final List<String> votedAnimeToday =
            prefs.getStringList('votedAnime_$today') ?? [];

        if (votedAnimeToday.length < 1) {
          rtdb.DatabaseReference animeRef =
              databaseReference.child(animeNameEn);
          rtdb.TransactionResult result =
              await animeRef.runTransaction((Object? currentValue) {
            if (currentValue == null) {
              return rtdb.Transaction.success(1);
            }
            return rtdb.Transaction.success((currentValue as int) + 1);
          });

          if (result.committed) {
            await prefs.setString('lastVote_$animeNameEn', today);
            votedAnimeToday.add(animeNameEn);
            await prefs.setStringList('votedAnime_$today', votedAnimeToday);

            voteActivityData['status'] = 'success';
            voteActivityData['newCount'] = result.snapshot.value;
            await _logger.logUserActivity('vote_success', voteActivityData);
          } else {
            voteActivityData['status'] = 'failed';
            voteActivityData['error'] = 'Transaction not committed';
            await _logger.logUserActivity('vote_failure', voteActivityData);
          }
        } else {
          voteActivityData['status'] = 'limited';
          voteActivityData['reason'] = 'daily_limit_reached';
          await _logger.logUserActivity('vote_limit_reached', voteActivityData);
        }
      } else {
        voteActivityData['status'] = 'already_voted';
        voteActivityData['lastVoteDate'] = lastVoteDate;
        await _logger.logUserActivity('vote_already_cast', voteActivityData);
      }
    } catch (e) {
      await _logger.logUserActivity('vote_error', {
        'animeNameEn': animeNameEn,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    await _logger.logUserActivity('navigation', {
      'from': 'anime_list',
      'to': 'anime_details',
      'animeNameEn': animeNameEn,
      'timestamp': DateTime.now().toIso8601String(),
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnimeDetailsEngPage(animeNameEn: animeNameEn),
      ),
    );
  }

  Widget _buildAnimeList() {
    List<Map<String, dynamic>> filteredAnimeData = _sortedAnimeData
        .where((anime) =>
            anime['nameEn'].toLowerCase().contains(_searchQuery) ||
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
            '■ Ranking (Top 10)',
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
                          onTap: () =>
                              _navigateAndVote2(context, anime['nameEn']),
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
                                        placeholder: (context, url) =>
                                            ShimmerLoading.imageShimmer(
                                          width: double.infinity,
                                          height: 200,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
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
                                  anime['nameEn'],
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
            '■ Anime list',
            style: TextStyle(
              color: Color(0xFF00008b),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        Expanded(
          child: _allAnimeData.isEmpty
              ? ShimmerLoading.animeGridShimmer(itemCount: 6)
              : filteredAnimeData.isEmpty
                  ? Center(
                      child: Text('nothing found..'),
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
                        // 【修正】サブスクリプション有効時は広告を表示しない
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
                                  'advertisement',
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

                        final key = adjustedIndex == 0 ? firstItemKey : null;

                        return GestureDetector(
                          key: key,
                          onTap: () => _navigateAndVote2(context,
                              filteredAnimeData[adjustedIndex]['nameEn']),
                          child: AnimeGridItem(
                            animeName: filteredAnimeData[adjustedIndex]
                                ['nameEn'],
                            animeNameEn: filteredAnimeData[adjustedIndex]
                                ['nameEn'],
                            imageUrl: filteredAnimeData[adjustedIndex]
                                ['imageUrl'],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // 【追加】サブスクリプションプロンプトオーバーレイ
  Widget _buildSubscriptionPromptOverlay() {
    // サブスクリプションが有効な場合は何も表示しない
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
                            'Premium Plan',
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
                      'Please consider using\nJAM Premium Plan!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Enjoy unlimited pilgrimage\nwith Premium Plan',
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
                        onPressed: () {
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
                          'View Premium Plan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
                  onPressed: () {
                    setState(() {
                      _showSubscriptionPrompt = false;
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

  @override
  Widget build(BuildContext context) {
    if (!_isEventsLoaded) {
      return ShimmerLoading.fullScreenShimmer();
    }

    return WillPopScope(
      onWillPop: () async {
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Do you want to close the app?'),
                content: Text('Are you sure you want to close the app?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text('close'),
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
                        ? 'Search by anime...'
                        : _currentTabIndex == 1
                            ? 'Search by prefecture...'
                            : 'Search by event...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                  style: TextStyle(color: Colors.black),
                )
              : Row(
                  children: [
                    Text(
                      'Pilgrimage spot',
                      style: TextStyle(
                        color: Color(0xFF00008b),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // 【追加】サブスクリプション状態表示
                    if (_isSubscriptionActive)
                      Container(
                        margin: EdgeInsets.only(left: 5),
                        padding:
                            EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Premium',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
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
                MaterialPageRoute(
                    builder: (context) => const CheckInEnScreen()),
              ),
              icon: const Icon(Icons.check_circle, color: Color(0xFF00008b)),
            ),
            IconButton(
              key: favoriteKey,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => FavoriteLocationsEnPage()),
              ),
              icon: const Icon(Icons.favorite, color: Color(0xFF00008b)),
            ),
            IconButton(
              key: addKey,
              icon: Icon(Icons.add, color: Color(0xFF00008b)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AnimeRequestCustomerFormEn()),
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
              Tab(text: 'Search by anime'),
              Tab(text: 'Search by location'),
            ],
            labelColor: Color(0xFF00008b),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF00008b),
          ),
        ),
        body: !_isEventsLoaded
            ? ShimmerLoading.fullScreenShimmer()
            : Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: TabBarView(
                          physics: NeverScrollableScrollPhysics(),
                          controller: _tabController,
                          children: [
                            _buildAnimeList(),
                            _currentTabIndex == 1
                                ? PrefectureListEnPage(
                                    prefectureSpots: _prefectureSpots,
                                    searchQuery: _searchQuery,
                                    onFetchPrefectureData: _fetchPrefectureData,
                                  )
                                : Container(),
                          ],
                        ),
                      ),
                      // 【修正】サブスクリプション有効時は底部広告を非表示
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
                  if (_showSubscriptionPrompt)
                    _buildSubscriptionPromptOverlay(),
                ],
              ),
      ),
    );
  }
}

class AnimeGridItem extends StatelessWidget {
  final String animeName;
  final String animeNameEn;
  final String imageUrl;

  const AnimeGridItem({
    Key? key,
    required this.animeName,
    required this.animeNameEn,
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
              placeholder: (context, url) => ShimmerLoading.imageShimmer(
                width: double.infinity,
                height: 200,
                borderRadius: BorderRadius.circular(8),
              ),
              errorWidget: (context, url, error) => Icon(Icons.error),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              animeNameEn,
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
