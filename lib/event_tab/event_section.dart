import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'dart:developer' as developer;
import 'event_more_movie.dart';

class EventSection extends StatefulWidget {
  const EventSection({Key? key}) : super(key: key);

  @override
  State<EventSection> createState() => _EventSectionState();
}

class _EventSectionState extends State<EventSection> {
  static final loadingWidget = LoadingAnimationWidget.discreteCircle(
    color: Colors.blue,
    size: 50,
  );

  final ScrollController _scrollController = ScrollController();
  final List<DocumentSnapshot> _events = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isInitialLoad = true;
  static const int _pageSize = 10; // 1回で取得するアイテム数

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      // スクロール位置が80%に達したら次のデータを読み込み
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.8) {
        if (!_isLoading && _hasMore) {
          _loadMoreData();
        }
      }
    });
  }

  Future<void> _loadInitialData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _isInitialLoad = true;
    });

    try {
      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('anime_event_info')
          .orderBy('eventNumber', descending: true) // ソート順を指定
          .limit(_pageSize)
          .get();

      developer.log('初回データ取得: ${querySnapshot.docs.length}件');

      setState(() {
        _events.clear();
        _events.addAll(querySnapshot.docs);
        _lastDocument = querySnapshot.docs.isNotEmpty
            ? querySnapshot.docs.last
            : null;
        _hasMore = querySnapshot.docs.length == _pageSize;
        _isLoading = false;
        _isInitialLoad = false;
      });
    } catch (e) {
      developer.log('初回データ取得エラー: $e');
      setState(() {
        _isLoading = false;
        _isInitialLoad = false;
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoading || !_hasMore || _lastDocument == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('anime_event_info')
          .orderBy('eventNumber', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize)
          .get();

      developer.log('追加データ取得: ${querySnapshot.docs.length}件');

      setState(() {
        _events.addAll(querySnapshot.docs);
        _lastDocument = querySnapshot.docs.isNotEmpty
            ? querySnapshot.docs.last
            : _lastDocument;
        _hasMore = querySnapshot.docs.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      developer.log('追加データ取得エラー: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    developer.log('データリフレッシュ開始');
    setState(() {
      _events.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    await _loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    // 初回読み込み中の場合
    if (_isInitialLoad && _events.isEmpty) {
      return Center(child: loadingWidget);
    }

    // データが空の場合
    if (!_isInitialLoad && _events.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('イベント情報がありません'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // セクションタイトル
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '注目のイベント',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // 無限スクロール対応GridView
          Expanded(
            child: GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _events.length + (_isLoading ? 2 : 0), // ローディング用のアイテムを追加
              itemBuilder: (context, index) {
                // ローディング表示
                if (index >= _events.length) {
                  return Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: LoadingAnimationWidget.discreteCircle(
                          color: Colors.blue,
                          size: 30,
                        ),
                      ),
                    ),
                  );
                }

                final event = _events[index].data() as Map<String, dynamic>;

                // メディア情報を取得
                String? mediaUrl;
                String mediaType = 'image';

                if (event['eventTopMediaType'] != null) {
                  mediaType = event['eventTopMediaType'].toString().toLowerCase();
                  developer.log('イベント[$index] メディアタイプ: $mediaType');
                }

                if (event['eventTopMediaUrl'] != null) {
                  mediaUrl = event['eventTopMediaUrl'];
                  developer.log('イベント[$index] TopMediaURL: $mediaUrl');
                } else if (event['eventPosts'] != null &&
                    (event['eventPosts'] as List).isNotEmpty) {
                  final firstPost = (event['eventPosts'] as List).first;
                  if (firstPost is Map && firstPost['url'] != null) {
                    mediaUrl = firstPost['url'];
                    developer.log('イベント[$index] PostURL: $mediaUrl');
                  }
                }

                if (mediaUrl != null) {
                  final bool isValidStorageUrl =
                      mediaUrl.contains('firebasestorage.googleapis.com') &&
                          mediaUrl.contains('alt=media');
                  if (!isValidStorageUrl) {
                    developer.log('イベント[$index] 無効なURL形式: $mediaUrl');
                  }
                }

                final eventName = event['eventName'] ?? 'イベント名なし';
                final eventMoreInfo = event['eventMoreInfo'];
                final eventInfo = event['eventInfo'];
                final eventNumber = event['eventNumber'] ?? 'default_id';

                return VideoCard(
                  eventName: eventName,
                  mediaUrl: mediaUrl,
                  mediaType: mediaType,
                  index: index,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EventMoreMovie(
                          eventName: eventName,
                          mediaUrl: mediaUrl,
                          mediaType: mediaType,
                          eventMoreInfo: eventMoreInfo,
                          eventInfo: eventInfo,
                          eventId: eventNumber ??
                              'unknown_event_${DateTime.now().millisecondsSinceEpoch}',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // 下部のローディング表示
          if (_isLoading && !_isInitialLoad)
            Container(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LoadingAnimationWidget.horizontalRotatingDots(
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '読み込み中...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// VideoCardクラスは変更なし（元のコードをそのまま使用）
class VideoCard extends StatefulWidget {
  final String eventName;
  final String? mediaUrl;
  final String mediaType;
  final int index;
  final VoidCallback onTap;

  const VideoCard({
    Key? key,
    required this.eventName,
    this.mediaUrl,
    required this.mediaType,
    required this.index,
    required this.onTap,
  }) : super(key: key);

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (widget.mediaUrl != null && widget.mediaType == 'video') {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    try {
      final url = widget.mediaUrl!;
      developer.log('動画初期化開始: $url');

      _controller = VideoPlayerController.network(
          url,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          httpHeaders: {'Cache-Control': 'no-cache'}
      );

      bool initialized = false;
      try {
        await _controller!.initialize().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              developer.log('動画初期化: タイムアウト');
              throw Exception('初期化タイムアウト');
            }
        );
        initialized = true;
      } catch (timeoutError) {
        developer.log('初期化タイムアウトエラー: $timeoutError');
        throw timeoutError;
      }

      if (initialized && _controller!.value.isInitialized) {
        developer.log('動画初期化成功: 長さ=${_controller!.value.duration.inSeconds}秒');

        _controller!.setVolume(0.0);
        _controller!.setLooping(true);
        await _controller!.play();
        _controller!.addListener(_checkPosition);

        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      } else {
        throw Exception('コントローラーが正しく初期化されませんでした');
      }
    } catch (e) {
      developer.log('動画初期化エラー: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _checkPosition() {
    if (_controller != null && _controller!.value.isInitialized) {
      final position = _controller!.value.position;
      if (position.inSeconds >= 3) {
        _controller!.seekTo(Duration.zero).then((_) {
          if (!_controller!.value.isPlaying) {
            _controller!.play();
          }
        }).catchError((error) {
          developer.log('シークエラー: $error');
        });
      }

      if (_controller!.value.hasError && !_hasError) {
        developer.log('再生中にエラーが発生: ${_controller!.value.errorDescription}');
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_checkPosition);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                    child: _buildMediaContent(),
                  ),
                  if (widget.mediaType == 'video')
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.eventName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      // Icon(
                      //   Icons.event,
                      //   size: 14,
                      //   color: Colors.grey[600],
                      // ),
                      // const SizedBox(width: 4),
                      // Text(
                      //   'ユーザ名をここに表示',
                      //   style: TextStyle(
                      //     fontSize: 12,
                      //     color: Colors.grey[600],
                      //   ),
                      // ),
                      // const Spacer(),
                      Icon(
                        Icons.favorite_border,
                        size: 16,
                        color: Colors.pink[300],
                      ),
                      Text(
                        '100',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent() {
    if (widget.mediaUrl == null) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      );
    }

    if (widget.mediaType == 'video') {
      if (_hasError) {
        return Container(
          color: Colors.grey[800],
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam, color: Colors.white70, size: 40),
                SizedBox(height: 8),
                Text(
                  "動画プレビュー",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }

      if (!_isInitialized || _controller == null) {
        return Container(
          color: Colors.black,
          child: Center(
              child: LoadingAnimationWidget.discreteCircle(
                color: Colors.blue,
                size: 50,
              )
          ),
        );
      }

      return Container(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
        ),
      );
    } else {
      return CachedNetworkImage(
        imageUrl: widget.mediaUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[300],
          child: Center(
              child: LoadingAnimationWidget.discreteCircle(
                color: Colors.blue,
                size: 50,
              )
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      );
    }
  }
}