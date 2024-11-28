import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parts/post_page/community_list_screen.dart';
import 'package:parts/post_page/make_community.dart';
import 'package:parts/post_page/post_first/community_chat.dart';
import 'package:parts/post_page/post_mypage.dart';
import 'package:parts/post_page/post_screen.dart';
import 'package:parts/post_page/replay_screen.dart';
import 'package:rxdart/rxdart.dart';
import 'package:share/share.dart';
import 'package:vibration/vibration.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({Key? key}) : super(key: key);

  @override
  _TimelineScreenState createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoadingMore = false;
  final int _postsPerPage = 20;
  List<DocumentSnapshot> posts = [];
  DocumentSnapshot? _lastDocument;
  User? currentUser;
  bool _hasMore = true;
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _showCommunityOptions = false;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);
    currentUser = _auth.currentUser;
    _loadInitialPosts();

    _tabController.addListener(() {
      setState(() {
        _showCommunityOptions = false;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialPosts() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(_postsPerPage)
          .get();

      setState(() {
        posts = snapshot.docs;
        if (posts.isNotEmpty) {
          _lastDocument = posts.last;
        }
        _hasMore = posts.length == _postsPerPage;
      });
    } catch (e) {
      print('Error loading initial posts: $e');
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMore && _hasMore) {
        _loadMorePosts();
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore || _lastDocument == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_postsPerPage)
          .get();

      setState(() {
        posts.addAll(snapshot.docs);
        if (snapshot.docs.isNotEmpty) {
          _lastDocument = posts.last;
          _hasMore = snapshot.docs.length == _postsPerPage;
        } else {
          _hasMore = false;
        }
      });
    } catch (e) {
      print('Error loading more posts: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refreshPosts() async {
    Vibration.vibrate(duration: 50);
    setState(() {
      posts = [];
      _lastDocument = null;
      _hasMore = true;
    });
    await _loadInitialPosts();
  }

  Widget _buildCommunityOptions() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _showCommunityOptions ? 150 : 0,
      child: Card(
        margin: const EdgeInsets.all(8.0),
        child: ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('新しいコミュニティを作成'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateOpenChatScreen(),
                  ),
                );
                setState(() {
                  _showCommunityOptions = false;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('コミュニティを探す'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CommunityListScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: DrawerHeader(
                decoration: const BoxDecoration(
                  color: Color(0xFF00008b),
                ),
                child: Container(
                  width: double.infinity,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'メニュー',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '参加中のチャンネルを検索',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: ListTile(
                leading: Icon(Icons.home),
                title: Text('ホーム'),
              ),
            ),
            const SliverToBoxAdapter(child: Divider()),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(left: 16.0, top: 8.0),
                child: Text(
                  'あなたの参加中チャンネル',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 270,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser?.uid)
                      .collection('communities')
                      .where('isActive', isEqualTo: true)
                      .snapshots(),
                  builder: (context, userCommunitiesSnapshot) {
                    if (userCommunitiesSnapshot.hasError) {
                      return ListTile(
                        title: Text(
                            'エラーが発生しました: ${userCommunitiesSnapshot.error}'),
                        subtitle: const Text('コミュニティ情報の取得に失敗しました'),
                      );
                    }

                    if (!userCommunitiesSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final communities = userCommunitiesSnapshot.data!.docs;
                    if (communities.isEmpty) {
                      return const ListTile(
                        title: Text('参加中のコミュニティはありません'),
                        subtitle: Text('新しいコミュニティに参加してみましょう'),
                      );
                    }

                    final communityIds =
                        communities.map((doc) => doc.id).toList();

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('community_list')
                          .where(FieldPath.documentId, whereIn: communityIds)
                          .snapshots(),
                      builder: (context, communitySnapshot) {
                        if (!communitySnapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        var filteredDocs =
                            communitySnapshot.data!.docs.where((doc) {
                          final communityData =
                              doc.data() as Map<String, dynamic>;

                          // isActiveがtrueのものだけをフィルタリング
                          final bool isActive =
                              communityData['isActive'] == true;

                          // 検索クエリとの一致判定
                          final communityName =
                              communityData['name'] as String? ?? '';
                          final matchesSearch = communityName
                              .toLowerCase()
                              .contains(_searchQuery.toLowerCase());

                          return isActive && matchesSearch;
                        }).toList();

                        if (filteredDocs.isEmpty) {
                          if (_searchQuery.isNotEmpty) {
                            return const Center(
                              child: Text('検索結果が見つかりません'),
                            );
                          }
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.group_outlined,
                                    size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'アクティブなコミュニティがありません\nコミュニティに参加してみましょう！',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: filteredDocs.length,
                          itemBuilder: (context, index) {
                            final community = filteredDocs[index];
                            final communityData =
                                community.data() as Map<String, dynamic>;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    communityData['backgroundImageUrl'] != null
                                        ? CachedNetworkImageProvider(
                                            communityData['backgroundImageUrl'])
                                        : null,
                                backgroundColor: Colors.grey[200],
                                child: communityData['backgroundImageUrl'] ==
                                        null
                                    ? Icon(Icons.group, color: Colors.grey[600])
                                    : null,
                              ),
                              title: Text(
                                communityData['name'] ?? '不明なコミュニティ',
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => GroupChatScreen(
                                      roomName:
                                          communityData['name'] ?? '不明なコミュニティ',
                                      communityId: community.id,
                                      participantCount:
                                          communityData['memberCount'] ?? 0,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: Divider()),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(left: 16.0, top: 8.0),
                child: Text(
                  'その他',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: ListTile(
                leading: Icon(Icons.settings),
                title: Text('コミュニティ設定'),
              ),
            ),
            const SliverToBoxAdapter(
              child: ListTile(
                leading: Icon(Icons.help),
                title: Text('ヘルプ'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text(
            'タイムライン',
            style: TextStyle(
              color: Color(0xFF00008b),
              fontWeight: FontWeight.bold,
            ),
          ),
          elevation: 0,
          actions: [
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                String? avatarUrl;
                if (snapshot.hasData && snapshot.data != null) {
                  final userData =
                      snapshot.data!.data() as Map<String, dynamic>?;
                  avatarUrl = userData?['avatarUrl'] as String?;
                }

                return IconButton(
                  icon: CircleAvatar(
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    backgroundColor: Colors.grey[200],
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? Icon(Icons.person, color: Colors.grey[600])
                        : null,
                  ),
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (context) => ProfilePage(),
                      ),
                    );
                  },
                );
              },
            ),
          ],
          leading: IconButton(
            icon: const Icon(
              Icons.menu,
              color: Color(0xFF00008b),
            ),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'おすすめ'),
              Tab(text: 'コミュニティ'),
              Tab(text: '運営'),
            ],
          ),
        ),
        drawer: _buildDrawer(),
        body: Column(
          children: [
            if (_tabController.index == 1) _buildCommunityOptions(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // おすすめタブ
                  RefreshIndicator(
                    onRefresh: _refreshPosts,
                    child: posts.isEmpty && !_isLoadingMore
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.post_add,
                                    size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  '投稿がありません\n最初の投稿をしてみましょう！',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            key: const PageStorageKey<String>('timeline_list'),
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: posts.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == posts.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              return StreamBuilder<DocumentSnapshot>(
                                stream: posts[index].reference.snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const SizedBox.shrink();
                                  }
                                  return PostCard(
                                    key: ValueKey(snapshot.data!.id),
                                    post: snapshot.data!,
                                    currentUserId: currentUser?.uid ?? '',
                                  );
                                },
                              );
                            },
                          ),
                  ),
                  // コミュニティタブ
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser?.uid)
                        .collection('communities')
                        .where('isActive', isEqualTo: true)
                        .snapshots(),
                    builder: (context, userCommunitiesSnapshot) {
                      if (userCommunitiesSnapshot.hasError) {
                        return Center(
                            child: Text(
                                'エラーが発生しました: ${userCommunitiesSnapshot.error}'));
                      }

                      if (!userCommunitiesSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final communities = userCommunitiesSnapshot.data!.docs;
                      if (communities.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.group_outlined,
                                  size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                '参加しているコミュニティがありません\nコミュニティに参加してみましょう！',
                                textAlign: TextAlign.center,
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                            ],
                          ),
                        );
                      }

                      final communityIds =
                          communities.map((doc) => doc.id).toList();

                      // 各コミュニティのチャットストリームを作成
                      final chatStreams = communityIds.map(
                        (communityId) => FirebaseFirestore.instance
                            .collection('community_list')
                            .doc(communityId)
                            .collection('chat')
                            .orderBy('createdAt', descending: true)
                            .limit(50)
                            .snapshots(),
                      );

                      // StreamGroupを使用してストリームをマージ
                      return StreamBuilder<QuerySnapshot>(
                        stream: Rx.merge(chatStreams.toList()),
                        builder: (context, chatSnapshot) {
                          if (chatSnapshot.hasError) {
                            return Center(
                                child: Text(
                                    'チャットの取得中にエラーが発生しました: ${chatSnapshot.error}'));
                          }

                          if (!chatSnapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          // コミュニティの情報を取得するStreamBuilder
                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('community_list')
                                .where(FieldPath.documentId,
                                    whereIn: communityIds)
                                .snapshots(),
                            builder: (context, communitySnapshot) {
                              if (!communitySnapshot.hasData) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              // アクティブなコミュニティのメッセージのみをフィルタリング
                              final activeMessages =
                                  chatSnapshot.data!.docs.where((message) {
                                final messageData =
                                    message.data() as Map<String, dynamic>;
                                return communityIds
                                    .contains(messageData['communityId']);
                              }).toList();

                              if (activeMessages.isEmpty) {
                                return const Center(
                                  child: Text('アクティブなコミュニティのメッセージがありません'),
                                );
                              }

                              return ListView.builder(
                                itemCount: activeMessages.length,
                                itemBuilder: (context, index) {
                                  final messageData = activeMessages[index]
                                      .data() as Map<String, dynamic>;
                                  final bool isCurrentUser =
                                      messageData['userId'] == currentUser?.uid;

                                  return StreamBuilder<DocumentSnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('community_list')
                                        .doc(messageData['communityId']
                                            as String?)
                                        .snapshots(),
                                    builder: (context, communityDoc) {
                                      if (!communityDoc.hasData ||
                                          communityDoc.data == null) {
                                        return const SizedBox.shrink();
                                      }

                                      final communityData = communityDoc.data!
                                          .data() as Map<String, dynamic>?;

                                      // isActiveでない場合はスキップ
                                      if (communityData?['isActive'] != true) {
                                        return const SizedBox.shrink();
                                      }

                                      final communityName =
                                          communityData?['name'] as String? ??
                                              '不明なコミュニティ';

                                      return Card(
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 8.0, vertical: 4.0),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                communityName,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  CircleAvatar(
                                                    backgroundImage: messageData[
                                                                'userPhotoURL'] !=
                                                            null
                                                        ? CachedNetworkImageProvider(
                                                            messageData[
                                                                    'userPhotoURL']
                                                                as String)
                                                        : null,
                                                    backgroundColor:
                                                        Colors.grey[200],
                                                    child: messageData[
                                                                'userPhotoURL'] ==
                                                            null
                                                        ? Icon(Icons.person,
                                                            color: Colors
                                                                .grey[600])
                                                        : null,
                                                    radius: 20,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          messageData['userName']
                                                                  as String? ??
                                                              '不明なユーザー',
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 4),
                                                        Text(messageData['text']
                                                                as String? ??
                                                            ''),
                                                        const SizedBox(
                                                            height: 4),
                                                        Text(
                                                          _formatDateTime((messageData[
                                                                      'createdAt']
                                                                  as Timestamp)
                                                              .toDate()),
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors
                                                                .grey[600],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  // 運営タブ
                  const Center(
                    child: Text('運営からのお知らせがここに表示されます'),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF00008b),
          onPressed: () {
            if (_tabController.index == 1) {
              setState(() {
                _showCommunityOptions = !_showCommunityOptions;
              });
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PostScreen(currentUser: currentUser!),
                  fullscreenDialog: true,
                ),
              );
            }
          },
          child: Icon(
            _tabController.index == 1 ? Icons.add : Icons.add,
            color: Colors.white,
          ),
          elevation: 4,
        ),
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  final DocumentSnapshot post;
  final String currentUserId;
  final bool isDetailScreen;

  const PostCard({
    Key? key,
    required this.post,
    required this.currentUserId,
    this.isDetailScreen = false,
  }) : super(key: key);

  Future<void> _handleReply(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ReplyScreen(
            currentUser: currentUser,
            originalPost: post,
          ),
          fullscreenDialog: true,
        ),
      );
    }
  }

  Future<void> _toggleLike() async {
    final postData = post.data() as Map<String, dynamic>;
    final List<String> likedBy = List<String>.from(postData['likedBy'] ?? []);
    final likes = postData['likes'] ?? 0;

    if (likedBy.contains(currentUserId)) {
      await post.reference.update({
        'likedBy': FieldValue.arrayRemove([currentUserId]),
        'likes': likes - 1,
      });
    } else {
      await post.reference.update({
        'likedBy': FieldValue.arrayUnion([currentUserId]),
        'likes': likes + 1,
      });
    }
  }

  Future<void> _toggleRetweet() async {
    final postData = post.data() as Map<String, dynamic>;
    final List<String> retweetedBy =
        List<String>.from(postData['retweetedBy'] ?? []);
    final retweets = postData['retweets'] ?? 0;

    if (retweetedBy.contains(currentUserId)) {
      await post.reference.update({
        'retweetedBy': FieldValue.arrayRemove([currentUserId]),
        'retweets': retweets - 1,
      });
    } else {
      await post.reference.update({
        'retweetedBy': FieldValue.arrayUnion([currentUserId]),
        'retweets': retweets + 1,
      });
    }
  }

  Future<void> _toggleBookmark() async {
    final postData = post.data() as Map<String, dynamic>;
    final List<String> bookmarkedBy =
        List<String>.from(postData['bookmarkedBy'] ?? []);

    if (bookmarkedBy.contains(currentUserId)) {
      await post.reference.update({
        'bookmarkedBy': FieldValue.arrayRemove([currentUserId]),
      });
    } else {
      await post.reference.update({
        'bookmarkedBy': FieldValue.arrayUnion([currentUserId]),
      });
    }
  }

  void _shareContent(BuildContext context) {
    final postData = post.data() as Map<String, dynamic>;
    final StringBuffer shareContent = StringBuffer();

    shareContent.writeln('Posted by: ${postData['userHandle']}');
    shareContent.writeln('User ID: ${postData['userId']}');
    shareContent.writeln('\n${postData['text']}');

    if (postData['hashtags'] != null &&
        (postData['hashtags'] as List).isNotEmpty) {
      shareContent.writeln('\nHashtags:');
      for (var tag in postData['hashtags']) {
        shareContent.write('#$tag ');
      }
      shareContent.writeln();
    }

    if (postData['mediaUrls'] != null &&
        (postData['mediaUrls'] as List).isNotEmpty) {
      shareContent.writeln('\nImages:');
      for (var url in postData['mediaUrls']) {
        shareContent.writeln(url);
      }
    }

    shareContent.writeln('\nInteractions:');
    shareContent.writeln('Likes: ${postData['likes'] ?? 0}');
    shareContent.writeln('Retweets: ${postData['retweets'] ?? 0}');
    shareContent.writeln('Comments: ${postData['commentCount'] ?? 0}');

    if (postData['createdAt'] != null) {
      final timestamp = (postData['createdAt'] as Timestamp).toDate();
      shareContent.writeln('\nPosted on: ${_formatDateTime(timestamp)}');
    }

    Share.share(
      shareContent.toString(),
      subject: 'Check out this post',
    );
  }

  String _formatDateTime(DateTime dateTime) {
    String year = dateTime.year.toString();
    String month = dateTime.month.toString().padLeft(2, '0');
    String day = dateTime.day.toString().padLeft(2, '0');
    String hour = dateTime.hour.toString().padLeft(2, '0');
    String minute = dateTime.minute.toString().padLeft(2, '0');

    return '$year年$month月$day日$hour時$minute分';
  }

  void _navigateToPostDetail(BuildContext context) {
    if (!isDetailScreen) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PostDetailScreen(post: post),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final postData = post.data() as Map<String, dynamic>;
    final List<String> likedBy = List<String>.from(postData['likedBy'] ?? []);
    final List<String> retweetedBy =
        List<String>.from(postData['retweetedBy'] ?? []);
    final List<String> bookmarkedBy =
        List<String>.from(postData['bookmarkedBy'] ?? []);
    final likes = postData['likes'] ?? 0;
    final retweets = postData['retweets'] ?? 0;
    final commentCount = postData['commentCount'] ?? 0;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(postData['userId'])
          .snapshots(),
      builder: (context, userSnapshot) {
        String? avatarUrl;
        if (userSnapshot.hasData && userSnapshot.data != null) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
          avatarUrl = userData?['avatarUrl'] as String?;
        }

        Widget content = Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                          ? CachedNetworkImageProvider(avatarUrl)
                          : null,
                      backgroundColor: Colors.grey[200],
                      child: avatarUrl == null || avatarUrl.isEmpty
                          ? Icon(Icons.person, color: Colors.grey[600])
                          : null,
                      radius: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '@${postData['userHandle'] ?? ''}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            postData['text'] as String,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (postData['mediaUrls'] != null &&
                    (postData['mediaUrls'] as List).isNotEmpty)
                  Container(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final List<String> mediaUrls =
                              List<String>.from(postData['mediaUrls']);
                          final bool isSingleImage = mediaUrls.length == 1;

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: isSingleImage ? 1 : 2,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 4,
                              childAspectRatio: isSingleImage
                                  ? constraints.maxWidth /
                                      (constraints.maxWidth * 0.75)
                                  : 1.0,
                            ),
                            itemCount: mediaUrls.length,
                            itemBuilder: (context, index) {
                              return CachedNetworkImage(
                                imageUrl: mediaUrls[index],
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                if (postData['hashtags'] != null &&
                    (postData['hashtags'] as List).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Wrap(
                      spacing: 4.0,
                      children: (postData['hashtags'] as List)
                          .map((tag) => Text(
                                '#$tag',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 14.0,
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInteractionButton(
                            icon: Icons.chat_bubble_outline,
                            color: Colors.grey,
                            count: commentCount,
                            onPressed: () => _handleReply(context),
                          ),
                          _buildInteractionButton(
                            icon: likedBy.contains(currentUserId)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: likedBy.contains(currentUserId)
                                ? Colors.red
                                : Colors.grey,
                            count: likes,
                            onPressed: _toggleLike,
                          ),
                          _buildInteractionButton(
                            icon: retweetedBy.contains(currentUserId)
                                ? Icons.repeat
                                : Icons.repeat,
                            color: retweetedBy.contains(currentUserId)
                                ? Colors.green
                                : Colors.grey,
                            count: retweets,
                            onPressed: _toggleRetweet,
                          ),
                          _buildInteractionButton(
                            icon: bookmarkedBy.contains(currentUserId)
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            color: bookmarkedBy.contains(currentUserId)
                                ? Colors.blue
                                : Colors.grey,
                            count: bookmarkedBy.length,
                            onPressed: _toggleBookmark,
                          ),
                          IconButton(
                            icon: const Icon(Icons.share_outlined),
                            color: Colors.grey,
                            onPressed: () => _shareContent(context),
                          ),
                        ],
                      ),
                    ),
                    if (postData['createdAt'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 0.0, left: 5.0),
                        child: Text(
                          _formatDateTime(
                              (postData['createdAt'] as Timestamp).toDate()),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );

        if (!isDetailScreen) {
          return GestureDetector(
            onTap: () => _navigateToPostDetail(context),
            child: content,
          );
        }

        return content;
      },
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required Color color,
    required int count,
    required VoidCallback onPressed,
  }) {
    return Row(
      children: [
        IconButton(
          icon: Icon(icon, color: color),
          onPressed: onPressed,
        ),
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

class PostDetailScreen extends StatelessWidget {
  final DocumentSnapshot post;

  const PostDetailScreen({
    Key? key,
    required this.post,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '投稿詳細',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          PostCard(
            post: post,
            currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
            isDetailScreen: true,
          ),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: post.reference.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final postData = snapshot.data!.data() as Map<String, dynamic>;
                final comments =
                    List<Map<String, dynamic>>.from(postData['comments'] ?? []);

                if (comments.isEmpty) {
                  return const Center(
                    child: Text('コメントはありません'),
                  );
                }

                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            comment['userPhotoURL']?.isNotEmpty == true
                                ? CachedNetworkImageProvider(
                                    comment['userPhotoURL'])
                                : null,
                        backgroundColor: Colors.grey[200],
                        child: comment['userPhotoURL']?.isNotEmpty != true
                            ? Icon(Icons.person, color: Colors.grey[600])
                            : null,
                      ),
                      title: Text(comment['userName'] ?? ''),
                      subtitle: Text(comment['text'] ?? ''),
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

String _formatDateTime(DateTime dateTime) {
  String year = dateTime.year.toString();
  String month = dateTime.month.toString().padLeft(2, '0');
  String day = dateTime.day.toString().padLeft(2, '0');
  String hour = dateTime.hour.toString().padLeft(2, '0');
  String minute = dateTime.minute.toString().padLeft(2, '0');
  return '$year年$month月$day日 $hour:$minute';
}
