import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parts/post_page/profile_edit.dart';

class ProfilePage extends StatefulWidget {
  ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String bio = "";
  final String location = "";
  final String website = "";
  String favoriteAnime = "";
  static const int _pageSize = 10;
  List<DocumentSnapshot> _posts = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitialPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialPosts() async {
    try {
      final querySnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize)
          .get();

      setState(() {
        _posts = querySnapshot.docs;
        if (_posts.isNotEmpty) {
          _lastDocument = _posts.last;
        }
        _hasMore = querySnapshot.docs.length == _pageSize;
      });
    } catch (e) {
      print('Error loading initial posts: $e');
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMorePosts();
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _posts = [];
      _lastDocument = null;
      _hasMore = true;
    });
    await _loadInitialPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        backgroundColor: Colors.white,
        color: Color(0xFF00008b),
        child: CustomScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 150.0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: Color(0xFF00008b),
                ),
              ),
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.white,
                  ),
                  onPressed: () {},
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(),
                  _buildProfileInfo(),
                  _buildTabBar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection('users')
          .doc(_auth.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final avatarUrl = userData['avatarUrl'];
        final userName = userData['name'] ?? 'Unknown User';
        final userId = userData['id'] ?? 'unknown';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8),
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? Icon(Icons.person, color: Colors.grey[600], size: 40)
                        : null,
                  ),
                  SizedBox(height: 12),
                  Text(
                    userName,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "@$userId",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(top: 56),
                  child: ElevatedButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfilePage(
                            currentName: userName,
                            currentBio: bio,
                            currentLocation: location,
                            currentWebsite: website,
                            currentFavoriteAnime: '',
                          ),
                        ),
                      );

                      if (result != null) {
                        print('Updated profile: $result');
                      }
                    },
                    child: Text(
                      'プロフィールを編集',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00008b),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileInfo() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection('users')
          .doc(_auth.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox.shrink();
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final bio = userData['bio'] ?? '';
        final location = userData['location'] ?? '';
        final website = userData['website'] ?? '';
        final favoriteAnime = userData['favoriteAnime'] ?? '';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (bio.isNotEmpty) _buildExpandableBio(bio),
              SizedBox(height: 12),
              Row(
                children: [
                  if (location.isNotEmpty) ...[
                    Icon(Icons.location_on, size: 16, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(location, style: TextStyle(color: Colors.grey)),
                    SizedBox(width: 16),
                  ],
                  if (website.isNotEmpty) ...[
                    Icon(Icons.link, size: 16, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(website, style: TextStyle(color: Colors.blue)),
                  ],
                ],
              ),
              if (favoriteAnime.isNotEmpty) ...[
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.movie, size: 16, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(
                      favoriteAnime,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ],
              SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpandableBio(String bio) {
    final lines = bio.split('\n');
    bool needsExpansion = lines.length > 3;

    return StatefulBuilder(
      builder: (context, setState) {
        bool isExpanded = false;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isExpanded ? bio : lines.take(3).join('\n'),
              style: TextStyle(fontSize: 14),
              maxLines: isExpanded ? null : 3,
              overflow: isExpanded ? null : TextOverflow.ellipsis,
            ),
            if (needsExpansion)
              GestureDetector(
                onTap: () {
                  setState(() {
                    isExpanded = !isExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    isExpanded ? '閉じる' : 'もっとみる',
                    style: TextStyle(
                      color: Color(0xFF00008b),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTabBar() {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            padding: EdgeInsets.zero,
            tabs: [
              Tab(text: '投稿'),
              Tab(text: '返信'),
              Tab(text: 'いいね'),
              Tab(text: '保存'),
            ],
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF00008b),
          ),
          Container(
            height: 300,
            child: TabBarView(
              children: [
                RefreshIndicator(
                  onRefresh: _refreshData,
                  backgroundColor: Colors.white,
                  color: Color(0xFF00008b),
                  child: _buildTweetList(),
                ),
                RefreshIndicator(
                  onRefresh: _refreshData,
                  backgroundColor: Colors.white,
                  color: Color(0xFF00008b),
                  child: _buildTweetList(),
                ),
                RefreshIndicator(
                  onRefresh: _refreshData,
                  backgroundColor: Colors.white,
                  color: Color(0xFF00008b),
                  child: _buildTweetList(),
                ),
                BookmarkedPostsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.year}/${date.month}/${date.day} ${date.hour}:${date.minute}';
  }

  Widget _buildTweetList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('エラーが発生しました'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return ListView(
            physics: AlwaysScrollableScrollPhysics(),
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 50.0),
                  child: Text('投稿はありません'),
                ),
              ),
            ],
          );
        }

        _posts = snapshot.data!.docs;

        return ListView.builder(
          controller: _scrollController,
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _posts.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _posts.length) {
              if (_hasMore) {
                _loadMorePosts();
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              return SizedBox.shrink();
            }

            final post = _posts[index];
            final data = post.data() as Map<String, dynamic>;

            final userHandle = data['userHandle'] ?? 'unknown';
            final text = data['text'] ?? '';
            final authorRef = data['userId'] as String;

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(authorRef).get(),
              builder: (context, userSnapshot) {
                String? avatarUrl;
                if (userSnapshot.hasData && userSnapshot.data != null) {
                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>?;
                  avatarUrl = userData?['avatarUrl'];
                }

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[300],
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? Icon(Icons.person, color: Colors.grey[600])
                        : null,
                  ),
                  title: Text(userHandle),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(text),
                      if (data['createdAt'] != null)
                        Text(
                          _formatDate(data['createdAt']),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                  trailing: Icon(Icons.more_vert),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final lastDoc = _posts.last;
      final morePostsSnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(lastDoc)
          .limit(_pageSize)
          .get();

      if (morePostsSnapshot.docs.isNotEmpty) {
        setState(() {
          _posts.addAll(morePostsSnapshot.docs);
          _hasMore = morePostsSnapshot.docs.length == _pageSize;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Error loading more posts: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }
}

class BookmarkedPostsView extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _refreshData() async {
    return Future<void>.delayed(Duration(seconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      backgroundColor: Colors.white,
      color: Color(0xFF00008b),
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('posts')
            .where('bookmarkedBy', arrayContains: _auth.currentUser?.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return ListView(
              physics: AlwaysScrollableScrollPhysics(),
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 50.0),
                    child: Text('保存された投稿はありません'),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final post = snapshot.data!.docs[index];
              return _buildBookmarkedPostTile(post);
            },
          );
        },
      ),
    );
  }

  Widget _buildBookmarkedPostTile(DocumentSnapshot post) {
    final data = post.data() as Map<String, dynamic>;
    final userHandle = data['userHandle'] ?? 'unknown';
    final text = data['text'] ?? '';
    final authorRef = data['userId'] as String;

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(authorRef).get(),
      builder: (context, userSnapshot) {
        String? avatarUrl;
        if (userSnapshot.hasData && userSnapshot.data != null) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
          avatarUrl = userData?['avatarUrl'];
        }

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey[300],
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? Icon(Icons.person, color: Colors.grey[600])
                : null,
          ),
          title: Text(userHandle),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text),
              if (data['createdAt'] != null)
                Text(
                  _formatDate(data['createdAt']),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
          trailing: PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Text('ブックマークから削除'),
                onTap: () => _removeBookmark(post.id),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.year}/${date.month}/${date.day} ${date.hour}:${date.minute}';
  }

  Future<void> _removeBookmark(String postId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _firestore.collection('posts').doc(postId).update({
        'bookmarkedBy': FieldValue.arrayRemove([currentUser.uid])
      });
    } catch (e) {
      print('Error removing bookmark: $e');
    }
  }
}
