import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'anime_list_detail.dart';
import 'liked_maps.dart'; // SpotDetailScreenをインポート

class FavoriteLocationsPage extends StatefulWidget {
  @override
  _FavoriteLocationsPageState createState() => _FavoriteLocationsPageState();
}

class _FavoriteLocationsPageState extends State<FavoriteLocationsPage> {
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
              print("Location ID $locationId が存在しません。");
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
          'お気に入りのスポット',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => LikedMaps(
                          longitude: 0.0,
                          latitude: 0.0,
                        )),
              );
            },
            icon: Icon(
              Icons.map,
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
            return Center(child: Text('エラー: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('お気に入りのスポットが見つかりませんでした。'));
          } else {
            final favoriteLocations = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0, // 左右に8.0のパディングを追加
              ),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 3列に設定
                  childAspectRatio: 1.0, // 高さと幅の比率を1:1に設定
                  mainAxisSpacing: 10.0,
                  crossAxisSpacing: 10.0,
                ),
                itemCount: favoriteLocations.length,
                itemBuilder: (context, index) {
                  final location = favoriteLocations[index];
                  return GestureDetector(
                    onTap: () => _navigateToDetails(context, location),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(9.0),
                            child: Image.network(
                              location['imageUrl'] ?? '',
                              width: 200, // 画像サイズを調整
                              height: 100, // 画像サイズを調整
                              fit: BoxFit.cover,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            location['title'] ?? 'タイトルなし',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          Text(
                            location['description'] ?? '説明なし',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10.0), // 説明文のフォントサイズを調整
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
          title: location['title'] ?? '名称不明',
          description: location['description'] ?? '説明なし',
          latitude: location['latitude'] ?? 0.0,
          longitude: location['longitude'] ?? 0.0,
          imageUrl: location['imageUrl'] ?? '',
          sourceTitle: location['sourceTitle'] ?? '引用元なし',
          sourceLink: location['sourceLink'] ?? 'リンクなし',
        ),
      ),
    );
  }
}
