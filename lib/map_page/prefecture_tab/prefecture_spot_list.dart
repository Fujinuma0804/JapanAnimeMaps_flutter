import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parts/spot_page/anime_list_detail.dart';

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

class _PrefectureSpotListPageState extends State<PrefectureSpotListPage>
    with TickerProviderStateMixin {
  late AnimationController _headerAnimationController;
  late AnimationController _listAnimationController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;

  // キャッシュ機能（場所名用に変更）
  static final Map<String, String> _imageUrlCache = {};
  static final Map<String, String> _locationNameCache = {}; // _animeNameCacheから変更

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimations();
  }

  void _setupAnimations() {
    _headerAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _listAnimationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _headerFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _headerSlideAnimation = Tween<Offset>(
      begin: Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOutBack,
    ));
  }

  void _startAnimations() {
    _headerAnimationController.forward();
    Future.delayed(Duration(milliseconds: 300), () {
      _listAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _listAnimationController.dispose();
    super.dispose();
  }

  Future<String> getPrefectureImageUrl(String prefectureName) async {
    if (_imageUrlCache.containsKey(prefectureName)) {
      return _imageUrlCache[prefectureName]!;
    }

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('prefectures/$prefectureName.jpg');
      final url = await ref.getDownloadURL();
      _imageUrlCache[prefectureName] = url;
      return url;
    } catch (e) {
      print('Error getting image URL for $prefectureName: $e');
      _imageUrlCache[prefectureName] = '';
      return '';
    }
  }

  Future<String> getLocationName(String locationId) async {
    if (_locationNameCache.containsKey(locationId)) {
      return _locationNameCache[locationId]!;
    }

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('locations')
          .doc(locationId)
          .get();
      // titleまたはnameフィールドから場所名を取得
      final locationName = doc.get('title') as String? ??
          doc.get('name') as String? ??
          doc.get('spot_name') as String? ??
          'Unknown Location';
      _locationNameCache[locationId] = locationName;
      return locationName;
    } catch (e) {
      print('Error getting location name for location $locationId: $e');
      _locationNameCache[locationId] = 'Unknown Location';
      return 'Unknown Location';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
        title: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Text(
                '${widget.prefecture} のスポット',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  shadows: [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 3,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: CustomScrollView(
        physics: BouncingScrollPhysics(),
        slivers: [
          // ヘッダー画像とタイトル
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _headerAnimationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _headerFadeAnimation,
                  child: SlideTransition(
                    position: _headerSlideAnimation,
                    child: Stack(
                      children: [
                        // ヘッダー画像
                        Container(
                          height: 300,
                          width: double.infinity,
                          child: FutureBuilder<String>(
                            future: getPrefectureImageUrl(widget.prefecture),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF6B73FF),
                                        Color(0xFF9DD5FF),
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: SizedBox(
                                          width: 30,
                                          height: 30,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Color(0xFF00008b),
                                            ),
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
                                        Colors.grey[400]!,
                                        Colors.grey[600]!,
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      padding: EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.landscape_outlined,
                                        size: 50,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                );
                              } else {
                                return Hero(
                                  tag: 'prefecture-${widget.prefecture}',
                                  child: CachedNetworkImage(
                                    imageUrl: snapshot.data!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF6B73FF),
                                            Color(0xFF9DD5FF),
                                          ],
                                        ),
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.9),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: SizedBox(
                                              width: 30,
                                              height: 30,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 3,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  Color(0xFF00008b),
                                                ),
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
                                            Colors.grey[400]!,
                                            Colors.grey[600]!,
                                          ],
                                        ),
                                      ),
                                      child: Center(
                                        child: Container(
                                          padding: EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.9),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.landscape_outlined,
                                            size: 50,
                                            color: Colors.grey[600],
                                          ),
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
                        Container(
                          height: 300,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.2),
                                Colors.black.withOpacity(0.6),
                              ],
                            ),
                          ),
                        ),
                        // タイトル部分
                        Positioned(
                          bottom: 30,
                          left: 20,
                          right: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.prefecture,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(2, 2),
                                      blurRadius: 4,
                                      color: Colors.black.withOpacity(0.7),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Color(0xFF00008b).withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '${widget.locations.length} スポット',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
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
            ),
          ),
          // スポットリスト
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            sliver: AnimatedBuilder(
              animation: _listAnimationController,
              builder: (context, child) {
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // 2列に戻す
                    childAspectRatio: 1.0, // 正方形に近い比率に設定
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final location = widget.locations[index];
                      final locationId = location['locationID'] ?? '';

                      // スタガードアニメーション
                      final itemAnimation = Tween<double>(
                        begin: 0.0,
                        end: 1.0,
                      ).animate(CurvedAnimation(
                        parent: _listAnimationController,
                        curve: Interval(
                          (index * 0.1).clamp(0.0, 1.0),
                          ((index * 0.1) + 0.5).clamp(0.0, 1.0),
                          curve: Curves.easeOutBack,
                        ),
                      ));

                      final slideAnimation = Tween<Offset>(
                        begin: Offset(0, 0.5),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _listAnimationController,
                        curve: Interval(
                          (index * 0.1).clamp(0.0, 1.0),
                          ((index * 0.1) + 0.5).clamp(0.0, 1.0),
                          curve: Curves.easeOutCubic,
                        ),
                      ));

                      return FadeTransition(
                        opacity: itemAnimation,
                        child: SlideTransition(
                          position: slideAnimation,
                          child: StylishSpotCard(
                            location: location,
                            locationId: locationId,
                            getLocationName: getLocationName, // getAnimeNameから変更
                            onTap: () => _navigateToSpotDetail(locationId),
                            onLocationTap: (locationName) => _navigateToSpotDetail(locationId), // アニメ詳細ではなくスポット詳細へ
                          ),
                        ),
                      );
                    },
                    childCount: widget.locations.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToSpotDetail(String locationId) async {
    try {
      HapticFeedback.lightImpact();
    } catch (e) {}

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('locations')
                  .doc(locationId)
                  .get(),
              builder: (BuildContext context,
                  AsyncSnapshot<DocumentSnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Scaffold(
                    body: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF6B73FF),
                            Color(0xFF9DD5FF),
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
                                strokeWidth: 4,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF00008b),
                                ),
                              ),
                            ),
                            SizedBox(height: 20),
                            Text(
                              'スポット情報を読み込み中...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    offset: Offset(1, 1),
                                    blurRadius: 2,
                                    color: Colors.black.withOpacity(0.3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Scaffold(
                    body: Center(child: Text("エラーが発生しました")),
                  );
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Scaffold(
                    body: Center(child: Text("スポットが見つかりません")),
                  );
                }

                Map<String, dynamic> data =
                snapshot.data!.data() as Map<String, dynamic>;
                return SpotDetailScreen(
                  title: data['title'] ?? 'No Title',
                  userId: '',
                  imageUrl: data['imageUrl'] ?? '',
                  description: data['description'] ?? '',
                  spot_description: data['spot_description'] ?? '',
                  latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
                  longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
                  sourceLink: data['sourceLink'] ?? '',
                  sourceTitle: data['sourceTitle'] ?? '',
                  url: data['url'] ?? '',
                  subMedia: (data['subMedia'] as List?)
                      ?.where((item) => item is Map<String, dynamic>)
                      .cast<Map<String, dynamic>>()
                      .toList() ??
                      [],
                  locationId: locationId,
                  animeName: data['animeName'] ?? 'Unknown Anime',
                );
              },
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0.0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: Duration(milliseconds: 400),
      ),
    );
  }

  void _navigateToAnimeDetail(String animeName) {
    try {
      HapticFeedback.lightImpact();
    } catch (e) {}

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AnimeDetailsPage(animeName: animeName),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: Duration(milliseconds: 350),
      ),
    );
  }
}

