import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:flutter/material.dart';
import 'package:parts/spot_page/check_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../login_page/sign_up.dart';
import 'anime_list_detail.dart';
import 'customer_anime_request.dart';
import 'liked_post.dart';

class AnimeListPage extends StatefulWidget {
  @override
  _AnimeListPageState createState() => _AnimeListPageState();
}

class _AnimeListPageState extends State<AnimeListPage> {
  final FirebaseInAppMessaging fiam = FirebaseInAppMessaging.instance;
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  List<Map<String, dynamic>> _allAnimeData = [];

  late TutorialCoachMark tutorialCoachMark;
  List<TargetFocus> targets = [];

  GlobalKey searchKey = GlobalKey();
  GlobalKey addKey = GlobalKey();
  GlobalKey favoriteKey = GlobalKey();
  GlobalKey checkInKey = GlobalKey();
  GlobalKey firstItemKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchAnimeData();
    _initTargets();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showTutorial();
      _triggerInAppMessage();
    });
  }

  void _triggerInAppMessage() async {
    // アナリティクスイベントをトリガーしてIn-App Messageを表示
    await analytics.logEvent(
      name: 'anime_list_viewed',
      parameters: {'user_type': 'returning_user'},
    );
  }

  void _initTargets() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      targets = [
        TargetFocus(
          identify: "Search Button",
          keyTarget: searchKey,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              child: Text(
                "アニメを検索するにはここから！",
                style: TextStyle(color: Colors.white),
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
                "新しいアニメをリクエストするにはここから！",
                style: TextStyle(color: Colors.white),
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
                "お気に入りのスポットを見るにはここから！",
                style: TextStyle(color: Colors.white),
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
                "チェックインしたスポットの確認はここから！",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        TargetFocus(
          identify: "First Anime Item",
          keyTarget: firstItemKey,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              child: Text(
                "アニメごとのスポットはここから！",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ];
    });
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
          return false;
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
        };
      }).toList();
      setState(() {});
    } catch (e) {
      print("Error fetching anime data: $e");
    }
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
    List<Map<String, dynamic>> filteredAnimeData = _allAnimeData
        .where((anime) => anime['name'].toLowerCase().contains(_searchQuery))
        .toList();

    return WillPopScope(
      onWillPop: () async {
        // アプリ終了時にIn-App Messagingを無効化
        await fiam.setMessagesSuppressed(true);
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
                    hintText: 'アニメで検索...',
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
              icon: Icon(
                Icons.add,
                color: Color(0xFF00008b),
              ),
              onPressed: () {
                // 現在のユーザーを取得
                User? user = FirebaseAuth.instance.currentUser;

                // 匿名ユーザーの場合の処理
                if (user != null && user.isAnonymous) {
                  // 匿名ユーザー向けの画面を表示
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WillPopScope(
                        onWillPop: () async => false,
                        child: Scaffold(
                          appBar: AppBar(
                            leading: IconButton(
                              icon: Icon(Icons.arrow_back,
                                  color: Color(0xFF00008b)),
                              onPressed: () {
                                Navigator.pop(context); // 戻る処理
                              },
                            ),
                            automaticallyImplyLeading: false,
                            backgroundColor: Colors.white,
                            title: Text(
                              '登録が必要です',
                              style: const TextStyle(
                                color: Color(0xFF00008b),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          body: Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blueAccent.shade100,
                                  Colors.blue.shade200
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 100,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    '現在、ゲストログインでご利用いただいております。\nそのため、ポイントをお貯めいただけません。\n以下より登録をお願いします。',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 40, vertical: 15),
                                      backgroundColor: Colors.orangeAccent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const SignUpPage()),
                                      );
                                    },
                                    child: Text(
                                      '登録はこちら',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                } else {
                  // 通常のユーザーはリクエストフォーム画面に遷移
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AnimeRequestCustomerForm(),
                    ),
                  );
                }
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
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
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
                      ? Center(child: Text('何も見つかりませんでした。。'))
                      : GridView.builder(
                          padding: EdgeInsets.only(bottom: 16.0),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.3,
                            mainAxisSpacing: 1.0,
                            crossAxisSpacing: 3.0,
                          ),
                          itemCount: filteredAnimeData.length,
                          itemBuilder: (context, index) {
                            final animeName = filteredAnimeData[index]['name'];
                            final imageUrl =
                                filteredAnimeData[index]['imageUrl'];
                            final key = index == 0 ? firstItemKey : GlobalKey();
                            return GestureDetector(
                              key: key,
                              onTap: () =>
                                  _navigateToDetails(context, animeName),
                              child: AnimeGridItem(
                                  animeName: animeName, imageUrl: imageUrl),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetails(BuildContext context, String animeName) {
    analytics.logEvent(
      name: 'view_anime_details',
      parameters: {'anime_name': animeName},
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnimeDetailsPage(animeName: animeName),
      ),
    );
  }
}

// ... (前のコードは変更なし)

class AnimeGridItem extends StatelessWidget {
  final String animeName;
  final String imageUrl;

  const AnimeGridItem({
    Key? key,
    required this.animeName,
    required this.imageUrl,
  }) : super(key: key);

  Future<void> _checkAndUpdateTap(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    final userId = user.uid;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final tapRef = FirebaseFirestore.instance
        .collection('anime_taps')
        .doc('${userId}_${animeName}_${today.toIso8601String()}');

    try {
      final tapDoc = await tapRef.get();
      if (!tapDoc.exists) {
        await tapRef.set({
          'userId': userId,
          'animeName': animeName,
          'date': today,
          'count': 1,
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ランキングへの反映は1日1回まで！')),
        );
      }
    } catch (e) {
      print('Error checking/updating tap: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textStyle = TextStyle(
          fontSize: 12.0, // フォントサイズを小さくして、より多くのテキストを表示
          fontWeight: FontWeight.bold,
          height: 1.2,
        );

        final textPainter = TextPainter(
          text: TextSpan(text: animeName, style: textStyle),
          maxLines: 3, // 最大3行まで表示を許可
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        final textHeight = textPainter.height;
        final itemHeight = 100 + textHeight + 16.0;

        return GestureDetector(
          onTap: () async {
            await _checkAndUpdateTap(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AnimeDetailsPage(animeName: animeName),
              ),
            );
          },
          child: Container(
            height: itemHeight,
            padding: const EdgeInsets.all(4.0),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9.0),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: constraints.maxWidth,
                    height: 100,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Icon(Icons.error),
                  ),
                ),
                SizedBox(height: 8.0),
                Expanded(
                  child: Text(
                    animeName,
                    textAlign: TextAlign.center,
                    style: textStyle,
                    maxLines: 3, // 最大3行まで表示
                    overflow: TextOverflow.ellipsis,
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
