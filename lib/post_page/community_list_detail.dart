import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parts/post_page/post_first/community_chat.dart';

import 'in_community.dart';

class CommunityDetailScreen extends StatefulWidget {
  final Map<String, dynamic> community;

  const CommunityDetailScreen({
    Key? key,
    required this.community,
  }) : super(key: key);

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  bool _showFullDescription = false;
  final int _maxLines = 4;
  bool _hasTextOverflow = false;
  bool _isJoined = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkJoinStatus();
  }

  Future<void> _checkJoinStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('communities')
          .doc(widget.community['id'])
          .get();

      setState(() {
        _isJoined = docSnapshot.exists;
        _isLoading = false;
      });
    } catch (e) {
      print('Error checking join status: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasTextOverflow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final TextPainter textPainter = TextPainter(
          text: TextSpan(
            text: widget.community['description'] ?? '',
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
          maxLines: _maxLines,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(maxWidth: MediaQuery.of(context).size.width - 32);

        if (mounted) {
          setState(() {
            _hasTextOverflow = textPainter.didExceedMaxLines;
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true, // これを追加
        title: const Text(
          'コミュニティ',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF00008b)),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.local_police_outlined,
              color: Color(0xFF00008b),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.more_vert,
              color: Color(0xFF00008b),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  Stack(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        width: double.infinity,
                        child: widget.community['backgroundImageUrl'] != null &&
                                widget
                                    .community['backgroundImageUrl'].isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl:
                                    widget.community['backgroundImageUrl'],
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.error),
                              )
                            : Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.group,
                                  size: 100,
                                  color: Colors.grey,
                                ),
                              ),
                      ),
                      Positioned(
                        top: MediaQuery.of(context).padding.top,
                        left: 16,
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          widget.community['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.community['memberCount'] ?? 0} メンバー',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          widget.community['description'] ?? '',
                          maxLines: _showFullDescription ? null : _maxLines,
                          overflow: _showFullDescription
                              ? null
                              : TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_hasTextOverflow) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showFullDescription = !_showFullDescription;
                              });
                            },
                            child: Text(
                              _showFullDescription ? '閉じる' : 'もっと見る',
                              style: const TextStyle(
                                color: Color(0xFF06C755),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        if (widget.community['hashtag'] != null)
                          Text(
                            widget.community['hashtag'],
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 14,
                            ),
                          ),
                        SizedBox(
                            height:
                                MediaQuery.of(context).padding.bottom + 120),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                color: Colors.white,
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 16 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: _isJoined
                              ? Colors.grey[400]
                              : const Color(0xFF00008b),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isJoined
                                ? null
                                : () {
                                    final String communityId =
                                        widget.community['id'] ?? '';
                                    if (communityId.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('コミュニティIDが見つかりません'),
                                        ),
                                      );
                                      return;
                                    }

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => InCommunity(
                                          communityId: communityId,
                                          backgroundImage: widget.community[
                                                  'backgroundImageUrl'] ??
                                              '',
                                          communityName:
                                              widget.community['name'] ?? '',
                                          description:
                                              widget.community['description'] ??
                                                  '',
                                        ),
                                      ),
                                    ).then((_) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => GroupChatScreen(
                                            roomName:
                                                widget.community['name'] ?? '',
                                            participantCount: widget
                                                    .community['memberCount'] ??
                                                0,
                                          ),
                                        ),
                                      );
                                    });
                                  },
                            child: Center(
                              child: Text(
                                _isJoined ? '参加済み' : '新しいプロフィールで参加',
                                style: TextStyle(
                                  color: _isJoined
                                      ? Colors.white.withOpacity(0.7)
                                      : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
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
}
