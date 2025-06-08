import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:parts/components/ad_mob.dart';
import 'package:parts/spot_page/anime_event_detail.dart';
import 'package:parts/spot_page/check_in.dart';
import 'package:parts/spot_page/customer_animename_request.dart';
import 'package:parts/spot_page/user_activity_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';


import 'anime_list_detail.dart';
import 'anime_list_en_ranking.dart';
import 'customer_anime_request.dart';
import 'liked_post.dart';

// AdManagerクラスの実装
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
    // 指数関数的なバックオフ: 5秒 → 10秒 → 20秒
    return Duration(seconds: _initialBackoff.inSeconds * (1 << failures));
  }

  static bool canLoadAdForIndex(int index) {
    final lastAttempt = _lastAdLoadAttempt[index];
    if (lastAttempt == null) return true;

    final backoff = _getBackoffDuration(index);
    return DateTime.now().difference(lastAttempt) >= backoff;
  }

  static Future<void> loadGridBannerAd(int index) async {
    // 既に広告が読み込まれている場合はスキップ
    if (_gridBannerAds[index] != null && _isGridBannerAdReady[index] == true) {
      return;
    }

    // レート制限チェック
    if (!canLoadAdForIndex(index)) {
      return;
    }

    // 最大リトライ回数を超えた場合はスキップ
    if ((_failureCount[index] ?? 0) >= _maxRetries) {
      return;
    }

    _lastAdLoadAttempt[index] = DateTime.now();

    // 既存の広告を破棄
    _gridBannerAds[index]?.dispose();

    _gridBannerAds[index] = BannerAd(
      adUnitId: 'ca-app-pub-1580421227117187/3454220382',
      request: AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _isGridBannerAdReady[index] = true;
          _failureCount[index] = 0; // 成功時にカウントをリセット
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

  static bool isAdReadyForIndex(int index) {
    return _isGridBannerAdReady[index] == true && _gridBannerAds[index] != null;
  }

  static BannerAd? getAdForIndex(int index) {
    return _gridBannerAds[index];
  }

  static void resetFailureCount(int index) {
    _failureCount[index] = 0;
  }
}

class AnimeEventList extends StatefulWidget {
  @override
  _AnimeEventListState createState() => _AnimeEventListState();
}

class _AnimeEventListState extends State<AnimeEventList>
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
  List<Map<String, dynamic>> _recommendedEvents = []; // 追加: おすすめイベント用のリスト
  bool _isRecommendedEventsLoaded = false; // 追加: おすすめイベント読み込み状態
  Map<String, List<Map<String, dynamic>>> _prefectureSpots = {};
  List<String> _activeEvents = [];
  bool _isEventsLoaded = false;
  bool _isEventsExpanded = false;
  final AdMob _adMob = AdMob();

  BannerAd? _bottomBannerAd;
  bool _isBottomBannerAdReady = false;

  late TabController _tabController;
  int _currentTabIndex = 0;
  bool _isPrefectureDataFetched = false;

  // _AnimeListTestRankingStateクラス内の変数定義部分
  GlobalKey searchKey = GlobalKey();
  GlobalKey addKey = GlobalKey();
  GlobalKey favoriteKey = GlobalKey();
  GlobalKey checkInKey = GlobalKey();
  GlobalKey firstItemKey = GlobalKey();
  GlobalKey rankingKey = GlobalKey();
  GlobalKey eventsKey = GlobalKey(); // この行を追加

  final FirebaseInAppMessaging fiam = FirebaseInAppMessaging.instance;

  // _AnimeEventListState クラスに以下の変数定義を追加
  final ScrollController _eventScrollController = ScrollController();
  bool _showRecommendedEvents = true;
  bool _isRecommendedEventsExpanded = true;

  final Map<String, Map<String, double>> prefectureBounds = {
    '北海道': {
      'minLat': 41.3,
      'maxLat': 45.6,
      'minLng': 139.3,
      'maxLng': 148.9
    },
    '青森県': {
      'minLat': 40.2,
      'maxLat': 41.6,
      'minLng': 139.5,
      'maxLng': 141.7
    },
    '岩手県': {
      'minLat': 38.7,
      'maxLat': 40.5,
      'minLng': 140.6,
      'maxLng': 142.1
    },
    '宮城県': {
      'minLat': 37.8,
      'maxLat': 39.0,
      'minLng': 140.3,
      'maxLng': 141.7
    },
    '秋田県': {
      'minLat': 38.8,
      'maxLat': 40.5,
      'minLng': 139.7,
      'maxLng': 141.0
    },
    '山形県': {
      'minLat': 37.8,
      'maxLat': 39.0,
      'minLng': 139.5,
      'maxLng': 140.6
    },
    '福島県': {
      'minLat': 36.8,
      'maxLat': 38.0,
      'minLng': 139.2,
      'maxLng': 141.0
    },
    '茨城県': {
      'minLat': 35.8,
      'maxLat': 36.9,
      'minLng': 139.7,
      'maxLng': 140.9
    },
    '栃木県': {
      'minLat': 36.2,
      'maxLat': 37.2,
      'minLng': 139.3,
      'maxLng': 140.3
    },
    '群馬県': {
      'minLat': 36.0,
      'maxLat': 37.0,
      'minLng': 138.4,
      'maxLng': 139.7
    },
    '埼玉県': {
      'minLat': 35.7,
      'maxLat': 36.3,
      'minLng': 138.8,
      'maxLng': 139.9
    },
    '千葉県': {
      'minLat': 34.9,
      'maxLat': 36.1,
      'minLng': 139.7,
      'maxLng': 140.9
    },
    '東京都': {
      'minLat': 35.5,
      'maxLat': 35.9,
      'minLng': 138.9,
      'maxLng': 139.9
    },
    '神奈川県': {
      'minLat': 35.1,
      'maxLat': 35.7,
      'minLng': 139.0,
      'maxLng': 139.8
    },
    '新潟県': {
      'minLat': 36.8,
      'maxLat': 38.6,
      'minLng': 137.6,
      'maxLng': 139.8
    },
    '富山県': {
      'minLat': 36.2,
      'maxLat': 36.9,
      'minLng': 136.8,
      'maxLng': 137.7
    },
    '石川県': {
      'minLat': 36.0,
      'maxLat': 37.6,
      'minLng': 136.2,
      'maxLng': 137.4
    },
    '福井県': {
      'minLat': 35.3,
      'maxLat': 36.3,
      'minLng': 135.4,
      'maxLng': 136.8
    },
    '山梨県': {
      'minLat': 35.2,
      'maxLat': 35.9,
      'minLng': 138.2,
      'maxLng': 139.1
    },
    '長野県': {
      'minLat': 35.2,
      'maxLat': 37.0,
      'minLng': 137.3,
      'maxLng': 138.7
    },
    '岐阜県': {
      'minLat': 35.2,
      'maxLat': 36.5,
      'minLng': 136.3,
      'maxLng': 137.6
    },
    '静岡県': {
      'minLat': 34.6,
      'maxLat': 35.7,
      'minLng': 137.4,
      'maxLng': 139.1
    },
    '愛知県': {
      'minLat': 34.6,
      'maxLat': 35.4,
      'minLng': 136.7,
      'maxLng': 137.8
    },
    '三重県': {
      'minLat': 33.7,
      'maxLat': 35.3,
      'minLng': 135.9,
      'maxLng': 136.9
    },
    '滋賀県': {
      'minLat': 34.8,
      'maxLat': 35.7,
      'minLng': 135.8,
      'maxLng': 136.4
    },
    '京都府': {
      'minLat': 34.7,
      'maxLat': 35.8,
      'minLng': 134.8,
      'maxLng': 136.0
    },
    '大阪府': {
      'minLat': 34.2,
      'maxLat': 35.0,
      'minLng': 135.1,
      'maxLng': 135.7
    },
    '兵庫県': {
      'minLat': 34.2,
      'maxLat': 35.7,
      'minLng': 134.2,
      'maxLng': 135.4
    },
    '奈良県': {
      'minLat': 33.8,
      'maxLat': 34.7,
      'minLng': 135.6,
      'maxLng': 136.2
    },
    '和歌山県': {
      'minLat': 33.4,
      'maxLat': 34.3,
      'minLng': 135.0,
      'maxLng': 136.0
    },
    '鳥取県': {
      'minLat': 35.1,
      'maxLat': 35.6,
      'minLng': 133.1,
      'maxLng': 134.4
    },
    '島根県': {
      'minLat': 34.3,
      'maxLat': 35.6,
      'minLng': 131.6,
      'maxLng': 133.4
    },
    '岡山県': {
      'minLat': 34.3,
      'maxLat': 35.4,
      'minLng': 133.3,
      'maxLng': 134.4
    },
    '広島県': {
      'minLat': 34.0,
      'maxLat': 35.1,
      'minLng': 132.0,
      'maxLng': 133.5
    },
    '山口県': {
      'minLat': 33.8,
      'maxLat': 34.8,
      'minLng': 130.8,
      'maxLng': 132.4
    },
    '徳島県': {
      'minLat': 33.5,
      'maxLat': 34.2,
      'minLng': 133.6,
      'maxLng': 134.8
    },
    '香川県': {
      'minLat': 34.0,
      'maxLat': 34.6,
      'minLng': 133.5,
      'maxLng': 134.4
    },
    '愛媛県': {
      'minLat': 32.9,
      'maxLat': 34.3,
      'minLng': 132.0,
      'maxLng': 133.7
    },
    '高知県': {
      'minLat': 32.7,
      'maxLat': 33.9,
      'minLng': 132.5,
      'maxLng': 134.3
    },
    '福岡県': {
      'minLat': 33.1,
      'maxLat': 34.0,
      'minLng': 129.9,
      'maxLng': 131.0
    },
    '佐賀県': {
      'minLat': 32.9,
      'maxLat': 33.6,
      'minLng': 129.7,
      'maxLng': 130.5
    },
    '長崎県': {
      'minLat': 32.6,
      'maxLat': 34.7,
      'minLng': 128.6,
      'maxLng': 130.4
    },
    '熊本県': {
      'minLat': 32.1,
      'maxLat': 33.2,
      'minLng': 129.9,
      'maxLng': 131.2
    },
    '大分県': {
      'minLat': 32.7,
      'maxLat': 33.7,
      'minLng': 130.7,
      'maxLng': 132.1
    },
    '宮崎県': {
      'minLat': 31.3,
      'maxLat': 32.9,
      'minLng': 130.7,
      'maxLng': 131.9
    },
    '鹿児島県': {
      'minLat': 30.4,
      'maxLat': 32.2,
      'minLng': 129.5,
      'maxLng': 131.1
    },
    '沖縄県': {
      'minLat': 24.0,
      'maxLat': 27.9,
      'minLng': 122.9,
      'maxLng': 131.3
    },
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
    _initializeTabController();
    databaseReference =
        rtdb.FirebaseDatabase.instance.ref().child('anime_rankings');
    _fetchAnimeData();
    _fetchEventData();
    _fetchRecommendedEvents(); // 追加: おすすめイベントの取得
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorial());
    _listenToRankingChanges();
    _setupInAppMessaging();
    _loadBottomBannerAd();

    _scrollController.addListener(_onScroll);
    _eventScrollController.addListener(_onEventScroll); // この行を追加
  }

  // イベントタブのスクロールを監視する関数を追加
  void _onEventScroll() {
    if (_eventScrollController.position.pixels > 0 && _showRecommendedEvents) {
      setState(() {
        _showRecommendedEvents = false;
        _isRecommendedEventsExpanded = false;
      });
    } else if (_eventScrollController.position.pixels == 0 &&
        !_showRecommendedEvents) {
      setState(() {
        _showRecommendedEvents = true;
        _isRecommendedEventsExpanded = true;
      });
    }
  }

  // 追加: ユーザーの閲覧履歴に基づくおすすめイベントを取得するメソッド
  Future<void> _fetchRecommendedEvents() async {
    try {
      setState(() {
        _isRecommendedEventsLoaded = false;
      });

      List<String> preferredAnimeNames = [];

      // 現在のユーザーを取得
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // ユーザーのviewedAnimesコレクションを取得
        final viewedAnimesSnapshot = await firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('viewedAnimes')
            .orderBy('viewCount', descending: true)
            .limit(5)
            .get();

        if (viewedAnimesSnapshot.docs.isNotEmpty) {
          // 閲覧したアニメ名を抽出
          preferredAnimeNames = viewedAnimesSnapshot.docs
              .map((doc) => doc.data()['animeName'] as String)
              .toList();
        }
      }

      // ユーザーに閲覧履歴がない場合、ランダムなアニメ名を取得
      if (preferredAnimeNames.isEmpty && _allAnimeData.isNotEmpty) {
        // シャッフルして最大5件のランダムなアニメを取得
        final randomAnimes = List<Map<String, dynamic>>.from(_allAnimeData)
          ..shuffle();
        preferredAnimeNames = randomAnimes
            .take(min(5, randomAnimes.length))
            .map((anime) => anime['name'] as String)
            .toList();
      }

      // 好みのアニメに関連するイベントを取得
      if (preferredAnimeNames.isNotEmpty) {
        final eventSnapshot = await firestore
            .collection('anime_event_info')
            .get();

        // ユーザーの好みのアニメに関連するイベントをフィルタリング
        // 注: イベントに'animeRelated'フィールドがあることを前提としています
        // ない場合は、このロジックを修正する必要があります
        List<Map<String, dynamic>> recommendedEvents = [];

        for (var doc in eventSnapshot.docs) {
          final data = doc.data();
          final String eventDescription = (data['eventInfo'] as String? ?? '')
              .toLowerCase();
          final String eventTitle = (data['eventName'] as String? ?? '')
              .toLowerCase();

          // いずれかの好みのアニメがイベントで言及されているかチェック
          bool isRelated = preferredAnimeNames.any((animeName) {
            final String lowercaseAnimeName = animeName.toLowerCase();
            return eventDescription.contains(lowercaseAnimeName) ||
                eventTitle.contains(lowercaseAnimeName);
          });

          // ユーザーの好みのアニメに関連している場合、おすすめに追加
          if (isRelated) {
            recommendedEvents.add({
              'id': doc.id,
              'title': data['eventName'] as String? ?? '',
              'eventTopImageUrl': data['eventTopImageUrl'] as String? ?? '',
              'description': data['eventInfo'] as String? ?? '',
              'eventStart': data['eventStart'] ??
                  Timestamp.fromDate(DateTime.now()),
              'eventFinish': data['eventFinish'] ??
                  Timestamp.fromDate(DateTime.now().add(Duration(days: 30))),
              'location': data['eventPlace'] as String? ?? '',
              'eventRemarks': data['eventRemarks'] as String? ?? '',
              'relatedAnime': preferredAnimeNames.firstWhere(
                      (animeName) {
                    final String lowercaseAnimeName = animeName.toLowerCase();
                    return eventDescription.contains(lowercaseAnimeName) ||
                        eventTitle.contains(lowercaseAnimeName);
                  },
                  orElse: () => 'Unknown'
              )
            });
          }
        }

        // 関連するイベントが見つからない場合、いくつかのランダムなイベントを含める
        if (recommendedEvents.isEmpty && eventSnapshot.docs.isNotEmpty) {
          final randomEvents = List<DocumentSnapshot>.from(eventSnapshot.docs)
            ..shuffle();
          recommendedEvents = randomEvents
              .take(min(3, randomEvents.length))
              .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'title': data['eventName'] as String? ?? '',
              'eventTopImageUrl': data['eventTopImageUrl'] as String? ?? '',
              'description': data['eventInfo'] as String? ?? '',
              'eventStart': data['eventStart'] ??
                  Timestamp.fromDate(DateTime.now()),
              'eventFinish': data['eventFinish'] ??
                  Timestamp.fromDate(DateTime.now().add(Duration(days: 30))),
              'location': data['eventPlace'] as String? ?? '',
              'eventRemarks': data['eventRemarks'] as String? ?? '',
              'isRandom': true
            };
          })
              .toList();
        }

        // おすすめイベントで状態を更新
        setState(() {
          _recommendedEvents = recommendedEvents;
          _isRecommendedEventsLoaded = true;
        });
      } else {
        // 好みのアニメ名がない場合、空のおすすめを設定
        setState(() {
          _recommendedEvents = [];
          _isRecommendedEventsLoaded = true;
        });
      }
    } catch (e) {
      print('おすすめイベント取得エラー: $e');
      setState(() {
        _recommendedEvents = [];
        _isRecommendedEventsLoaded = true;
      });
    }
  }

  void _loadBottomBannerAd() {
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
    // イベントの有無に関わらず3つのタブを表示するように変更
    int tabCount = 3;
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

  void _loadBannerAd() {
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

  // タブ変更時のログを記録
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
      // anime_event_info コレクションからイベントデータを取得
      final eventSnapshot = await firestore.collection('anime_event_info')
          .get();
      List<Map<String, dynamic>> events = [];

      // データが見つからない場合のチェック
      if (eventSnapshot.docs.isEmpty) {
        print(
            'イベントデータが見つかりませんでした。サンプルデータを使用します。');
        // サンプルデータを追加
        events = [
          {
            'id': 'sample1',
            'eventName': 'サンプルイベント',
            'eventTopImageUrl': '',
            'eventInfo': 'これはサンプルイベントです。',
            'eventStart': Timestamp.fromDate(DateTime.now()),
            'eventFinish': Timestamp.fromDate(
                DateTime.now().add(Duration(days: 30))),
            'location': '東京都',
            'eventRemarks': 'サンプルデータです',
          }
        ];
      } else {
        // データが存在する場合の処理
        events = eventSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'title': data['eventName'] as String? ?? '',
            'eventTopImageUrl': data['eventTopImageUrl'] as String? ?? '',
            'description': data['eventInfo'] as String? ?? '',
            'eventStart': data['eventStart'] ??
                Timestamp.fromDate(DateTime.now()),
            'eventFinish': data['eventFinish'] ??
                Timestamp.fromDate(DateTime.now().add(Duration(days: 30))),
            'location': data['eventPlace'] as String? ?? '',
            // eventPlace フィールドを使用
            'eventRemarks': data['eventRemarks'] as String? ?? '',
          };
        }).toList();
      }

      // データをUIに反映
      if (mounted) {
        setState(() {
          _eventData = events;
          _isEventsLoaded = true; // ロード完了フラグを設定
        });
      }

      print('イベントデータを${events.length}件ロードしました');
    } catch (e) {
      print('イベントデータ取得エラー: $e');
      // エラー時もUIを更新して表示する
      if (mounted) {
        setState(() {
          _eventData = [
            {
              'id': 'error1',
              'title': 'データ読み込みエラー',
              'eventTopImageUrl': '',
              'description': 'イベントデータの読み込み中にエラーが発生しました。',
              'eventStart': Timestamp.fromDate(DateTime.now()),
              'eventFinish': Timestamp.fromDate(
                  DateTime.now().add(Duration(days: 1))),
              'location': 'エラー',
              'eventRemarks': 'エラーが発生しました',
            }
          ];
          _isEventsLoaded = true; // エラー時もロード完了としてマーク
        });
      }
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

    // 検索アクティビティを記録
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
    // アニメ詳細表示のログを記録
    await _logger.logUserActivity('anime_view', {
      'animeName': animeName,
      'timestamp': DateTime.now().toIso8601String(),
    });

    String userId = '';
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        userId = currentUser.uid;
      }
    } catch (e) {
      print('ユーザーID取得エラー: $e');
    }

    if (userId.isNotEmpty) {
      try {
        final animeQuery = await firestore.collection('animes')
            .where('name', isEqualTo: animeName)
            .limit(1)
            .get();

        String animeId = '';
        if (animeQuery.docs.isNotEmpty) {
          animeId = animeQuery.docs.first.id;
        } else {
          animeId = animeName;
        }
        final userDocRef = firestore.collection('users').doc(userId);
        final userDoc = await userDocRef.get();
        if (!userDoc.exists) {
          await userDocRef.set({
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        final viewedAnimeRef = userDocRef.collection('viewedAnimes').doc(
            animeId);
        final viewedAnimeDoc = await viewedAnimeRef.get();

        if (viewedAnimeDoc.exists) {
          await viewedAnimeRef.update({
            'viewCount': FieldValue.increment(1),
            'lastViewdAt': FieldValue.serverTimestamp(),
          });
        } else {
          await viewedAnimeRef.set({
            'animeId': animeId,
            'animeName': animeName,
            'viewCount': 1,
            'firstViewedAt': FieldValue.serverTimestamp(),
            'lastViewedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        print('アニメ閲覧記録保存エラー: $e');
      }
    }

    try {
      final String today = DateTime.now().toString().split(' ')[0];
      final prefs = await SharedPreferences.getInstance();
      final String? lastVoteDate = prefs.getString('lastVote_$animeName');

      // 投票アクティビティの記録準備
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

            // 成功した投票のログを記録
            voteActivityData['status'] = 'success';
            voteActivityData['newCount'] = result.snapshot.value;
            await _logger.logUserActivity('vote_success', voteActivityData);

            print("Incremented count for $animeName");
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: Text('${animeName}の投票を受け付けました。'),
            //     backgroundColor: Colors.green,
            //   ),
            // );
          } else {
            // 投票失敗のログを記録
            voteActivityData['status'] = 'failed';
            voteActivityData['error'] = 'Transaction not committed';
            await _logger.logUserActivity('vote_failure', voteActivityData);

            print("Failed to increment count for $animeName");
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: Text('投票に失敗しました。もう一度お試しください。'),
            //     backgroundColor: Colors.red,
            //   ),
            // );
          }
        } else {
          // 投票制限到達のログを記録
          voteActivityData['status'] = 'limited';
          voteActivityData['reason'] = 'daily_limit_reached';
          await _logger.logUserActivity('vote_limit_reached', voteActivityData);

          print("Daily vote limit reached");
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(
          //     content: Text('本日の投票回数の上限に達しました。また明日お試しください。'),
          //     backgroundColor: Colors.orange,
          //   ),
          // );
        }
      } else {
        // 既に投票済みのログを記録
        voteActivityData['status'] = 'already_voted';
        voteActivityData['lastVoteDate'] = lastVoteDate;
        await _logger.logUserActivity('vote_already_cast', voteActivityData);

        print("Already voted for this anime today");
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('このアニメには既に投票済みです。'),
        //     backgroundColor: Colors.orange,
        //   ),
        // );
      }
    } catch (e) {
      // エラーのログを記録
      await _logger.logUserActivity('vote_error', {
        'animeName': animeName,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });

      print("Error incrementing anime count: $e");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('エラーが発生しました。もう一度お試しください。'),
      //     backgroundColor: Colors.red,
      //   ),
      // );
    }

    // 遷移のログを記録
    await _logger.logUserActivity('navigation', {
      'from': 'anime_list',
      'to': 'anime_details',
      'animeName': animeName,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // 投票処理の後で詳細画面に遷移
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnimeDetailsPage(animeName: animeName),
      ),
    );
  }

  // 更新: おすすめイベントを含むイベントリストを構築するメソッド
  Widget _buildEventList() {
    final DateTime now = DateTime.now();

    // 終了していないイベントだけをフィルタリング
    List<Map<String, dynamic>> activeEventData = _eventData
        .where((event) {
      if (event['eventFinish'] != null) {
        DateTime eventEndDate = (event['eventFinish'] as Timestamp).toDate();
        return eventEndDate.isAfter(now);
      }
      return true;
    })
        .toList();

    // 検索クエリに基づいてイベントデータをフィルタリング
    List<Map<String, dynamic>> filteredEventData = activeEventData
        .where((event) =>
    event['title'].toString().toLowerCase().contains(_searchQuery) ||
        (event['location'] != null &&
            event['location'].toString().toLowerCase().contains(
                _searchQuery)) ||
        (event['description'] != null &&
            event['description'].toString().toLowerCase().contains(
                _searchQuery))
    )
        .toList();

    // 同様に検索クエリでおすすめイベントをフィルタリング
    List<Map<String, dynamic>> filteredRecommendedEvents = _recommendedEvents
        .where((event) =>
    event['title'].toString().toLowerCase().contains(_searchQuery) ||
        (event['location'] != null &&
            event['location'].toString().toLowerCase().contains(
                _searchQuery)) ||
        (event['description'] != null &&
            event['description'].toString().toLowerCase().contains(
                _searchQuery))
    )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 「あなたへのおすすめイベント」セクションをExpansionTileに変更
        Visibility(
          visible: filteredRecommendedEvents.isNotEmpty,
          child: ExpansionTile(
            title: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Color(0xFF00008b),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'あなたへのおすすめイベント',
                  style: TextStyle(
                    color: Color(0xFF00008b),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            initiallyExpanded: _isRecommendedEventsExpanded,
            onExpansionChanged: (expanded) {
              setState(() {
                _isRecommendedEventsExpanded = expanded;
              });
            },
            children: _showRecommendedEvents
                ? [
              SizedBox(
                height: 200, // おすすめイベントの高さを設定
                child: !_isRecommendedEventsLoaded
                    ? Center(child: CircularProgressIndicator())
                    : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  itemCount: filteredRecommendedEvents.length,
                  itemBuilder: (context, index) {
                    final event = filteredRecommendedEvents[index];

                    // イベント情報を取得
                    final String title = event['title'] ?? '';
                    final String description = event['description'] ?? '';
                    final String location = event['location'] ?? '場所未定';
                    final String eventTopImageUrl = event['eventTopImageUrl'] ??
                        '';
                    final String relatedAnime = event['relatedAnime'] ?? '';
                    final bool isRandom = event['isRandom'] ?? false;

                    // イベントの日付を取得
                    final DateTime? startDate = event['eventStart'] != null
                        ? (event['eventStart'] as Timestamp).toDate()
                        : null;
                    final DateTime? eventFinish = event['eventFinish'] != null
                        ? (event['eventFinish'] as Timestamp).toDate()
                        : null;

                    // イベントの状態を判断
                    String status = '';
                    Color statusColor = Colors.grey;

                    if (startDate != null && eventFinish != null) {
                      if (now.isAfter(startDate) && now.isBefore(eventFinish)) {
                        status = '開催中';
                        statusColor = Colors.green;
                      } else if (now.isBefore(startDate)) {
                        status = '近日開催';
                        statusColor = Colors.orange;
                      }
                    }

                    // 横スクロール用のイベントカード
                    return Container(
                      width: 210,
                      margin: EdgeInsets.only(right: 12, bottom: 8),
                      child: Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            // イベントタップ時の処理
                            _logger.logUserActivity('recommended_event_view', {
                              'eventTitle': title,
                              'eventId': event['id'] ?? '',
                              'relatedAnime': relatedAnime,
                              'isRandom': isRandom,
                              'timestamp': DateTime.now().toIso8601String(),
                            });

                            // イベント詳細画面に遷移
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AnimeEventDetail(
                                      eventNumber: event['id'] ?? '',
                                    ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // イベント画像
                              Stack(
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: eventTopImageUrl,
                                    height: 120,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        Container(
                                          height: 120,
                                          color: Colors.grey[300],
                                          child: Center(
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2.0)),
                                        ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          height: 120,
                                          color: Colors.grey[300],
                                          child: Center(
                                            child: Icon(
                                                Icons.image_not_supported,
                                                size: 30, color: Colors.grey),
                                          ),
                                        ),
                                  ),
                                  // ステータスバッジ
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // 関連アニメのバッジ（ランダム選出でなければ表示）
                                  if (!isRandom && relatedAnime.isNotEmpty)
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.deepOrange.withOpacity(
                                              0.8),
                                          borderRadius: BorderRadius.circular(
                                              12),
                                        ),
                                        child: Text(
                                          relatedAnime.length > 10
                                              ? '${relatedAnime.substring(
                                              0, 10)}...'
                                              : relatedAnime,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              // イベント情報
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.all(10.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment
                                        .start,
                                    children: [
                                      // タイトル
                                      Text(
                                        title,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.deepOrange,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on, size: 12,
                                              color: Colors.grey[600]),
                                          SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              location,
                                              style: TextStyle(
                                                fontSize: 15,
                                                color: Colors.grey[600],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ]
                : [],
          ),
        ),

        // 「開催中・近日開催イベント」ヘッダー (既存のセクション)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Color(0xFF00008b),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 8),
              Text(
                '開催中・近日開催イベント',
                style: TextStyle(
                  color: Color(0xFF00008b),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        // 既存のイベント一覧
        Expanded(
          child: _eventData.isEmpty
              ? Center(child: CircularProgressIndicator()) // データ読み込み中
              : filteredEventData.isEmpty
              ? Center(
            child: Text('該当するイベントが見つかりませんでした。'),
          ) // 検索結果なし
              : Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: GridView.builder(
              controller: _eventScrollController,
              // スクロールコントローラーを設定
              padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.82,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: filteredEventData.length,
              itemBuilder: (context, index) {
                final event = filteredEventData[index];

                // 以下は既存のコードと同じ
                final String title = event['title'] ?? '';
                final String description = event['description'] ?? '';
                final String location = event['location'] ?? '場所未定';
                final String eventTopImageUrl = event['eventTopImageUrl'] ?? '';

                final DateTime? startDate = event['eventStart'] != null
                    ? (event['eventStart'] as Timestamp).toDate()
                    : null;
                final DateTime? eventFinish = event['eventFinish'] != null
                    ? (event['eventFinish'] as Timestamp).toDate()
                    : null;

                String status = '';
                Color statusColor = Colors.grey;

                if (startDate != null && eventFinish != null) {
                  if (now.isAfter(startDate) && now.isBefore(eventFinish)) {
                    status = '開催中';
                    statusColor = Colors.green;
                  } else if (now.isBefore(startDate)) {
                    status = '近日開催';
                    statusColor = Colors.orange;
                  }
                }

                return Card(
                  margin: EdgeInsets.zero,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      _logger.logUserActivity('event_view', {
                        'eventTitle': title,
                        'eventId': event['id'] ?? '',
                        'timestamp': DateTime.now().toIso8601String(),
                      });

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AnimeEventDetail(
                                eventNumber: event['id'] ?? '',
                              ),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            CachedNetworkImage(
                              imageUrl: eventTopImageUrl,
                              height: 100,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  Container(
                                    height: 100,
                                    color: Colors.grey[300],
                                    child: Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.0)),
                                  ),
                              errorWidget: (context, url, error) =>
                                  Container(
                                    height: 100,
                                    color: Colors.grey[300],
                                    child: Center(
                                      child: Icon(
                                          Icons.image_not_supported, size: 30,
                                          color: Colors.grey),
                                    ),
                                  ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00008b),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Spacer(),
                                Row(
                                  children: [
                                    Icon(Icons.location_on, size: 12,
                                        color: Colors.grey[600]),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        location,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 12,
                                        color: Colors.grey[600]),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        startDate != null && eventFinish != null
                                            ? '${startDate.month}/${startDate
                                            .day}〜${eventFinish
                                            .month}/${eventFinish.day}'
                                            : '日程未定',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
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
                                  placeholder: (context, url) =>
                                      Center(
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
              if (index != 0 && index % 6 == 0) {
                if (AdManager.canLoadAdForIndex(index)) {
                  Future.microtask(
                          () => AdManager.loadGridBannerAd(index));
                }

                if (AdManager.isAdReadyForIndex(index)) {
                  final ad = AdManager.getAdForIndex(index);
                  return Container(
                    width: ad!.size.width.toDouble(),
                    height: ad.size.height.toDouble(),
                    child: AdWidget(ad: ad),
                  );
                } else {
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
                }
              }

              final adjustedIndex = index - (index ~/ 6);
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

  @override
  Widget build(BuildContext context) {
    if (!_isEventsLoaded) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return ShowCaseWidget(
        builder: (context) =>
            WillPopScope(
              onWillPop: () async {
                return await showDialog<bool>(
                  context: context,
                  builder: (context) =>
                      AlertDialog(
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
                      : Text(
                    _currentTabIndex == 2 ? 'イベント情報' : '巡礼スポット',
                    style: TextStyle(
                      color: Color(0xFF00008b),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  actions: [
                    IconButton(
                      key: checkInKey,
                      onPressed: () =>
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SpotTestScreen()),
                          ),
                      icon: const Icon(
                          Icons.check_circle, color: Color(0xFF00008b)),
                    ),
                    IconButton(
                      key: favoriteKey,
                      onPressed: () =>
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => FavoriteLocationsPage()),
                          ),
                      icon: const Icon(
                          Icons.favorite, color: Color(0xFF00008b)),
                    ),
                    IconButton(
                      key: addKey,
                      icon: Icon(Icons.add, color: Color(0xFF00008b)),
                      onPressed: () {
                        showCupertinoModalPopup(
                          context: context,
                          builder: (BuildContext context) =>
                              CupertinoActionSheet(
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
                                        MaterialPageRoute(builder: (context) =>
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
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) =>
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
                      Tab(text: 'アニメで探す'),
                      Tab(text: '場所で探す'),
                      Tab(text: 'イベントで探す'),
                    ],
                    labelColor: Color(0xFF00008b),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Color(0xFF00008b),
                  ),
                ),
                body: Column(
                  children: [
                    Expanded(
                      child: TabBarView(
                        physics: NeverScrollableScrollPhysics(),
                        controller: _tabController,
                        children: [
                          _buildAnimeList(),
                          _currentTabIndex == 1
                              ? PrefectureListPage(
                            prefectureSpots: _prefectureSpots,
                            searchQuery: _searchQuery,
                            onFetchPrefectureData: _fetchPrefectureData,
                          )
                              : Container(),
                          _buildEventList(),
                        ],
                      ),
                    ),
                    if (_isBottomBannerAdReady && _bottomBannerAd != null)
                      Container(
                        width: _bottomBannerAd!.size.width.toDouble(),
                        height: _bottomBannerAd!.size.height.toDouble(),
                        child: AdWidget(ad: _bottomBannerAd!),
                      ),
                  ],
                ),
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