import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ハプティックフィードバック用
import 'package:parts/map_page/prefecture_tab/prefecture_spot_list.dart';
import 'package:parts/spot_page/anime_list_en_ranking.dart';

import '../../spot_page/anime_list_detail.dart';

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

  // 画像URLキャッシュを追加
  static final Map<String, String> _imageUrlCache = {};
  static final Map<String, Future<String>> _pendingRequests = {};

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
  List<String>? _cachedFilteredPrefectures;
  String _lastSearchQuery = '';
  Set<String> _lastSelectedPrefectures = {};

  @override
  void initState() {
    super.initState();
    // データ取得の開始を遅延させる（UIの初期表示を優先）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onFetchPrefectureData();
    });

    // よく使われる都道府県の画像を事前読み込み
    _preloadPopularPrefectureImages();
  }

  // 人気の都道府県画像を事前読み込み
  void _preloadPopularPrefectureImages() {
    final popularPrefectures = ['東京都', '大阪府', '京都府', '神奈川県', '愛知県'];
    for (String prefecture in popularPrefectures) {
      getPrefectureImageUrl(prefecture);
    }
  }

  // 改善された画像URL取得（キャッシュ機能付き）
  Future<String> getPrefectureImageUrl(String prefectureName) async {
    // キャッシュされた結果があればそれを返す
    if (_imageUrlCache.containsKey(prefectureName)) {
      return _imageUrlCache[prefectureName]!;
    }

    // 既に同じリクエストが進行中の場合は、それを待つ
    if (_pendingRequests.containsKey(prefectureName)) {
      return _pendingRequests[prefectureName]!;
    }

    // 新しいリクエストを開始
    final future = _fetchImageUrl(prefectureName);
    _pendingRequests[prefectureName] = future;

    try {
      final url = await future;
      _imageUrlCache[prefectureName] = url;
      return url;
    } catch (e) {
      print('Error getting image URL for $prefectureName: $e');
      _imageUrlCache[prefectureName] = '';
      return '';
    } finally {
      _pendingRequests.remove(prefectureName);
    }
  }

  Future<String> _fetchImageUrl(String prefectureName) async {
    final ref = storage.ref().child('prefectures/$prefectureName.jpg');
    return await ref.getDownloadURL();
  }

  // フィルタリング結果をキャッシュ
  List<String> getFilteredPrefectures() {
    // キャッシュが有効な場合はそれを返す
    if (_cachedFilteredPrefectures != null &&
        _lastSearchQuery == widget.searchQuery &&
        _lastSelectedPrefectures.length == selectedPrefectures.length &&
        _lastSelectedPrefectures.containsAll(selectedPrefectures)) {
      return _cachedFilteredPrefectures!;
    }

    // フィルタリングを実行
    final filtered = widget.prefectureSpots.keys.where((prefecture) {
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
                  false);

      bool matchesRegion = selectedPrefectures.isEmpty ||
          selectedPrefectures.contains(prefecture);

      return matchesSearch && matchesRegion;
    }).toList();

    // キャッシュを更新
    _cachedFilteredPrefectures = filtered;
    _lastSearchQuery = widget.searchQuery;
    _lastSelectedPrefectures = Set.from(selectedPrefectures);

    return filtered;
  }

  // デバッグログを削除して軽量化
  void _logDebugInfo(List<String> filteredPrefectures) {
    // プロダクション環境では削除
    if (false) { // デバッグ時のみ true に変更
      for (String prefecture in filteredPrefectures) {
        List<Map<String, dynamic>> spots =
            widget.prefectureSpots[prefecture] ?? [];
        print('Debug: $prefecture のスポット数: ${spots.length}');
        for (var spot in spots) {
          print(
              'Debug: $prefecture のスポット: ${spot['name'] ?? 'タイトルなし'}, LocationID: ${spot['locationID'] ?? 'ID未設定'}');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> filteredPrefectures = getFilteredPrefectures();
    _logDebugInfo(filteredPrefectures);

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
                          // フィルタリングキャッシュをクリア
                          _cachedFilteredPrefectures = null;
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
                    _cachedFilteredPrefectures = null;
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
              ? Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [
                  Colors.blue[50]!,
                  Colors.indigo[100]!,
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF00008b),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'データを読み込み中...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF00008b),
                    ),
                  ),
                ],
              ),
            ),
          )
              : Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.grey[50]!,
                  Colors.white,
                ],
              ),
            ),
            child: GridView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              physics: BouncingScrollPhysics(), // iOS風のスクロール
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.2, // より縦長に調整
                crossAxisSpacing: 16,
                mainAxisSpacing: 20,
              ),
              itemCount: filteredPrefectures.length,
              itemBuilder: (context, index) {
                final prefecture = filteredPrefectures[index];
                final spotCount =
                    widget.prefectureSpots[prefecture]?.length ?? 0;
                return OptimizedPrefectureGridItem(
                  prefectureName: prefecture,
                  spotCount: spotCount,
                  getImageUrl: getPrefectureImageUrl,
                  onTap: () {
                    // ハプティックフィードバック（Android/iOS対応）
                    try {
                      HapticFeedback.lightImpact();
                    } catch (e) {
                      // ハプティックフィードバックが利用できない場合は無視
                    }

                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            PrefectureSpotListPage(
                              prefecture: prefecture,
                              locations:
                              widget.prefectureSpots[prefecture] ?? [],
                              animeName: '',
                              prefectureBounds: {},
                            ),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          const begin = Offset(1.0, 0.0);
                          const end = Offset.zero;
                          const curve = Curves.easeInOutCubic;

                          var tween = Tween(begin: begin, end: end)
                              .chain(CurveTween(curve: curve));

                          return SlideTransition(
                            position: animation.drive(tween),
                            child: child,
                          );
                        },
                        transitionDuration: Duration(milliseconds: 300),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// おしゃれなGridItemウィジェット
class OptimizedPrefectureGridItem extends StatefulWidget {
  final String prefectureName;
  final int spotCount;
  final Future<String> Function(String) getImageUrl;
  final VoidCallback onTap; // タップコールバックを追加

  const OptimizedPrefectureGridItem({
    Key? key,
    required this.prefectureName,
    required this.spotCount,
    required this.getImageUrl,
    required this.onTap, // 必須パラメータに追加
  }) : super(key: key);

  @override
  _OptimizedPrefectureGridItemState createState() => _OptimizedPrefectureGridItemState();
}

class _OptimizedPrefectureGridItemState extends State<OptimizedPrefectureGridItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animationController.reverse();
    // タップ完了時にコールバックを実行
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            behavior: HitTestBehavior.opaque, // タップ領域を確実に検出
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _isPressed
                        ? Colors.black.withOpacity(0.2)
                        : Colors.black.withOpacity(0.1),
                    blurRadius: _isPressed ? 8 : 12,
                    offset: _isPressed ? Offset(0, 2) : Offset(0, 4),
                  ),
                ],
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.grey[50]!,
                  ],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // 背景画像
                    Positioned.fill(
                      child: FutureBuilder<String>(
                        future: widget.getImageUrl(widget.prefectureName),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.blue[50]!,
                                    Colors.indigo[100]!,
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF00008b),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.grey[200]!,
                                    Colors.grey[300]!,
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.landscape_outlined,
                                    size: 32,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ),
                            );
                          } else {
                            return CachedNetworkImage(
                              imageUrl: snapshot.data!,
                              fit: BoxFit.cover,
                              memCacheWidth: 300,
                              memCacheHeight: 200,
                              placeholder: (context, url) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.blue[50]!,
                                      Colors.indigo[100]!,
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.8),
                                      shape: BoxShape.circle,
                                    ),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFF00008b),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.grey[200]!,
                                      Colors.grey[300]!,
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.8),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.landscape_outlined,
                                      size: 32,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    // グラデーションオーバーレイ
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.4),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // テキスト情報
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.prefectureName,
                              style: TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    offset: Offset(1, 1),
                                    blurRadius: 2,
                                    color: Colors.black.withOpacity(0.5),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF00008b).withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 2),
                                      Text(
                                        '${widget.spotCount}',
                                        style: TextStyle(
                                          fontSize: 11.0,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ホバー効果のためのオーバーレイ
                    if (_isPressed)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}