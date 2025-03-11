import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parts/spot_page/anime_list_en_detail.dart';

import 'anime_list_detail.dart';

class CheckInEnScreen extends StatefulWidget {
  const CheckInEnScreen({Key? key}) : super(key: key);

  @override
  _CheckInEnScreenState createState() => _CheckInEnScreenState();
}

class _CheckInEnScreenState extends State<CheckInEnScreen> {
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
      query = query.orderBy('titleEn');
    }

    _checkInsStream = query.snapshots();
  }

  void _toggleSortOrder() {
    setState(() {
      _sortByTimestamp = !_sortByTimestamp;
      _fetchCheckIns();
    });
  }

  void _navigateToDetails(BuildContext context, String locationId) async {
    DocumentSnapshot locationSnapshot = await FirebaseFirestore.instance
        .collection('locations')
        .doc(locationId)
        .get();

    if (locationSnapshot.exists) {
      Map<String, dynamic> locationData =
      locationSnapshot.data() as Map<String, dynamic>;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SpotDetailEnScreen(
            titleEn: locationData['titleEn'] ?? '',
            imageUrl: locationData['imageUrl'] ?? '',
            descriptionEn: locationData['descriptionEn'] ?? '',
            spot_description: locationData['spot_description'] ?? '',
            latitude: locationData['latitude'] as double? ?? 0.0,
            longitude: locationData['longitude'] as double? ?? 0.0,
            sourceLink: locationData['sourceLink'] as String? ?? '',
            sourceTitle: locationData['sourceTitle'] as String? ?? '',
            url: locationData['url'] as String? ?? '',
            subMedia: (locationData['subMedia'] as List?)
                ?.where((item) => item is Map<String, dynamic>)
                .cast<Map<String, dynamic>>()
                .toList() ??
                [],
            locationId: locationId,
            animeNameEn: locationData['animeNameEn'] ?? '',
            userId: locationData['userId'] ?? '',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location details not found.')),
      );
    }
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
            return const Center(child: Text('No checked-in locations found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              DocumentSnapshot document = snapshot.data!.docs[index];
              Map<String, dynamic> data = document.data() as Map<String, dynamic>;
              String locationId = data['locationId'] ?? '';

              // Debug display
              print('Check-in ID: ${document.id}');
              print('Location ID: $locationId');

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('locations')
                    .doc(locationId)
                    .get(),
                builder: (context, locationSnapshot) {
                  String title = 'No title';
                  String description = 'No subtitle';

                  if (locationSnapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      title: Text('Loading...'),
                      subtitle: Text('Loading location data'),
                      trailing: CircularProgressIndicator(),
                    );
                  }

                  if (locationSnapshot.hasData && locationSnapshot.data!.exists) {
                    Map<String, dynamic> locationData =
                    locationSnapshot.data!.data() as Map<String, dynamic>;
                    title = locationData['titleEn'] ?? 'No title';
                    description = locationData['descriptionEn'] ?? 'No subtitle';

                    // Debug display of location data
                    print('Location title: $title');
                    print('Location description: $description');
                  } else {
                    print('Location not found for ID: $locationId');
                  }

                  return ListTile(
                    title: Text(title),
                    subtitle: Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                    onTap: () {
                      _navigateToDetails(context, locationId);
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}