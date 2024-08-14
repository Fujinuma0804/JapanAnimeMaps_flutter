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
        throw 'No user is logged in';
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
          if (locationData.containsKey('subMedia')) {
            locationData['subMedia'] =
                (locationData['subMedia'] as List<dynamic>?)
                        ?.map((item) => item as Map<String, dynamic>)
                        .toList() ??
                    [];
          } else {
            locationData['subMedia'] = [];
          }
          favoriteLocations.add(locationData);
        } else {
          print("Location ID $locationId does not exist.");
        }
      }
    } catch (e) {
      print("Error fetching favorite locations: $e");
    }
    return favoriteLocations;
  }

  Future<List<Map<String, dynamic>>> _searchFavorites(String query) async {
    List<Map<String, dynamic>> searchResults = [];
    try {
      User? user = auth.currentUser;
      if (user == null) {
        throw 'No user is logged in';
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

          if (title.contains(query) || description.contains(query)) {
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
      print("Error searching favorites: $e");
    }
    return searchResults;
  }

  Future<void> _toggleFavorite(String locationId) async {
    try {
      User? user = auth.currentUser;
      if (user == null) {
        throw 'No user is logged in';
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

      setState(() {});
    } catch (e) {
      print("Error toggling favorite: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'お気に入りスポット',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
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
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchFavoriteLocations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Favorite spot not found.'));
          } else {
            final favoriteLocations = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8.0,
                  mainAxisSpacing: 8.0,
                  childAspectRatio: 0.75,
                ),
                itemCount: favoriteLocations.length,
                itemBuilder: (context, index) {
                  final location = favoriteLocations[index];
                  return GestureDetector(
                    onTap: () => _navigateToDetails(context, location),
                    child: GridTile(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(9.0), // 角を丸くする半径を指定
                                  child: Image.network(
                                    location['imageUrl'] ?? '',
                                    width: 200,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  location['isFavorite']
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    _toggleFavorite(location['id']),
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  location['description'] ?? 'Not Description',
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
                },
              ),
            );
          }
        },
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
          latitude: location['latitude'] ?? 0.0,
          longitude: location['longitude'] ?? 0.0,
          imageUrl: location['imageUrl'] ?? '',
          sourceTitle: location['sourceTitle'] ?? 'Not Quote source',
          sourceLink: location['sourceLink'] ?? 'Not Link',
          url: location['url'] ?? '',
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
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
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
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
                childAspectRatio: 0.75,
              ),
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final location = searchResults[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SpotDetailScreen(
                          locationId: location['id'] ?? '',
                          title: location['title'] ?? 'Not title',
                          description:
                              location['description'] ?? 'Not Description',
                          latitude: location['latitude'] ?? 0.0,
                          longitude: location['longitude'] ?? 0.0,
                          imageUrl: location['imageUrl'] ?? '',
                          sourceTitle:
                              location['sourceTitle'] ?? 'Not Quote source',
                          sourceLink: location['sourceLink'] ?? 'Not Link',
                          url: location['url'] ?? '',
                          subMedia: (location['subMedia'] as List<dynamic>?)
                                  ?.map((item) => item as Map<String, dynamic>)
                                  .toList() ??
                              [],
                        ),
                      ),
                    );
                  },
                  child: GridTile(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9.0),
                                child: Image.network(
                                  location['imageUrl'] ?? '',
                                  width: 200,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                location['isFavorite']
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: Colors.red,
                              ),
                              onPressed: () => toggleFavorite(location['id']),
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
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              SizedBox(height: 4),
                              Text(
                                location['description'] ?? 'Not Description',
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
              },
            ),
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
