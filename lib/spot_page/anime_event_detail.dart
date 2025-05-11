import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class AnimeEventDetail extends StatefulWidget {
  final String eventNumber;

  const AnimeEventDetail({
    Key? key,
    required this.eventNumber,
  }) : super(key: key);

  @override
  _AnimeEventDetailState createState() => _AnimeEventDetailState();
}

class _AnimeEventDetailState extends State<AnimeEventDetail> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _eventData;
  bool _isLoading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _fetchEventData();
  }

  Future<void> _fetchEventData() async {
    try {
      final doc = await _firestore
          .collection('anime_event_info')
          .doc(widget.eventNumber)
          .get();

      if (doc.exists) {
        setState(() {
          _eventData = doc.data();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching event data: $e');
      setState(() {
        _error = true;
        _isLoading = false;
      });
    }
  }

  // 日付をフォーマットする関数
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    return DateFormat('yyyy年MM月dd日').format(timestamp.toDate());
  }

  // 「行ったよ」カウントをインクリメントする関数
  Future<void> _incrementEventCount() async {
    if (_eventData == null) return;

    try {
      await _firestore.collection('anime_event_info').doc(widget.eventNumber).update({
        'eventCount': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      });

      // UI更新
      setState(() {
        _eventData!['eventCount'] = (_eventData!['eventCount'] ?? 0) + 1;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「行ったよ」に追加しました！')),
      );
    } catch (e) {
      print('Error incrementing count: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました。もう一度お試しください。')),
      );
    }
  }

  // イベントをシェアする関数
  void _shareEvent() {
    if (_eventData == null) return;

    final String eventName = _eventData!['eventName'] ?? 'アニメイベント';
    final String eventPlace = _eventData!['eventPlace'] ?? '';
    final String eventPeriod = '${_formatDate(_eventData!['eventStart'])} - ${_formatDate(_eventData!['eventFinish'])}';

    Share.share(
      '$eventName\n開催場所: $eventPlace\n開催期間: $eventPeriod\n\nアニメイベント情報をチェックしよう！',
      subject: eventName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoading ? 'イベント詳細' : (_eventData?['eventName'] ?? 'イベント詳細'), style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: _isLoading ? null : _shareEvent,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: !_isLoading && !_error ? FloatingActionButton.extended(
        onPressed: _incrementEventCount,
        icon: Icon(Icons.thumb_up),
        label: Text('行ったよ！'),
        backgroundColor: Colors.blue,
      ) : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('イベント情報の取得に失敗しました。', style: TextStyle(fontSize: 18)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = false;
                });
                _fetchEventData();
              },
              child: Text('再読み込み'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // トップ画像
          if (_eventData!['eventTopImageUrl'] != null)
            CachedNetworkImage(
              imageUrl: _eventData!['eventTopImageUrl'],
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => Container(
                height: 200,
                color: Colors.grey[300],
                child: Center(child: Icon(Icons.image_not_supported, size: 50)),
              ),
            ),

          // イベント基本情報
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _eventData!['eventName'] ?? '',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  _eventData!['eventNameEn'] ?? '',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600], fontStyle: FontStyle.italic),
                ),
                SizedBox(height: 16),

                // カウント情報
                Row(
                  children: [
                    Icon(Icons.people, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      '行ったよカウント: ${_eventData!['eventCount'] ?? 0}',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),

                Divider(height: 32),

                // 開催期間
                Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(
                      '開催期間',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '${_formatDate(_eventData!['eventStart'])} - ${_formatDate(_eventData!['eventFinish'])}',
                  style: TextStyle(fontSize: 16),
                ),

                SizedBox(height: 16),

                // 開催場所
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      '開催場所',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  _eventData!['eventPlace'] ?? '',
                  style: TextStyle(fontSize: 16),
                ),

                Divider(height: 32),

                // イベント簡略情報
                Text(
                  'イベント概要',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  _eventData!['eventInfo'] ?? '',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  _eventData!['eventInfoEn'] ?? '',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600], fontStyle: FontStyle.italic),
                ),

                SizedBox(height: 24),

                // イベント詳細情報
                Text(
                  'イベント詳細',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  _eventData!['eventMoreInfo'] ?? '',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  _eventData!['eventMoreInfoEn'] ?? '',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600], fontStyle: FontStyle.italic),
                ),

                SizedBox(height: 24),

                // イベントジャンル
                Text(
                  'イベントジャンル',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildGenreChip(_eventData!['eventGenreMore'] ?? ''),
                  ],
                ),

                SizedBox(height: 32),
              ],
            ),
          ),

          // ユーザ投稿（あれば）
          if (_eventData!['eventPosts'] != null && (_eventData!['eventPosts'] as List).isNotEmpty)
            _buildPostsSection(),

          // コメント欄（あれば）
          if (_eventData!['eventComments'] != null && (_eventData!['eventComments'] as List).isNotEmpty)
            _buildCommentsSection(),

          SizedBox(height: 80),  // Floating Action Buttonのスペース
        ],
      ),
    );
  }

  Widget _buildGenreChip(String genre) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        genre,
        style: TextStyle(color: Colors.blue[800]),
      ),
    );
  }

  Widget _buildPostsSection() {
    final posts = _eventData!['eventPosts'] as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'イベント投稿',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(height: 8),
        Container(
          height: 200,
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index] as Map<String, dynamic>;
              return Container(
                margin: EdgeInsets.only(right: 12),
                width: 160,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: post['type'] == 'video'
                          ? Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(Icons.play_circle_fill, color: Colors.white, size: 50),
                        ),
                      )
                          : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: post['url'],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (context, url) => Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => Center(child: Icon(Icons.error)),
                        ),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      post['name'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCommentsSection() {
    final comments = _eventData!['eventComments'] as List;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'コメント',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          ...comments.map((comment) => Container(
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(comment.toString()),
          )),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}