import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:parts/components/ad_mob.dart';
import 'package:parts/spot_page/check_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translator/translator.dart';
import 'package:showcaseview/showcaseview.dart';

import 'anime_list_detail.dart';
import 'anime_list_en_ranking.dart';
import 'customer_anime_request.dart';
import 'liked_post.dart';

class AnimeListTestRankingEng extends StatefulWidget {
  @override
  _AnimeListTestRankingEngState createState() =>
      _AnimeListTestRankingEngState();
}

class _AnimeListTestRankingEngState extends State<AnimeListTestRankingEng>
    with SingleTickerProviderStateMixin {
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
  final translator = GoogleTranslator();

  Map<String, String> _japaneseToEnglishPrefecture = {
    '北海道': 'Hokkaido',
    '青森県': 'Aomori',
    '岩手県': 'Iwate',
    '宮城県': 'Miyagi',
    '秋田県': 'Akita',
    '山形県': 'Yamagata',
    '福島県': 'Fukushima',
    '茨城県': 'Ibaraki',
    '栃木県': 'Tochigi',
    '群馬県': 'Gunma',
    '埼玉県': 'Saitama',
    '千葉県': 'Chiba',
    '東京都': 'Tokyo',
    '神奈川県': 'Kanagawa',
    '新潟県': 'Niigata',
    '富山県': 'Toyama',
    '石川県': 'Ishikawa',
    '福井県': 'Fukui',
    '山梨県': 'Yamanashi',
    '長野県': 'Nagano',
    '岐阜県': 'Gifu',
    '静岡県': 'Shizuoka',
    '愛知県': 'Aichi',
    '三重県': 'Mie',
    '滋賀県': 'Shiga',
    '京都府': 'Kyoto',
    '大阪府': 'Osaka',
    '兵庫県': 'Hyogo',
    '奈良県': 'Nara',
    '和歌山県': 'Wakayama',
    '鳥取県': 'Tottori',
    '島根県': 'Shimane',
    '岡山県': 'Okayama',
    '広島県': 'Hiroshima',
    '山口県': 'Yamaguchi',
    '徳島県': 'Tokushima',
    '香川県': 'Kagawa',
    '愛媛県': 'Ehime',
    '高知県': 'Kochi',
    '福岡県': 'Fukuoka',
    '佐賀県': 'Saga',
    '長崎県': 'Nagasaki',
    '熊本県': 'Kumamoto',
    '大分県': 'Oita',
    '宮崎県': 'Miyazaki',
    '鹿児島県': 'Kagoshima',
    '沖縄県': 'Okinawa'
  };

  BannerAd? _bottomBannerAd;
  bool _isBottomBannerAdReady = false;
  Map<int, BannerAd> _gridBannerAds = {};
  Map<int, bool> _isGridBannerAdReady = {};

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
    'Niigata': {
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
    'Niigata',
    'Toyama',
    'Ishikawa',
    'Fukui',
    'Yamanashi',
    'Nagano',
    'Gifu',
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorial());
    _listenToRankingChanges();
    _setupInAppMessaging();
    _loadBottomBannerAd();
  }

  // Helper method to translate text
  Future<String> translateText(String text) async {
    try {
      var translation = await translator.translate(text, from: 'ja', to: 'en');
      return translation.text;
    } catch (e) {
      print("Translation error: $e");
      return text;
    }
  }

  Future<String> translatePrefecture(String prefecture) async {
    return _japaneseToEnglishPrefecture[prefecture] ?? prefecture;
  }

  void _loadBottomBannerAd() {
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

  void _loadGridBannerAd(int index) {
    if (_gridBannerAds[index] != null) return;

    _gridBannerAds[index] = BannerAd(
      adUnitId: 'ca-app-pub-1580421227117187/7240101933',
      request: AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isGridBannerAdReady[index] = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          print('Grid banner ad failed to load: ${err.message}');
          _isGridBannerAdReady[index] = false;
          ad.dispose();
        },
      ),
    );

    _gridBannerAds[index]?.load();
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
      List<String> activeEvents = [];

      for (var doc in eventSnapshot.docs) {
        if (doc.data()['isEnabled'] == true) {
          String title = doc.data()['title'] as String? ?? '';
          String translatedTitle = await translateText(title);
          activeEvents.add(translatedTitle);
        }
      }

      setState(() {
        _activeEvents = activeEvents;
      });
    } catch (e) {
      print('Error fetching events: $e');
      _activeEvents = [];
    }
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

  void _updateRankings(Map<dynamic, dynamic> rankings) async {
    List<MapEntry<String, int>> sortedRankings = rankings.entries
        .map((entry) =>
            MapEntry(entry.key.toString(), (entry.value as num).toInt()))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    List<Map<String, dynamic>> updatedTopRanked = [];
    for (var entry in sortedRankings.take(10)) {
      var animeData = _allAnimeData.firstWhere(
        (anime) => anime['originalName'] == entry.key,
        orElse: () => {
          'name': entry.key,
          'originalName': entry.key,
          'imageUrl': '',
          'count': entry.value
        },
      );
      updatedTopRanked.add(animeData);
    }

    setState(() {
      _topRankedAnime = updatedTopRanked;

      for (var anime in _allAnimeData) {
        anime['count'] = rankings[anime['originalName']] != null
            ? (rankings[anime['originalName']] as num).toInt()
            : 0;
      }

      _allAnimeData
          .sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    });
  }

  Future<void> _fetchAnimeData() async {
    try {
      QuerySnapshot animeSnapshot = await firestore.collection('animes').get();
      List<Map<String, dynamic>> translatedData = [];

      for (var doc in animeSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String originalName = data['name'] ?? '';
        String translatedName = await translateText(originalName);

        translatedData.add({
          'name': translatedName,
          'originalName': originalName,
          'imageUrl': data['imageUrl'] ?? '',
          'count': 0,
          'sortKey': translatedName.toLowerCase(),
        });
      }

      setState(() {
        _allAnimeData = translatedData;
        _sortedAnimeData = List.from(_allAnimeData);
        _sortedAnimeData.sort((a, b) => a['sortKey'].compareTo(b['sortKey']));
      });

      DatabaseEvent event = await databaseReference.once();
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> rankings =
            event.snapshot.value as Map<dynamic, dynamic>;
        _updateRankings(rankings);
      }
    } catch (e) {
      print("Error fetching anime data: $e");
    }
  }

  Future<void> _fetchEventData() async {
    try {
      final eventSnapshot = await firestore.collection('events').get();
      List<Map<String, dynamic>> translatedEvents = [];

      for (var doc in eventSnapshot.docs) {
        if (doc.data()['isEnabled'] == true) {
          final data = doc.data();
          String translatedTitle =
              await translateText(data['title'] as String? ?? '');
          String translatedDescription =
              await translateText(data['description'] as String? ?? '');

          translatedEvents.add({
            'title': translatedTitle,
            'originalTitle': data['title'] as String? ?? '',
            'imageUrl': data['imageUrl'] as String? ?? '',
            'description': translatedDescription,
            'startDate': data['startDate'],
            'endDate': data['endDate'],
            'htmlContent': await translateText(data['html'] as String? ?? ''),
          });
        }
      }

      setState(() {
        _eventData = translatedEvents;
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
        List<Map<String, dynamic>> prefSpots = [];

        for (var doc in spotSnapshot.docs) {
          var data = doc.data() as Map<String, dynamic>;
          String jpPrefecture = _japaneseToEnglishPrefecture.entries
              .firstWhere((entry) => entry.value == prefecture)
              .key;

          var spotData = {
            'name': await translateText(data['sourceTitle'] ?? ''),
            'originalName': data['sourceTitle'] ?? '',
            'imageUrl': data['imageUrl'] ?? '',
            'anime': await translateText(data['anime'] ?? ''),
            'originalAnime': data['anime'] ?? '',
            'latitude': (data['latitude'] is num)
                ? (data['latitude'] as num).toDouble()
                : 0.0,
            'longitude': (data['longitude'] is num)
                ? (data['longitude'] as num).toDouble()
                : 0.0,
            'locationID': doc.id,
          };

          if (_isInPrefecture(spotData, jpPrefecture)) {
            prefSpots.add(spotData);
          }
        }

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
    var englishPrefecture = _japaneseToEnglishPrefecture[prefecture];
    if (englishPrefecture == null) return false;

    var bounds = prefectureBounds[englishPrefecture];
    if (bounds == null) {
      print("No bounds found for $englishPrefecture");
      return false;
    }

    double lat = spot['latitude'];
    double lng = spot['longitude'];

    return lat >= bounds['minLat']! &&
        lat <= bounds['maxLat']! &&
        lng >= bounds['minLng']! &&
        lng <= bounds['maxLng']!;
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
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

  Future<void> _navigateAndVote(
      BuildContext context, String animeName, String originalName) async {
    try {
      final String today = DateTime.now().toString().split(' ')[0];
      final prefs = await SharedPreferences.getInstance();
      final String? lastVoteDate = prefs.getString('lastVote_$originalName');

      if (lastVoteDate == null || lastVoteDate != today) {
        final List<String> votedAnimeToday =
            prefs.getStringList('votedAnime_$today') ?? [];

        if (votedAnimeToday.length < 1) {
          rtdb.DatabaseReference animeRef =
              databaseReference.child(originalName);
          rtdb.TransactionResult result =
              await animeRef.runTransaction((Object? currentValue) {
            if (currentValue == null) {
              return rtdb.Transaction.success(1);
            }
            return rtdb.Transaction.success((currentValue as int) + 1);
          });

          if (result.committed) {
            await prefs.setString('lastVote_$originalName', today);
            votedAnimeToday.add(originalName);
            await prefs.setStringList('votedAnime_$today', votedAnimeToday);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Vote recorded for $animeName'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to record vote. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Daily voting limit reached. Please try again tomorrow.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You have already voted for this anime today.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print("Error incrementing anime count: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnimeDetailsPage(
          animeName: originalName,
        ),
      ),
    );
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
            '■ Rankings (Top 10)',
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
          children: [
            SizedBox(
              height: 200,
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                scrollDirection: Axis.horizontal,
                itemCount: _topRankedAnime.length,
                itemBuilder: (context, index) {
                  final anime = _topRankedAnime[index];
                  return GestureDetector(
                    onTap: () => _navigateAndVote(
                      context,
                      anime['name'],
                      anime['originalName'],
                    ),
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
                                    borderRadius: BorderRadius.circular(12),
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
          ],
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            '■ Anime List',
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
                      child: Text('No results found'),
                    )
                  : GridView.builder(
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
                          _loadGridBannerAd(index);
                          if (_isGridBannerAdReady[index] == true &&
                              _gridBannerAds[index] != null) {
                            return Container(
                              width:
                                  _gridBannerAds[index]!.size.width.toDouble(),
                              height:
                                  _gridBannerAds[index]!.size.height.toDouble(),
                              child: AdWidget(ad: _gridBannerAds[index]!),
                            );
                          } else {
                            return Container(
                              height: 50,
                              child: Center(child: Text('Ad')),
                            );
                          }
                        }

                        final adjustedIndex = index - (index ~/ 6);
                        if (adjustedIndex >= filteredAnimeData.length) {
                          return SizedBox();
                        }

                        final anime = filteredAnimeData[adjustedIndex];
                        final key = adjustedIndex == 0 ? firstItemKey : null;

                        return GestureDetector(
                          key: key,
                          onTap: () => _navigateAndVote(
                            context,
                            anime['name'],
                            anime['originalName'],
                          ),
                          child: AnimeGridItemEn(
                            animeName: anime['name'],
                            imageUrl: anime['imageUrl'],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    _bannerAd?.dispose();
    _bottomBannerAd?.dispose();
    _gridBannerAds.values.forEach((ad) => ad.dispose());
    _adMob.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
      if (_currentTabIndex == 1 && !_isPrefectureDataFetched) {
        _fetchPrefectureData();
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
                title: Text('Exit Application'),
                content: Text('Are you sure you want to exit?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text('Exit'),
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
                            ? 'Search by location...'
                            : 'Search by event...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                  style: TextStyle(color: Colors.black),
                )
              : Text(
                  'Pilgrimage Spots',
                  style: TextStyle(
                    color: Color(0xFF00008b),
                    fontWeight: FontWeight.bold,
                  ),
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
            IconButton(
              key: addKey,
              icon: Icon(Icons.add, color: Color(0xFF00008b)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AnimeRequestCustomerForm()),
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
              Tab(text: 'Find by Anime'),
              Tab(text: 'Find by Location'),
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
    );
  }
}

class AnimeGridItemEn extends StatelessWidget {
  final String animeName;
  final String imageUrl;

  const AnimeGridItemEn({
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
