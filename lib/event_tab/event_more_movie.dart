import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:developer' as developer;
// Firebase のインポート
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
//他クラスのインポート
import 'package:parts/src/emoji_list.dart';

// 弾幕コメントのデータモデル
class DanmakuCommentModel {
  final String content;
  final String displayName;
  final double horizontalPosition; // 水平位置
  final double speed;

  DanmakuCommentModel({
    required this.content,
    required this.displayName,
    required this.horizontalPosition,
    required this.speed,
  });
}

// コメントリスト表示用のデータモデル（新規追加）
class CommentModel {
  final String id;
  final String content;
  final String displayName;
  final String userId;
  final DateTime timestamp;
  final String? userPhotoUrl;

  CommentModel({
    required this.id,
    required this.content,
    required this.displayName,
    required this.userId,
    required this.timestamp,
    this.userPhotoUrl,
  });

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommentModel(
      id: doc.id,
      content: data['content'] ?? '',
      displayName: data['displayName'] ?? '匿名ユーザー',
      userId: data['userId'] ?? '',
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      userPhotoUrl: data['userPhotoUrl'],
    );
  }
}

class EventMoreMovie extends StatefulWidget {
  final String eventName;
  final String? mediaUrl;
  final String mediaType;
  final String? eventMoreInfo;
  final String? eventInfo;
  final String eventId;

  const EventMoreMovie({
    Key? key,
    required this.eventName,
    required this.mediaUrl,
    required this.mediaType,
    this.eventMoreInfo,
    this.eventInfo,
    required this.eventId,
  }) : super(key: key);

  @override
  State<EventMoreMovie> createState() => _EventMoreMovieState();
}
class _EventMoreMovieState extends State<EventMoreMovie> with TickerProviderStateMixin {
  bool isFollowing = false;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _hasVideoError = false;
  bool _showFullText = false; // この変数を利用して「続きを読む」の状態を管理
  bool _isPlaying = true;
  bool _danmakuCompleted = false;

  // リストが等しいかどうか比較する補助メソッド
  bool _areListsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  TextEditingController _commentController = TextEditingController();

  final ScrollController _commentsScrollController = ScrollController();

  // 弾幕のコメントを管理するリスト
  List<DanmakuCommentModel> _danmakuComments = [];
  List<String> _danmakuCommentIds = [];

  // Firebase のインスタンス
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 弾幕アニメーション用のコントローラー
  late AnimationController _danmakuController;

  // 表示する絵文字のリスト（ランダムに選ばれる）
  late List<String> _displayEmojis;