// おしゃれなスポットカードウィジェット
class StylishSpotCard extends StatefulWidget {
  final Map<String, dynamic> location;
  final String locationId;
  final Future<String> Function(String) getLocationName; // getAnimeNameから変更
  final VoidCallback onTap;
  final Function(String) onLocationTap; // onAnimeTapから変更

  const StylishSpotCard({
    Key? key,
    required this.location,
    required this.locationId,
    required this.getLocationName, // getAnimeNameから変更
    required this.onTap,
    required this.onLocationTap, // onAnimeTapから変更
  }) : super(key: key);

  @override
  _StylishSpotCardState createState() => _StylishSpotCardState();
}

class _StylishSpotCardState extends State<StylishSpotCard>
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) {
              setState(() => _isPressed = true);
              _animationController.forward();
            },
            onTapUp: (_) {
              setState(() => _isPressed = false);
              _animationController.reverse();
              widget.onTap();
            },
            onTapCancel: () {
              setState(() => _isPressed = false);
              _animationController.reverse();
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _isPressed
                        ? Colors.black.withOpacity(0.15)
                        : Colors.black.withOpacity(0.08),
                    blurRadius: _isPressed ? 8 : 15,
                    offset: _isPressed ? Offset(0, 4) : Offset(0, 8),
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
                borderRadius: BorderRadius.circular(20),
                child: Column( // Rowから Columnに戻す
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 画像部分（上部）
                    Expanded(
                      flex: 4, // 画像の比率を4に
                      child: Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: double.infinity,
                            child: CachedNetworkImage(
                              imageUrl: widget.location['imageUrl'] ?? '',
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.blue[100]!,
                                      Colors.indigo[200]!,
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.9),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
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
                              ),
                              errorWidget: (context, url, error) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.grey[300]!,
                                      Colors.grey[400]!,
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.9),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 30,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ),
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
                                    Colors.black.withOpacity(0.3),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 場所名部分（下部）
                    Container(
                      height: 80, // 固定の高さに設定
                      padding: EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FutureBuilder<String>(
                            future: widget.getLocationName(widget.locationId), // getAnimeNameから変更
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Center(
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
                                );
                              }
                              return GestureDetector(
                                onTap: () => widget.onLocationTap(snapshot.data ?? 'Unknown Location'), // onAnimeTapから変更
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF00008b).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Color(0xFF00008b).withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        snapshot.data ?? 'Unknown Location', // Unknown Animeから変更
                                        style: TextStyle(
                                          fontSize: 11.0,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF00008b),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
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