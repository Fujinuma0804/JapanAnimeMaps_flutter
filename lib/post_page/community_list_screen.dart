import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'community_list_detail.dart';

class CommunityListScreen extends StatefulWidget {
  const CommunityListScreen({Key? key}) : super(key: key);

  @override
  State<CommunityListScreen> createState() => _CommunityListScreenState();
}

class _CommunityListScreenState extends State<CommunityListScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ユーザーの参加コミュニティを取得する関数
  Future<Map<String, bool>> _getUserCommunities() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('communities')
        .get();

    return {
      for (final doc in snapshot.docs) doc.id: doc.data()['isActive'] ?? false
    };
  }

  // 検索条件に合致するかどうかをチェックする関数
  // 検索条件に合致するかどうかをチェックする関数
  bool _matchesSearch(Map<String, dynamic> data) {
    if (_searchQuery.isEmpty) return true;

    final searchLower = _searchQuery.toLowerCase();
    final name = (data['name'] ?? '').toString().toLowerCase();
    final hashtag = (data['hashtag'] ?? '').toString().toLowerCase();
    final invitationCode =
        (data['invitationCode'] ?? '').toString().toLowerCase();

    return name.contains(searchLower) ||
        hashtag.contains(searchLower) ||
        invitationCode.contains(searchLower);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'コミュニティを探す',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF00008b)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'コミュニティを検索',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, bool>>(
              future: _getUserCommunities(),
              builder: (context, userCommunitiesSnapshot) {
                if (userCommunitiesSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final userCommunities = userCommunitiesSnapshot.data ?? {};

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('community_list')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Colors.black,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'エラーが発生しました\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '「$_searchQuery」に一致する結果が見つかりません\n(コミュニティ名、ハッシュタグ、招待コードで検索できます)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // 検索条件に合致するドキュメントのみをフィルタリング
                    final filteredDocs = snapshot.data!.docs
                        .where((doc) =>
                            _matchesSearch(doc.data() as Map<String, dynamic>))
                        .toList();

                    if (filteredDocs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '検索結果が見つかりません',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 8),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final isJoined = userCommunities[doc.id] ?? false;

                        final Map<String, dynamic> communityMap = {
                          'id': doc.id,
                          'displayName': data['displayName'] ?? '',
                          'description': data['description'] ?? '',
                          'backgroundImageUrl':
                              data['backgroundImageUrl'] ?? '',
                          'memberCount': data['memberCount'] ?? 0,
                          'hashtag': data['hashtag'] ?? '',
                          'name': data['name'] ?? '',
                        };

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isJoined ? Colors.grey[200] : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CommunityDetailScreen(
                                        community: communityMap,
                                      ),
                                    ),
                                  );
                                },
                                child: Stack(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 80,
                                            height: 80,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              color: Colors.grey[200],
                                            ),
                                            clipBehavior: Clip.hardEdge,
                                            child: data['backgroundImageUrl'] !=
                                                    null
                                                ? CachedNetworkImage(
                                                    imageUrl: data[
                                                        'backgroundImageUrl'],
                                                    fit: BoxFit.cover,
                                                    placeholder:
                                                        (context, url) =>
                                                            Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                        color: Colors.grey[400],
                                                      ),
                                                    ),
                                                    errorWidget:
                                                        (context, url, error) =>
                                                            const Icon(
                                                      Icons.group,
                                                      size: 40,
                                                      color: Colors.grey,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.group,
                                                    size: 40,
                                                    color: Colors.grey,
                                                  ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  data['name'] ?? '名称未設定',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: isJoined
                                                        ? Colors.grey[600]
                                                        : const Color(
                                                            0xFF00008b),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  data['description'] ?? '',
                                                  maxLines: 3,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.arrow_forward_ios,
                                            size: 16,
                                            color: Colors.grey,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isJoined)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[400],
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            '参加中',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
