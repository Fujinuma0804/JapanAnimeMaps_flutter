import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:parts/spot_page/check_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'anime_list_detail.dart';
import 'customer_anime_request.dart';
import 'liked_post.dart';

class AnimeListPage extends StatefulWidget {
  @override
  _AnimeListPageState createState() => _AnimeListPageState();
}

class _AnimeListPageState extends State<AnimeListPage> {
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorial());
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
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => AnimeRequestCustomerForm()));
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
                              key: key, // 各アイテムにキーを設定
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnimeDetailsPage(animeName: animeName),
      ),
    );
  }
}

class AnimeGridItem extends StatelessWidget {
  final String animeName;
  final String imageUrl;

  const AnimeGridItem(
      {Key? key, required this.animeName, required this.imageUrl})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: animeName,
            style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
          ),
          maxLines: 2,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        final textHeight = textPainter.height;
        final itemHeight = 100 + textHeight + 12.0;

        return Container(
          height: itemHeight,
          padding: const EdgeInsets.all(4.0),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9.0),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 200,
                  height: 100,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Icon(Icons.error),
                ),
              ),
              SizedBox(height: 4.0),
              Expanded(
                child: Text(
                  animeName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
