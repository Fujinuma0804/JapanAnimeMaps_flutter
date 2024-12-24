import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:parts/post_page/community_list_screen.dart';
import 'package:parts/post_page/community_setting/community_scanner.dart';
import 'package:parts/post_page/make_community.dart';
import 'package:parts/post_page/post_first/community_chat.dart';
import 'package:parts/post_page/post_screen.dart';
import 'package:parts/post_page/report_posts_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vibration/vibration.dart';

import 'management_tab.dart';

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
        if (snapshot.docs.isNotEmpty) {
          _lastDocument = snapshot.docs.last;
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
      _lastDocument = null;
      _hasMore = true;
      _isLoadingMore = false;
    });
  }

  Widget _buildTimelineContent() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(currentUser?.uid).snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          return Center(
            child: Text('エラーが発生しました: ${userSnapshot.error}'),
          );
        }

        if (!userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // ブロックされたユーザーのリストを取得
        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
        final List<String> blockedUsers =
            List<String>.from(userData?['blockedUsers'] ?? []);

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('posts')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('エラーが発生しました: ${snapshot.error}'),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final allPosts = snapshot.data!.docs;
            final posts = allPosts.where((doc) {
              final postData = doc.data() as Map<String, dynamic>;
              return !blockedUsers.contains(postData['userId']);
            }).toList();

            if (posts.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.post_add, size: 64, color: Colors.grey),
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
              );
            }

            return ListView.builder(
              key: const PageStorageKey<String>('timeline_list'),
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                return PostCard(
                  key: ValueKey(posts[index].id),
                  post: posts[index],
                  currentUserId: currentUser?.uid ?? '',
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCommunityOptions() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _showCommunityOptions ? 200 : 0,
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
            ListTile(
              leading: const Icon(Icons.qr_code_scanner_outlined),
              title: const Text('QRコードで参加'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QRScannerPage(),
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
                height: 500,
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
                          final bool isActive =
                              communityData['isActive'] == true;
                          final communityName =
                              communityData['name'] as String? ?? '';
                          final matchesSearch = communityName
                              .toLowerCase()
                              .contains(_searchQuery.toLowerCase());
                          return isActive && matchesSearch;
                        }).toList();

                        if (filteredDocs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off,
                                    size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'アクティブなコミュニティがありません'
                                      : '「$_searchQuery」に一致するコミュニティが見つかりません',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
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
                                          communityData['memberCount'] ?? 1,
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
            // const SliverToBoxAdapter(child: Divider()),
            // const SliverToBoxAdapter(
            //   child: Padding(
            //     padding: EdgeInsets.only(left: 16.0, top: 8.0),
            //     child: Text(
            //       'その他',
            //       style: TextStyle(
            //         color: Colors.grey,
            //         fontWeight: FontWeight.bold,
            //       ),
            //     ),
            //   ),
            // ),
            // const SliverToBoxAdapter(
            //   child: ListTile(
            //     leading: Icon(Icons.settings),
            //     title: Text('コミュニティ設定'),
            //   ),
            // ),
            // const SliverToBoxAdapter(
            //   child: ListTile(
            //     leading: Icon(Icons.help),
            //     title: Text('ヘルプ'),
            //   ),
            // ),
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
                    // Navigator.of(context).push<void>(
                    //   MaterialPageRoute(
                    //     builder: (context) => ProfilePage(),
                    //   ),
                    // );
                  },
                );
              },
            ),
          ],
          // leading: IconButton(
          //   icon: const Icon(
          //     Icons.settings_outlined,
          //     color: Color(0xFF00008b),
          //   ),
          //   onPressed: () {
          //     _scaffoldKey.currentState?.openDrawer();
          //   },
          // ),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'おすすめ'),
              Tab(text: 'コミュニティ'),
              Tab(text: '運営'),
            ],
            labelColor: const Color(0xFF00008b),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF00008b),
            indicatorWeight: 2,
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
                    child: _buildTimelineContent(),
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
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: const Icon(Icons.group_outlined,
                                    size: 64, color: Color(0xFF00008b)),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                '参加しているコミュニティがありません',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00008b),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'コミュニティに参加して、みんなと交流しましょう！',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CommunityListScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00008b),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: const Text('参加中のコミュニティを検索'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CommunityListScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00008b),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: const Text('コミュニティを検索'),
                              ),
                            ],
                          ),
                        );
                      }

                      final communityIds =
                          communities.map((doc) => doc.id).toList();

                      return Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  spreadRadius: 0,
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: '参加中のコミュニティを検索',
                                prefixIcon: const Icon(Icons.search,
                                    color: Color(0xFF00008b)),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear,
                                            color: Color(0xFF00008b)),
                                        onPressed: () {
                                          setState(() {
                                            _searchController.clear();
                                            _searchQuery = '';
                                          });
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 16),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
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

                                var filteredDocs =
                                    communitySnapshot.data!.docs.where((doc) {
                                  final communityData =
                                      doc.data() as Map<String, dynamic>;
                                  final bool isActive =
                                      communityData['isActive'] == true;
                                  final String communityName =
                                      (communityData['name'] as String? ?? '')
                                          .toLowerCase();
                                  final String hashtag =
                                      (communityData['hashtag'] as String? ??
                                              '')
                                          .toLowerCase();
                                  final String invitationCode =
                                      (communityData['invitationCode']
                                                  as String? ??
                                              '')
                                          .toLowerCase();

                                  final searchQuery =
                                      _searchQuery.toLowerCase();
                                  final bool matchesSearch =
                                      communityName.contains(searchQuery) ||
                                          hashtag.contains(searchQuery) ||
                                          invitationCode.contains(searchQuery);

                                  return isActive && matchesSearch;
                                }).toList();

                                if (filteredDocs.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.search_off,
                                            size: 64, color: Colors.grey[400]),
                                        const SizedBox(height: 16),
                                        Text(
                                          _searchQuery.isEmpty
                                              ? 'アクティブなコミュニティがありません'
                                              : '「$_searchQuery」に一致するコミュニティが見つかりません\n(コミュニティ名、ハッシュタグ、招待コードで検索できます)',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  itemCount: filteredDocs.length,
                                  itemBuilder: (context, index) {
                                    final community = filteredDocs[index];
                                    final communityData = community.data()
                                        as Map<String, dynamic>;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey.withOpacity(0.1),
                                            spreadRadius: 0,
                                            blurRadius: 10,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    GroupChatScreen(
                                                  roomName:
                                                      communityData['name'] ??
                                                          '不明なコミュニティ',
                                                  communityId: community.id,
                                                  participantCount:
                                                      communityData[
                                                              'memberCount'] ??
                                                          0,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 60,
                                                  height: 60,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                    color: Colors.grey[100],
                                                    image: communityData[
                                                                'backgroundImageUrl'] !=
                                                            null
                                                        ? DecorationImage(
                                                            image:
                                                                CachedNetworkImageProvider(
                                                              communityData[
                                                                  'backgroundImageUrl'],
                                                            ),
                                                            fit: BoxFit.cover,
                                                          )
                                                        : null,
                                                  ),
                                                  child: communityData[
                                                              'backgroundImageUrl'] ==
                                                          null
                                                      ? Icon(Icons.group,
                                                          color:
                                                              Colors.grey[400],
                                                          size: 30)
                                                      : null,
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        communityData['name'] ??
                                                            '不明なコミュニティ',
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              Color(0xFF00008b),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          Icon(Icons.people,
                                                              size: 16,
                                                              color: Colors
                                                                  .grey[600]),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            '${communityData['memberCount'] ?? 1}人が参加中',
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .grey[600],
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Icon(Icons.chevron_right,
                                                    color: Colors.grey[400],
                                                    size: 24),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  // 運営タブ
                  const ManagementTab(),
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

// PostCard クラスの実装
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

  // テキストを省略する処理
  String _truncateText(String text, {int maxLength = 10}) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

  // シェア用の画像を生成
// シェア用の画像を生成

  Future<void> _shareContent(BuildContext context) async {
    final postData = post.data() as Map<String, dynamic>;
    final StringBuffer shareContent = StringBuffer();

    // ユーザーハンドルを取得
    final String userHandle = postData['userHandle'] as String? ?? 'unknown';

    // テキストを取得して省略
    final String originalText = postData['text'] as String? ?? '';
    final String truncatedText = originalText.length <= 10
        ? originalText
        : '${originalText.substring(0, 10)}...';

    // 画像の有無をチェック
    final bool hasImages = postData['mediaUrls'] != null &&
        (postData['mediaUrls'] as List).isNotEmpty;

    // シェアするコンテンツを構築
    shareContent.writeln('$userHandleさんの投稿');
    shareContent.writeln(truncatedText);

    if (hasImages) {
      shareContent.writeln('\n📷 画像付きの投稿です');
    }

    // 興味を引くようなメッセージを追加
    shareContent.writeln('\n👉 タップして続きを読む');

    // シェアを実行
    await Share.share(shareContent.toString(), subject: '$userHandleさんの投稿');
  }

  Future<void> _handleReply(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final userId = userData['id'] ?? '';

        if (userId.isNotEmpty) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ReplyScreen(
                currentUser: currentUser,
                originalPost: post,
              ),
              fullscreenDialog: true,
            ),
          );
        } else {
          print('User ID is not set in the user document');
        }
      } else {
        print('User document not found');
      }
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
    try {
      final postData = post.data() as Map<String, dynamic>;
      final List<String> retweetedBy =
          List<String>.from(postData['retweetedBy'] ?? []);

      final querySnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('originalPostId', isEqualTo: post.id)
          .where('userId', isEqualTo: currentUserId)
          .where('type', isEqualTo: 'repost')
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        for (var doc in querySnapshot.docs) {
          await doc.reference.delete();
        }

        await post.reference.update({
          'retweetedBy': FieldValue.arrayRemove([currentUserId]),
          'retweets': FieldValue.increment(-1),
        });
      } else {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .get();

        if (!userDoc.exists) {
          print('User document not found for ID: $currentUserId');
          return;
        }

        final userData = userDoc.data() as Map<String, dynamic>;
        final userId = userData['id'] ?? '';

        if (userId.isEmpty) {
          print('User ID is empty');
          return;
        }

        final newPostData = {
          'userId': currentUserId,
          'userHandle': userId,
          'text': postData['text'],
          'mediaUrls': postData['mediaUrls'] ?? [],
          'hashtags': postData['hashtags'] ?? [],
          'likes': 0,
          'likedBy': [],
          'retweets': 0,
          'retweetedBy': [],
          'bookmarkedBy': [],
          'commentCount': 0,
          'createdAt': Timestamp.now(),
          'type': 'repost',
          'originalPostId': post.id,
          'originalUserId': postData['userId'],
          'originalUserHandle': postData['userHandle'],
        };

        await FirebaseFirestore.instance.collection('posts').add(newPostData);

        await post.reference.update({
          'retweetedBy': FieldValue.arrayUnion([currentUserId]),
          'retweets': FieldValue.increment(1),
        });
      }
    } catch (e) {
      print('Error in _toggleRetweet: $e');
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

  void _navigateToPostDetail(BuildContext context) {
    if (!isDetailScreen) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PostDetailScreen(post: post),
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
    return '$year年$month月$day日$hour時$minute分';
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
    final commentCount = postData['replyCount'] ?? 0;
    final isReply = postData['type'] == 'reply';
    final isRepost = postData['type'] == 'repost';

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
                if (isRepost)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.repeat,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '@${postData['originalUserHandle']}さんの投稿を再投稿しました',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                                '@${postData['userHandle']}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isReply)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '返信された投稿',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12),
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
                            icon: const Icon(Icons.ios_share),
                            color: Colors.grey,
                            onPressed: () => _shareContent(context),
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_vert),
                            color: Colors.grey,
                            onPressed: () {
                              // ここにmoreボタンの処理を追加
                              showModalBottomSheet(
                                context: context,
                                builder: (BuildContext context) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.flag),
                                          title: const Text('投稿を報告'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            // 報告機能の処理を追加
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    ReportPostsPage(
                                                  communityId: '',
                                                  userHandle: '',
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.block),
                                          title: const Text('このユーザーをブロック'),
                                          onTap: () async {
                                            Navigator.pop(context);
                                            try {
                                              // 現在のユーザーのドキュメントを取得
                                              final currentUserDoc =
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('users')
                                                      .doc(currentUserId)
                                                      .get();

                                              // blockedUsers配列を取得（存在しない場合は空配列を使用）
                                              List<String> blockedUsers =
                                                  List<String>.from(
                                                      currentUserDoc.data()?[
                                                              'blockedUsers'] ??
                                                          []);

                                              // ブロックするユーザーのIDを追加
                                              if (!blockedUsers.contains(
                                                  postData['userId'])) {
                                                blockedUsers
                                                    .add(postData['userId']);

                                                // Firestoreを更新
                                                await FirebaseFirestore.instance
                                                    .collection('users')
                                                    .doc(currentUserId)
                                                    .update({
                                                  'blockedUsers': blockedUsers,
                                                });

                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content:
                                                        Text('ユーザーをブロックしました'),
                                                    duration:
                                                        Duration(seconds: 2),
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              print('Error blocking user: $e');
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content:
                                                      Text('ユーザーのブロックに失敗しました'),
                                                  duration:
                                                      Duration(seconds: 2),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
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
}

// 投稿詳細画面
class PostDetailScreen extends StatelessWidget {
  final DocumentSnapshot post;

  const PostDetailScreen({
    Key? key,
    required this.post,
  }) : super(key: key);

  // 返信を表示するウィジェット（レベルは0か1か2のみ）
  Widget _buildReply(DocumentSnapshot reply, int level) {
    double leftMargin = level == 0 ? 32 : (level == 1 ? 52 : 52);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // インデントと接続線
            SizedBox(
              width: leftMargin + 16,
              height: 40,
              child: CustomPaint(
                painter: ReplyLinePainter(),
              ),
            ),
            // 返信カード
            Expanded(
              child: Container(
                transform: Matrix4.translationValues(0, -4, 0),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: Transform.scale(
                    scale: 0.95,
                    alignment: Alignment.topLeft,
                    child: PostCard(
                      post: reply,
                      currentUserId:
                          FirebaseAuth.instance.currentUser?.uid ?? '',
                      isDetailScreen: true,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        // この返信に対する返信を取得して表示
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .where('originalPostId', isEqualTo: reply.id)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }

            return Column(
              children: snapshot.data!.docs.map((nestedReply) {
                return _buildReply(nestedReply, level + 1);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '投稿詳細',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF00008b)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .doc(post.id)
            .snapshots(),
        builder: (context, originalPostSnapshot) {
          if (!originalPostSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // オリジナルの投稿
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8.0),
                  child: PostCard(
                    post: originalPostSnapshot.data!,
                    currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
                    isDetailScreen: true,
                  ),
                ),
                // 最初のレベルの返信を取得
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('originalPostId', isEqualTo: post.id)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, repliesSnapshot) {
                    if (repliesSnapshot.hasError) {
                      return Center(
                        child: Text('エラーが発生しました: ${repliesSnapshot.error}'),
                      );
                    }

                    if (!repliesSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final replies = repliesSnapshot.data!.docs;

                    if (replies.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: Text(
                            '返信はまだありません',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: replies.map((reply) {
                        return _buildReply(reply, 0);
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00008b),
        onPressed: () async {
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
        },
        child: const Icon(Icons.reply, color: Colors.white),
      ),
    );
  }
}

// 返信の接続線を描画するカスタムペインター
class ReplyLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // 縦線を描画
    canvas.drawLine(
      Offset(size.width - 16, 0),
      Offset(size.width - 16, size.height * 0.5),
      paint,
    );

    // 横線を描画
    canvas.drawLine(
      Offset(size.width - 16, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// ReplyScreen の実装
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

class _ReplyScreenState extends State<ReplyScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<String> _selectedImages = [];
  bool _isSubmitting = false;

  List<String> _extractHashtags(String text) {
    final hashtags = <String>[];
    final hashtagRegex = RegExp(r'#(\w+)');
    final matches = hashtagRegex.allMatches(text);

    for (var match in matches) {
      if (match.group(1) != null) {
        hashtags.add(match.group(1)!);
      }
    }

    return hashtags;
  }

  Future<void> _submitReply() async {
    if (_textController.text.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // ユーザードキュメントを取得
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUser.uid)
          .get();

      if (!userDoc.exists) {
        print('User document not found');
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final userId = userData['id'] ?? ''; // id フィールドを使用

      if (userId.isEmpty) {
        print('User ID is not set');
        return;
      }

      final newPost = {
        'text': _textController.text,
        'userId': widget.currentUser.uid,
        'userHandle': userId, // id を userHandle として使用
        'createdAt': Timestamp.now(),
        'likes': 0,
        'likedBy': [],
        'retweets': 0,
        'retweetedBy': [],
        'bookmarkedBy': [],
        'commentCount': 0,
        'type': 'reply',
        'originalPostId': widget.originalPost.id,
        'mediaUrls': _selectedImages,
        'hashtags': _extractHashtags(_textController.text),
      };

      // 返信を投稿
      await FirebaseFirestore.instance.collection('posts').add(newPost);

      // 元の投稿の返信数を更新
      await widget.originalPost.reference.update({
        'replyCount': FieldValue.increment(1),
      });

      Navigator.of(context).pop();
    } catch (e) {
      print('Error submitting reply: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('返信の投稿中にエラーが発生しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '返信を作成',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF00008b)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submitReply,
            child: Text(
              _isSubmitting ? '投稿中...' : '投稿',
              style: TextStyle(
                color: _isSubmitting ? Colors.grey : const Color(0xFF00008b),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 元の投稿の表示
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.originalPost.get('userId'))
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox.shrink();
                      }

                      final userData =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      final avatarUrl = userData?['avatarUrl'] as String?;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundImage:
                                avatarUrl != null && avatarUrl.isNotEmpty
                                    ? CachedNetworkImageProvider(avatarUrl)
                                    : null,
                            backgroundColor: Colors.grey[200],
                            child: avatarUrl == null || avatarUrl.isEmpty
                                ? Icon(Icons.person, color: Colors.grey[600])
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '@${widget.originalPost.get('userHandle')}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(widget.originalPost.get('text')),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // 返信入力フィールド
                  TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: '返信を入力...',
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                    autofocus: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
