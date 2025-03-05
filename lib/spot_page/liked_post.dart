import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'anime_list_detail.dart';

class FavoriteLocationsPage extends StatefulWidget {
  @override
  _FavoriteLocationsPageState createState() => _FavoriteLocationsPageState();
}

class _FavoriteLocationsPageState extends State<FavoriteLocationsPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  String searchQuery = '';

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
      } else {
        await favoriteRef.set({'timestamp': FieldValue.serverTimestamp()});
        print('Added to favorites');
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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'お気に入りスポット',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              showSearch(
                context: context,
                delegate: LocationSearchDelegate(
                  onSearch: _searchFavorites,
                  toggleFavorite: _toggleFavorite,
                ),
              );
            },
            icon: Icon(
              Icons.search,
              color: Color(0xFF00008b),
              size: 28,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFF5F5F5)],
          ),
        ),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchFavoriteLocations(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00008b)),
                ),
              );
            } else if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                    SizedBox(height: 16),
                    Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'お気に入りのスポットが見つかりません。',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              );
            } else {
              final favoriteLocations = snapshot.data!;
              return ListView.builder(
                padding: EdgeInsets.all(12.0),
                itemCount: favoriteLocations.length,
                itemBuilder: (context, index) {
                  final location = favoriteLocations[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: GestureDetector(
                      onTap: () => _navigateToDetails(context, location),
                      child: Card(
                        elevation: 4,
                        shadowColor: Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            // 画像部分
                            ClipRRect(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                              ),
                              child: Hero(
                                tag: 'location_image_${location['id']}',
                                child: CachedNetworkImage(
                                  imageUrl: location['imageUrl'] ?? '',
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[200],
                                    width: 120,
                                    height: 120,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            Color(0xFF00008b)),
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: Colors.grey[200],
                                    width: 120,
                                    height: 120,
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // テキスト部分
                            Expanded(
                              child: Container(
                                height: 120,
                                child: Stack(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            location['title'] ?? 'No title',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Color(0xFF00008b),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 8),
                                          Expanded(
                                            child: Text(
                                              location['description'] ?? 'Not Description',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[700],
                                                height: 1.3,
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // お気に入りボタン
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.8),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black12,
                                              spreadRadius: 1,
                                              blurRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: IconButton(
                                          icon: Icon(
                                            location['isFavorite']
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color: Colors.redAccent,
                                            size: 20,
                                          ),
                                          onPressed: () => _toggleFavorite(location['id']),
                                          padding: EdgeInsets.all(6),
                                          constraints: BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
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
          animeName: '',
          userId: '',
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
      IconButton(
        icon: Icon(Icons.clear, color: Color(0xFF00008b)),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back, color: Color(0xFF00008b)),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: AppBarTheme(
        color: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.grey),
      ),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFF5F5F5)],
        ),
      ),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: onSearch(query),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00008b)),
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No results found.',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            );
          } else {
            final searchResults = snapshot.data!;
            return ListView.builder(
              padding: EdgeInsets.all(12.0),
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final location = searchResults[index];
                return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                child: GestureDetector(
                onTap: () {
                Navigator.push(
                context,
                MaterialPageRoute(
                builder: (context) => SpotDetailScreen(
                locationId: location['id'] ?? '',
                title: location['title'] ?? 'Not title',
                description:
                location['description'] ?? 'Not Description',
                spot_description: location['spot_description'] ??
                'spot_description',
                latitude: location['latitude'] ?? 0.0,
                longitude: location['longitude'] ?? 0.0,
                imageUrl: location['imageUrl'] ?? '',
                sourceTitle:
                location['sourceTitle'] ?? 'Not Quote source',
                sourceLink: location['sourceLink'] ?? 'Not Link',
                url: location['url'] ?? '',
                animeName: '',
                userId: '',
                subMedia: (location['subMedia'] as List<dynamic>?)
                    ?.map((item) => item as Map<String, dynamic>)
                    .toList() ??
                [],
                ),
                ),
                );
                },
                child: Card(
                elevation: 4,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                children: [
                // 画像部分
                ClipRRect(
                borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                ),
                child: CachedNetworkImage(
                imageUrl: location['imageUrl'] ?? '',
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                color: Colors.grey[200],
                width: 120,
                height: 120,
                child: Center(
                child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                Color(0xFF00008b)),
                strokeWidth: 2,
                ),
                ),
                ),
                errorWidget: (context, url, error) => Container(
                color: Colors.grey[200],
                width: 120,
                height: 120,
                child: Icon(
                Icons.image_not_supported_outlined,
                color: Colors.grey[400],
                ),
                ),
                ),
                ),
                // テキスト部分
                Expanded(
                child: Container(
                height: 120,
                child: Stack(
                children: [
                Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(
                location['title'] ?? 'No title',
                style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF00008b),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                Expanded(
                child: Text(
                location['description'] ?? 'Not Description',
                style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                ),
                ),
                ],
                ),
                ),
                // お気に入りボタン
                Positioned(
                top: 4,
                right: 4,
                child: Container(
                decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                shape: BoxShape.circle,
                boxShadow: [
                BoxShadow(
                color: Colors.black12,
                spreadRadius: 1,
                blurRadius: 2,
                ),
                ],
                ),
                child: IconButton(
                icon: Icon(
                location['isFavorite']
                ? Icons.favorite
                    : Icons.favorite_border,
                color: Colors.redAccent,
                size: 20,
                ),
                onPressed: () => toggleFavorite(location['id']),
                padding: EdgeInsets.all(6),
                constraints: BoxConstraints(
                minWidth: 32,
                minHeight: 32,
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
                )
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
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey[300],
            ),
            SizedBox(height: 16),
            Text(
              '検索キーワードを入力してください',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}