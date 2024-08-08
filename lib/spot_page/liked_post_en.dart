import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'anime_list_detail.dart'; // SpotDetailScreenをインポート

class FavoriteLocationsEnPage extends StatefulWidget {
  @override
  _FavoriteLocationsEnPageState createState() =>
      _FavoriteLocationsEnPageState();
}

class _FavoriteLocationsEnPageState extends State<FavoriteLocationsEnPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

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
        var data = doc.data() as Map<String, dynamic>;
        print('Favorite data for user $userID: $data');

        for (var key in data.keys) {
          if (key.startsWith('locationId')) {
            String locationId = data[key];
            print('Fetching location data for location ID: $locationId');

            DocumentSnapshot locationDoc =
                await firestore.collection('locations').doc(locationId).get();

            if (locationDoc.exists) {
              print('Location data for $locationId: ${locationDoc.data()}');
              favoriteLocations.add(locationDoc.data() as Map<String, dynamic>);
            } else {
              print("Location ID $locationId does not exist.");
            }
            break;
          }
        }
      }
    } catch (e) {
      print("Error fetching favorite locations: $e");
    }
    return favoriteLocations;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Favorite Spot',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
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
              padding: const EdgeInsets.symmetric(
                  horizontal: 8.0), // 左右に8.0のパディングを追加
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 3列に設定
                  crossAxisSpacing: 8.0,
                  mainAxisSpacing: 8.0,
                  childAspectRatio: 0.75, // 高さと幅の比率
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
                          // 画像の表示
                          Expanded(
                            child: Image.network(
                              location['imageUrl'] ?? '',
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
                          // タイトルと説明の表示
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
          title: location['title'] ?? 'Not title',
          description: location['description'] ?? 'Not Description',
          latitude: location['latitude'] ?? 0.0,
          longitude: location['longitude'] ?? 0.0,
          imageUrl: location['imageUrl'] ?? '',
          sourceTitle: location['sourceTitle'] ?? 'Not Quote source',
          sourceLink: location['sourceLink'] ?? 'Not Link',
        ),
      ),
    );
  }
}
