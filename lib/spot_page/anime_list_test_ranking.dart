import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:parts/spot_page/check_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'anime_list.dart';
import 'anime_list_detail.dart';
import 'customer_anime_request.dart';
import 'liked_post.dart';

class AnimeListTestRanking extends StatefulWidget {
  @override
  _AnimeListTestRankingState createState() => _AnimeListTestRankingState();
}

class _AnimeListTestRankingState extends State<AnimeListTestRanking>
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
  Map<String, List<Map<String, dynamic>>> _prefectureSpots = {};

  late TabController _tabController;

  late TutorialCoachMark tutorialCoachMark;
  List<TargetFocus> targets = [];

  GlobalKey searchKey = GlobalKey();
  GlobalKey addKey = GlobalKey();
  GlobalKey favoriteKey = GlobalKey();
  GlobalKey checkInKey = GlobalKey();
  GlobalKey firstItemKey = GlobalKey();
  GlobalKey rankingKey = GlobalKey();

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

  int _currentTabIndex = 0;
  bool _isPrefectureDataFetched = false;

  @override
  void initState() {
    super.initState();
    databaseReference =
        rtdb.FirebaseDatabase.instance.reference().child('anime_rankings');
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _fetchAnimeData();
    _initTargets();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorial());
    _listenToRankingChanges();
    _setupInAppMessaging();
  }

  void _setupInAppMessaging() {
    //アプリ起動時にトリガーイベントを発火
    fiam.triggerEvent('app_open');

    //メッセージの表示を許可
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

      // Update counts in _allAnimeData
      for (var anime in _allAnimeData) {
        anime['count'] = rankings[anime['name']] != null
            ? (rankings[anime['name']] as num).toInt()
            : 0;
      }

      // Sort _allAnimeData by count
      _allAnimeData
          .sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
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

  void _initTargets() {
    targets = [
      TargetFocus(
        identify: "Ranking",
        keyTarget: rankingKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: Text(
              "ここでは人気のアニメランキングを見ることができます。",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "Search Button",
        keyTarget: searchKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: Text(
              "アニメや都道府県を検索するにはここをタップしてください。",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "Add Button",
        keyTarget: addKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: Text(
              "新しいアニメをリクエストしたい場合はここをタップしてください。",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "Favorite Button",
        keyTarget: favoriteKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: Text(
              "お気に入りのスポットを見るにはここをタップしてください。",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "Check In Button",
        keyTarget: checkInKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: Text(
              "チェックインしたスポットの確認はここをタップしてください。",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "Anime Item",
        keyTarget: firstItemKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: Text(
              "アニメをタップすると、関連するスポットを見ることができます。",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    ];
  }

  Future<void> _showTutorial() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool showTutorial = prefs.getBool('showTutorial') ?? true;

    if (showTutorial) {
      tutorialCoachMark = TutorialCoachMark(
        targets: targets,
        colorShadow: Colors.black,
        textSkip: "スキップ",
        paddingFocus: 10,
        opacityShadow: 0.8,
        onFinish: () {
          print("チュートリアル完了");
        },
        onClickTarget: (target) {
          print('${target.identify} がクリックされました');
        },
        onSkip: () {
          print("チュートリアルをスキップしました");
          return true;
        },
      );

      tutorialCoachMark.show(context: context);
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
        };
      }).toList();

      // 五十音順でソートされたリストを作成
      _sortedAnimeData = List.from(_allAnimeData);
      _sortedAnimeData.sort((a, b) => a['name'].compareTo(b['name']));

      // Fetch initial rankings
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

    print("Checking spot (${lat}, ${lng}) for $prefecture: $result");
    if (!result) {
      print("Bounds for $prefecture: ${bounds}");
    }

    return result;
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

  @override
  Widget build(BuildContext context) {
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
                        : '都道府県で検索...', // タブに応じてhintTextを変更
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                  style: TextStyle(color: Colors.black),
                )
              : Text(
                  '巡礼スポット',
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
              Tab(text: 'アニメ一覧から探す'),
              Tab(text: '都道府県から探す'),
            ],
            labelColor: Color(0xFF00008b),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF00008b),
          ),
        ),
        body: TabBarView(
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

    Future<void> _incrementAnimeCount(String animeName) async {
      try {
        // Get current date as string (YYYY-MM-DD format)
        final String today = DateTime.now().toString().split(' ')[0];

        // Get SharedPreferences instance
        final prefs = await SharedPreferences.getInstance();

        // Check if user has already voted for this anime
        final String? lastVoteDate = prefs.getString('lastVote_$animeName');

        // If user has never voted for this anime or voted on a different day
        if (lastVoteDate == null || lastVoteDate != today) {
          // Get total votes for today
          final List<String> votedAnimeToday =
              prefs.getStringList('votedAnime_$today') ?? [];

          // Check if user hasn't exceeded daily vote limit
          if (votedAnimeToday.length < 1) {
            rtdb.DatabaseReference animeRef =
                databaseReference.child(animeName);
            rtdb.TransactionResult result =
                await animeRef.runTransaction((Object? currentValue) {
              if (currentValue == null) {
                return rtdb.Transaction.success(1);
              }
              return rtdb.Transaction.success((currentValue as int) + 1);
            });

            if (result.committed) {
              // Save the vote date for this anime
              await prefs.setString('lastVote_$animeName', today);

              // Add anime to today's voted list
              votedAnimeToday.add(animeName);
              await prefs.setStringList('votedAnime_$today', votedAnimeToday);

              print("Incremented count for $animeName");

              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$animeNameの投票を受け付けました。'),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              print("Failed to increment count for $animeName");
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('投票に失敗しました。もう一度お試しください。'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } else {
            print("Daily vote limit reached");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('本日の投票回数の上限に達しました。また明日お試しください。'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          print("Already voted for this anime today");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('このアニメには既に投票済みです。'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        print("Error incrementing anime count: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました。もう一度お試しください。'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    void _navigateToDetails(BuildContext context, String animeName) {
      _incrementAnimeCount(animeName);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AnimeDetailsPage(animeName: animeName),
        ),
      );
    }

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
                    onTap: () => _navigateToDetails(context, anime['name']),
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
                      padding: EdgeInsets.only(bottom: 16.0),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.3,
                        mainAxisSpacing: 1.0,
                        crossAxisSpacing: 3.0,
                      ),
                      itemCount: filteredAnimeData.length,
                      itemBuilder: (context, index) {
                        final animeName = filteredAnimeData[index]['name'];
                        final imageUrl = filteredAnimeData[index]['imageUrl'];
                        final key = index == 0 ? firstItemKey : null;
                        return GestureDetector(
                          key: key,
                          onTap: () => _navigateToDetails(context, animeName),
                          child: AnimeGridItem(
                              animeName: animeName, imageUrl: imageUrl),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class PrefectureListPage extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> prefectureSpots;
  final String searchQuery;
  final Function onFetchPrefectureData;

  const PrefectureListPage({
    Key? key,
    required this.prefectureSpots,
    required this.searchQuery,
    required this.onFetchPrefectureData,
  }) : super(key: key);

  @override
  _PrefectureListPageState createState() => _PrefectureListPageState();
}

class _PrefectureListPageState extends State<PrefectureListPage> {
  final FirebaseStorage storage = FirebaseStorage.instance;
  final Map<String, List<String>> regions = {
    '北海道・東北': ['北海道', '青森県', '岩手県', '宮城県', '秋田県', '山形県', '福島県'],
    '関東': ['茨城県', '栃木県', '群馬県', '埼玉県', '千葉県', '東京都', '神奈川県'],
    '中部': ['新潟県', '富山県', '石川県', '福井県', '山梨県', '長野県', '岐阜県', '静岡県', '愛知県'],
    '近畿': ['三重県', '滋賀県', '京都府', '大阪府', '兵庫県', '奈良県', '和歌山県'],
    '中国・四国': ['鳥取県', '島根県', '岡山県', '広島県', '山口県', '徳島県', '香川県', '愛媛県', '高知県'],
    '九州・沖縄': ['福岡県', '佐賀県', '長崎県', '熊本県', '大分県', '宮崎県', '鹿児島県', '沖縄県'],
  };

  Set<String> selectedPrefectures = {};
  String currentRegion = '';

  @override
  void initState() {
    super.initState();
    widget.onFetchPrefectureData();
  }

  Future<String> getPrefectureImageUrl(String prefectureName) async {
    try {
      final ref = storage.ref().child('prefectures/$prefectureName.jpg');
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error getting image URL for $prefectureName: $e');
      return '';
    }
  }

  List<String> getFilteredPrefectures() {
    return widget.prefectureSpots.keys.where((prefecture) {
      bool matchesSearch =
          prefecture.toLowerCase().contains(widget.searchQuery.toLowerCase()) ||
              (widget.prefectureSpots[prefecture]?.any((spot) {
                    bool animeMatch = spot['anime']
                            ?.toString()
                            .toLowerCase()
                            .contains(widget.searchQuery.toLowerCase()) ??
                        false;
                    bool nameMatch = spot['name']
                            ?.toString()
                            .toLowerCase()
                            .contains(widget.searchQuery.toLowerCase()) ??
                        false;
                    return animeMatch || nameMatch;
                  }) ??
                  false); // explicitly set to false if null

      bool matchesRegion = selectedPrefectures.isEmpty ||
          selectedPrefectures.contains(prefecture);

      return matchesSearch && matchesRegion;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    List<String> filteredPrefectures = getFilteredPrefectures();

    // デバッグ情報を追加
    for (String prefecture in filteredPrefectures) {
      List<Map<String, dynamic>> spots =
          widget.prefectureSpots[prefecture] ?? [];
      print('Debug: $prefecture のスポット数: ${spots.length}');
      for (var spot in spots) {
        print(
            'Debug: $prefecture のスポット: ${spot['name'] ?? 'タイトルなし'}, LocationID: ${spot['locationID'] ?? 'ID未設定'}');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            '■ 都道府県一覧',
            style: TextStyle(
              color: Color(0xFF00008b),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        Container(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: regions.keys.map((region) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    hint: Text(
                      region,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00008b),
                      ),
                    ),
                    icon: Icon(Icons.arrow_drop_down, color: Color(0xFF00008b)),
                    items: regions[region]!.map((String prefecture) {
                      return DropdownMenuItem<String>(
                        value: prefecture,
                        child: Text(prefecture),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          if (selectedPrefectures.contains(newValue)) {
                            selectedPrefectures.remove(newValue);
                          } else {
                            selectedPrefectures.add(newValue);
                          }
                          currentRegion = region;
                        });
                      }
                    },
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Container(
          padding: EdgeInsets.all(8.0),
          color: Color(0xFFE6E6FA),
          child: Row(
            children: [
              Icon(Icons.place, color: Color(0xFF00008b)),
              SizedBox(width: 8),
              Text(
                '現在選択中の地方: $currentRegion',
                style: TextStyle(
                  color: Color(0xFF00008b),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '選択中の都道府県: ${selectedPrefectures.isEmpty ? "なし" : selectedPrefectures.join(", ")}',
                  style: TextStyle(
                    color: Color(0xFF00008b),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    selectedPrefectures.clear();
                    currentRegion = '';
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00008b),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.0),
                  ),
                ),
                child: Text(
                  'クリア',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: widget.prefectureSpots.isEmpty
              ? Center(child: CircularProgressIndicator())
              : GridView.builder(
                  padding: EdgeInsets.all(16.0),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filteredPrefectures.length,
                  itemBuilder: (context, index) {
                    final prefecture = filteredPrefectures[index];
                    final spotCount =
                        widget.prefectureSpots[prefecture]?.length ?? 0;
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PrefectureSpotListPage(
                              prefecture: prefecture,
                              locations:
                                  widget.prefectureSpots[prefecture] ?? [],
                              animeName: '',
                              prefectureBounds: {},
                            ),
                          ),
                        );
                      },
                      child: PrefectureGridItem(
                        prefectureName: prefecture,
                        spotCount: spotCount,
                        getImageUrl: getPrefectureImageUrl,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class PrefectureGridItem extends StatelessWidget {
  final String prefectureName;
  final int spotCount;
  final Future<String> Function(String) getImageUrl;

  const PrefectureGridItem({
    Key? key,
    required this.prefectureName,
    required this.spotCount,
    required this.getImageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: FutureBuilder<String>(
              future: getImageUrl(prefectureName),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError || !snapshot.hasData) {
                  return Container(
                    color: Colors.grey[200],
                    child: Icon(Icons.image_not_supported, size: 50),
                  );
                } else {
                  return CachedNetworkImage(
                    imageUrl: snapshot.data!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => Icon(Icons.error),
                  );
                }
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Column(
              children: [
                Text(
                  prefectureName,
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'スポット数: $spotCount',
                  style: TextStyle(
                    fontSize: 12.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PrefectureSpotListPage extends StatefulWidget {
  final String prefecture;
  final List<Map<String, dynamic>> locations;
  final String animeName;
  final Map<String, Map<String, double>> prefectureBounds;

  PrefectureSpotListPage({
    Key? key,
    required this.prefecture,
    required this.locations,
    required this.animeName,
    required this.prefectureBounds,
  }) : super(key: key);

  @override
  _PrefectureSpotListPageState createState() => _PrefectureSpotListPageState();
}

class _PrefectureSpotListPageState extends State<PrefectureSpotListPage> {
  Future<String> getPrefectureImageUrl(String prefectureName) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('prefectures/$prefectureName.jpg');
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error getting image URL for $prefectureName: $e');
      return '';
    }
  }

  Future<String> getAnimeName(String locationId) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('locations')
          .doc(locationId)
          .get();
      return doc.get('animeName') as String? ?? 'Unknown Anime';
    } catch (e) {
      print('Error getting animeName for location $locationId: $e');
      return 'Unknown Anime';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.prefecture} のスポット',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 200,
            width: double.infinity,
            child: FutureBuilder<String>(
              future: getPrefectureImageUrl(widget.prefecture),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError || !snapshot.hasData) {
                  return Container(
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      size: 50,
                    ),
                  );
                } else {
                  return CachedNetworkImage(
                    imageUrl: snapshot.data!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => Icon(Icons.error),
                  );
                }
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '■ ${widget.prefecture} のアニメスポット',
              style: TextStyle(
                color: Color(0xFF00008b),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8.0),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.3,
                mainAxisSpacing: 1.0,
                crossAxisSpacing: 3.0,
              ),
              itemCount: widget.locations.length,
              itemBuilder: (context, index) {
                final location = widget.locations[index];
                final locationId = location['locationID'] ?? '';

                return Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('locations')
                                  .doc(locationId)
                                  .get(),
                              builder: (BuildContext context,
                                  AsyncSnapshot<DocumentSnapshot> snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Center(
                                      child: CircularProgressIndicator());
                                }
                                if (snapshot.hasError) {
                                  return Center(child: Text("エラーが発生しました"));
                                }
                                if (!snapshot.hasData ||
                                    !snapshot.data!.exists) {
                                  return Center(child: Text("スポットが見つかりません"));
                                }

                                Map<String, dynamic> data = snapshot.data!
                                    .data() as Map<String, dynamic>;
                                String title = data['title'] ?? 'No Title';
                                String animeName =
                                    data['animeName'] ?? 'Unknown Anime';

                                return SpotDetailScreen(
                                  title: title,
                                  userId: '',
                                  imageUrl: data['imageUrl'] ?? '',
                                  description: data['description'] ?? '',
                                  latitude:
                                      (data['latitude'] as num?)?.toDouble() ??
                                          0.0,
                                  longitude:
                                      (data['longitude'] as num?)?.toDouble() ??
                                          0.0,
                                  sourceLink: data['sourceLink'] ?? '',
                                  sourceTitle: data['sourceTitle'] ?? '',
                                  url: data['url'] ?? '',
                                  subMedia: (data['subMedia'] as List?)
                                          ?.where((item) =>
                                              item is Map<String, dynamic>)
                                          .cast<Map<String, dynamic>>()
                                          .toList() ??
                                      [],
                                  locationId: locationId,
                                  animeName: animeName,
                                );
                              },
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: location['imageUrl'] ?? '',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: Icon(Icons.image_not_supported, size: 50),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: FutureBuilder<String>(
                        future: getAnimeName(locationId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Text('Loading...');
                          }
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AnimeDetailsPage(
                                    animeName: snapshot.data ?? 'Unknown Anime',
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              snapshot.data ?? 'Unknown Anime',
                              style: TextStyle(
                                fontSize: 13.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue, // タップ可能であることを示す
                                decoration:
                                    TextDecoration.underline, // タップ可能であることを示す
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Column(
//   crossAxisAlignment: CrossAxisAlignment.start,
//   children: [
//     Padding(
//       padding: EdgeInsets.all(16.0),
//       child: Text(
//         '■ $prefecture のアニメスポット',
//         style: TextStyle(
//           color: Color(0xFF00008b),
//           fontWeight: FontWeight.bold,
//           fontSize: 16,
//         ),
//       ),
//     ),
//     Expanded(
//       child: GridView.builder(
//         padding: const EdgeInsets.all(8.0),
//         gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//           crossAxisCount: 2,
//           childAspectRatio: 1.3,
//           crossAxisSpacing: 10.0,
//           mainAxisSpacing: 10.0,
//         ),
//         itemCount: locations.length,
//         itemBuilder: (context, index) {
//           final location = locations[index];
//           final locationId = location['locationID'] ?? '';
//           final title = location['name'] as String? ??
//               'No Title'; // Changed from 'title' to 'name'
//           final animeName =
//               location['animeName'] as String? ?? 'Unknown Anime';
//           final imageUrl = location['imageUrl'] as String? ?? '';
//
//           return GestureDetector(
//             onTap: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) => SpotDetailScreen(
//                     title: title, // Use the 'name' field for the title
//                     imageUrl: location['imageUrl'] as String? ?? '',
//                     description: location['description'] as String? ?? '',
//                     latitude:
//                         (location['latitude'] as num?)?.toDouble() ?? 0.0,
//                     longitude:
//                         (location['longitude'] as num?)?.toDouble() ??
//                             0.0,
//                     sourceLink: location['sourceLink'] as String? ?? '',
//                     sourceTitle: location['sourceTitle'] as String? ?? '',
//                     url: location['url'] as String? ?? '',
//                     subMedia: (location['subMedia'] as List?)
//                             ?.where(
//                                 (item) => item is Map<String, dynamic>)
//                             .cast<Map<String, dynamic>>()
//                             .toList() ??
//                         [],
//                     locationId: locationId,
//                   ),
//                 ),
//               );
//             },
//             child: SpotGridItem(
//               title: title,
//               animeName: animeName,
//               imageUrl: imageUrl,
//             ),
//           );
//         },
//       ),
//     ),
//   ],
// ),
