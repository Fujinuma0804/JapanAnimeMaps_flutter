import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../spot_page/check_in.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  List<Map<String, dynamic>> _locations = [];

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  Future<void> _fetchLocations() async {
    FirebaseFirestore.instance
        .collection('locations')
        .orderBy('checkinCount', descending: true)
        .get()
        .then((querySnapshot) {
      setState(() {
        _locations = querySnapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
      });
    }).catchError((error) {
      print('Error fetching locations: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '巡礼スポット',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SpotTestScreen()),
            );
          },
          icon: const Icon(
            Icons.check_circle,
            color: Color(0xFF00008b),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start, // Align items to the left
            children: [
              const Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 16.0), // Add some padding
                child: Text(
                  '■ 人気のスポット',
                  style: TextStyle(
                    color: Color(0xFF00008b),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 10.0), // Add some spacing
              ..._locations.map((location) => Column(
                    children: [
                      _buildImageCard(
                        context,
                        location['imageUrl'],
                        location['title'],
                        location['description'],
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailPage(
                              title: location['title'],
                              description: location['description'],
                              imagePath: location['imageUrl'],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10.0), // Add space between cards
                    ],
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageCard(BuildContext context, String imagePath,
      String textLine1, String textLine2, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Image.network(
            imagePath,
            fit: BoxFit.cover,
            width: double.infinity,
            height: MediaQuery.of(context).size.height /
                3, // Adjust height as needed
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).size.height /
                  6, // Adjust filter height as needed
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              padding: const EdgeInsets.all(8.0),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      textLine1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.0,
                      ),
                    ),
                    Text(
                      textLine2,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.0,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DetailPage extends StatelessWidget {
  final String title;
  final String description;
  final String imagePath;

  const DetailPage({
    Key? key,
    required this.title,
    required this.description,
    required this.imagePath,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Image.network(imagePath),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              description,
              style: const TextStyle(fontSize: 18.0),
            ),
          ),
        ],
      ),
    );
  }
}
