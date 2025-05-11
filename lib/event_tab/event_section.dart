import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'dart:developer' as developer;
import 'event_more_movie.dart';

class EventSection extends StatelessWidget {
  const EventSection({Key? key}) : super(key: key);

  static final loadingWidget = LoadingAnimationWidget.discreteCircle(
    color: Colors.blue,
    size: 50,
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('anime_event_info').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: loadingWidget);
        }

        if (snapshot.hasError) {
          return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('イベント情報がありません'));
        }

        final events = snapshot.data!.docs;
        developer.log('取得したイベント数: ${events.length}');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // セクションタイトル
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '注目のイベント',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'もっと見る',
                      style: TextStyle(
                        color: const Color(0xFF00bfff),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // 横2列
                childAspectRatio: 0.6, // カードの縦横比
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index].data() as Map<String, dynamic>;

                // メディア情報を取得
                String? mediaUrl;
                String mediaType = 'image'; // デフォルトタイプ

                if (event['eventTopMediaType'] != null) {
                  mediaType = event['eventTopMediaType'].toString().toLowerCase();
                  developer.log('イベント[$index] メディアタイプ: $mediaType');
                }

                // URLの取得ロジック
                if (event['eventTopMediaUrl'] != null) {
                  mediaUrl = event['eventTopMediaUrl'];
                  developer.log('イベント[$index] TopMediaURL: $mediaUrl');
                }
                // eventPosts内のURLを確認
                else if (event['eventPosts'] != null && (event['eventPosts'] as List).isNotEmpty) {
                  final firstPost = (event['eventPosts'] as List).first;
                  if (firstPost is Map && firstPost['url'] != null) {
                    mediaUrl = firstPost['url'];
                    developer.log('イベント[$index] PostURL: $mediaUrl');
                  }
                }

                // サンプルURLのパターンが確認できたため、必要に応じてURLを検証・修正
                if (mediaUrl != null) {
                  // URLが適切なフォーマットかどうかを確認
                  final bool isValidStorageUrl = mediaUrl.contains('firebasestorage.googleapis.com') &&
                      mediaUrl.contains('alt=media');
                  if (!isValidStorageUrl) {
                    developer.log('イベント[$index] 無効なURL形式: $mediaUrl');
                  }
                }

                final eventName = event['eventName'] ?? 'イベント名なし';
                developer.log('イベント[$index] 名前: $eventName');

                // eventMoreInfoを取得
                final eventMoreInfo = event['eventMoreInfo'];
                developer.log('イベント[$index] 説明: $eventMoreInfo');

                final eventInfo = event['eventInfo'];
                developer.log('イベント[$index] イベント名: $eventInfo');

                final eventNumber = event['eventNumber'] ?? 'default_id';

                developer.log('イベント[$index] ID: ${event['eventNumber'] ?? "IDなし"}');

                if (event['eventNumber'] == null) {
                  developer.log('Warning: イベント[$index] にIDがありません');
                  // 必要に応じて対処（例: このイベントはスキップするなど）
                }

                return VideoCard(
                  eventName: eventName,
                  mediaUrl: mediaUrl,
                  mediaType: mediaType,
                  index: index,
                  onTap: () {
                    // 触覚フィードバックを追加
                    HapticFeedback.mediumImpact();

                    // EventMoreMovieへデータを渡して遷移
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EventMoreMovie(
                          eventName: eventName,
                          mediaUrl: mediaUrl,
                          mediaType: mediaType,
                          eventMoreInfo: eventMoreInfo,
                          eventInfo: eventInfo,
                          eventId: eventNumber ?? 'unknown_event_${DateTime.now().millisecondsSinceEpoch}', // null の場合の対処
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class VideoCard extends StatefulWidget {
  final String eventName;
  final String? mediaUrl;
  final String mediaType;
  final int index;
  final VoidCallback onTap;  // タップ時のコールバック追加

  const VideoCard({
    Key? key,
    required this.eventName,
    this.mediaUrl,
    required this.mediaType,
    required this.index,
    required this.onTap,  // 必須パラメータに変更
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
      // URLをそのまま使用
      final url = widget.mediaUrl!;
      developer.log('動画初期化開始: $url');

      // URLフォーマットのデバッグ情報
      developer.log('URL分析: パス部分=${Uri.parse(url).path}, クエリ部分=${Uri.parse(url).query}');

      // VideoPlayerControllerを初期化
      _controller = VideoPlayerController.network(
          url,
          // より詳細なエラー情報を取得するためのオプション
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          // HTTPヘッダーを追加してキャッシュを防止
          httpHeaders: {'Cache-Control': 'no-cache'}
      );

      // 初期化を試みる（タイムアウト付き）
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

      // 初期化成功
      if (initialized && _controller!.value.isInitialized) {
        developer.log('動画初期化成功: 長さ=${_controller!.value.duration.inSeconds}秒');

        // ボリュームをミュート
        _controller!.setVolume(0.0);
        // ループ再生を有効化
        _controller!.setLooping(true);
        // 再生開始
        await _controller!.play();

        // 3秒ループのリスナーを設定
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

      // エラーの詳細ログ
      if (_controller != null) {
        developer.log('コントローラー状態: isInitialized=${_controller!.value.isInitialized}, '
            'isPlaying=${_controller!.value.isPlaying}, '
            'hasError=${_controller!.value.hasError}');
      }

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

      // 3秒を超えたら先頭に戻す
      if (position.inSeconds >= 3) {
        _controller!.seekTo(Duration.zero).then((_) {
          // シーク成功後に再生を確認
          if (!_controller!.value.isPlaying) {
            _controller!.play();
          }
        }).catchError((error) {
          developer.log('シークエラー: $error');
        });
      }

      // エラーが発生した場合のチェック
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
      onTap: widget.onTap,  // タップ時のコールバックを追加
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // メディアコンテンツ
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
                  // 動画プレイアイコン
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

            // イベント名
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
                      Icon(
                        Icons.event,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(
                        width: 4,
                      ),
                      Text(
                        'ユーザ名をここに表示',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.favorite_border,
                        size: 16,
                        color: Colors.pink[300],
                      ),
                      const Spacer(),
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
    // URLがない場合
    if (widget.mediaUrl == null) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      );
    }

    // 動画の場合
    if (widget.mediaType == 'video') {
      // エラーが発生した場合
      if (_hasError) {
        return Container(
          color: Colors.grey[800],
          child: Stack(
            children: [
              // バックグラウンドの動画アイコン
              const Center(
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

              // 再試行ボタン（開発中のみ表示、デバッグ目的）
              if (false) // 本番では非表示
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: InkWell(
                    onTap: () {
                      // コントローラーを再初期化
                      if (mounted) {
                        setState(() {
                          _hasError = false;
                          _isInitialized = false;
                          _controller?.dispose();
                          _controller = null;
                          _initializeVideo();
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.refresh,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }

      // 初期化中
      if (!_isInitialized || _controller == null) {
        return Container(
          color: Colors.black,
          child: Center(child: EventSection.loadingWidget),
        );
      }

      // 初期化完了、再生中
      return Container(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
        ),
      );
    }
    // 画像の場合
    else {
      return CachedNetworkImage(
        imageUrl: widget.mediaUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[300],
          child: Center(child: EventSection.loadingWidget),
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