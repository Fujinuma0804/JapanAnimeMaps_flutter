import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PostDetailScreen extends StatelessWidget {
  final DocumentSnapshot post;

  const PostDetailScreen({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final postData = post.data() as Map<String, dynamic>;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final List<String> likedBy = List<String>.from(postData['likedBy'] ?? []);
    final List<String> retweetedBy =
        List<String>.from(postData['retweetedBy'] ?? []);
    final List<String> bookmarkedBy =
        List<String>.from(postData['bookmarkedBy'] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '投稿',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundImage:
                            postData['userPhotoURL']?.isNotEmpty == true
                                ? CachedNetworkImageProvider(
                                    postData['userPhotoURL'])
                                : null,
                        child: postData['userPhotoURL']?.isNotEmpty != true
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              postData['userName'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
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
                  const SizedBox(height: 20.0),
                  Text(
                    postData['text'] as String,
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (postData['mediaUrls'] != null &&
                      (postData['mediaUrls'] as List).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SizedBox(
                              height: 200,
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      (postData['mediaUrls'] as List).length ==
                                              1
                                          ? 1
                                          : 2,
                                  crossAxisSpacing: 4,
                                  mainAxisSpacing: 4,
                                  childAspectRatio:
                                      (postData['mediaUrls'] as List).length ==
                                              1
                                          ? constraints.maxWidth / 200
                                          : 1,
                                ),
                                itemCount:
                                    (postData['mediaUrls'] as List).length,
                                itemBuilder: (context, index) {
                                  return CachedNetworkImage(
                                    imageUrl:
                                        postData['mediaUrls'][index] as String,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  if (postData['hashtags'] != null &&
                      (postData['hashtags'] as List).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Wrap(
                        spacing: 4.0,
                        children: (postData['hashtags'] as List)
                            .map((tag) => Text(
                                  tag as String,
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 14.0,
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  const SizedBox(
                    height: 50.0,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInteractionCount(
                        Icons.chat_bubble_outline,
                        postData['replies']?.length ?? 0,
                        Colors.grey,
                      ),
                      _buildInteractionCount(
                        likedBy.contains(currentUserId)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        likedBy.length,
                        likedBy.contains(currentUserId)
                            ? Colors.red
                            : Colors.grey,
                      ),
                      _buildInteractionCount(
                        Icons.repeat,
                        retweetedBy.length,
                        retweetedBy.contains(currentUserId)
                            ? Colors.green
                            : Colors.grey,
                      ),
                      _buildInteractionCount(
                        bookmarkedBy.contains(currentUserId)
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        bookmarkedBy.length,
                        bookmarkedBy.contains(currentUserId)
                            ? Colors.blue
                            : Colors.grey,
                      ),
                      Icon(
                        Icons.share_outlined,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // ここに返信一覧を表示するウィジェットを追加することができます
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionCount(IconData icon, int count, Color color) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 4),
        Text(
          count.toString(),
          style: TextStyle(
            color: color,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
