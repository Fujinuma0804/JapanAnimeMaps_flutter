import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:parts/spot_page/anime_list_detail.dart';
import 'package:parts/spot_page/anime_list_test_ranking.dart';
import 'package:parts/spot_page/event_more.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:parts/subscription/payment_subscription.dart';

class RankingTopPageEn extends StatefulWidget {
  @override
  _RankingTopPageEnState createState() => _RankingTopPageEnState();
}

class _RankingTopPageEnState extends State<RankingTopPageEn> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  VideoPlayerController? _videoController;
  bool _showVideo = false;
  bool _hasStartedPlaying = false;

  List<Map<String, dynamic>> _eventData = [];
  List<Map<String, dynamic>> _genreData = [];
  List<Map<String, dynamic>> _animeList = [];
  Map<String, int> _animeRankings = {};
  bool _isEventsLoaded = false;
  bool _isGenresLoaded = false;
  bool _isAnimesLoaded = false;
  List<String> _activeEvents = [];
  String? _currentGenreName;
  Timer? _flipTimer;
  Timer? _restartTimer;
  int _currentFlipIndex = 0;
  List<bool> _isFlipped = [];
  bool _isAnimating = false;
  String? _expandedGenreId;
  Set<String> _expandedGenreIds = {};

  bool _isSubscriptionActive = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _flipTimer?.cancel();
    _restartTimer?.cancel();
    super.dispose();
  }

  // 【修正】初期化の順序を修正
  Future<void> _initializeApp() async {
    // RevenueCatを初期化
    await SubscriptionManager.initializeWithDebug();

    // サブスクリプション状態をチェック
    await _checkSubscriptionStatusWithRetry();

    // RevenueCatユーザー同期
    await _syncRevenueCatUser();

    // その他の初期化を実行
    _fetchEventData();
    _fetchGenreData();
    _checkActiveEvents();
    _startFlipAnimation();

    // 【修正】サブスクリプション状態をチェックしてから動画を初期化
    await _initializeVideoIfNeeded();
  }

  // 【修正】サブスクリプション状態に基づいて動画を初期化
  Future<void> _initializeVideoIfNeeded() async {
    // プレミアム会員の場合は動画を表示しない
    if (_isSubscriptionActive) {
      print('🚫 Skipping video initialization - Premium user');
      return;
    }

    await _initializeVideo();
  }

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

        // Success, break out of loop
        break;
      } catch (e) {
        retryCount++;
        print('❌ Subscription check failed (attempt $retryCount): $e');

        if (retryCount < maxRetries) {
          // Exponential backoff wait
          await Future.delayed(Duration(seconds: 2 * retryCount));
        } else {
          // Final attempt: check local status
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

  Future<bool> _checkLocalSubscriptionFallback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('local_subscription_active') ?? false;
    } catch (e) {
      print('❌ Local fallback check failed: $e');
      return false;
    }
  }

  // Simple subscription status check
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

  // RevenueCat user sync function
  Future<void> _syncRevenueCatUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Sync user ID to RevenueCat
        await SubscriptionManager.setUserId(user.uid);
        print('RevenueCat user synced: ${user.uid}');

        // Check subscription status and sync to Firestore
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

  Future<List<Map<String, dynamic>>> _getAnimeDataForGenre(
      String genreId) async {
    try {
      // Fetch anime ranking data
      final rankingSnapshot =
      await _database.ref().child('anime_rankings').get();

      Map<String, int> rankings = {};
      if (rankingSnapshot.value != null) {
        final data = rankingSnapshot.value as Map;
        data.forEach((animeTitle, value) {
          if (value is int) {
            rankings[animeTitle.toString()] = value;
          }
        });
      }

      // Fetch anime data from Firestore
      final animeSnapshot = await firestore
          .collection('animes')
          .where('genres', arrayContains: genreId)
          .get();

      final animes = animeSnapshot.docs.map((doc) {
        final data = doc.data();
        final title = data['name'] as String? ?? '';
        return {
          'id': doc.id,
          'name': title,
          'imageUrl': data['imageUrl'] as String? ?? '',
          'ranking': rankings[title] ?? 0,
        };
      }).toList();

      // Sort by ranking count
      animes.sort((a, b) {
        final rankingA = a['ranking'] as int;
        final rankingB = b['ranking'] as int;
        return rankingB.compareTo(rankingA);
      });

      // Return top 10 animes
      return animes.take(10).toList();
    } catch (e) {
      print('Error fetching anime data for genre $genreId: $e');
      return [];
    }
  }

  Future<void> _fetchAnimesByGenre(String genreId) async {
    try {
      // Fetch anime ranking data
      final rankingSnapshot =
      await _database.ref().child('anime_rankings').get();

      Map<String, int> rankings = {};
      if (rankingSnapshot.value != null) {
        final data = rankingSnapshot.value as Map;
        data.forEach((animeTitle, value) {
          if (value is int) {
            // Use title as key
            rankings[animeTitle.toString()] = value;
          }
        });
      }

      // Fetch anime data from Firestore
      final animeSnapshot = await firestore
          .collection('animes')
          .where('genres', arrayContains: genreId)
          .get();

      final animes = animeSnapshot.docs.map((doc) {
        final data = doc.data();
        final title = data['name'] as String? ?? '';
        return {
          'id': doc.id,
          'name': title,
          'imageUrl': data['imageUrl'] as String? ?? '',
          'ranking': rankings[title] ?? 0, // Search by title
        };
      }).toList();

      // Debug output (check fetched data)
      print('Rankings before sort:');
      animes.forEach((anime) {
        print('${anime['name']}: ${anime['ranking']}');
      });

      // Sort by ranking count
      animes.sort((a, b) {
        final rankingA = a['ranking'] as int;
        final rankingB = b['ranking'] as int;
        return rankingB.compareTo(rankingA);
      });

      // Get top 10 only
      final topAnimes = animes.take(10).toList();

      if (mounted) {
        setState(() {
          _animeList = topAnimes;
          _isAnimesLoaded = true;
        });
      }

      // Debug log (check after sorting)
      print('Sorted animes:');
      topAnimes.forEach((anime) {
        print('${anime['name']}: ${anime['ranking']}');
      });
    } catch (e, stackTrace) {
      print('Error fetching animes and rankings: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _animeList = [];
          _isAnimesLoaded = true;
        });
      }
    }
  }

  // Video related methods
  Future<void> _initializeVideo() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final weekStart = now.subtract(Duration(
        days: now.weekday - 1,
        hours: now.hour,
        minutes: now.minute,
        seconds: now.second,
        milliseconds: now.millisecond,
        microseconds: now.microsecond,
      ));

      final videoDoc = await firestore
          .collection('weeklyVideos')
          .orderBy('weekOf', descending: true)
          .limit(1)
          .get();

      if (videoDoc.docs.isNotEmpty) {
        final videoData = videoDoc.docs.first.data();
        final videoUrl = videoData['url'] as String;
        final videoWeekOf = videoData['weekOf'] as String;
        final videoDocId = videoDoc.docs.first.id;

        final viewerDoc = await firestore
            .collection('weeklyVideos')
            .doc(videoDocId)
            .collection('viewers')
            .doc(user.uid)
            .get();

        if (viewerDoc.exists) {
          print('User has already started watching this video');
          return;
        }

        final videoWeekStart = DateTime.parse(videoWeekOf);
        if (videoWeekStart.isAtSameMomentAs(weekStart)) {
          _videoController = VideoPlayerController.network(
            videoUrl,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );

          await _videoController!.initialize();

          final difference = now.difference(weekStart);
          if (difference.inSeconds > 0) {
            await _videoController!
                .seekTo(Duration(seconds: difference.inSeconds));
          }

          _videoController!.addListener(() {
            if (_videoController!.value.isPlaying && !_hasStartedPlaying) {
              _trackVideoStart(videoDocId);
              _hasStartedPlaying = true;
            }
            _onVideoFinished();
          });

          await _videoController!.play();

          if (mounted) {
            setState(() {
              _showVideo = true;
            });
          }
        }
      }
    } catch (e) {
      print('Error initializing video: $e');
    }
  }

  Future<void> _trackVideoStart(String videoDocId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await firestore
          .collection('weeklyVideos')
          .doc(videoDocId)
          .collection('viewers')
          .doc(user.uid)
          .set({
        'startedAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'userEmail': user.email,
      });
    } catch (e) {
      print('Error tracking video start: $e');
    }
  }

  void _onVideoFinished() {
    if (_videoController?.value.position == _videoController?.value.duration) {
      _markVideoAsWatched();
      setState(() {
        _showVideo = false;
      });
    }
  }

  Future<void> _markVideoAsWatched() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartStr = weekStart.toString().split(' ')[0];

      await firestore.collection('users').doc(user.uid).update({
        'videoHistory.$weekStartStr': true,
      });
    } catch (e) {
      print('Error marking video as watched: $e');
    }
  }

  // Event related methods
  Future<void> _checkActiveEvents() async {
    try {
      final eventSnapshot = await firestore.collection('events').get();
      final activeEvents = eventSnapshot.docs
          .where((doc) => doc.data()['isEnabled'] == true)
          .map((doc) => doc.data()['title'] as String)
          .toList();

      setState(() {
        _activeEvents = activeEvents;
        _isEventsLoaded = true;
      });
    } catch (e) {
      print('Error fetching events: $e');
      setState(() {
        _activeEvents = [];
        _isEventsLoaded = true;
      });
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

  // Genre related methods
  Future<void> _fetchGenreData() async {
    try {
      final genreSnapshot = await firestore
          .collection('genres')
          .orderBy('managementCode', descending: false)
          .get();

      final genres = genreSnapshot.docs.map((doc) {
        final data = doc.data();
        // Find genre with managementCode "A"
        if (data['managementCode'] == 'A') {
          _expandedGenreIds.add(doc.id); // Add ID to set
          _currentGenreName = data['name'] as String? ?? '';
          _fetchAnimesByGenre(doc.id); // Fetch anime data
        }
        return {
          'id': doc.id,
          'name': data['name'] as String? ?? '',
          'imageUrl': data['imageUrl'] as String? ?? '',
          'sub_imageUrl': data['sub_imageUrl'] as String? ?? '',
          'managementCode': data['managementCode'] as String? ?? '',
        };
      }).toList();

      setState(() {
        _genreData = genres;
        _isFlipped = List<bool>.filled(genres.length, false);
        _currentFlipIndex = 0;
        _isGenresLoaded = true;
      });
    } catch (e) {
      print('Error fetching genre data: $e');
      setState(() {
        _genreData = [];
        _isFlipped = [];
        _currentFlipIndex = 0;
        _isGenresLoaded = true;
      });
    }
  }

  void _startFlipAnimation() {
    _isAnimating = true;
    _currentFlipIndex = 0;

    if (_isFlipped.isNotEmpty) {
      setState(() {
        _isFlipped = List<bool>.filled(_isFlipped.length, false);
      });
    }

    _flipTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      if (!mounted) return;
      if (_genreData.isEmpty || _isFlipped.isEmpty) return;

      setState(() {
        if (_currentFlipIndex < _isFlipped.length) {
          if (!_isFlipped[_currentFlipIndex]) {
            _isFlipped[_currentFlipIndex] = true;
          }
          _currentFlipIndex++;
        }

        if (_currentFlipIndex >= _isFlipped.length) {
          timer.cancel();
          _isAnimating = false;

          _restartTimer = Timer(Duration(seconds: 30), () {
            if (mounted) {
              setState(() {
                _isFlipped = List<bool>.filled(_isFlipped.length, false);
              });
              _startFlipAnimation();
            }
          });
        }
      });
    });
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    if (date is String) {
      try {
        final DateTime dateTime =
        DateTime.parse(date.replaceAll('T00:00:00.000', ''));
        return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
      } catch (e) {
        return '';
      }
    }
    if (date is Timestamp) {
      final DateTime dateTime = date.toDate();
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
    return '';
  }

  Color _getRankingColor(int index) {
    switch (index) {
      case 0:
        return Color(0xFFFFD700); // Gold
      case 1:
        return Color(0xFFC0C0C0); // Silver
      case 2:
        return Color(0xFFCD7F32); // Bronze
      default:
        return Color(0xFF1E88E5); // Others
    }
  }

  IconData _getRankingIcon(int index) {
    switch (index) {
      case 0:
        return Icons.workspace_premium;
      case 1:
      case 2:
        return Icons.military_tech;
      default:
        return Icons.star;
    }
  }

  Widget _buildAnimeCard(Map<String, dynamic> anime, int index) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnimeDetailsPage(
              animeName: anime['name'] ?? 'Unknown Title',
            ),
          ),
        );
      },
      child: Container(
        width: 200,
        margin: EdgeInsets.only(right: 12.0),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Hero(
                      tag: 'anime_image_${anime['id']}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: anime['imageUrl'] ?? '',
                          width: 200,
                          height: 120,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: Icon(Icons.movie, color: Colors.grey[400]),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getRankingColor(index),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getRankingIcon(index),
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Rank ${index + 1}',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Center(
                    child: Text(
                      anime['name'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                Text(
                  'Genre & Event Information',
                  style: TextStyle(
                    color: Color(0xFF00008b),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Premium subscription status indicator
                if (_isSubscriptionActive)
                  Container(
                    margin: EdgeInsets.only(left: 8),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          body: Container(
            color: Colors.white,
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isEventsLoaded)
                      Container(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_activeEvents.isNotEmpty)
                      _buildEventSection(),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16.0,
                        bottom: 8.0,
                      ),
                      child: Text(
                        '■Genre Rankings',
                        style: TextStyle(
                          color: Color(0xFF00008b),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (!_isGenresLoaded)
                      Center(child: CircularProgressIndicator())
                    else
                      _buildGenreList(),
                    SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ),
        // 【修正】サブスクリプション状態をチェックしてビデオオーバーレイを表示
        if (_showVideo && _videoController != null && !_isSubscriptionActive)
          _buildVideoOverlay(),
      ],
    );
  }

  Widget _buildGenreList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: _genreData.length,
      separatorBuilder: (context, index) => Divider(
        color: Colors.grey[300],
        height: 1,
      ),
      itemBuilder: (context, index) {
        final genre = _genreData[index];
        final genreId = genre['id'] as String;

        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: _expandedGenreIds.contains(genreId),
              tilePadding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              title: Text(
                genre['name'] ?? '',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF00008b),
                  fontWeight: FontWeight.w500,
                ),
              ),
              iconColor: Color(0xFF00008b),
              collapsedIconColor: Color(0xFF00008b),
              onExpansionChanged: (expanded) {
                setState(() {
                  if (expanded) {
                    _expandedGenreIds.add(genreId);
                    _fetchAnimesByGenre(genreId);
                  } else {
                    _expandedGenreIds.remove(genreId);
                  }
                });
              },
              children: [
                if (_expandedGenreIds.contains(genreId))
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _getAnimeDataForGenre(genreId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          height: 160,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Container(
                          height: 160,
                          child: Center(
                            child: Text('No anime in this genre'),
                          ),
                        );
                      }

                      final animeList = snapshot.data!;
                      return Column(
                        children: [
                          Container(
                            height: 160,
                            margin: EdgeInsets.only(bottom: 8.0),
                            child: Stack(
                              children: [
                                ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding:
                                  EdgeInsets.symmetric(horizontal: 16.0),
                                  itemCount: animeList.length,
                                  itemBuilder: (context, animeIndex) {
                                    final anime = animeList[animeIndex];
                                    return _buildAnimeCard(anime, animeIndex);
                                  },
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 24,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Colors.white.withOpacity(0.0),
                                          Colors.white.withOpacity(0.8),
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.chevron_right,
                                        color: Colors.grey[400],
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.swipe,
                                  size: 16,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Swipe horizontally to see more',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventSection() {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: Text(
              '■ Event Information',
              style: TextStyle(
                color: Color(0xFF00008b),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Container(
            height: 150,
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              scrollDirection: Axis.horizontal,
              itemCount: _eventData.length,
              itemBuilder: (context, index) =>
                  _buildEventCard(_eventData[index]),
            ),
          ),
          const SizedBox(height: 20.0),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    return GestureDetector(
      onTap: () {
        try {
          if (event['startDate'] == null) {
            print('Error: startDate is null');
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventMoreScreen(
                eventTitle: event['title']?.toString() ?? 'Untitled Event',
                startDate: event['startDate']?.toString() ?? '',
                htmlContent:
                event['htmlContent']?.toString() ?? 'No content available',
              ),
            ),
          );
        } catch (e) {
          print('Error navigating to event details: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to display event details'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Container(
        width: 280,
        margin: EdgeInsets.only(right: 16.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
              child: CachedNetworkImage(
                imageUrl: event['imageUrl']?.toString() ?? '',
                width: 140,
                height: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: Icon(Icons.event, size: 50, color: Colors.grey[400]),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      event['title'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    if (event['startDate'] != null && event['endDate'] != null)
                      Container(
                        width: double.infinity,
                        child: Text(
                          '${_formatDate(event['startDate'])} - ${_formatDate(event['endDate'])}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.visible,
                          softWrap: true,
                        ),
                      ),
                    SizedBox(height: 8),
                    if (event['description'] != null)
                      Text(
                        event['description'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[800],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.8),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: MediaQuery.of(context).size.width * 0.9,
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(
                    color: Colors.white,
                    width: 2.0,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: GestureDetector(
                  onTap: () {
                    _markVideoAsWatched();
                    setState(() {
                      _showVideo = false;
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.close,
                        color: Colors.black,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}