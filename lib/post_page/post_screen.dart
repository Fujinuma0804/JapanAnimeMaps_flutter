import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import 'drafts_list.dart';

class PostScreen extends StatefulWidget {
  final User currentUser;

  const PostScreen({
    Key? key,
    required this.currentUser,
  }) : super(key: key);

  @override
  _PostScreenState createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  List<String> _mediaUrls = [];
  bool _isLoading = false;
  bool _hasDrafts = false;
  late AnimationController _progressController;
  final int _maxLength = 280;
  String? _avatarUrl;
  String? _userHandle;
  String? _firebaseId;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _textController.addListener(_updateProgress);
    _checkForDrafts();
    _loadUserAvatar();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(widget.currentUser.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null && userData['id'] != null) {
          setState(() {
            _firebaseId = userData['id'] as String;
            _userHandle = userData['id'] as String;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadUserAvatar() async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(widget.currentUser.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null && userData['avatarUrl'] != null) {
          setState(() {
            _avatarUrl = userData['avatarUrl'] as String;
          });
        }
      }
    } catch (e) {
      print('Error loading user avatar: $e');
    }
  }

  Future<void> _checkForDrafts() async {
    try {
      final draftsSnapshot = await _firestore
          .collection('drafts')
          .where('userId', isEqualTo: widget.currentUser.uid)
          .get();
      setState(() {
        _hasDrafts = draftsSnapshot.docs.isNotEmpty;
      });
    } catch (e) {
      print('Error checking drafts: $e');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _progressController.dispose();
    super.dispose();
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

  Future<void> _saveDraft() async {
    if (_textController.text.trim().isEmpty && _mediaUrls.isEmpty) {
      _showErrorSnackBar('テキストまたは画像を入力してください');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<String> hashtags = _extractHashtags(_textController.text);

      await _firestore.collection('drafts').add({
        'userId': widget.currentUser.uid,
        'text': _textController.text,
        'mediaUrls': _mediaUrls,
        'hashtags': hashtags,
        'createdAt': FieldValue.serverTimestamp(),
        'userPhotoURL': _avatarUrl,
        'userName': widget.currentUser.displayName,
      });

      Navigator.of(context).pop();
      Navigator.of(context).pop();
    } catch (e) {
      _showErrorSnackBar('下書きの保存に失敗しました: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showExitBottomSheet() {
    if (_textController.text.trim().isEmpty && _mediaUrls.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('削除'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.save_outlined),
                title: const Text('下書きを保存'),
                onTap: _saveDraft,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).primaryColor,
                    side: BorderSide(
                      color: Theme.of(context).primaryColor,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'キャンセル',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showDraftsBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraftsList(
          currentUser: widget.currentUser,
          onDraftSelected: (draft) {
            setState(() {
              _textController.text = draft['text'] ?? '';
              _mediaUrls = List<String>.from(draft['mediaUrls'] ?? []);
            });
            Navigator.pop(context);
            _firestore.collection('drafts').doc(draft.id).delete();
            _checkForDrafts();
          },
        );
      },
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
        Reference storageRef = _storage.ref().child('posts/$fileName');
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

  Future<void> _submitPost() async {
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

      await _firestore.collection('posts').add({
        'text': text,
        'mediaUrls': _mediaUrls,
        'hashtags': hashtags,
        'likes': 0,
        'likedBy': [],
        'retweets': 0,
        'retweetedBy': [],
        'bookmarkedBy': [],
        'createdAt': FieldValue.serverTimestamp(),
        'userId': widget.currentUser.uid,
        'userPhotoURL': _avatarUrl,
        'userName': widget.currentUser.displayName,
        'userHandle': _firebaseId ?? widget.currentUser.uid,
      });

      for (String hashtag in hashtags) {
        await _firestore.collection('hashtags').doc(hashtag).set({
          'count': FieldValue.increment(1),
          'lastUsed': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      Navigator.pop(context);
    } catch (e) {
      _showErrorSnackBar('投稿に失敗しました: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
          onPressed: _showExitBottomSheet,
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(_avatarUrl!)
                  : null,
              backgroundColor: Colors.grey[200],
              child: _avatarUrl == null || _avatarUrl!.isEmpty
                  ? Icon(Icons.person, color: Colors.grey[600])
                  : null,
              radius: 16,
            ),
            const SizedBox(width: 8),
            Text(
              widget.currentUser.displayName ?? '',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          if (_hasDrafts)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed: _showDraftsBottomSheet,
                child: const Text('下書き'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00008b),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                '投稿',
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
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Stack(
                    children: [
                      TextField(
                        controller: _textController,
                        maxLines: null,
                        decoration: const InputDecoration(
                          hintText: 'いまどうしてる？',
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
                      color: Color(0xFF00008b),
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
