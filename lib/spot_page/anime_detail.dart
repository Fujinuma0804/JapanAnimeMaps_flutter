import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:parts/help_page/help.dart';
import 'package:parts/spot_page/report_screen.dart';
import 'package:parts/spot_page/review.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class AnimeDetail extends StatefulWidget {
  final String animeName;

  const AnimeDetail({Key? key, required this.animeName}) : super(key: key);

  @override
  State<AnimeDetail> createState() => _AnimeDetailState();
}

class _AnimeDetailState extends State<AnimeDetail> {
  double _userRating = 0;
  double _averageRating = 0;
  Map<String, dynamic>? _animeData;
  List<Map<String, dynamic>> _streamingTools = [];
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;
  bool _isLoadingMoreReviews = false;
  int _currentReviewIndex = 0;
  ScrollController _scrollController = ScrollController();
  YoutubePlayerController? _youtubeController;
  bool _showVideo = false;
  bool _videoInitialized = false;
  String? _videoId;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    _fetchAnimeData();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _youtubeController?.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange) {
      _fetchMoreReviews();
    }
  }

  Future<void> _initializeVideo() async {
    if (_animeData != null &&
        _animeData!['officialVideoUrl'] != null &&
        _animeData!['officialVideoUrl'].toString().isNotEmpty) {
      try {
        String originalUrl = _animeData!['officialVideoUrl'];
        String? videoId = YoutubePlayer.convertUrlToId(originalUrl);

        if (videoId != null) {
          _videoId = videoId;
          _youtubeController = YoutubePlayerController(
            initialVideoId: videoId,
            flags: YoutubePlayerFlags(
              mute: _isMuted, // _isMuted変数を使用
              autoPlay: true,
              hideControls: true,
              enableCaption: false,
              isLive: false,
              loop: true,
              forceHD: false,
            ),
          );

          if (mounted) {
            setState(() {
              _videoInitialized = true;
            });

            Future.delayed(Duration(seconds: 1), () {
              // 2秒から1秒に変更
              if (mounted) {
                setState(() {
                  _showVideo = true;
                });
              }
            });
          }
        } else {
          print("Invalid YouTube URL: $originalUrl");
        }
      } catch (e) {
        print("Error initializing video: $e");
        if (mounted) {
          setState(() {
            _videoInitialized = false;
            _showVideo = false;
          });
        }
      }
    }
  }

  Widget _buildStreamingToolsList() {
    return _streamingTools.isEmpty
        ? Center(child: Text('現在、配信情報がありません。'))
        : ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _streamingTools.length,
            itemBuilder: (context, index) {
              final animeTool = _streamingTools[index];
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Row(
                  children: [
                    _getStreamingSeviceImage(animeTool['name']),
                    SizedBox(width: 16.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            animeTool['name'],
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4.0),
                          Text(
                            '月額: ${_formatMonthlyFee(animeTool['monthlyFee'], animeTool['name'])}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _launchURL(context, animeTool['downloadUrl']);
                      },
                      child: Text(
                        '視聴する',
                        style: TextStyle(color: Color(0xFF00008b)),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
  }

  void _launchURL(BuildContext context, String url) async {
    try {
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) {
          return CupertinoAlertDialog(
            title: Text("エラー"),
            content: Text("リンクを開けませんでした。"),
            actions: <Widget>[
              CupertinoDialogAction(
                child: Text("閉じる"),
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(context),
              ),
              CupertinoDialogAction(
                child: Text("OK"),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _fetchAnimeData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      QuerySnapshot animeSnapshot = await FirebaseFirestore.instance
          .collection('animes')
          .where('name', isEqualTo: widget.animeName)
          .limit(1)
          .get();

      if (animeSnapshot.docs.isNotEmpty) {
        _animeData = animeSnapshot.docs.first.data() as Map<String, dynamic>;
        await _fetchStreamingTools();
        await _fetchReviews();
        await _initializeVideo();
      } else {
        print("No anime data found.");
      }
    } catch (e) {
      print("Error fetching anime data: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchReviews() async {
    try {
      QuerySnapshot reviewsSnapshot =
          await FirebaseFirestore.instance.collection('reviews').get();

      List<Map<String, dynamic>> allReviews = reviewsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'animeName': data['animeName'] ?? '',
          'username': data['nickname'] ?? '不明',
          'content': data['review'] ?? '',
          'rating': data['rating'] ?? 0,
          'createdAt': data['timestamp'] ?? Timestamp.now(),
        };
      }).toList();

      setState(() {
        _reviews = allReviews
            .where((review) => review['animeName'] == widget.animeName)
            .toList();

        _reviews.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));

        if (_reviews.length > 10) {
          _reviews = _reviews.sublist(0, 10);
        }

        if (_reviews.isNotEmpty) {
          double totalRating = _reviews.fold(
              0, (sum, review) => sum + (review['rating'] as num));
          _averageRating = totalRating / _reviews.length;
        }

        _currentReviewIndex = _reviews.length;
      });
    } catch (e) {
      print("Error fetching reviews: $e");
    }
  }

  Future<void> _fetchMoreReviews() async {
    if (_isLoadingMoreReviews || _currentReviewIndex >= _reviews.length) return;

    setState(() {
      _isLoadingMoreReviews = true;
    });

    try {
      QuerySnapshot reviewsSnapshot =
          await FirebaseFirestore.instance.collection('reviews').get();

      List<Map<String, dynamic>> allReviews = reviewsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'animeName': data['animeName'] ?? '',
          'username': data['nickname'] ?? '不明',
          'content': data['review'] ?? '',
          'rating': data['rating'] ?? 0,
          'createdAt': data['timestamp'] ?? Timestamp.now(),
        };
      }).toList();

      List<Map<String, dynamic>> filteredReviews = allReviews
          .where((review) => review['animeName'] == widget.animeName)
          .toList();

      filteredReviews.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));

      int endIndex = _currentReviewIndex + 10;
      if (endIndex > filteredReviews.length) {
        endIndex = filteredReviews.length;
      }

      List<Map<String, dynamic>> newReviews =
          filteredReviews.sublist(_currentReviewIndex, endIndex);

      setState(() {
        _reviews.addAll(newReviews);
        _currentReviewIndex = endIndex;

        if (_reviews.isNotEmpty) {
          double totalRating = _reviews.fold(
              0, (sum, review) => sum + (review['rating'] as num));
          _averageRating = totalRating / _reviews.length;
        }
      });
    } catch (e) {
      print("Error fetching more reviews: $e");
    } finally {
      setState(() {
        _isLoadingMoreReviews = false;
      });
    }
  }

  Future<void> _fetchStreamingTools() async {
    try {
      List<dynamic> toolIds = _animeData?['tools'] ?? [];
      if (toolIds.isEmpty) {
        print("No tool IDs found.");
        return;
      }

      setState(() {
        _streamingTools = toolIds.map((toolId) {
          return {
            'name': toolId.toString(),
            'imageUrl': 'https://via.placeholder.com/50',
            'downloadUrl': '',
          };
        }).toList();
      });

      print("Fetching streaming tools with IDs: $toolIds");

      if (toolIds.length > 10) {
        toolIds = toolIds.take(10).toList();
        print("Truncated toolIds to 10: $toolIds");
      }

      QuerySnapshot toolsSnapshot = await FirebaseFirestore.instance
          .collection('anime_tools')
          .where(FieldPath.documentId, whereIn: toolIds)
          .get();

      if (toolsSnapshot.size > 0) {
        setState(() {
          _streamingTools = toolsSnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'name': data['name'] ?? 'Unknown Tool',
              'imageUrl': data['imageUrl'] ?? 'https://via.placeholder.com/50',
              'downloadUrl': doc['downloadUrl'] ?? '',
              'monthlyFee': data['monthlyFee'],
            };
          }).toList();
        });
      }

      print("Fetched streaming tools: $_streamingTools");
    } catch (e) {
      print("Error fetching streaming tools: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.animeName,
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'report') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          ReportScreen(animeName: widget.animeName)),
                );
              }
              if (value == 'help') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HelpCenter()),
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'report',
                child: Text('フィードバック'),
              ),
              const PopupMenuItem<String>(
                value: 'help',
                child: Text('ヘルプ'),
              ),
            ],
            icon: Icon(Icons.more_vert),
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _animeData == null
              ? Center(child: Text('アニメデータが見つかりませんでした。'))
              : ListView(
                  controller: _scrollController,
                  children: [
                    _buildAnimeImage(),
                    _buildAnimeOverview(),
                    _buildAnimeReleaseDate(),
                    _buildAverageRating(),
                    _buildWriteReviewButton(),
                    _buildReviewsList(),
                    _buildStreamingToolsList(),
                  ],
                ),
    );
  }

  Widget _buildAnimeImage() {
    if (_showVideo && _videoInitialized && _youtubeController != null) {
      return SizedBox(
        height: 250.0,
        width: double.infinity,
        child: Stack(
          children: [
            YoutubePlayer(
              controller: _youtubeController!,
              showVideoProgressIndicator: false,
              onReady: () {
                print("YouTube Player is ready");
              },
              onEnded: (YoutubeMetaData metaData) {
                _youtubeController?.seekTo(Duration.zero);
                _youtubeController?.play();
              },
            ),
            // タップでミュート切り替えができるように修正
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isMuted = !_isMuted;
                    if (_isMuted) {
                      _youtubeController?.mute();
                    } else {
                      _youtubeController?.unMute();
                    }
                  });
                },
                child: Container(
                  color: Colors.transparent,
                  child: Center(
                    child: Icon(
                      _isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white.withOpacity(0.7),
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return _animeData!['imageUrl'] != null
          ? Image.network(
              _animeData!['imageUrl'],
              height: 250.0,
              width: double.infinity,
              fit: BoxFit.cover,
            )
          : Container(
              height: 250.0,
              width: double.infinity,
              color: Colors.grey,
              child: Center(
                child: Text('No image available'),
              ),
            );
    }
  }

  Widget _buildAnimeOverview() {
    return Padding(
      padding: EdgeInsets.all(20.0),
      child: Text(
        _animeData!['overview'] ?? '概要がありません。準備中です。',
        style: TextStyle(color: Colors.black),
      ),
    );
  }

  Widget _buildAnimeReleaseDate() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.0),
      child: Text(
        'アニメ配信日：${_formatReleaseDate(_animeData!['releaseDate'])}',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }

  void _showFullReview(Map<String, dynamic> review) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: 600),
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(
                      review['username'],
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      textAlign: TextAlign.left,
                    ),
                  ]),
                  SizedBox(height: 8),
                  RatingBarIndicator(
                    rating: (review['rating'] as num).toDouble(),
                    itemBuilder: (context, index) =>
                        Icon(Icons.star, color: Colors.amber),
                    itemCount: 5,
                    itemSize: 20.0,
                    direction: Axis.horizontal,
                  ),
                  SizedBox(height: 16),
                  Text(
                    review['content'],
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.left,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            'レビュー',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _reviews.isEmpty
            ? Center(
                child: Text('レビューがありません。'),
              )
            : SizedBox(
                height: 200,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification scrollInfo) {
                    if (scrollInfo.metrics.pixels ==
                        scrollInfo.metrics.maxScrollExtent) {
                      _fetchMoreReviews();
                    }
                    return true;
                  },
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: (_reviews.length / 2).ceil(),
                    itemBuilder: (context, index) {
                      return _buildReviewRow(index);
                    },
                  ),
                ),
              ),
        if (_isLoadingMoreReviews) Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildReviewRow(int rowIndex) {
    final startIndex = rowIndex * 2;
    final endIndex = startIndex + 2;
    final rowReviews = _reviews.sublist(
      startIndex,
      endIndex > _reviews.length ? _reviews.length : endIndex,
    );

    return Row(
      children: rowReviews.map((review) => _buildReviewItem(review)).toList(),
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> review) {
    return Container(
      width: MediaQuery.of(context).size.width / 2 - 30,
      child: Card(
        margin: EdgeInsets.all(10.0),
        child: InkWell(
          onTap: () => _showFullReview(review),
          child: Padding(
            padding: EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  review['username'],
                  style: TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.0),
                RatingBarIndicator(
                  rating: (review['rating'] as num).toDouble(),
                  itemBuilder: (context, index) =>
                      Icon(Icons.star, color: Colors.amber),
                  itemCount: 5,
                  itemSize: 16.0,
                  direction: Axis.horizontal,
                ),
                SizedBox(height: 8.0),
                Text(
                  review['content'],
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.0),
                Text(
                  '全文を表示',
                  style: TextStyle(
                    color: Color(0xFF00008b),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAverageRating() {
    return Padding(
      padding: EdgeInsets.all(20.0),
      child: Row(
        children: [
          Text(
            '平均評価: ',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16.0,
            ),
          ),
          RatingBarIndicator(
            rating: _averageRating,
            itemBuilder: (context, index) => Icon(
              Icons.star,
              color: Colors.amber,
            ),
            itemCount: 5,
            itemSize: 20.0,
            direction: Axis.horizontal,
          ),
          SizedBox(width: 8.0),
          Text(
            _averageRating.toStringAsFixed(1),
            style: TextStyle(
              color: Colors.black,
              fontSize: 16.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWriteReviewButton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          Icon(Icons.create_outlined),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReviewPage(animeName: widget.animeName),
                ),
              ).then((_) {
                _fetchReviews();
              });
            },
            child: Text(
              'レビューを書く',
              style: TextStyle(
                color: Color(0xFF00008b),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ExpandableText extends StatefulWidget {
  final String text;

  const ExpandableText({Key? key, required this.text}) : super(key: key);

  @override
  _ExpandableTextState createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: isExpanded ? null : 2,
          overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (widget.text.length > 50)
          TextButton(
            onPressed: () {
              setState(() {
                isExpanded = !isExpanded;
              });
            },
            child: Text(
              isExpanded ? '閉じる' : 'もっと見る',
              style: TextStyle(color: Color(0xFF00008b)),
            ),
          ),
      ],
    );
  }
}

Widget _getStreamingSeviceImage(String serviceName) {
  switch (serviceName.toLowerCase()) {
    case 'prime video':
      return Image.asset(
        'assets/images/amazon.jpeg',
        width: 50.0,
        height: 50.0,
        fit: BoxFit.cover,
      );
    case 'u-next':
      return Image.asset(
        'assets/images/U-NEXT.jpg',
        width: 50.0,
        height: 50.0,
        fit: BoxFit.cover,
      );
    case 'dアニメ':
      return Image.asset(
        'assets/images/danime.jpg',
        width: 50.0,
        height: 50.0,
        fit: BoxFit.cover,
      );
    case 'hulu':
      return Image.asset(
        'assets/images/hulu.jpg',
        width: 50.0,
        height: 50.0,
        fit: BoxFit.cover,
      );
    case 'dmm':
      return Image.asset(
        'assets/images/dmm.jpg',
        width: 50.0,
        height: 50.0,
        fit: BoxFit.cover,
      );
    case 'netflix':
      return Image.asset(
        'assets/images/netflix.jpg',
        width: 50.0,
        height: 50.0,
        fit: BoxFit.cover,
      );
    case 'disney+':
      return Image.asset(
        'assets/images/disney.jpg',
        width: 50.0,
        height: 50.0,
        fit: BoxFit.cover,
      );
    case 'abema':
      return Image.asset(
        'assets/images/abema.jpg',
        width: 50.0,
        height: 50.0,
        fit: BoxFit.cover,
      );
    case 'fodプレミアム':
      return Image.asset(
        'assets/images/fod.jpg',
        width: 50.0,
        height: 50.0,
        fit: BoxFit.cover,
      );
    case 'lemino':
      return Image.asset(
        'assets/images/lemino.jpg',
        width: 50.0,
        height: 50.0,
        fit: BoxFit.cover,
      );
    default:
      return Image.asset(
        'assets/images/error.jpg',
        width: 50.0,
        height: 50.0,
        fit: BoxFit.cover,
      );
  }
}

String _formatReleaseDate(dynamic releaseDateField) {
  if (releaseDateField == null) return '未設定';
  try {
    if (releaseDateField is Timestamp) {
      final date = releaseDateField.toDate();
      return '${date.year}年${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日';
    } else if (releaseDateField is String) {
      final date = DateTime.parse(releaseDateField);
      return '${date.year}年${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日';
    }
    return '未定';
  } catch (e) {
    print("Error formatting release date: $e");
    return '未定';
  }
}

String _formatMonthlyFee(dynamic fee, String serviceName) {
  switch (serviceName.toLowerCase()) {
    case 'prime video':
      return '600円';
    case 'u-next':
      return '2189円';
    case 'dアニメ':
      return '550円';
    case 'hulu':
      return '1026円';
    case 'dmm':
      return '550円';
    case 'netflix':
      return '990円';
    case 'disney+':
      return '1000円';
    case 'abema':
      return '960円';
    case 'fodプレミアム':
      return '976円';
    case 'lemino':
      return '990円';
    default:
      return '';
  }
}
