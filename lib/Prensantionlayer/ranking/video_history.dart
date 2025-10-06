// video_history_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoHistoryScreen extends StatefulWidget {
  @override
  _VideoHistoryScreenState createState() => _VideoHistoryScreenState();
}

class _VideoHistoryScreenState extends State<VideoHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _historyData = [];
  bool _isLoading = true;
  VideoPlayerController? _videoController;
  bool _showVideo = false;

  @override
  void initState() {
    super.initState();
    _fetchVideoHistory();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _fetchVideoHistory() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final videoHistory =
          userDoc.data()?['videoHistory'] as Map<String, dynamic>?;

      if (videoHistory != null) {
        final List<Map<String, dynamic>> historyList = [];

        // videoHistoryの各エントリに対して対応する動画URLを取得
        for (var entry in videoHistory.entries) {
          if (entry.value == true) {
            final date = DateTime.parse(entry.key);
            final videoDoc = await _getVideoForDate(date);

            if (videoDoc != null) {
              historyList.add({
                'date': date,
                'watched': entry.value,
                'videoUrl': videoDoc['url'],
                'title': videoDoc['title'] ?? '無題の動画',
                'description': videoDoc['description'] ?? '',
              });
            }
          }
        }

        // 日付で降順ソート
        historyList.sort((a, b) => b['date'].compareTo(a['date']));

        setState(() {
          _historyData = historyList;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching video history: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _getVideoForDate(DateTime date) async {
    try {
      final weekStart = date.subtract(Duration(
        days: date.weekday - 1,
        hours: date.hour,
        minutes: date.minute,
        seconds: date.second,
        milliseconds: date.millisecond,
        microseconds: date.microsecond,
      ));

      final videoQuery = await _firestore
          .collection('weeklyVideos')
          .where('weekOf', isEqualTo: weekStart.toString().split(' ')[0])
          .get();

      if (videoQuery.docs.isNotEmpty) {
        return videoQuery.docs.first.data();
      }
      return null;
    } catch (e) {
      print('Error getting video for date: $e');
      return null;
    }
  }

  Future<void> _playVideo(String videoUrl) async {
    try {
      await _videoController?.dispose();

      _videoController = VideoPlayerController.network(
        videoUrl,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await _videoController!.initialize();
      await _videoController!.play();

      setState(() {
        _showVideo = true;
      });
    } catch (e) {
      print('Error playing video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('動画の再生に失敗しました'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(
              '動画履歴',
              style: TextStyle(
                color: Color(0xFF00008b),
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Color(0xFF00008b)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _historyData.isEmpty
                  ? Center(
                      child: Text(
                        '視聴履歴はありません',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _historyData.length,
                      itemBuilder: (context, index) {
                        final history = _historyData[index];
                        return Card(
                          margin: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            title: Text(
                              _formatDate(history['date']),
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  history['title'],
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                  ),
                                ),
                                if (history['description'].isNotEmpty)
                                  Text(
                                    history['description'],
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                            leading: Icon(
                              Icons.play_circle_outline,
                              color: Color(0xFF00008b),
                            ),
                            trailing: Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            ),
                            onTap: () => _playVideo(history['videoUrl']),
                          ),
                        );
                      },
                    ),
        ),
        if (_showVideo && _videoController != null)
          Positioned.fill(
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 再生/一時停止ボタン
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (_videoController!.value.isPlaying) {
                                  _videoController!.pause();
                                } else {
                                  _videoController!.play();
                                }
                              });
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              margin: EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _videoController!.value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          // 閉じるボタン
                          GestureDetector(
                            onTap: () {
                              _videoController?.pause();
                              setState(() {
                                _showVideo = false;
                              });
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              margin: EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
