import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'anime_list_detail.dart';

class FavoriteLocationsPage extends StatefulWidget {
  @override
  _FavoriteLocationsPageState createState() => _FavoriteLocationsPageState();
}

class _FavoriteLocationsPageState extends State<FavoriteLocationsPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  String searchQuery = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchFavoriteLocations() async {
    List<Map<String, dynamic>> favoriteLocations = [];
    try {
      User? user = auth.currentUser;
      if (user == null) {
        throw 'ユーザーがログインしていません';
      }
      String userID = user.uid;
      print('User ID: $userID');

      QuerySnapshot favoriteSnapshot = await firestore
          .collection('users')
          .doc(userID)
          .collection('favorites')
          .get();

      for (var doc in favoriteSnapshot.docs) {
        String locationId = doc.id;
        print('Fetching location data for location ID: $locationId');

        DocumentSnapshot locationDoc =
        await firestore.collection('locations').doc(locationId).get();

        if (locationDoc.exists) {
          print('Location data for $locationId: ${locationDoc.data()}');
          Map<String, dynamic> locationData =
          locationDoc.data() as Map<String, dynamic>;
          locationData['isFavorite'] = true;
          locationData['id'] = locationId;
          locationData['subMedia'] =
              (locationData['subMedia'] as List<dynamic>?)
                  ?.map((item) => item as Map<String, dynamic>)
                  .toList() ??
                  [];
          favoriteLocations.add(locationData);
        } else {
          print("Location ID $locationId does not exist.");
        }
      }
    } catch (e) {
      print("お気に入りの場所の取得中にエラーが発生しました: $e");
    }
    return favoriteLocations;
  }

  Future<List<Map<String, dynamic>>> _searchFavorites(String query) async {
    List<Map<String, dynamic>> searchResults = [];
    try {
      User? user = auth.currentUser;
      if (user == null) {
        throw 'ユーザーがログインしていません';
      }
      String userID = user.uid;

      QuerySnapshot favoriteSnapshot = await firestore
          .collection('users')
          .doc(userID)
          .collection('favorites')
          .get();

      for (var doc in favoriteSnapshot.docs) {
        String locationId = doc.id;
        DocumentSnapshot locationDoc =
        await firestore.collection('locations').doc(locationId).get();

        if (locationDoc.exists) {
          Map<String, dynamic> locationData =
          locationDoc.data() as Map<String, dynamic>;

          String title = locationData['title'] ?? '';
          String description = locationData['description'] ?? '';

          if (title.toLowerCase().contains(query.toLowerCase()) ||
              description.toLowerCase().contains(query.toLowerCase())) {
            locationData['isFavorite'] = true;
            locationData['id'] = locationId;
            locationData['subMedia'] =
                (locationData['subMedia'] as List<dynamic>?)
                    ?.map((item) => item as Map<String, dynamic>)
                    .toList() ??
                    [];
            searchResults.add(locationData);
          }
        }
      }
    } catch (e) {
      print("お気に入りの検索中にエラーが発生しました: $e");
    }
    return searchResults;
  }

  Future<void> _toggleFavorite(String locationId) async {
    try {
      User? user = auth.currentUser;
      if (user == null) {
        throw 'ユーザーがログインしていません';
      }
      String userID = user.uid;

      DocumentReference favoriteRef = firestore
          .collection('users')
          .doc(userID)
          .collection('favorites')
          .doc(locationId);

      DocumentSnapshot favoriteDoc = await favoriteRef.get();

      if (favoriteDoc.exists) {
        await favoriteRef.delete();
        print('Removed from favorites');

        // お気に入り削除の通知
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'お気に入りから削除しました',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            backgroundColor: Colors.grey.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 50),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        await favoriteRef.set({'timestamp': FieldValue.serverTimestamp()});
        print('Added to favorites');

        // お気に入り追加の通知
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'お気に入りに追加しました',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print("お気に入りの切り替え中にエラーが発生しました: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'お気に入りスポット',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF3498DB).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () {
                showSearch(
                  context: context,
                  delegate: LocationSearchDelegate(
                    onSearch: _searchFavorites,
                    toggleFavorite: _toggleFavorite,
                  ),
                );
              },
              icon: const Icon(
                Icons.search,
                color: Color(0xFF3498DB),
                size: 24,
              ),
              tooltip: '検索',
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchFavoriteLocations(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF3498DB),
                  ),
                ),
              );
            } else if (snapshot.hasError) {
              return Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade400,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'エラーが発生しました',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.favorite_border,
                        size: 64,
                        color: Colors.red.shade300,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'お気に入りのスポットがありません',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'お気に入りのスポットを探してみましょう！',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF7F8C8D),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              final favoriteLocations = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: favoriteLocations.length,
                itemBuilder: (context, index) {
                  final location = favoriteLocations[index];

                  return AnimatedContainer(
                    duration: Duration(milliseconds: 300 + (index * 100)),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Material(
                      elevation: 0,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3498DB).withOpacity(0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () => _navigateToDetails(context, location),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
                                      width: 1,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: location['imageUrl'] != null && location['imageUrl'].toString().isNotEmpty
                                        ? CachedNetworkImage(
                                      imageUrl: location['imageUrl'],
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) {
                                        return Container(
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF3498DB),
                                                Color(0xFF2ECC71),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(15),
                                          ),
                                          child: const Icon(
                                            Icons.location_on,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        );
                                      },
                                      placeholder: (context, url) => Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8F9FA),
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Color(0xFF3498DB),
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                        : Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF3498DB),
                                            Color(0xFF2ECC71),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: const Icon(
                                        Icons.location_on,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        location['title'] ?? 'タイトルなし',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2C3E50),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        location['description'] ?? 'サブタイトルなし',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF7F8C8D),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: InkWell(
                                    onTap: () => _toggleFavorite(location['id']),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Icon(
                                      location['isFavorite'] ? Icons.favorite : Icons.favorite_border,
                                      color: Colors.red.shade400,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }

  void _navigateToDetails(BuildContext context, Map<String, dynamic> location) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpotDetailScreen(
          locationId: location['id'] ?? '',
          title: location['title'] ?? 'Not title',
          description: location['description'] ?? 'Not Description',
          spot_description:
          location['spot_description'] ?? 'Not spot_description',
          latitude: location['latitude'] ?? 0.0,
          longitude: location['longitude'] ?? 0.0,
          imageUrl: location['imageUrl'] ?? '',
          sourceTitle: location['sourceTitle'] ?? 'Not Quote source',
          sourceLink: location['sourceLink'] ?? 'Not Link',
          url: location['url'] ?? '',
          animeName: location['animeName'] ?? '',
          userId: location['userId'] ?? '',
          subMedia: (location['subMedia'] as List<dynamic>?)
              ?.map((item) => item as Map<String, dynamic>)
              .toList() ??
              [],
        ),
      ),
    );
  }
}

