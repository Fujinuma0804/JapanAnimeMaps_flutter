import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SpotDetailScreen extends StatelessWidget {
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final String sourceTitle;
  final String sourceLink;

  const SpotDetailScreen({
    Key? key,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    required this.sourceTitle,
    required this.sourceLink,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Details',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            if (imageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  height: 200,
                  width: double.infinity,
                ),
              ),
            Align(
              alignment: FractionalOffset.centerRight,
              child: Text(
                sourceTitle,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10.0,
                ),
              ),
            ),
            Align(
              alignment: FractionalOffset.centerRight,
              child: Text(
                sourceLink,
                style: TextStyle(
                  fontSize: 10.0,
                  color: Colors.grey,
                ),
              ),
            ),
            SizedBox(
              height: 200,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(latitude, longitude),
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('spot_location'),
                    position: LatLng(latitude, longitude),
                  ),
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                description,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SpotTestScreenEn extends StatefulWidget {
  const SpotTestScreenEn({Key? key}) : super(key: key);

  @override
  _SpotTestScreenEnState createState() => _SpotTestScreenEnState();
}

class _SpotTestScreenEnState extends State<SpotTestScreenEn> {
  late User _user;
  late String _userId;
  late Stream<QuerySnapshot> _checkInsStream;
  bool _sortByTimestamp = true;
  int _correctCount = 0;

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

    _countAndSaveCorrectCheckIns();
  }

  Future<void> _countAndSaveCorrectCheckIns() async {
    int correctCount = 0;
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('check_ins')
        .get();

    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['isCorrect'] == true) {
        correctCount++;
      }
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .update({'correctCount': correctCount});

    setState(() {
      _correctCount = correctCount;
    });
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
        backgroundColor: Colors.white,
        title: const Text(
          'Check-in History',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _toggleSortOrder(),
            icon: Icon(
              _sortByTimestamp ? Icons.sort : Icons.sort_by_alpha,
              color: const Color(0xFF00008b),
            ),
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
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text('No check-in locations available.'));
          }

          return ListView(
            padding: const EdgeInsets.all(8),
            children: snapshot.data!.docs.map((DocumentSnapshot document) {
              Map<String, dynamic> data =
                  document.data() as Map<String, dynamic>;
              String locationId = data['locationId'] ?? '';
              bool isCorrect = data['isCorrect'] ?? false;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('locations')
                    .doc(locationId)
                    .get(),
                builder: (BuildContext context,
                    AsyncSnapshot<DocumentSnapshot> locationSnapshot) {
                  if (locationSnapshot.connectionState ==
                      ConnectionState.done) {
                    if (locationSnapshot.hasError) {
                      return ListTile(
                          title: Text('Error: ${locationSnapshot.error}'));
                    }

                    if (locationSnapshot.hasData &&
                        locationSnapshot.data!.exists) {
                      Map<String, dynamic> locationData =
                          locationSnapshot.data!.data() as Map<String, dynamic>;
                      String title = locationData['title'] ?? '';
                      String description = locationData['description'] ?? '';
                      double latitude = locationData['latitude'] ?? 0.0;
                      double longitude = locationData['longitude'] ?? 0.0;
                      String imageUrl = locationData['imageUrl'] ?? '';
                      String sourceTitle = locationData['sourceTitle'] ?? '';
                      String sourceLink = locationData['sourceLink'] ?? '';

                      return ListTile(
                        title: Text(title),
                        subtitle: Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                                description: description,
                                latitude: latitude,
                                longitude: longitude,
                                imageUrl: imageUrl,
                                sourceTitle: sourceTitle,
                                sourceLink: sourceLink,
                              ),
                            ),
                          );
                        },
                      );
                    }
                  }
                  return ListTile(title: Text('Loading...'));
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
