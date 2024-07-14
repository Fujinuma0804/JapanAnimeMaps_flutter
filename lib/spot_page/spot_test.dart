import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SpotDetailScreen extends StatelessWidget {
  final String title;
  final String comment;
  final bool isCorrect;
  final double latitude;
  final double longitude;
  final String imageUrl;

  const SpotDetailScreen({
    Key? key,
    required this.title,
    required this.comment,
    required this.isCorrect,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // デバッグ用に座標と画像URLをコンソールに出力
    print('Debug: Latitude: $latitude, Longitude: $longitude');
    if (imageUrl.isNotEmpty) {
      print('Debug: Image URL: $imageUrl');
    } else {
      print('Debug: Image URL is empty');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('詳細'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                comment.isNotEmpty ? comment : 'なし',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                height: 200,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(child: Text('画像を読み込めませんでした'));
                        },
                      )
                    : const Center(child: Text('画像がありません')),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '地図:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(latitude, longitude), // 緯度と経度の順番に注意
                  zoom: 16,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('selected_location'),
                    position: LatLng(latitude, longitude), // 緯度と経度の順番に注意
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SpotTestScreen extends StatefulWidget {
  const SpotTestScreen({Key? key}) : super(key: key);

  @override
  _SpotTestScreenState createState() => _SpotTestScreenState();
}

class _SpotTestScreenState extends State<SpotTestScreen> {
  late User _user;
  late String _userId;
  late Stream<QuerySnapshot> _checkInsStream;
  bool _sortByTimestamp = true;

  @override
  void initState() {
    super.initState();
    _getUser();
    _fetchCheckIns();
  }

  Future<void> _getUser() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    _user = auth.currentUser!;
    _userId = _user.uid;
  }

  void _fetchCheckIns() {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('check_ins');

    if (_sortByTimestamp) {
      query = query.orderBy('timestamp', descending: true);
    } else {
      query = query.orderBy('title');
    }

    _checkInsStream = query.snapshots();
  }

  void _toggleSortOrder() {
    setState(() {
      _sortByTimestamp = !_sortByTimestamp;
      _fetchCheckIns();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('チェックインした場所'),
        actions: [
          IconButton(
            onPressed: () => _toggleSortOrder(),
            icon: Icon(_sortByTimestamp ? Icons.sort : Icons.sort_by_alpha),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _checkInsStream,
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('チェックインした場所がありません。'));
          }

          return ListView(
            padding: const EdgeInsets.all(8),
            children: snapshot.data!.docs.map((DocumentSnapshot document) {
              Map<String, dynamic> data =
                  document.data() as Map<String, dynamic>;

              // フィールド名とその値をデバッグ出力
              data.forEach((key, value) {
                print('Debug: Field: $key, Value: $value');
              });

              String title = data['title'] ?? 'タイトルなし';
              String comment = data['comment'] ?? '';
              bool isCorrect = data['isCorrect'] ?? false;
              double latitude = 0.0;
              double longitude = 0.0;
              String imageUrl = '';

              // locationIdを使ってlocationデータを取得する
              String locationId = data['locationId'];
              FirebaseFirestore.instance
                  .collection('locations')
                  .doc(locationId)
                  .get()
                  .then((locationDoc) {
                if (locationDoc.exists) {
                  Map<String, dynamic> locationData =
                      locationDoc.data() as Map<String, dynamic>;
                  latitude = locationData['latitude']?.toDouble() ?? 0.0;
                  longitude = locationData['longitude']?.toDouble() ?? 0.0;
                  imageUrl = locationData['imageUrl'] ?? '';
                  // デバッグ用に取得したデータを表示
                  print('Debug: Fetched Latitude: $latitude');
                  print('Debug: Fetched Longitude: $longitude');
                  print('Debug: Fetched Image URL: $imageUrl');
                }
              });

              return ListTile(
                title: Text(title),
                subtitle: Text(comment.isNotEmpty ? comment : 'コメントなし'),
                trailing: Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? Colors.green : Colors.red,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SpotDetailScreen(
                        title: title,
                        comment: comment,
                        isCorrect: isCorrect,
                        latitude: latitude,
                        longitude: longitude,
                        imageUrl: imageUrl,
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
