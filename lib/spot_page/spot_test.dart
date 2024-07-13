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
    // デバッグ用に座標をコンソールに出力
    print('Debug: Latitude: $latitude, Longitude: $longitude');

    return Scaffold(
      appBar: AppBar(
        title: const Text('場所の詳細'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '場所名: $title',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'コメント: ${comment.isNotEmpty ? comment : 'なし'}',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '正誤: ${isCorrect ? '正解' : '不正解'}',
              style: TextStyle(
                fontSize: 16,
                color: isCorrect ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(child: Text('画像を読み込めませんでした'));
                      },
                    )
                  : Center(child: Text('画像がありません')),
            ),
            const SizedBox(height: 16),
            Text(
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
                    markerId: MarkerId('selected_location'),
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
              String title = data['title'] ?? 'タイトルなし';
              String comment = data['comment'] ?? '';
              bool isCorrect = data['isCorrect'] ?? false;
              double latitude = data['latitude']?.toDouble() ?? 0.0;
              double longitude = data['longitude']?.toDouble() ?? 0.0;
              String imageUrl = data['imageUrl'] ?? '';

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
