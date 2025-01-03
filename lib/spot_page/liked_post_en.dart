import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:translator/translator.dart';

import 'anime_list_detail.dart';

class FavoriteLocationsEnPage extends StatefulWidget {
  @override
  _FavoriteLocationsEnPageState createState() =>
      _FavoriteLocationsEnPageState();
}

class _FavoriteLocationsEnPageState extends State<FavoriteLocationsEnPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final translator = GoogleTranslator();
  String searchQuery = '';
  List<Map<String, dynamic>> cachedFavoriteLocations = [];
  bool isLoading = false;
  int currentPage = 1;
  final int itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      isLoading = true;
    });
    await _fetchFavoriteLocations();
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _fetchFavoriteLocations() async {
    try {
      User? user = auth.currentUser;
      if (user == null) {
        throw 'User is not logged in';
      }
      String userID = user.uid;

      QuerySnapshot favoriteSnapshot = await firestore
          .collection('users')
          .doc(userID)
          .collection('favorites')
          .limit(itemsPerPage)
          .get();

      List<Future<Map<String, dynamic>>> futures =
          favoriteSnapshot.docs.map((doc) async {
        String locationId = doc.id;
        DocumentSnapshot locationDoc =
            await firestore.collection('locations').doc(locationId).get();

        if (locationDoc.exists) {
          Map<String, dynamic> locationData =
              locationDoc.data() as Map<String, dynamic>;
          locationData['isFavorite'] = true;
          locationData['id'] = locationId;
          locationData['subMedia'] =
              (locationData['subMedia'] as List<dynamic>?)
                      ?.map((item) => item as Map<String, dynamic>)
                      .toList() ??
                  [];

          locationData['title'] = (await translator
                  .translate(locationData['title'] ?? 'No title', to: 'en'))
              .text;
          locationData['description'] = (await translator.translate(
                  locationData['description'] ?? 'No description',
                  to: 'en'))
              .text;

          return locationData;
        } else {
          return <String, dynamic>{};
        }
      }).toList();

      List<Map<String, dynamic>> newLocations = await Future.wait(futures);
      newLocations.removeWhere((location) => location.isEmpty);

      setState(() {
        cachedFavoriteLocations.addAll(newLocations);
        currentPage++;
      });
    } catch (e) {
      print("Error fetching favorite locations: $e");
    }
  }

  Future<List<Map<String, dynamic>>> _searchFavorites(String query) async {
    List<Map<String, dynamic>> searchResults = [];
    try {
      User? user = auth.currentUser;
      if (user == null) {
        throw 'User is not logged in';
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

            // 翻訳を追加し、text プロパティを取得
            locationData['title'] = (await translator
                    .translate(locationData['title'] ?? 'No title', to: 'en'))
                .text;
            locationData['description'] = (await translator.translate(
                    locationData['description'] ?? 'No description',
                    to: 'en'))
                .text;

            searchResults.add(locationData);
          }
        }
      }
    } catch (e) {
      print("Error searching favorites: $e");
    }
    return searchResults;
  }

  Future<void> _toggleFavorite(String locationId) async {
    try {
      User? user = auth.currentUser;
      if (user == null) {
        throw 'User is not logged in';
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
      print("Error toggling favorite: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Favorite Spots',
            style: TextStyle(
                color: Color(0xFF00008b), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () {
              showSearch(
                context: context,
                delegate: LocationSearchDelegate(
                    onSearch: _searchFavorites,
                    toggleFavorite: _toggleFavorite),
              );
            },
            icon: Icon(Icons.search, color: Color(0xFF00008b)),
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                if (!isLoading &&
                    scrollInfo.metrics.pixels ==
                        scrollInfo.metrics.maxScrollExtent) {
                  _fetchFavoriteLocations();
                  return true;
                }
                return false;
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                    childAspectRatio: 0.7,
                  ),
                  itemCount:
                      cachedFavoriteLocations.length + (isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == cachedFavoriteLocations.length) {
                      return Center(child: CircularProgressIndicator());
                    }
                    final location = cachedFavoriteLocations[index];
                    return _buildLocationCard(context, location);
                  },
                ),
              ),
            ),
    );
  }

  Widget _buildLocationCard(
      BuildContext context, Map<String, dynamic> location) {
    return GestureDetector(
      onTap: () => _navigateToDetails(context, location),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                  child: CachedNetworkImage(
                    imageUrl: location['imageUrl'] ?? '',
                    width: double.infinity,
                    height: 120,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                        color: Colors.grey[300],
                        child: Center(child: CircularProgressIndicator())),
                    errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300], child: Icon(Icons.error)),
                  ),
                ),
                IconButton(
                  icon: Icon(
                      location['isFavorite']
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: Colors.red),
                  onPressed: () => _toggleFavorite(location['id']),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location['title'] ?? 'No title',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  SizedBox(height: 4),
                  Text(
                    location['description'] ?? 'No description',
                    style: TextStyle(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
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
          title: location['title'] ?? 'No title',
          description: location['description'] ?? 'No description',
          spot_description:
              location['spot_description'] ?? 'No spot_description',
          latitude: location['latitude'] ?? 0.0,
          longitude: location['longitude'] ?? 0.0,
          imageUrl: location['imageUrl'] ?? '',
          sourceTitle: location['sourceTitle'] ?? 'No quote source',
          sourceLink: location['sourceLink'] ?? 'No link',
          url: location['url'] ?? '',
          subMedia: location['subMedia'] ?? [],
          animeName: '',
          userId: '',
        ),
      ),
    );
  }
}

class LocationSearchDelegate extends SearchDelegate {
  final Future<List<Map<String, dynamic>>> Function(String query) onSearch;
  final Future<void> Function(String locationId) toggleFavorite;

  LocationSearchDelegate({
    required this.onSearch,
    required this.toggleFavorite,
  });

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      appBarTheme: AppBarTheme(
        color: Color(0xFF00008b),
        foregroundColor: Colors.white,
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(color: Colors.white, fontSize: 18.0),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: onSearch(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No results found.'));
        } else {
          final searchResults = snapshot.data!;
          return ListView.builder(
            itemCount: searchResults.length,
            itemBuilder: (context, index) {
              final location = searchResults[index];
              return ListTile(
                leading: CachedNetworkImage(
                  imageUrl: location['imageUrl'] ?? '',
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => CircularProgressIndicator(),
                  errorWidget: (context, url, error) => Icon(Icons.error),
                ),
                title: Text(location['title'] ?? 'No title'),
                subtitle: Text(location['description'] ?? 'No description'),
                trailing: IconButton(
                  icon: Icon(
                    location['isFavorite']
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: Colors.red,
                  ),
                  onPressed: () async {
                    await toggleFavorite(location['id']);
                    showResults(context);
                  },
                ),
                onTap: () {
                  close(context, null);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SpotDetailScreen(
                        locationId: location['id'] ?? '',
                        title: location['title'] ?? 'No title',
                        description:
                            location['description'] ?? 'No description',
                        spot_description:
                            location['spot_description'] ?? 'spot_description',
                        latitude: location['latitude'] ?? 0.0,
                        longitude: location['longitude'] ?? 0.0,
                        imageUrl: location['imageUrl'] ?? '',
                        sourceTitle:
                            location['sourceTitle'] ?? 'No quote source',
                        sourceLink: location['sourceLink'] ?? 'No link',
                        url: location['url'] ?? '',
                        subMedia: location['subMedia'] ?? [],
                        animeName: '',
                        userId: '',
                      ),
                    ),
                  );
                },
              );
            },
          );
        }
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Container();
  }
}
