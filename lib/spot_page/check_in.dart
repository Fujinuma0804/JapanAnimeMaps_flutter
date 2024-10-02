import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'anime_list_detail.dart';

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
          builder: (context) => SpotDetailScreen(
            title: locationData['title'] ?? '',
            imageUrl: locationData['imageUrl'] ?? '',
            description: locationData['description'] ?? '',
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
            animeName: '',
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
          'チェックイン履歴',
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
              String locationId = data['locationId'] ?? '';
              bool isCorrect = data['isCorrect'] ?? false;

              return ListTile(
                title: Text(data['title'] ?? 'タイトルなし'),
                subtitle: Text(
                  data['description'] ?? 'サブタイトルなし',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? Colors.green : Colors.red,
                ),
                onTap: () {
                  _navigateToDetails(context, locationId);
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