  @override
  void initState() {
    super.initState();

    // 弾幕アニメーション用のコントローラー初期化
    _danmakuController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10), // 速度を調整
    );
    _danmakuController.forward();
    _danmakuController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _danmakuCompleted = true;
        });
      }
    });
    if (widget.mediaType == 'video' && widget.mediaUrl != null) {
      _initializeVideo();
    }

    // Firestoreからコメントを取得して弾幕リストに追加
    _setupCommentStream();

    // 最初のランダム絵文字を生成
    _generateRandomEmojis();
  }
  // コメント一覧を表示するボトムシートを修正
  void _showCommentsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // ハンドル
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white54,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),

                // タイトル
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'コメント一覧',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),

                // イベント情報の全文表示部分（新規追加）
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.eventInfo ?? "イベント情報",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.eventMoreInfo ?? "詳細情報がありません",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // コメント入力フォーム
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.grey[800],
                        child: const Icon(Icons.person, color: Colors.white70),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'コメントを入力...',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                            filled: true,
                            fillColor: Colors.grey[800],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.blue,
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white, size: 18),
                          onPressed: () {
                            if (_commentController.text.isNotEmpty) {
                              _submitComment(_commentController.text);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // 区切り線
                Divider(color: Colors.grey[700], height: 1),

                // コメントリスト
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('anime_event_info')
                        .doc(widget.eventId)
                        .collection('comment')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: LoadingAnimationWidget.staggeredDotsWave(
                            color: Colors.white,
                            size: 40,
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'エラーが発生しました',
                            style: TextStyle(color: Colors.white.withOpacity(0.7)),
                          ),
                        );
                      }

                      final comments = snapshot.data?.docs ?? [];

                      if (comments.isEmpty) {
                        return Center(
                          child: Text(
                            'コメントはまだありません',
                            style: TextStyle(color: Colors.white.withOpacity(0.7)),
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: comments.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final comment = CommentModel.fromFirestore(comments[index]);

                          // 時間を整形
                          String timeAgo = _getTimeAgo(comment.timestamp);

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ユーザーアバター
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.grey[800],
                                  backgroundImage: comment.userPhotoUrl != null
                                      ? NetworkImage(comment.userPhotoUrl!)
                                      : null,
                                  child: comment.userPhotoUrl == null
                                      ? Text(
                                    comment.displayName.isNotEmpty
                                        ? comment.displayName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(color: Colors.white),
                                  )
                                      : null,
                                ),
                                const SizedBox(width: 12),

                                // コメント内容
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            comment.displayName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            timeAgo,
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.6),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        comment.content,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.favorite_border,
                                            color: Colors.white.withOpacity(0.6),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'いいね',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.6),
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Icon(
                                            Icons.reply,
                                            color: Colors.white.withOpacity(0.6),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '返信',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.6),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  // 時間の経過を「〜分前」「〜時間前」などの形式で返す関数を追加
  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'たった今';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}時間前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}日前';
    } else {
      return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
    }
  }

  // ランダムな絵文字を生成するメソッド
  void _generateRandomEmojis() {
    // 絵文字リストをシャッフル
    final shuffledList = List<String>.from(EmojiListData.emojiList)
      ..shuffle(math.Random());
    // 最初の10個を取得
    _displayEmojis = shuffledList.take(10).toList();
  }

  // Firestoreからのコメントストリームをセットアップ
  void _setupCommentStream() {
    _firestore
        .collection('anime_event_info')
        .doc(widget.eventId)
        .collection('comment')
        .orderBy('timestamp', descending: true)
        .limit(5) // 最新の5つのコメントに変更
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      final comments = snapshot.docs;
      if (comments.isEmpty) return; // コメントがない場合は何もしない

      // 前回と同じコメントか確認するためにIDリストを比較
      final List<String> newCommentIds = comments.map((doc) => doc.id).toList();
      final List<String> currentCommentIds = _danmakuCommentIds; // 新しく追加する変数

      // コメントが変わっていなければ処理しない（無限リピート防止）
      bool hasNewComments = !_areListsEqual(newCommentIds, currentCommentIds);
      if (!hasNewComments) return;

      // 新しいコメントIDリストを保存
      _danmakuCommentIds = newCommentIds;

      List<DanmakuCommentModel> newComments = [];

      // 左側に配置するため、固定の水平位置を使用
      final double fixedHorizontalPosition = 0.25; // 画面左側の固定位置（25%位置）

      for (int i = 0; i < comments.length; i++) {
        final commentData = comments[i].data();
        final content = commentData['content'] ?? '';
        final displayName = commentData['displayName'] ?? '匿名';

        // コメント間隔を狭くするため、初期オフセットを小さくする
        final double initialOffsetPercent = 0.08 * i; // 間隔を小さく調整（0.08間隔）

        newComments.add(DanmakuCommentModel(
          content: content,
          displayName: displayName,
          horizontalPosition: fixedHorizontalPosition,
          speed: 0.35 + (i * 0.03), // 速度差も小さくして集まりやすくする
        ));
      }

      setState(() {
        _danmakuComments = newComments;
        _danmakuCompleted = false; // 新しいコメントが来たらリセット

        // アニメーションをリセットして再開
        _danmakuController.reset();
        _danmakuController.forward();
      });
    });
  }

  // コメントをFirebaseに送信するメソッド
  Future<void> _submitComment(String commentText) async {
    if (commentText.isEmpty) return;

    try {
      // 現在のユーザーを取得
      User? currentUser = _auth.currentUser;

      if (currentUser == null) {
        _showToast('コメントを投稿するにはログインが必要です');
        return;
      }

      // コメントデータの作成
      Map<String, dynamic> commentData = {
        'content': commentText,
        'userId': currentUser.uid,
        'userEmail': currentUser.email,
        'displayName': currentUser.displayName ?? '匿名ユーザー',
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Firestoreに追加
      await _firestore
          .collection('anime_event_info')
          .doc(widget.eventId)
          .collection('comment')
          .add(commentData);

      _showToast('コメントを送信しました');
      _commentController.clear();
    } catch (e) {
      developer.log('コメント送信エラー: $e');
      _showToast('コメントの送信に失敗しました');
    }
  }
  // コメント入力用ボトムシートを表示
  void _showCommentBottomSheet() {
    // ボトムシートを表示する前に新しいランダム絵文字を生成
    _generateRandomEmojis();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery
                  .of(context)
                  .viewInsets
                  .bottom,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'コメントを入力...',
                            hintStyle: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          autofocus: true,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.white70),
                        onPressed: () {
                          if (_commentController.text.isNotEmpty) {
                            _submitComment(_commentController.text);
                          }
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 絵文字選択エリア - ランダムな絵文字を表示
                  Container(
                    height: 50,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _displayEmojis.map((emoji) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8.0),
                            child: GestureDetector(
                              onTap: () {
                                _commentController.text += emoji;
                              },
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildDanmakuComments() {
    // 弾幕が表示終了した場合、または動画が一時停止中の場合は弾幕を表示しない
    if (_danmakuCompleted || (widget.mediaType == 'video' && !_isPlaying && _isVideoInitialized)) {
      return const SizedBox.shrink(); // 何も表示しない
    }

    return AnimatedBuilder(
      animation: _danmakuController,
      builder: (context, child) {
        final double screenHeight = MediaQuery.of(context).size.height;
        final double commentHeight = 30; // おおよそのコメント高さ

        // 画面上部のフェードアウト開始位置（上から30%の位置）
        final double fadeOutStartY = screenHeight * 0.3;

        final widgets = _danmakuComments.asMap().entries.map((entry) {
          final int index = entry.key;
          final comment = entry.value;

          // 各コメントに初期オフセットを追加して異なる高さから開始（間隔を狭く）
          final double initialOffset = index * 0.08; // 間隔を小さく

          // アニメーションの進行度は0-1の範囲
          double rawPosition = _danmakuController.value;

          // 実際のY位置計算
          final double verticalProgress = rawPosition * comment.speed;

          // 垂直方向の位置計算（下から上へ移動）
          final double startY = screenHeight; // 画面下端から開始
          final double endY = commentHeight; // 上端近くまで移動

          // 現在のY位置を計算（下から上に移動）
          final double currentY = startY - (startY - endY) * verticalProgress;

          // 透明度計算 - 上部30%に入ったらフェードアウト
          double opacity = 1.0;
          if (currentY < fadeOutStartY) {
            // fadeOutStartYで1.0、endYで0.0になるよう計算
            opacity = (currentY - endY) / (fadeOutStartY - endY);
            opacity = opacity.clamp(0.0, 1.0);
          }

          // 完全に透明なら表示しない（パフォーマンス向上）
          if (opacity <= 0.01) {
            return const SizedBox.shrink();
          }

          // コメントが10文字を超える場合は省略して表示
          String displayText = comment.content;
          if (displayText.length > 10) {
            displayText = displayText.substring(0, 10) + '...';
          }

          return Positioned(
            left: MediaQuery.of(context).size.width * comment.horizontalPosition,
            top: currentY,
            child: Opacity(
              opacity: opacity,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white30, width: 0.5),
                ),
                child: Text(
                  displayText,  // 修正したテキストを表示
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList();

        return Stack(children: widgets);
      },
    );
  }
  // 動画の再生/一時停止を切り替えるメソッド
  void _togglePlayPause() {
    if (_videoController != null && _isVideoInitialized) {
      setState(() {
        if (_isPlaying) {
          _videoController!.pause();
          // 一時停止時に弾幕アニメーションも停止
          _danmakuController.stop();
        } else {
          _videoController!.play();
          // 再生時に弾幕アニメーションも再開
          if (_danmakuCompleted) {
            // 弾幕が完了していた場合は、最初から再開
            _danmakuController.reset();
            _danmakuController.forward();
            _danmakuCompleted = false; // 再生時に弾幕を再表示
          } else {
            // 途中だった場合は続きから再開
            _danmakuController.forward();
          }
        }
        _isPlaying = !_isPlaying;
      });
    }
  }
  // 動画のダウンロードと保存
  Future<void> _downloadAndSaveVideo() async {
    final url = widget.mediaUrl!;
    // ファイル名を生成
    final fileName = 'JapanAnimeMaps_video_${DateTime
        .now()
        .millisecondsSinceEpoch}.mp4';

    // 一時ディレクトリのパスを取得
    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/$fileName';

    // Dioを使ってファイルをダウンロード
    final dio = Dio();
    await dio.download(
      url,
      filePath,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          final progress = (received / total * 100).toStringAsFixed(0);
          developer.log('ダウンロード進捗: $progress%');
        }
      },
    );

    // ギャラリーに保存
    final result = await ImageGallerySaverPlus.saveFile(
      filePath,
      name: fileName,
    );

    developer.log('保存結果: $result');

    // 一時ファイルの削除
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  // 画像のダウンロードと保存
  Future<void> _downloadAndSaveImage() async {
    final url = widget.mediaUrl!;
    final fileName = 'JapanAnimeMaps_image_${DateTime
        .now()
        .millisecondsSinceEpoch}.jpg';

    // 一時ディレクトリのパスを取得
    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/$fileName';

    // Dioを使ってファイルをダウンロード
    final dio = Dio();
    await dio.download(
      url,
      filePath,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          final progress = (received / total * 100).toStringAsFixed(0);
          developer.log('ダウンロード進捗: $progress%');
        }
      },
    );

    // ギャラリーに保存
    final result = await ImageGallerySaverPlus.saveFile(
      filePath,
      name: fileName,
    );

    developer.log('保存結果: $result');

    // 一時ファイルの削除
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  // トーストメッセージを表示
  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  Future<void> _initializeVideo() async {
    try {
      final url = widget.mediaUrl!;
      developer.log('動画詳細画面: 動画初期化開始: $url');

      _videoController = VideoPlayerController.network(
          url,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          httpHeaders: {'Cache-Control': 'no-cache'}
      );

      // 初期化を試みる
      await _videoController!.initialize().timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            developer.log('動画詳細画面: 初期化タイムアウト');
            throw Exception('初期化タイムアウト');
          }
      );

      // 初期化成功
      if (_videoController!.value.isInitialized) {
        developer.log(
            '動画詳細画面: 初期化成功: 長さ=${_videoController!.value.duration
                .inSeconds}秒');

        // ミュートで再生
        _videoController!.setVolume(1.0);
        // ループ再生
        _videoController!.setLooping(true);
        // 再生開始
        await _videoController!.play();

        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
            _isPlaying = true; // 初期化時に再生中に設定
          });
        }
      } else {
        throw Exception('コントローラーが正しく初期化されませんでした');
      }
    } catch (e) {
      developer.log('動画詳細画面: 初期化エラー: $e');

      if (mounted) {
        setState(() {
          _hasVideoError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _commentController.dispose();
    _danmakuController.dispose();
    _commentsScrollController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // キーボードが表示されても画面をリサイズしない
      body: Stack(
        children: [
        // 背景動画/画像
        Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.black,
        ),
        child: _buildMediaContent(),
      ),

      // 弾幕コメント表示オーバーレイ
      _buildDanmakuComments(),

      // コンテンツオーバーレイ
      Column(
          children: [
      // トップアプリバー
      SafeArea(
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
                Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'もっと検索する',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text(
              '検索',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.white),
            onPressed: () {}, // シェアボトムシートを表示するメソッドを呼び出す
          ),
        ],
      ),
    ),
    ),

    // ビデオコンテンツ
    Expanded(
    child: Center(
    child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
    if (widget.mediaType == 'video' && _hasVideoError)
    GestureDetector(
    onTap: () {
    if (mounted) {
    setState(() {
    _hasVideoError = false;
    _isVideoInitialized = false;
    _videoController?.dispose();
    _videoController = null;
    _initializeVideo();
    });
    }
    },
    child: Container(
    width: 70,
    height: 70,
    decoration: BoxDecoration(
    color: Colors.white,
    shape: BoxShape.circle,
    boxShadow: [
    BoxShadow(
    color: Colors.black.withOpacity(0.3),
    blurRadius: 10,
    offset: const Offset(0, 3),
    ),
    ],
    ),
    child: const Icon(
    Icons.play_arrow,
    size: 50,
    color: Colors.black54,
    ),
    ),
    ),
    ],
    ),
    ),
    ),
            // 下部ユーザー情報・アクションエリア
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // プロフィール行、Firebase から取得した eventInfo を表示
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      widget.eventInfo ?? "エラー",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // eventMoreInfo を表示し、「続きを読む」ボタンを追加
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.eventMoreInfo ?? "説明がありません",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: _showCommentsBottomSheet, // コメント一覧ボトムシートを表示
                          child: const Text(
                            "続きを読む",
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // コメント入力欄（固定の入力欄）
                  GestureDetector(
                    onTap: () {
                      // コメント入力用のボトムシートを表示
                      _showCommentBottomSheet();
                    },
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Text(
                            '感想を伝えてみよう',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          // 固定された表示用の絵文字を3つランダムに選んで表示し、タップで直接入力できるようにする
                          GestureDetector(
                            onTap: () {
                              // 絵文字をタップしたときにボトムシートを表示し、テキストに絵文字を追加
                              _commentController.text = _displayEmojis.isNotEmpty ? _displayEmojis[0] : '🍋';
                              _showCommentBottomSheet();
                            },
                            child: Text(
                              _displayEmojis.isNotEmpty ? _displayEmojis[0] : '🍋',
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              // 絵文字をタップしたときにボトムシートを表示し、テキストに絵文字を追加
                              _commentController.text = _displayEmojis.length > 1 ? _displayEmojis[1] : '😚';
                              _showCommentBottomSheet();
                            },
                            child: Text(
                              _displayEmojis.length > 1 ? _displayEmojis[1] : '😚',
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              // 絵文字をタップしたときにボトムシートを表示し、テキストに絵文字を追加
                              _commentController.text = _displayEmojis.length > 2 ? _displayEmojis[2] : '😂';
                              _showCommentBottomSheet();
                            },
                            child: Text(
                              _displayEmojis.length > 2 ? _displayEmojis[2] : '😂',
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.bookmark_border,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '52 人が保存済み',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 24),
                        const Icon(
                          Icons.favorite_border,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '127',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: _showCommentsBottomSheet,
                          child: const Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StreamBuilder<QuerySnapshot>(
                          stream: _firestore
                              .collection('anime_event_info')
                              .doc(widget.eventId)
                              .collection('comment')
                              .snapshots(),
                          builder: (context, snapshot) {
                            final commentCount = snapshot.data?.docs.length ??
                                0;
                            return Text(
                              '$commentCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      height: 5,
                      width: 130,
                      margin: const EdgeInsets.only(
                        bottom: 8,
                        top: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
      ),
        ],
      ),
    );
  }
  // メディアコンテンツを表示するウィジェット
  Widget _buildMediaContent() {
    // メディアタイプが動画で、URLがある場合
    if (widget.mediaType == 'video' && widget.mediaUrl != null) {
      // エラーが発生した場合
      if (_hasVideoError) {
        return Container(
          color: Colors.black,
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.white70, size: 50),
                SizedBox(height: 16),
                Text(
                  "動画の読み込みに失敗しました",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  "タップして再試行",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        );
      }

      // 初期化中
      if (!_isVideoInitialized || _videoController == null) {
        return Container(
          color: Colors.black,
          child: Center(
            child: LoadingAnimationWidget.discreteCircle(
              color: Colors.white,
              size: 50,
            ),
          ),
        );
      }

      // 初期化完了、再生中またはポーズ中
      return GestureDetector(
        onTap: _togglePlayPause, // タップで再生/停止を切り替え
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 動画プレイヤー
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController!.value.size.width,
                height: _videoController!.value.size.height,
                child: VideoPlayer(_videoController!),
              ),
            ),
            // 一時停止中に表示する再生アイコン
            if (!_isPlaying)
              Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 40,
                ),
              ),
          ],
        ),
      );
    }
    // 画像の場合か、メディアURLがない場合
    else {
      return widget.mediaUrl != null
          ? Image.network(
        widget.mediaUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Container(
              color: Colors.black,
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.white, size: 50),
              ),
            ),
      )
          : Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.mediaType == 'video'
                    ? Icons.videocam_off
                    : Icons.image_not_supported,
                color: Colors.white70,
                size: 50,
              ),
              const SizedBox(height: 16),
              const Text(
                "メディアが利用できません",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
  }
}