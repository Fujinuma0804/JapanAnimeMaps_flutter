import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class ReplyScreen extends StatefulWidget {
  final User currentUser;
  final DocumentSnapshot originalPost;

  const ReplyScreen({
    Key? key,
    required this.currentUser,
    required this.originalPost,
  }) : super(key: key);

  @override
  _ReplyScreenState createState() => _ReplyScreenState();
}

class _ReplyScreenState extends State<ReplyScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ScrollController _scrollController = ScrollController();
  List<String> _mediaUrls = [];
  bool _isLoading = false;
  bool _showOriginalPost = false;
  late AnimationController _progressController;
  final int _maxLength = 280;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _textController.addListener(_updateProgress);
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _textController.dispose();
    _progressController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.position.pixels < -50) {
      setState(() {
        _showOriginalPost = true;
      });
    } else if (_scrollController.position.pixels > 0) {
      setState(() {
        _showOriginalPost = false;
      });
    }
  }

  void _updateProgress() {
    final textLength = _textController.text.length;
    final progress = textLength / _maxLength;
    _progressController.animateTo(progress);
    setState(() {});
  }

  List<String> _extractHashtags(String text) {
    RegExp exp = RegExp(
        r'#[一-龠ぁ-んァ-ヶー-龥a-zA-Z0-9_\p{Emoji_Presentation}\p{Extended_Pictographic}]+',
        unicode: true);
    return exp.allMatches(text).map((m) => m.group(0)!).toList();
  }

  Widget _buildRichText(String text) {
    List<TextSpan> spans = [];
    RegExp exp = RegExp(
        r'(#[一-龠ぁ-んァ-ヶー-龥a-zA-Z0-9_\p{Emoji_Presentation}\p{Extended_Pictographic}]+)|([^#]+)',
        unicode: true);

    exp.allMatches(text).forEach((match) {
      String part = match.group(0)!;
      if (part.startsWith('#')) {
        spans.add(TextSpan(
          text: part,
          style: const TextStyle(
            color: Color(0xFF00008b),
            decoration: TextDecoration.underline,
          ),
        ));
      } else {
        spans.add(TextSpan(text: part));
      }
    });

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 18,
          color: Colors.black,
        ),
        children: spans,
      ),
    );
  }

  bool _isValidPostLength(String text) {
    int fullWidthCount =
        text.replaceAll(RegExp(r'[^\u3000-\u9FFF]'), '').length;
    int halfWidthCount = text.replaceAll(RegExp(r'[\u3000-\u9FFF]'), '').length;
    return fullWidthCount <= 140 && halfWidthCount <= 280;
  }

  Future<void> _pickMedia() async {
    final ImagePicker picker = ImagePicker();
    final XFile? media = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1800,
      maxHeight: 1800,
      imageQuality: 85,
    );

    if (media != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        String fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${path.basename(media.path)}';
        Reference storageRef = _storage.ref().child('replies/$fileName');
        await storageRef.putFile(File(media.path));
        String downloadUrl = await storageRef.getDownloadURL();

        setState(() {
          _mediaUrls.add(downloadUrl);
        });
      } catch (e) {
        _showErrorSnackBar('画像のアップロードに失敗しました: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _submitReply() async {
    if (!_isValidPostLength(_textController.text)) {
      _showErrorSnackBar('文字数制限を超えています');
      return;
    }

    if (_textController.text.trim().isEmpty && _mediaUrls.isEmpty) {
      _showErrorSnackBar('テキストまたは画像を投稿してください');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String text = _textController.text;
      List<String> hashtags = _extractHashtags(text);
      final timestamp = FieldValue.serverTimestamp();

      final comment = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'text': text,
        'mediaUrls': _mediaUrls,
        'hashtags': hashtags,
        'likes': 0,
        'likedBy': [],
        'createdAt': timestamp,
        'userId': widget.currentUser.uid,
        'userPhotoURL': widget.currentUser.photoURL,
        'userName': widget.currentUser.displayName,
        'userHandle': widget.currentUser.email?.split('@')[0] ?? '',
      };

      // Get current comments
      DocumentSnapshot postDoc = await widget.originalPost.reference.get();
      List<dynamic> currentComments =
          (postDoc.data() as Map<String, dynamic>)['comments'] ?? [];
      currentComments.add(comment);

      await widget.originalPost.reference.update({
        'comments': currentComments,
        'commentCount': currentComments.length,
      });

      Navigator.pop(context);
    } catch (e) {
      _showErrorSnackBar('返信の投稿に失敗しました: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildOriginalPost() {
    final postData = widget.originalPost.data() as Map<String, dynamic>;

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: postData['userPhotoURL']?.isNotEmpty == true
                      ? CachedNetworkImageProvider(postData['userPhotoURL'])
                      : null,
                  child: postData['userPhotoURL']?.isNotEmpty != true
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        postData['userName'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '@${postData['userHandle'] ?? ''}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(postData['text'] ?? ''),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remainingChars = _maxLength - _textController.text.length;
    final progress = _textController.text.length / _maxLength;
    final isOverLimit = progress > 1;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('返信を投稿'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitReply,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00008b),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                '返信',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_showOriginalPost) _buildOriginalPost(),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        child: Stack(
                          children: [
                            TextField(
                              controller: _textController,
                              maxLines: null,
                              decoration: const InputDecoration(
                                hintText: '返信をツイート',
                                border: InputBorder.none,
                              ),
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.transparent,
                              ),
                            ),
                            _buildRichText(_textController.text),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_mediaUrls.isNotEmpty)
                Container(
                  height: 120,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _mediaUrls.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: _mediaUrls[index],
                                height: 120,
                                width: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 12,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _mediaUrls.removeAt(index);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image),
                      color: const Color(0xFF00008b),
                      onPressed: _mediaUrls.length >= 4 ? null : _pickMedia,
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CustomPaint(
                        painter: CircularProgressPainter(
                          progress: progress,
                          isOverLimit: isOverLimit,
                        ),
                        child: Center(
                          child: Text(
                            remainingChars.toString(),
                            style: TextStyle(
                              color: isOverLimit ? Colors.red : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

class CircularProgressPainter extends CustomPainter {
  final double progress;
  final bool isOverLimit;

  CircularProgressPainter({
    required this.progress,
    required this.isOverLimit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Background circle
    paint.color = Colors.grey.withOpacity(0.2);
    canvas.drawCircle(center, radius, paint);

    // Progress arc
    paint.color = isOverLimit ? Colors.red : Colors.blue;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        isOverLimit != oldDelegate.isOverLimit;
  }
}