class LocationSearchDelegate extends SearchDelegate {
  final Future<List<Map<String, dynamic>>> Function(String) onSearch;
  final Future<void> Function(String) toggleFavorite;

  LocationSearchDelegate({
    required this.onSearch,
    required this.toggleFavorite,
  });

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      Container(
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF3498DB).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: const Icon(Icons.clear, color: Color(0xFF3498DB)),
          onPressed: () {
            query = '';
          },
        ),
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF3498DB).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF3498DB)),
        onPressed: () {
          close(context, null);
        },
      ),
    );
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: const AppBarTheme(
        color: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.grey),
      ),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: onSearch(query),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3498DB)),
              ),
            );
          } else if (snapshot.hasError) {
            return Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade400,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'エラーが発生しました',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3498DB).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.search_off,
                      size: 64,
                      color: Color(0xFF3498DB),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '検索結果が見つかりません',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '別のキーワードで検索してみてください',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF7F8C8D),
                    ),
                  ),
                ],
              ),
            );
          } else {
            final searchResults = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final location = searchResults[index];
                return AnimatedContainer(
                  duration: Duration(milliseconds: 300 + (index * 100)),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Material(
                    elevation: 0,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3498DB).withOpacity(0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SpotDetailScreen(
                                locationId: location['id'] ?? '',
                                title: location['title'] ?? 'Not title',
                                description: location['description'] ?? 'Not Description',
                                spot_description: location['spot_description'] ?? 'spot_description',
                                latitude: location['latitude'] ?? 0.0,
                                longitude: location['longitude'] ?? 0.0,
                                imageUrl: location['imageUrl'] ?? '',
                                sourceTitle: location['sourceTitle'] ?? 'Not Quote source',
                                sourceLink: location['sourceLink'] ?? 'Not Link',
                                url: location['url'] ?? '',
                                animeName: location['animeName'] ?? '',
                                userId: location['userId'] ?? '',
                                subMedia: (location['subMedia'] as List<dynamic>?)
                                    ?.map((item) => item as Map<String, dynamic>)
                                    .toList() ?? [],
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                    width: 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: location['imageUrl'] != null && location['imageUrl'].toString().isNotEmpty
                                      ? CachedNetworkImage(
                                    imageUrl: location['imageUrl'],
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF3498DB),
                                              Color(0xFF2ECC71),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                        child: const Icon(
                                          Icons.location_on,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      );
                                    },
                                    placeholder: (context, url) => Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8F9FA),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Color(0xFF3498DB),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                      : Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF3498DB),
                                          Color(0xFF2ECC71),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      location['title'] ?? 'タイトルなし',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2C3E50),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      location['description'] ?? 'サブタイトルなし',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF7F8C8D),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  onTap: () => toggleFavorite(location['id']),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Icon(
                                    location['isFavorite'] ? Icons.favorite : Icons.favorite_border,
                                    color: Colors.red.shade400,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF3498DB).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search,
                size: 64,
                color: Color(0xFF3498DB),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '検索キーワードを入力してください',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'お気に入りスポットから検索します',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF7F8C8D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}